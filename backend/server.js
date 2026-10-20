const express = require('express');
const cors = require('cors');
const mysql = require('mysql2');
const bcrypt = require('bcryptjs');
const sqlite3 = require('sqlite3').verbose();
const crypto = require('crypto');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

const app = express();

app.use(cors({
    origin: true,
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept', 'X-Requested-With']
}));
app.use(express.json());

const DB_NAME = process.env.DB_NAME || 'volunteer_db';
const DB_USER = process.env.DB_USER || 'volunteer_app';
const DB_PASSWORD = process.env.DB_PASSWORD || 'volunteer123';
const DB_HOST = process.env.DB_HOST || '127.0.0.1';
const DB_PORT = Number(process.env.DB_PORT || 3306);
const DB_TYPE = process.env.DB_TYPE || 'sqlite';
const AUTH_TOKEN_SECRET =
    process.env.AUTH_TOKEN_SECRET || crypto.randomBytes(32).toString('hex');
const AUTH_TOKEN_LIFETIME_SECONDS = 60 * 60 * 12;

const dbFile = path.resolve(process.env.SQLITE_DB_PATH || path.join(__dirname, 'volunteer.db'));
const SQLITE_SCHEMA_VERSION = 2;
let db;
let sqliteTransactionQueue = Promise.resolve();
const isValidIsoDate = (value) => {
    if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
        return false;
    }
    const parsed = new Date(`${value}T00:00:00Z`);
    return !Number.isNaN(parsed.valueOf()) &&
        parsed.toISOString().slice(0, 10) === value;
};

const installSqliteQueryShim = (connection) => {
    connection.query = (sql, values, callback) => {
        if (typeof values === 'function') {
            callback = values;
            values = [];
        }

        const query = String(sql || '');
        const params = Array.isArray(values) ? values : values == null ? [] : [values];

        if (/^\s*SELECT\b/i.test(query)) {
            return connection.all(query, params, (err, rows) => {
                if (callback) callback(err, rows);
            });
        }

        return connection.run(query, params, function (err) {
            if (callback) {
                callback(err, {
                    insertId: this ? this.lastID : undefined,
                    affectedRows: this ? this.changes : 0,
                    changedRows: this ? this.changes : 0
                });
            }
        });
    };
};

const migrateLegacyPasswords = (connection, callback) => {
    connection.query(
        'SELECT id, password FROM users',
        async (selectErr, rows) => {
            if (selectErr) return callback(selectErr);

            const plaintextRows = rows.filter(
                (row) => typeof row.password === 'string' &&
                    !row.password.startsWith('$2'),
            );
            try {
                for (let index = 0; index < plaintextRows.length; index += 8) {
                    const batch = plaintextRows.slice(index, index + 8);
                    const hashedRows = await Promise.all(batch.map(async (row) => ({
                        id: row.id,
                        hash: await bcrypt.hash(String(row.password), 10)
                    })));
                    for (const row of hashedRows) {
                        await new Promise((resolve, reject) => {
                            connection.query(
                                'UPDATE users SET password = ? WHERE id = ?',
                                [row.hash, row.id],
                                (updateErr) => updateErr ? reject(updateErr) : resolve(),
                            );
                        });
                    }
                }
                callback();
            } catch (migrationErr) {
                callback(migrationErr);
            }
        },
    );
};

const migrateUserRoles = (connection, callback) => {
    if (DB_TYPE === 'sqlite') {
        const sqliteInstance = connection && typeof connection.all === 'function' ? connection : db;
        if (!sqliteInstance || typeof sqliteInstance.all !== 'function') {
            return callback(new Error('SQLite connection unavailable for role migration'));
        }

        sqliteInstance.all('PRAGMA table_info(users)', (err, columns) => {
            if (err) return callback(err);
            const colNames = (columns || []).map((c) => c.name);
            const actions = [];
            if (!colNames.includes('role_requested')) {
                actions.push((done) => sqliteInstance.run("ALTER TABLE users ADD COLUMN role_requested TEXT DEFAULT 'Volunteer'", done));
            }
            if (!colNames.includes('role_status')) {
                actions.push((done) => sqliteInstance.run("ALTER TABLE users ADD COLUMN role_status TEXT DEFAULT 'approved'", done));
            }

            const runNext = (index) => {
                if (index >= actions.length) {
                    sqliteInstance.run(
                        "UPDATE users SET role_requested = role WHERE role_requested IS NULL OR role_requested = '' OR role = 'Head Volunteer'",
                        () => {
                            sqliteInstance.run(
                                "UPDATE users SET role_status = 'approved' WHERE role_status IS NULL OR role_status = ''",
                                () => {
                                    sqliteInstance.run(`PRAGMA user_version = ${SQLITE_SCHEMA_VERSION}`, callback);
                                }
                            );
                        }
                    );
                    return;
                }
                actions[index]((actErr) => {
                    if (actErr) return callback(actErr);
                    runNext(index + 1);
                });
            };
            runNext(0);
        });
    } else {
        connection.query(`
            SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = ? AND TABLE_NAME = 'users' AND COLUMN_NAME IN ('role_requested', 'role_status')
        `, [DB_NAME], (err, rows) => {
            if (err) return callback(err);
            const found = (rows || []).map(r => r.COLUMN_NAME);
            const stmts = [];
            if (!found.includes('role_requested')) {
                stmts.push("ALTER TABLE users ADD COLUMN role_requested VARCHAR(50) NOT NULL DEFAULT 'Volunteer'");
            }
            if (!found.includes('role_status')) {
                stmts.push("ALTER TABLE users ADD COLUMN role_status ENUM('pending', 'approved', 'rejected') NOT NULL DEFAULT 'approved'");
            }
            const runMySQL = (index) => {
                if (index >= stmts.length) {
                    connection.query("UPDATE users SET role_requested = role WHERE role_requested IS NULL OR role = 'Head Volunteer'", () => {
                        connection.query("UPDATE users SET role_status = 'approved' WHERE role_status IS NULL", callback);
                    });
                    return;
                }
                connection.query(stmts[index], (mErr) => {
                    if (mErr) return callback(mErr);
                    runMySQL(index + 1);
                });
            };
            runMySQL(0);
        });
    }
};

const withDatabaseTransaction = (work, callback) => {
    const begin = (done) => DB_TYPE === 'sqlite'
        ? db.run('BEGIN IMMEDIATE', done)
        : db.beginTransaction(done);
    const commit = (done) => DB_TYPE === 'sqlite'
        ? db.run('COMMIT', done)
        : db.commit(done);
    const rollback = (done) => DB_TYPE === 'sqlite'
        ? db.run('ROLLBACK', done)
        : db.rollback(done);

    const run = () => new Promise((resolve) => {
        begin((beginErr) => {
            if (beginErr) {
                callback(beginErr);
                resolve();
                return;
            }
            work((workErr, result) => {
                if (workErr) {
                    return rollback(() => {
                        callback(workErr);
                        resolve();
                    });
                }
                commit((commitErr) => {
                    if (commitErr) {
                        return rollback(() => {
                            callback(commitErr);
                            resolve();
                        });
                    }
                    callback(null, result);
                    resolve();
                });
            });
        });
    });

    if (DB_TYPE === 'sqlite') {
        sqliteTransactionQueue = sqliteTransactionQueue.then(run, run);
    } else {
        run();
    }
};

const mysqlDbConfig = {
    host: DB_HOST,
    user: DB_USER,
    password: DB_PASSWORD,
    database: DB_NAME,
    port: DB_PORT,
    dateStrings: true,
    multipleStatements: true
};

const initializeDatabase = () => new Promise((resolve, reject) => {
    if (DB_TYPE === 'sqlite') {
        const sqliteDb = new sqlite3.Database(dbFile, (err) => {
            if (err) {
                console.error('SQLite connection failed:', err.message);
                return reject(err);
            }

            sqliteDb.run('PRAGMA busy_timeout = 5000', (timeoutErr) => {
                if (timeoutErr) {
                    sqliteDb.close(() => reject(timeoutErr));
                    return;
                }

                sqliteDb.run('PRAGMA foreign_keys = ON', (pragmaErr) => {
                if (pragmaErr) {
                    sqliteDb.close(() => reject(pragmaErr));
                    return;
                }

                sqliteDb.get('PRAGMA foreign_keys', (foreignKeyErr, foreignKeyRow) => {
                    if (foreignKeyErr || foreignKeyRow.foreign_keys !== 1) {
                        sqliteDb.close(() => reject(
                            foreignKeyErr || new Error('SQLite foreign-key enforcement could not be enabled')
                        ));
                        return;
                    }

                    sqliteDb.get('PRAGMA user_version', (versionErr, versionRow) => {
                        if (versionErr) {
                            sqliteDb.close(() => reject(versionErr));
                            return;
                        }

                        if (versionRow.user_version > SQLITE_SCHEMA_VERSION) {
                            sqliteDb.close(() => reject(new Error(
                                `SQLite database version ${versionRow.user_version} is newer than supported version ${SQLITE_SCHEMA_VERSION}`
                            )));
                            return;
                        }

                        sqliteDb.exec(`
                BEGIN IMMEDIATE;
                CREATE TABLE IF NOT EXISTS users (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name TEXT NOT NULL,
                    email TEXT COLLATE NOCASE UNIQUE NOT NULL,
                    student_id TEXT NOT NULL,
                    password TEXT NOT NULL,
                    role TEXT NOT NULL DEFAULT 'Volunteer',
                    role_requested TEXT NOT NULL DEFAULT 'Volunteer',
                    role_status TEXT NOT NULL DEFAULT 'approved',
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP
                );

                CREATE TABLE IF NOT EXISTS events (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name TEXT NOT NULL,
                    date TEXT NOT NULL,
                    location TEXT NOT NULL,
                    description TEXT,
                    volunteers_needed INTEGER,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP
                );

                CREATE TABLE IF NOT EXISTS tasks (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    event_id INTEGER NOT NULL,
                    task_name TEXT NOT NULL,
                    date TEXT NOT NULL,
                    start_time TEXT NOT NULL,
                    end_time TEXT NOT NULL,
                    location TEXT NOT NULL,
                    instructions TEXT,
                    volunteers_required INTEGER,
                    FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE
                );

                CREATE TABLE IF NOT EXISTS enrollments (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER NOT NULL,
                    task_id INTEGER NOT NULL,
                    status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected')),
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(user_id, task_id),
                    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                    FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
                );

                CREATE TABLE IF NOT EXISTS announcements (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    event_id INTEGER NOT NULL,
                    title TEXT NOT NULL,
                    message TEXT NOT NULL,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE
                );

                CREATE TABLE IF NOT EXISTS help_requests (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER NOT NULL,
                    event_id INTEGER NOT NULL,
                    message TEXT NOT NULL,
                    status TEXT NOT NULL DEFAULT 'open' CHECK(status IN ('open','resolved')),
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                    FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE
                );
                CREATE INDEX IF NOT EXISTS idx_events_date ON events(date);
                CREATE INDEX IF NOT EXISTS idx_tasks_event_id ON tasks(event_id);
                CREATE INDEX IF NOT EXISTS idx_enrollments_user_id ON enrollments(user_id);
                CREATE INDEX IF NOT EXISTS idx_enrollments_task_id ON enrollments(task_id);
                CREATE INDEX IF NOT EXISTS idx_announcements_event_id ON announcements(event_id);
                CREATE INDEX IF NOT EXISTS idx_help_requests_user_id ON help_requests(user_id);
                CREATE INDEX IF NOT EXISTS idx_help_requests_event_id ON help_requests(event_id);
                CREATE INDEX IF NOT EXISTS idx_help_requests_status ON help_requests(status);
                PRAGMA user_version = ${SQLITE_SCHEMA_VERSION};
                COMMIT;
            `, (execErr) => {
                            if (execErr) {
                                sqliteDb.exec('ROLLBACK', () => {
                                    sqliteDb.close(() => reject(execErr));
                                });
                                return;
                            }
                            db = sqliteDb;
                            installSqliteQueryShim(db);
                            migrateLegacyPasswords(db, (passwordErr) => {
                                if (passwordErr) {
                                    db = null;
                                    sqliteDb.close(() => reject(passwordErr));
                                    return;
                                }
                                migrateUserRoles(db, (roleErr) => {
                                    if (roleErr) {
                                        db = null;
                                        sqliteDb.close(() => reject(roleErr));
                                        return;
                                    }
                                    resolve();
                                });
                            });
                        });
                    });
                });
                });
            });
        });
        return;
    }

    const createTablesSql = `
        CREATE TABLE IF NOT EXISTS users (
            id INT PRIMARY KEY AUTO_INCREMENT,
            name VARCHAR(100) NOT NULL,
            email VARCHAR(255) UNIQUE NOT NULL,
            student_id VARCHAR(100) NOT NULL,
            password VARCHAR(255) NOT NULL,
            role VARCHAR(50) NOT NULL DEFAULT 'Volunteer',
            role_requested VARCHAR(50) NOT NULL DEFAULT 'Volunteer',
            role_status ENUM('pending', 'approved', 'rejected') NOT NULL DEFAULT 'approved',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS events (
            id INT PRIMARY KEY AUTO_INCREMENT,
            name VARCHAR(200) NOT NULL,
            date DATE NOT NULL,
            location VARCHAR(255) NOT NULL,
            description TEXT,
            volunteers_needed INT,
            KEY idx_events_date (date),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS tasks (
            id INT PRIMARY KEY AUTO_INCREMENT,
            event_id INT NOT NULL,
            task_name VARCHAR(200) NOT NULL,
            date DATE NOT NULL,
            start_time TIME NOT NULL,
            end_time TIME NOT NULL,
            location VARCHAR(255) NOT NULL,
            instructions TEXT,
            volunteers_required INT,
            KEY idx_tasks_event_id (event_id),
            FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS enrollments (
            id INT PRIMARY KEY AUTO_INCREMENT,
            user_id INT NOT NULL,
            task_id INT NOT NULL,
            status ENUM('pending', 'approved', 'rejected') NOT NULL DEFAULT 'pending',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY uq_user_task (user_id, task_id),
            KEY idx_enrollments_task_id (task_id),
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS announcements (
            id INT PRIMARY KEY AUTO_INCREMENT,
            event_id INT NOT NULL,
            title VARCHAR(255) NOT NULL,
            message TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            KEY idx_announcements_event_id (event_id),
            FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS help_requests (
            id INT PRIMARY KEY AUTO_INCREMENT,
            user_id INT NOT NULL,
            event_id INT NOT NULL,
            message TEXT NOT NULL,
            status ENUM('open', 'resolved') NOT NULL DEFAULT 'open',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            KEY idx_help_requests_user_id (user_id),
            KEY idx_help_requests_event_id (event_id),
            KEY idx_help_requests_status (status),
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS schema_migrations (
            version INT PRIMARY KEY,
            applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        INSERT IGNORE INTO schema_migrations (version) VALUES (1);
    `;

    const candidatePorts = Array.from(new Set([DB_PORT, 3306, 3307, 3308]));
    let lastError = null;

    const tryPort = (index) => {
        if (index >= candidatePorts.length) {
            console.error('MySQL connection failed during bootstrap. Checked ports:', candidatePorts.join(', '));
            console.error(lastError || 'Unknown bootstrap error');
            return reject(lastError || new Error('Unable to connect to MySQL bootstrap server'));
        }

        const port = candidatePorts[index];
        const bootstrap = mysql.createConnection({
            host: DB_HOST,
            user: 'root',
            password: '',
            port,
            multipleStatements: true
        });
        const dbUserLiteral = mysql.escape(DB_USER);
        const dbPasswordLiteral = mysql.escape(DB_PASSWORD);
        const dbNameIdentifier = mysql.escapeId(DB_NAME);

        bootstrap.connect((connectErr) => {
            if (connectErr) {
                lastError = connectErr;
                bootstrap.end(() => tryPort(index + 1));
                return;
            }

            bootstrap.query(`
                CREATE USER IF NOT EXISTS ${dbUserLiteral}@'localhost' IDENTIFIED WITH mysql_native_password BY ${dbPasswordLiteral};
                CREATE USER IF NOT EXISTS ${dbUserLiteral}@'127.0.0.1' IDENTIFIED WITH mysql_native_password BY ${dbPasswordLiteral};
                CREATE DATABASE IF NOT EXISTS ${dbNameIdentifier};
                REVOKE ALL PRIVILEGES, GRANT OPTION FROM ${dbUserLiteral}@'localhost';
                REVOKE ALL PRIVILEGES, GRANT OPTION FROM ${dbUserLiteral}@'127.0.0.1';
                GRANT ALL PRIVILEGES ON ${dbNameIdentifier}.* TO ${dbUserLiteral}@'localhost';
                GRANT ALL PRIVILEGES ON ${dbNameIdentifier}.* TO ${dbUserLiteral}@'127.0.0.1';
                FLUSH PRIVILEGES;
            `, (dbErr) => {
                if (dbErr) {
                    bootstrap.end(() => {
                        lastError = dbErr;
                        tryPort(index + 1);
                    });
                    return;
                }

                bootstrap.changeUser({ database: DB_NAME }, (changeErr) => {
                    if (changeErr) {
                        bootstrap.end(() => {
                            lastError = changeErr;
                            tryPort(index + 1);
                        });
                        return;
                    }

                    bootstrap.query(createTablesSql, (tableErr) => {
                        if (tableErr) {
                            return bootstrap.end(() => {
                                lastError = tableErr;
                                tryPort(index + 1);
                            });
                        }

                        migrateLegacyPasswords(bootstrap, (passwordErr) => {
                            if (passwordErr) {
                                return bootstrap.end(() => {
                                    lastError = passwordErr;
                                    tryPort(index + 1);
                                });
                            }
                            migrateUserRoles(bootstrap, (roleErr) => {
                                bootstrap.end(() => {
                                    if (roleErr) {
                                        lastError = roleErr;
                                        return tryPort(index + 1);
                                    }
                                    resolve();
                                });
                            });
                        });
                    });
                });
            });
        });
    };

    tryPort(0);
});

const BCRYPT_PREFIX = '$2';

const createAuthToken = (user) => {
    const payload = Buffer.from(JSON.stringify({
        sub: Number(user.id),
        role: user.role,
        exp: Math.floor(Date.now() / 1000) + AUTH_TOKEN_LIFETIME_SECONDS
    })).toString('base64url');
    const signature = crypto
        .createHmac('sha256', AUTH_TOKEN_SECRET)
        .update(payload)
        .digest('base64url');
    return `${payload}.${signature}`;
};

const requireAuth = (req, res, next) => {
    const authorization = req.get('authorization') || '';
    const match = authorization.match(/^Bearer ([A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)$/);
    if (!match) {
        return res.status(401).json({ message: 'Authentication is required' });
    }

    const [payload, signature] = match[1].split('.');
    const expected = crypto
        .createHmac('sha256', AUTH_TOKEN_SECRET)
        .update(payload)
        .digest();
    let supplied;
    let claims;

    try {
        supplied = Buffer.from(signature, 'base64url');
        claims = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
    } catch (err) {
        return res.status(401).json({ message: 'Invalid or expired session' });
    }

    if (!claims || typeof claims !== 'object' ||
        supplied.length !== expected.length ||
        !crypto.timingSafeEqual(supplied, expected) ||
        !Number.isInteger(claims.sub) ||
        typeof claims.role !== 'string' ||
        !Number.isInteger(claims.exp) ||
        claims.exp <= Math.floor(Date.now() / 1000)) {
        return res.status(401).json({ message: 'Invalid or expired session' });
    }

    req.authUser = { id: claims.sub, role: claims.role };
    next();
};

const requireHeadVolunteer = (req, res, next) => {
    db.query('SELECT role FROM users WHERE id = ?', [req.authUser.id], (err, rows) => {
        if (err) {
            console.error(err);
            return res.status(500).json({ message: 'Database error' });
        }
        if (rows.length === 0) {
            return res.status(401).json({ message: 'Account is no longer available' });
        }
        if (rows[0].role !== 'Head Volunteer') {
            return res.status(403).json({ message: 'Head Volunteer access is required' });
        }
        req.authUser.role = rows[0].role;
        next();
    });
};

// ===============================
// HOME & HEALTH
// ===============================

app.get('/', (req, res) => {
    res.send('Volunteer backend is running!');
});

app.get('/api/health', (req, res) => {
    res.status(200).json({
        status: 'ok',
        database: DB_TYPE,
        timestamp: new Date().toISOString()
    });
});


// ===============================
// REGISTER
// ===============================

app.post('/api/register', (req, res) => {

    const {
        name,
        email,
        student_id,
        password,
        role,
        role_requested
    } = req.body;

    if (!name || !email || !student_id || !password) {
        return res.status(400).json({
            message: 'All fields are required'
        });
    }

    const requestedRole = String(role || role_requested || '').trim();
    if (!requestedRole || (requestedRole !== 'Volunteer' && requestedRole !== 'Head Volunteer')) {
        return res.status(400).json({
            message: 'A valid role is required. Please select either Volunteer or Head Volunteer.'
        });
    }

    const normalizedEmail = String(email).trim().toLowerCase();
    const normalizedName = String(name).trim();
    const normalizedStudentId = String(student_id).trim();
    const passwordValue = String(password);
    const passwordBytes = Buffer.byteLength(passwordValue, 'utf8');

    if (!normalizedName || !normalizedEmail || !normalizedStudentId) {
        return res.status(400).json({ message: 'All fields are required' });
    }
    if (normalizedName.length > 100 ||
        normalizedStudentId.length > 100 ||
        normalizedEmail.length > 255 ||
        !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail)) {
        return res.status(400).json({ message: 'Enter valid name, email and student ID values' });
    }
    if (passwordValue.length < 6 || passwordBytes > 72) {
        return res.status(400).json({
            message: 'Password must be at least 6 characters and no more than 72 UTF-8 bytes'
        });
    }

    db.query(
        'SELECT id FROM users WHERE LOWER(email) = ?',
        [normalizedEmail],
        (lookupErr, existingUsers) => {
            if (lookupErr) {
                console.error(lookupErr);
                return res.status(500).json({ message: 'Database error' });
            }
            if (existingUsers.length > 0) {
                return res.status(409).json({ message: 'Email already registered' });
            }

            bcrypt.hash(passwordValue, 10, (hashErr, hash) => {
                if (hashErr) {
                    return res.status(500).json({
                        message: 'Failed to secure password'
                    });
                }

                // Security: Head Volunteer role request starts as Volunteer with pending approval.
                // Elevated permissions can only be granted by an authorized organizer/administrator.
                const assignedRole = 'Volunteer';
                const roleStatus = requestedRole === 'Head Volunteer' ? 'pending' : 'approved';

                const sql = `
                    INSERT INTO users
                    (name, email, student_id, password, role, role_requested, role_status)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                `;

                db.query(
                    sql,
                    [normalizedName, normalizedEmail, normalizedStudentId, hash, assignedRole, requestedRole, roleStatus],
                    (err, result) => {

                        if (err) {

                            if (err.code === 'ER_DUP_ENTRY' ||
                                err.code === 'SQLITE_CONSTRAINT' ||
                                err.code === 'SQLITE_CONSTRAINT_UNIQUE') {
                                return res.status(409).json({
                                    message: 'Email already registered'
                                });
                            }

                            console.error(err);

                            return res.status(500).json({
                                message: 'Database error'
                            });
                        }

                        const successMessage = requestedRole === 'Head Volunteer'
                            ? 'Account created! Your request for Head Volunteer access is pending administrator/organizer approval. You can currently log in as a Volunteer.'
                            : 'Account created successfully! You can now log in as a Volunteer.';

                        res.status(201).json({
                            message: successMessage,
                            userId: result.insertId,
                            role: assignedRole,
                            role_requested: requestedRole,
                            role_status: roleStatus
                        });
                    }
                );
            });
        },
    );
});


// ===============================
// LOGIN
// ===============================

app.post('/api/login', (req, res) => {

    const {
        email,
        password
    } = req.body;

    if (!email || !password) {
        return res.status(400).json({
            message: 'Email and password are required'
        });
    }

    const normalizedEmail = String(email).trim().toLowerCase();
    const sql = `
        SELECT
            id,
            name,
            email,
            student_id,
            password,
            role,
            COALESCE(role_requested, role) AS role_requested,
            COALESCE(role_status, 'approved') AS role_status
        FROM users
        WHERE LOWER(email) = ?
    `;

    db.query(
        sql,
        [normalizedEmail],
        (err, results) => {

            if (err) {
                console.error(err);

                return res.status(500).json({
                    message: 'Database error'
                });
            }

            if (results.length === 0) {
                return res.status(401).json({
                    message: 'Invalid email or password'
                });
            }

            const user = results[0];
            const stored = user.password;

            const verify = (match) => {
                if (!match) {
                    return res.status(401).json({
                        message: 'Invalid email or password'
                    });
                }

                // If this was an old plain-text password, upgrade it to a hash.
                if (!stored.startsWith(BCRYPT_PREFIX)) {
                    bcrypt.hash(String(password), 10, (hashErr, hash) => {
                        if (!hashErr) {
                            const upgradeSql = `UPDATE users SET password = ? WHERE id = ?`;
                            db.query(upgradeSql, [hash, user.id], () => {});
                        }
                    });
                }

                res.status(200).json({
                    message: 'Login successful',
                    token: createAuthToken(user),
                    user: {
                        id: user.id,
                        name: user.name,
                        email: user.email,
                        student_id: user.student_id,
                        role: user.role,
                        role_requested: user.role_requested,
                        role_status: user.role_status
                    }
                });
            };

            if (stored.startsWith(BCRYPT_PREFIX)) {
                bcrypt.compare(String(password), stored, (compareErr, match) => {
                    if (compareErr) {
                        return res.status(500).json({
                            message: 'Login error'
                        });
                    }
                    verify(match);
                });
            } else {
                // Backward compatibility for pre-bcrypt plain-text rows.
                verify(stored === String(password));
            }
        }
    );
});


// ===============================
// GET ALL EVENTS
// ===============================

app.get('/api/events', (req, res) => {

    const sql = `
        SELECT
            id,
            name,
            date,
            location,
            description,
            volunteers_needed
        FROM events
        ORDER BY date ASC
    `;

    db.query(sql, (err, results) => {

        if (err) {
            console.log(err);

            return res.status(500).json({
                message: 'Database error'
            });
        }

        res.status(200).json(results);
    });
});


// ===============================
// CREATE EVENT
// ===============================

app.post('/api/events', requireAuth, requireHeadVolunteer, (req, res) => {

    const {
        name,
        date,
        location,
        description,
        volunteers_needed
    } = req.body;
    const normalizedName = String(name || '').trim();
    const normalizedLocation = String(location || '').trim();
    const hasVolunteerLimit = volunteers_needed != null &&
        String(volunteers_needed).trim() !== '';
    const volunteerLimit = hasVolunteerLimit ? Number(volunteers_needed) : null;

    if (!normalizedName || !date || !normalizedLocation) {
        return res.status(400).json({
            message: 'Event name, date and location are required'
        });
    }
    if (normalizedName.length > 200 ||
        normalizedLocation.length > 255 ||
        !isValidIsoDate(date)) {
        return res.status(400).json({ message: 'Enter a valid event name, date and location' });
    }
    if (hasVolunteerLimit &&
        (!Number.isInteger(volunteerLimit) || volunteerLimit <= 0)) {
        return res.status(400).json({ message: 'Volunteers needed must be a positive whole number' });
    }

    const sql = `
        INSERT INTO events
        (name, date, location, description, volunteers_needed)
        VALUES (?, ?, ?, ?, ?)
    `;

    db.query(
        sql,
        [
            normalizedName,
            date,
            normalizedLocation,
            String(description || '').trim() || null,
            volunteerLimit
        ],
        (err, result) => {

            if (err) {
                console.log(err);

                return res.status(500).json({
                    message: 'Database error'
                });
            }

            res.status(201).json({
                message: 'Event created successfully',
                eventId: result.insertId
            });
        }
    );
});


// ===============================
// GET TASKS FOR AN EVENT
// ===============================

app.get('/api/events/:eventId/tasks', (req, res) => {

    const eventId = req.params.eventId;

    const sql = `
        SELECT
            id,
            event_id,
            task_name,
            date,
            start_time,
            end_time,
            location,
            instructions,
            volunteers_required
        FROM tasks
        WHERE event_id = ?
        ORDER BY date ASC, start_time ASC
    `;

    db.query(sql, [eventId], (err, results) => {

        if (err) {
            console.log(err);

            return res.status(500).json({
                message: 'Database error'
            });
        }

        res.status(200).json(results);
    });
});


// ===============================
// CREATE TASK
// ===============================

app.post('/api/tasks', requireAuth, requireHeadVolunteer, (req, res) => {

    const {
        event_id,
        task_name,
        date,
        start_time,
        end_time,
        location,
        instructions,
        volunteers_required
    } = req.body;
    const eventId = Number(event_id);
    const taskName = String(task_name || '').trim();
    const taskDate = String(date || '');
    const start = String(start_time || '');
    const end = String(end_time || '');
    const taskLocation = String(location || '').trim();
    const hasVolunteerLimit = volunteers_required != null &&
        String(volunteers_required).trim() !== '';
    const volunteerLimit = hasVolunteerLimit ? Number(volunteers_required) : null;

    if (!eventId || !taskName || !taskDate || !start || !end || !taskLocation) {
        return res.status(400).json({
            message: 'Event, task name, date, times and location are required'
        });
    }
    if (!Number.isSafeInteger(eventId) ||
        taskName.length > 200 ||
        taskLocation.length > 255 ||
        !isValidIsoDate(taskDate) ||
        !/^(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d$/.test(start) ||
        !/^(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d$/.test(end) ||
        start >= end) {
        return res.status(400).json({ message: 'Enter valid task details and a later end time' });
    }
    if (hasVolunteerLimit &&
        (!Number.isInteger(volunteerLimit) || volunteerLimit <= 0)) {
        return res.status(400).json({ message: 'Volunteers required must be a positive whole number' });
    }

    const checkSql = `SELECT id FROM events WHERE id = ?`;

    db.query(checkSql, [eventId], (checkErr, checkResults) => {

        if (checkErr) {
            console.log(checkErr);

            return res.status(500).json({
                message: 'Database error'
            });
        }

        if (checkResults.length === 0) {
            return res.status(400).json({
                message: 'Event does not exist'
            });
        }

        const sql = `
            INSERT INTO tasks
            (event_id, task_name, date, start_time, end_time, location, instructions, volunteers_required)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `;

        db.query(
            sql,
            [
                eventId,
                taskName,
                taskDate,
                start,
                end,
                taskLocation,
                String(instructions || '').trim() || null,
                volunteerLimit
            ],
            (err, result) => {

                if (err) {
                    console.log(err);

                    return res.status(500).json({
                        message: 'Database error'
                    });
                }

                res.status(201).json({
                    message: 'Task created successfully',
                    taskId: result.insertId
                });
            }
        );
    });
});


// ===============================
// ENROLL IN A TASK
// ===============================

app.post('/api/enroll', requireAuth, (req, res) => {

    const { user_id, task_id } = req.body;
    const userId = req.authUser.id;

    if (!task_id) {
        return res.status(400).json({
            message: 'task_id is required'
        });
    }

    if (user_id != null && Number(user_id) !== userId) {
        return res.status(403).json({ message: 'You cannot enroll another user' });
    }

    withDatabaseTransaction((finish) => {
        db.query('SELECT id FROM users WHERE id = ?', [userId], (userErr, users) => {
            if (userErr) return finish(userErr);
            if (users.length === 0) {
                return finish(null, {
                    status: 401,
                    message: 'Account is no longer available'
                });
            }

            const lockTask = DB_TYPE === 'sqlite' ? '' : ' FOR UPDATE';
            db.query(
                `SELECT id, volunteers_required FROM tasks WHERE id = ?${lockTask}`,
                [task_id],
                (taskErr, tasks) => {
                    if (taskErr) return finish(taskErr);
                    if (tasks.length === 0) {
                        return finish(null, { status: 404, message: 'Task does not exist' });
                    }

                    db.query(
                        'SELECT id, status FROM enrollments WHERE user_id = ? AND task_id = ?',
                        [userId, task_id],
                        (duplicateErr, enrollments) => {
                            if (duplicateErr) return finish(duplicateErr);
                            if (enrollments.length > 0 &&
                                enrollments[0].status !== 'rejected') {
                                return finish(null, {
                                    status: 409,
                                    message: 'You are already enrolled in this task'
                                });
                            }

                            const saveEnrollment = () => {
                                if (enrollments.length > 0) {
                                    return db.query(
                                        `UPDATE enrollments
                                         SET status = 'pending', created_at = CURRENT_TIMESTAMP
                                         WHERE id = ?`,
                                        [enrollments[0].id],
                                        (updateErr) => updateErr
                                            ? finish(updateErr)
                                            : finish(null, {
                                                status: 201,
                                                enrollmentId: enrollments[0].id
                                            }),
                                    );
                                }

                                db.query(
                                    `INSERT INTO enrollments (user_id, task_id, status)
                                     VALUES (?, ?, 'pending')`,
                                    [userId, task_id],
                                    (insertErr, result) => insertErr
                                        ? finish(insertErr)
                                        : finish(null, {
                                            status: 201,
                                            enrollmentId: result.insertId
                                        }),
                                );
                            };

                            const capacity = Number(tasks[0].volunteers_required);
                            if (!Number.isInteger(capacity) || capacity <= 0) {
                                return saveEnrollment();
                            }

                            db.query(
                                `SELECT COUNT(*) AS enrolled FROM enrollments
                                 WHERE task_id = ? AND status IN ('pending', 'approved')`,
                                [task_id],
                                (countErr, counts) => {
                                    if (countErr) return finish(countErr);
                                    if (Number(counts[0].enrolled) >= capacity) {
                                        return finish(null, {
                                            status: 409,
                                            message: 'This task has no remaining volunteer places'
                                        });
                                    }
                                    saveEnrollment();
                                },
                            );
                        },
                    );
                },
            );
        });
    }, (err, result) => {
        if (err) {
            if (err.code === 'ER_DUP_ENTRY' ||
                err.code === 'SQLITE_CONSTRAINT' ||
                err.code === 'SQLITE_CONSTRAINT_UNIQUE') {
                return res.status(409).json({
                    message: 'You are already enrolled in this task'
                });
            }
            console.error(err);
            return res.status(500).json({ message: 'Database error' });
        }
        if (result.status !== 201) {
            return res.status(result.status).json({ message: result.message });
        }
        res.status(201).json({
            message: 'Enrollment submitted',
            enrollmentId: result.enrollmentId,
            status: 'pending'
        });
    });
});


// ===============================
// GET ENROLLED TASKS FOR A USER (MY TASKS)
// ===============================

app.get('/api/users/:userId/tasks', requireAuth, (req, res) => {

    const userId = req.params.userId;
    if (Number(userId) !== req.authUser.id) {
        return res.status(403).json({ message: 'You cannot view another user\'s tasks' });
    }

    const sql = `
        SELECT
            e.id AS event_id,
            e.name AS event_name,
            t.id AS task_id,
            t.task_name,
            t.date,
            t.start_time,
            t.end_time,
            t.location,
            t.instructions,
            en.id AS enrollment_id,
            en.status
        FROM enrollments en
        JOIN tasks t ON en.task_id = t.id
        JOIN events e ON t.event_id = e.id
        WHERE en.user_id = ?
        ORDER BY t.date ASC, t.start_time ASC
    `;

    db.query(sql, [userId], (err, results) => {

        if (err) {
            console.log(err);

            return res.status(500).json({
                message: 'Database error'
            });
        }

        res.status(200).json(results);
    });
});

app.put('/api/users/:userId/profile', requireAuth, (req, res) => {
    const userId = Number(req.params.userId);
    if (userId !== req.authUser.id) {
        return res.status(403).json({ message: 'You cannot edit another user\'s profile' });
    }

    const name = String(req.body.name || '').trim();
    const studentId = String(req.body.student_id || '').trim();
    if (!name || !studentId) {
        return res.status(400).json({ message: 'Name and student ID are required' });
    }
    if (name.length > 100 || studentId.length > 100) {
        return res.status(400).json({ message: 'Name and student ID must be 100 characters or fewer' });
    }

    db.query('SELECT id FROM users WHERE id = ?', [userId], (lookupErr, rows) => {
        if (lookupErr) {
            console.error(lookupErr);
            return res.status(500).json({ message: 'Database error' });
        }
        if (rows.length === 0) {
            return res.status(404).json({ message: 'User not found' });
        }
        db.query(
            'UPDATE users SET name = ?, student_id = ? WHERE id = ?',
            [name, studentId, userId],
            (err) => {
                if (err) {
                    console.error(err);
                    return res.status(500).json({ message: 'Database error' });
                }
                res.status(200).json({
                    message: 'Profile updated',
                    user: { id: userId, name, student_id: studentId }
                });
            }
        );
    });
});


// ===============================
// AUTH PROFILE / CURRENT USER
// ===============================

app.get('/api/auth/me', requireAuth, (req, res) => {
    const sql = `
        SELECT
            id,
            name,
            email,
            student_id,
            role,
            COALESCE(role_requested, role) AS role_requested,
            COALESCE(role_status, 'approved') AS role_status,
            created_at
        FROM users
        WHERE id = ?
    `;
    db.query(sql, [req.authUser.id], (err, rows) => {
        if (err) {
            console.error(err);
            return res.status(500).json({ message: 'Database error' });
        }
        if (rows.length === 0) {
            return res.status(404).json({ message: 'User not found' });
        }
        res.status(200).json({ user: rows[0] });
    });
});


// ===============================
// ROLE REQUESTS (HEAD VOLUNTEER / ORGANIZER)
// ===============================

app.get('/api/role-requests', requireAuth, requireHeadVolunteer, (req, res) => {
    const sql = `
        SELECT
            id,
            name,
            email,
            student_id,
            role,
            COALESCE(role_requested, role) AS role_requested,
            COALESCE(role_status, 'approved') AS role_status,
            created_at
        FROM users
        WHERE role_requested = 'Head Volunteer' OR role = 'Head Volunteer'
        ORDER BY
            CASE WHEN role_status = 'pending' THEN 0 ELSE 1 END,
            created_at DESC
    `;
    db.query(sql, [], (err, rows) => {
        if (err) {
            console.error(err);
            return res.status(500).json({ message: 'Database error' });
        }
        res.status(200).json(rows);
    });
});

app.put('/api/role-requests/:userId', requireAuth, requireHeadVolunteer, (req, res) => {
    const targetUserId = Number(req.params.userId);
    const { action } = req.body;

    if (!Number.isInteger(targetUserId) || targetUserId <= 0) {
        return res.status(400).json({ message: 'Invalid user ID' });
    }

    if (action !== 'approve' && action !== 'reject') {
        return res.status(400).json({ message: 'Action must be "approve" or "reject"' });
    }

    const newRole = action === 'approve' ? 'Head Volunteer' : 'Volunteer';
    const newStatus = action === 'approve' ? 'approved' : 'rejected';

    const sql = `
        UPDATE users
        SET role = ?, role_status = ?
        WHERE id = ?
    `;

    db.query(sql, [newRole, newStatus, targetUserId], (err, result) => {
        if (err) {
            console.error(err);
            return res.status(500).json({ message: 'Database error' });
        }
        if (result.affectedRows === 0) {
            return res.status(404).json({ message: 'User not found' });
        }
        res.status(200).json({
            message: `Role request ${action === 'approve' ? 'approved' : 'rejected'} successfully`,
            userId: targetUserId,
            role: newRole,
            role_status: newStatus
        });
    });
});


// ===============================
// GET VOLUNTEERS FOR A TASK
// ===============================

app.get('/api/tasks/:taskId/volunteers', requireAuth, requireHeadVolunteer, (req, res) => {

    const taskId = req.params.taskId;

    const sql = `
        SELECT
            en.id AS enrollment_id,
            u.id AS user_id,
            u.name,
            u.email,
            u.student_id,
            t.task_name,
            t.date,
            en.status
        FROM enrollments en
        JOIN users u ON en.user_id = u.id
        JOIN tasks t ON en.task_id = t.id
        WHERE en.task_id = ?
        ORDER BY en.status ASC, en.id DESC
    `;

    db.query(sql, [taskId], (err, results) => {

        if (err) {
            console.log(err);

            return res.status(500).json({
                message: 'Database error'
            });
        }

        res.status(200).json(results);
    });
});


// ===============================
// GET ALL ENROLLMENTS (VOLUNTEER REQUESTS)
// ===============================

app.get('/api/enrollments', requireAuth, requireHeadVolunteer, (req, res) => {

    const status = req.query.status;

    let sql = `
        SELECT
            en.id AS enrollment_id,
            u.id AS user_id,
            u.name,
            u.email,
            u.student_id,
            t.id AS task_id,
            t.task_name,
            e.id AS event_id,
            e.name AS event_name,
            en.status
        FROM enrollments en
        JOIN users u ON en.user_id = u.id
        JOIN tasks t ON en.task_id = t.id
        JOIN events e ON t.event_id = e.id
    `;

    const params = [];

    if (status) {
        sql += ` WHERE en.status = ?`;
        params.push(status);
    }

    sql += ` ORDER BY en.id DESC`;

    db.query(sql, params, (err, results) => {

        if (err) {
            console.log(err);

            return res.status(500).json({
                message: 'Database error'
            });
        }

        res.status(200).json(results);
    });
});


// ===============================
// UPDATE ENROLLMENT STATUS (APPROVE / REJECT)
// ===============================

app.put('/api/enrollments/:enrollmentId/status', requireAuth, requireHeadVolunteer, (req, res) => {

    const enrollmentId = req.params.enrollmentId;
    const { status } = req.body;

    const allowed = ['pending', 'approved', 'rejected'];

    if (!status || !allowed.includes(status)) {
        return res.status(400).json({
            message: 'Status must be one of: pending, approved, rejected'
        });
    }

    const sql = `UPDATE enrollments SET status = ? WHERE id = ?`;

    db.query(sql, [status, enrollmentId], (err, result) => {

        if (err) {
            console.log(err);

            return res.status(500).json({
                message: 'Database error'
            });
        }

        if (result.affectedRows === 0) {
            return res.status(404).json({
                message: 'Enrollment not found'
            });
        }

        res.status(200).json({
            message: `Enrollment ${status}`,
            enrollmentId: Number(enrollmentId)
        });
    });
});


// ===============================
// GET ALL ANNOUNCEMENTS
// ===============================

app.get('/api/announcements', (req, res) => {

    const sql = `
        SELECT
            a.id,
            a.event_id,
            e.name AS event_name,
            a.title,
            a.message,
            a.created_at
        FROM announcements a
        JOIN events e ON a.event_id = e.id
        ORDER BY a.created_at DESC
    `;

    db.query(sql, (err, results) => {

        if (err) {
            console.log(err);

            return res.status(500).json({
                message: 'Database error'
            });
        }

        res.status(200).json(results);
    });
});


// ===============================
// GET ANNOUNCEMENTS FOR AN EVENT
// ===============================

app.get('/api/events/:eventId/announcements', (req, res) => {

    const eventId = req.params.eventId;

    const sql = `
        SELECT
            id,
            event_id,
            title,
            message,
            created_at
        FROM announcements
        WHERE event_id = ?
        ORDER BY created_at DESC
    `;

    db.query(sql, [eventId], (err, results) => {

        if (err) {
            console.log(err);

            return res.status(500).json({
                message: 'Database error'
            });
        }

        res.status(200).json(results);
    });
});


// ===============================
// CREATE ANNOUNCEMENT
// ===============================

app.post('/api/announcements', requireAuth, requireHeadVolunteer, (req, res) => {

    const {
        event_id,
        title,
        message
    } = req.body;

    if (!event_id || !title || !message) {
        return res.status(400).json({
            message: 'event_id, title and message are required'
        });
    }

    const checkSql = `SELECT id FROM events WHERE id = ?`;

    db.query(checkSql, [event_id], (checkErr, checkResults) => {

        if (checkErr) {
            console.log(checkErr);

            return res.status(500).json({
                message: 'Database error'
            });
        }

        if (checkResults.length === 0) {
            return res.status(400).json({
                message: 'Event does not exist'
            });
        }

        const sql = `
            INSERT INTO announcements
            (event_id, title, message, created_at)
            VALUES (?, ?, ?, CURRENT_TIMESTAMP)
        `;

        db.query(sql, [event_id, title, message], (err, result) => {

            if (err) {
                console.log(err);

                return res.status(500).json({
                    message: 'Database error'
                });
            }

            res.status(201).json({
                message: 'Announcement published',
                announcementId: result.insertId
            });
        });
    });
});


// ===============================
// SUBMIT HELP REQUEST
// ===============================

app.post('/api/help-requests', requireAuth, (req, res) => {

    const {
        user_id,
        event_id,
        message
    } = req.body;
    const userId = req.authUser.id;

    if (!event_id || !message) {
        return res.status(400).json({
            message: 'event_id and message are required'
        });
    }

    if (user_id != null && Number(user_id) !== userId) {
        return res.status(403).json({ message: 'You cannot submit a request for another user' });
    }

    const checkEventSql = `SELECT id FROM events WHERE id = ?`;

    db.query(checkEventSql, [event_id], (checkErr, checkResults) => {

        if (checkErr) {
            console.log(checkErr);

            return res.status(500).json({
                message: 'Database error'
            });
        }

        if (checkResults.length === 0) {
            return res.status(400).json({
                message: 'Event does not exist'
            });
        }

        const sql = `
            INSERT INTO help_requests
            (user_id, event_id, message, status, created_at)
            VALUES (?, ?, ?, 'open', CURRENT_TIMESTAMP)
        `;

        db.query(sql, [userId, event_id, message], (err, result) => {

            if (err) {
                console.log(err);

                return res.status(500).json({
                    message: 'Database error'
                });
            }

            res.status(201).json({
                message: 'Help request sent',
                requestId: result.insertId
            });
        });
    });
});


// ===============================
// GET ALL HELP REQUESTS
// ===============================

app.get('/api/help-requests', requireAuth, requireHeadVolunteer, (req, res) => {

    const status = req.query.status;

    let sql = `
        SELECT
            hr.id,
            u.id AS user_id,
            u.name,
            u.email,
            u.student_id,
            e.id AS event_id,
            e.name AS event_name,
            hr.message,
            hr.status,
            hr.created_at
        FROM help_requests hr
        JOIN users u ON hr.user_id = u.id
        JOIN events e ON hr.event_id = e.id
    `;

    const params = [];

    if (status) {
        sql += ` WHERE hr.status = ?`;
        params.push(status);
    }

    sql += ` ORDER BY hr.created_at DESC`;

    db.query(sql, params, (err, results) => {

        if (err) {
            console.log(err);

            return res.status(500).json({
                message: 'Database error'
            });
        }

        res.status(200).json(results);
    });
});


// ===============================
// UPDATE HELP REQUEST STATUS
// ===============================

app.put('/api/help-requests/:requestId/status', requireAuth, requireHeadVolunteer, (req, res) => {

    const requestId = req.params.requestId;
    const { status } = req.body;

    const allowed = ['open', 'resolved'];

    if (!status || !allowed.includes(status)) {
        return res.status(400).json({
            message: 'Status must be one of: open, resolved'
        });
    }

    const sql = `UPDATE help_requests SET status = ? WHERE id = ?`;

    db.query(sql, [status, requestId], (err, result) => {

        if (err) {
            console.log(err);

            return res.status(500).json({
                message: 'Database error'
            });
        }

        if (result.affectedRows === 0) {
            return res.status(404).json({
                message: 'Help request not found'
            });
        }

        res.status(200).json({
            message: `Help request ${status}`,
            requestId: Number(requestId)
        });
    });
});


// ===============================
// START SERVER
// ===============================

const PORT = Number(process.env.PORT || 3000);

const startServer = () => {
    app.listen(PORT, '0.0.0.0', () => {
        console.log(`Server running on http://0.0.0.0:${PORT}`);
    });
};

const closeDatabase = () => new Promise((resolve, reject) => {
    if (!db || typeof db.close !== 'function') {
        resolve();
        return;
    }

    const connection = db;
    db = null;
    connection.close((err) => err ? reject(err) : resolve());
});

if (require.main === module) {
    initializeDatabase()
        .then(() => {
        if (DB_TYPE === 'sqlite') {
            if (!db || typeof db.query !== 'function') {
                db = new sqlite3.Database(dbFile, sqlite3.OPEN_READWRITE, (sqliteErr) => {
                    if (sqliteErr) {
                        console.error('SQLite connection failed:', sqliteErr.message);
                        process.exit(1);
                        return;
                    }
                    installSqliteQueryShim(db);
                    console.log('SQLite connected successfully!');
                    startServer();
                });
                return;
            }
            console.log('SQLite connected successfully!');
            startServer();
            return;
        }

        db = mysql.createConnection(mysqlDbConfig);

        db.connect((err) => {
            if (err) {
                console.error('MySQL connection failed:');
                console.error(err);
                process.exit(1);
                return;
            }

            console.log('MySQL connected successfully!');
            startServer();
        });

        db.on('error', (err) => {
            console.error('MySQL connection error:', err.message);
            if (err.code === 'PROTOCOL_CONNECTION_LOST') {
                console.error('MySQL connection was lost. Restart backend to reconnect.');
            }
        });
    })
    .catch((err) => {
        console.error('Database initialization failed.');
        console.error(err);
        process.exit(1);
    });
}

module.exports = {
    app,
    initializeDatabase,
    closeDatabase,
    getDatabase: () => db
};