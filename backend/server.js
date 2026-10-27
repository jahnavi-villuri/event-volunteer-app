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
const SQLITE_SCHEMA_VERSION = 4;
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
const validateTaskCompensation = (body, existing = {}) => {
    const type = body.compensation_type === undefined
        ? existing.compensation_type || 'unpaid'
        : String(body.compensation_type).trim().toLowerCase();
    const amountValue = body.compensation_amount === undefined
        ? existing.compensation_amount
        : body.compensation_amount;
    const amount = amountValue == null || String(amountValue).trim() === ''
        ? null
        : Number(amountValue);
    const currency = body.compensation_currency === undefined
        ? existing.compensation_currency || 'INR'
        : String(body.compensation_currency).trim().toUpperCase();
    const terms = body.compensation_terms === undefined
        ? existing.compensation_terms
        : String(body.compensation_terms || '').trim() || null;
    const requirements = body.additional_requirements === undefined
        ? existing.additional_requirements
        : String(body.additional_requirements || '').trim() || null;

    if (!['unpaid', 'fixed', 'hourly'].includes(type)) {
        return { error: 'Compensation type must be unpaid, fixed, or hourly' };
    }
    if (type === 'unpaid' && amount !== null) {
        return { error: 'Unpaid tasks cannot have a compensation amount' };
    }
    if (type !== 'unpaid' &&
        (amount === null || !Number.isFinite(amount) || amount < 0 || amount > 99999999.99)) {
        return { error: 'Paid tasks require a valid non-negative compensation amount' };
    }
    if (!/^[A-Z]{3}$/.test(currency)) {
        return { error: 'Currency must be a 3-letter code' };
    }
    if ((terms && terms.length > 2000) ||
        (requirements && requirements.length > 2000)) {
        return { error: 'Compensation terms and requirements must be 2000 characters or fewer' };
    }
    return {
        type,
        amount: type === 'unpaid' ? null : amount,
        currency,
        terms,
        requirements
    };
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

const migrateMysqlEventWorkflows = (connection, callback) => {
    const definitions = {
        users: { phone: 'VARCHAR(40) NULL', area: 'VARCHAR(120) NULL' },
        events: {
            category: 'VARCHAR(100) NULL',
            start_time: 'TIME NULL',
            end_time: 'TIME NULL',
            area: 'VARCHAR(120) NULL',
            address: 'VARCHAR(500) NULL',
            required_roles: 'TEXT NULL',
            meeting_point: 'VARCHAR(255) NULL',
            reporting_instructions: 'TEXT NULL',
            instructions: 'TEXT NULL',
            contact_phone: 'VARCHAR(40) NULL',
            image_url: 'VARCHAR(2048) NULL',
            registration_deadline: 'DATE NULL',
            status: "VARCHAR(30) NOT NULL DEFAULT 'published'",
            published_at: 'TIMESTAMP NULL',
            created_by: 'INT NULL',
            responsible_head_id: 'INT NULL',
            admin_override: 'TINYINT(1) NOT NULL DEFAULT 0',
            admin_override_by: 'INT NULL',
            admin_override_at: 'TIMESTAMP NULL',
            cancelled_at: 'TIMESTAMP NULL'
        },
        tasks: {
            description: 'TEXT NULL',
            status: "VARCHAR(30) NOT NULL DEFAULT 'Open'",
            location_is_independent: 'TINYINT(1) NOT NULL DEFAULT 1',
            compensation_type: "VARCHAR(20) NOT NULL DEFAULT 'unpaid'",
            compensation_amount: 'DECIMAL(10, 2) NULL',
            compensation_currency: "CHAR(3) NOT NULL DEFAULT 'INR'",
            compensation_terms: 'TEXT NULL',
            additional_requirements: 'TEXT NULL'
        }
    };
    const tables = Object.keys(definitions);
    const tableSql = `
        CREATE TABLE IF NOT EXISTS event_registrations (
            id INT PRIMARY KEY AUTO_INCREMENT,
            event_id INT NOT NULL,
            user_id INT NOT NULL,
            selected_location VARCHAR(255) NOT NULL,
            status VARCHAR(30) NOT NULL DEFAULT 'confirmed',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY uq_event_user (event_id, user_id),
            KEY idx_event_registrations_user (user_id, created_at),
            FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        );
        CREATE TABLE IF NOT EXISTS notifications (
            id INT PRIMARY KEY AUTO_INCREMENT,
            user_id INT NOT NULL,
            event_id INT NULL,
            title VARCHAR(255) NOT NULL,
            message TEXT NOT NULL,
            type VARCHAR(50) NOT NULL,
            read_at TIMESTAMP NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            KEY idx_notifications_user (user_id, read_at, created_at),
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE
        );
        CREATE TABLE IF NOT EXISTS event_history (
            id INT PRIMARY KEY AUTO_INCREMENT,
            event_id INT NOT NULL,
            actor_id INT NULL,
            entity_type VARCHAR(30) NOT NULL,
            action VARCHAR(50) NOT NULL,
            details TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            KEY idx_event_history_event (event_id, created_at),
            FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE
        );
    `;
    const addColumns = (tableIndex) => {
        if (tableIndex >= tables.length) {
            return connection.query(tableSql, (tableErr) => {
                if (tableErr) return callback(tableErr);
                connection.query(
                    'UPDATE events SET responsible_head_id = created_by WHERE responsible_head_id IS NULL AND created_by IS NOT NULL',
                    (ownerErr) => {
                        if (ownerErr) return callback(ownerErr);
                        connection.query(
                            'INSERT IGNORE INTO schema_migrations (version) VALUES (2), (3)',
                            callback,
                        );
                    },
                );
            });
        }
        const table = tables[tableIndex];
        connection.query(
            `SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
             WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?`,
            [DB_NAME, table],
            (lookupErr, rows) => {
                if (lookupErr) return callback(lookupErr);
                const existing = new Set((rows || []).map((row) => row.COLUMN_NAME));
                const additions = Object.entries(definitions[table])
                    .filter(([name]) => !existing.has(name));
                const addNext = (columnIndex) => {
                    if (columnIndex >= additions.length) return addColumns(tableIndex + 1);
                    const [name, definition] = additions[columnIndex];
                    connection.query(
                        `ALTER TABLE ${table} ADD COLUMN ${name} ${definition}`,
                        (alterErr) => alterErr ? callback(alterErr) : addNext(columnIndex + 1),
                    );
                };
                addNext(0);
            },
        );
    };
    addColumns(0);
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
                                    sqliteInstance.run(
                                        "UPDATE users SET role = 'Head Volunteer', role_status = 'approved' WHERE role_requested = 'Head Volunteer'",
                                        (headRoleErr) => {
                                            if (headRoleErr) return callback(headRoleErr);
                                            sqliteInstance.run(`PRAGMA user_version = ${SQLITE_SCHEMA_VERSION}`, (versionErr) => {
                                                if (versionErr) return callback(versionErr);
                                                migrateEventWorkflows(sqliteInstance, callback);
                                            });
                                        },
                                    );
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

            const migrateEventWorkflows = (connection, callback) => {
                const sqliteInstance = DB_TYPE === 'sqlite'
                    ? connection && typeof connection.all === 'function' ? connection : db
                    : null;
                const sqliteColumns = {
                    users: {
                        phone: 'TEXT',
                        area: 'TEXT'
                    },
                    events: {
                        category: 'TEXT',
                        start_time: 'TEXT',
                        end_time: 'TEXT',
                        area: 'TEXT',
                        address: 'TEXT',
                        required_roles: 'TEXT',
                        meeting_point: 'TEXT',
                        reporting_instructions: 'TEXT',
                        instructions: 'TEXT',
                        contact_phone: 'TEXT',
                        image_url: 'TEXT',
                        registration_deadline: 'TEXT',
                        status: "TEXT NOT NULL DEFAULT 'published'",
                        published_at: 'TEXT',
                        created_by: 'INTEGER',
                        responsible_head_id: 'INTEGER',
                        admin_override: 'INTEGER NOT NULL DEFAULT 0',
                        admin_override_by: 'INTEGER',
                        admin_override_at: 'TEXT',
                        cancelled_at: 'TEXT'
                    },
                    tasks: {
                        description: 'TEXT',
                        status: "TEXT NOT NULL DEFAULT 'Open'",
                        location_is_independent: 'INTEGER NOT NULL DEFAULT 1',
                        compensation_type: "TEXT NOT NULL DEFAULT 'unpaid'",
                        compensation_amount: 'NUMERIC',
                        compensation_currency: "TEXT NOT NULL DEFAULT 'INR'",
                        compensation_terms: 'TEXT',
                        additional_requirements: 'TEXT'
                    }
                };

                const tableSql = DB_TYPE === 'sqlite' ? `
                    CREATE TABLE IF NOT EXISTS event_registrations (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        event_id INTEGER NOT NULL,
                        user_id INTEGER NOT NULL,
                        selected_location TEXT NOT NULL,
                        status TEXT NOT NULL DEFAULT 'confirmed',
                        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                        UNIQUE(event_id, user_id),
                        FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
                        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
                    );
                    CREATE TABLE IF NOT EXISTS notifications (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        user_id INTEGER NOT NULL,
                        event_id INTEGER,
                        title TEXT NOT NULL,
                        message TEXT NOT NULL,
                        type TEXT NOT NULL,
                        read_at TEXT,
                        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                        FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE
                    );
                    CREATE TABLE IF NOT EXISTS event_history (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        event_id INTEGER NOT NULL,
                        actor_id INTEGER,
                        entity_type TEXT NOT NULL,
                        action TEXT NOT NULL,
                        details TEXT,
                        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                        FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE
                    );
                    CREATE INDEX IF NOT EXISTS idx_event_registrations_event ON event_registrations(event_id, status);
                    CREATE INDEX IF NOT EXISTS idx_event_registrations_user ON event_registrations(user_id, created_at);
                    CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, read_at, created_at);
                    CREATE INDEX IF NOT EXISTS idx_event_history_event ON event_history(event_id, created_at);
                ` : `
                    CREATE TABLE IF NOT EXISTS event_registrations (
                        id INT PRIMARY KEY AUTO_INCREMENT,
                        event_id INT NOT NULL,
                        user_id INT NOT NULL,
                        selected_location VARCHAR(255) NOT NULL,
                        status VARCHAR(30) NOT NULL DEFAULT 'confirmed',
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        UNIQUE KEY uq_event_user (event_id, user_id),
                        KEY idx_event_registrations_user (user_id, created_at),
                        FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
                        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
                    );
                    CREATE TABLE IF NOT EXISTS notifications (
                        id INT PRIMARY KEY AUTO_INCREMENT,
                        user_id INT NOT NULL,
                        event_id INT NULL,
                        title VARCHAR(255) NOT NULL,
                        message TEXT NOT NULL,
                        type VARCHAR(50) NOT NULL,
                        read_at TIMESTAMP NULL,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        KEY idx_notifications_user (user_id, read_at, created_at),
                        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                        FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE
                    );
                    CREATE TABLE IF NOT EXISTS event_history (
                        id INT PRIMARY KEY AUTO_INCREMENT,
                        event_id INT NOT NULL,
                        actor_id INT NULL,
                        entity_type VARCHAR(30) NOT NULL,
                        action VARCHAR(50) NOT NULL,
                        details TEXT,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        KEY idx_event_history_event (event_id, created_at),
                        FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE
                    );
                `;

                if (DB_TYPE === 'sqlite') {
                    if (!sqliteInstance) return callback(new Error('SQLite connection unavailable for event migration'));
                    const tables = Object.keys(sqliteColumns);
                    const addColumns = (tableIndex) => {
                        if (tableIndex >= tables.length) {
                            return sqliteInstance.exec(tableSql, (tableErr) => {
                                if (tableErr) return callback(tableErr);
                                sqliteInstance.run(
                                    `UPDATE events SET responsible_head_id = created_by
                                     WHERE responsible_head_id IS NULL AND created_by IS NOT NULL`,
                                    (ownerErr) => {
                                        if (ownerErr) return callback(ownerErr);
                                        sqliteInstance.run(`PRAGMA user_version = ${SQLITE_SCHEMA_VERSION}`, callback);
                                    },
                                );
                            });
                        }

                        const table = tables[tableIndex];
                        sqliteInstance.all(`PRAGMA table_info(${table})`, (tableErr, columns) => {
                            if (tableErr) return callback(tableErr);
                            const existing = new Set((columns || []).map((column) => column.name));
                            const additions = Object.entries(sqliteColumns[table])
                                .filter(([name]) => !existing.has(name));
                            const addNext = (columnIndex) => {
                                if (columnIndex >= additions.length) return addColumns(tableIndex + 1);
                                const [name, definition] = additions[columnIndex];
                                sqliteInstance.run(
                                    `ALTER TABLE ${table} ADD COLUMN ${name} ${definition}`,
                                    (alterErr) => alterErr ? callback(alterErr) : addNext(columnIndex + 1),
                                );
                            };
                            addNext(0);
                        });
                    };
                    addColumns(0);
                    return;
                }

                const mysqlDefinitions = {
                    users: { phone: 'VARCHAR(40) NULL', area: 'VARCHAR(120) NULL' },
                    events: {
                        category: 'VARCHAR(100) NULL',
                        start_time: 'TIME NULL',
                        end_time: 'TIME NULL',
                        area: 'VARCHAR(120) NULL',
                        address: 'VARCHAR(500) NULL',
                        required_roles: 'TEXT NULL',
                        meeting_point: 'VARCHAR(255) NULL',
                        reporting_instructions: 'TEXT NULL',
                        instructions: 'TEXT NULL',
                        image_url: 'VARCHAR(2048) NULL',
                        registration_deadline: 'DATE NULL',
                        status: "VARCHAR(30) NOT NULL DEFAULT 'published'",
                        published_at: 'TIMESTAMP NULL',
                        created_by: 'INT NULL',
                        responsible_head_id: 'INT NULL',
                        admin_override: 'TINYINT(1) NOT NULL DEFAULT 0',
                        admin_override_by: 'INT NULL',
                        admin_override_at: 'TIMESTAMP NULL',
                        cancelled_at: 'TIMESTAMP NULL'
                    },
                    tasks: {
                        description: 'TEXT NULL',
                        status: "VARCHAR(30) NOT NULL DEFAULT 'Open'",
                        location_is_independent: 'TINYINT(1) NOT NULL DEFAULT 1',
                        compensation_type: "VARCHAR(20) NOT NULL DEFAULT 'unpaid'",
                        compensation_amount: 'DECIMAL(10, 2) NULL',
                        compensation_currency: "CHAR(3) NOT NULL DEFAULT 'INR'",
                        compensation_terms: 'TEXT NULL',
                        additional_requirements: 'TEXT NULL'
                    }
                };
                const tables = Object.keys(mysqlDefinitions);
                const addColumns = (tableIndex) => {
                    if (tableIndex >= tables.length) {
                        return connection.query(tableSql, (tableErr) => {
                            if (tableErr) return callback(tableErr);
                            connection.query(
                                'UPDATE events SET responsible_head_id = created_by WHERE responsible_head_id IS NULL AND created_by IS NOT NULL',
                                (ownerErr) => {
                                    if (ownerErr) return callback(ownerErr);
                                    connection.query(
                                        'INSERT IGNORE INTO schema_migrations (version) VALUES (2), (3)',
                                        callback,
                                    );
                                },
                            );
                        });
                    }
                    const table = tables[tableIndex];
                    connection.query(
                        `SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
                         WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?`,
                        [DB_NAME, table],
                        (tableErr, rows) => {
                            if (tableErr) return callback(tableErr);
                            const existing = new Set((rows || []).map((row) => row.COLUMN_NAME));
                            const additions = Object.entries(mysqlDefinitions[table])
                                .filter(([name]) => !existing.has(name));
                            const addNext = (columnIndex) => {
                                if (columnIndex >= additions.length) return addColumns(tableIndex + 1);
                                const [name, definition] = additions[columnIndex];
                                connection.query(
                                    `ALTER TABLE ${table} ADD COLUMN ${name} ${definition}`,
                                    (alterErr) => alterErr ? callback(alterErr) : addNext(columnIndex + 1),
                                );
                            };
                            addNext(0);
                        },
                    );
                };
                addColumns(0);
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
                    connection.query("UPDATE users SET role_requested = role WHERE role_requested IS NULL OR role = 'Head Volunteer'", (requestedErr) => {
                        if (requestedErr) return callback(requestedErr);
                        connection.query("UPDATE users SET role_status = 'approved' WHERE role_status IS NULL OR role_requested = 'Head Volunteer'", (statusErr) => {
                            if (statusErr) return callback(statusErr);
                            connection.query(
                                "UPDATE users SET role = 'Head Volunteer' WHERE role_requested = 'Head Volunteer'",
                                (headRoleErr) => headRoleErr
                                    ? callback(headRoleErr)
                                    : migrateMysqlEventWorkflows(connection, callback),
                            );
                        });
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
                    compensation_type TEXT NOT NULL DEFAULT 'unpaid',
                    compensation_amount NUMERIC,
                    compensation_currency TEXT NOT NULL DEFAULT 'INR',
                    compensation_terms TEXT,
                    additional_requirements TEXT,
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
            compensation_type VARCHAR(20) NOT NULL DEFAULT 'unpaid',
            compensation_amount DECIMAL(10, 2) NULL,
            compensation_currency CHAR(3) NOT NULL DEFAULT 'INR',
            compensation_terms TEXT,
            additional_requirements TEXT,
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
                                if (roleErr) {
                                    return bootstrap.end(() => {
                                        lastError = roleErr;
                                        tryPort(index + 1);
                                    });
                                }
                                bootstrap.end(() => {
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

const requireAdministrator = (req, res, next) => {
    db.query('SELECT role FROM users WHERE id = ?', [req.authUser.id], (err, rows) => {
        if (err) {
            console.error(err);
            return res.status(500).json({ message: 'Database error' });
        }
        if (rows.length === 0) {
            return res.status(401).json({ message: 'Account is no longer available' });
        }
        if (rows[0].role !== 'Administrator') {
            return res.status(403).json({ message: 'Administrator access is required' });
        }
        req.authUser.role = rows[0].role;
        next();
    });
};

const requireEventStaff = (req, res, next) => {
    db.query('SELECT role FROM users WHERE id = ?', [req.authUser.id], (err, rows) => {
        if (err) {
            console.error(err);
            return res.status(500).json({ message: 'Database error' });
        }
        if (rows.length === 0) {
            return res.status(401).json({ message: 'Account is no longer available' });
        }
        if (!['Head Volunteer', 'Administrator'].includes(rows[0].role)) {
            return res.status(403).json({ message: 'Head Volunteer access is required' });
        }
        req.authUser.role = rows[0].role;
        next();
    });
};

const isPublishDeadlineMet = (date, startTime) => {
    const start = new Date(`${date}T${startTime || '00:00:00'}Z`);
    return !Number.isNaN(start.valueOf()) &&
        start.valueOf() - Date.now() >= 5 * 24 * 60 * 60 * 1000;
};

const requireEventManager = (eventId, userId, callback) => {
    db.query(
        `SELECT id, name, date, start_time, end_time, location, status,
                created_by, responsible_head_id, volunteers_needed
         FROM events WHERE id = ?`,
        [eventId],
        (err, rows) => {
            if (err) return callback(err);
            if (rows.length === 0) return callback(null, null, false);
            const event = rows[0];
            db.query('SELECT role FROM users WHERE id = ?', [userId], (roleErr, users) => {
                if (roleErr) return callback(roleErr);
                const role = users.length > 0 ? users[0].role : null;
                callback(null, event, role === 'Administrator' ||
                    Number(event.created_by) === userId ||
                    Number(event.responsible_head_id) === userId);
            });
        },
    );
};

const recordEventHistory = (eventId, actorId, entityType, action, details, callback) => {
    db.query(
        `INSERT INTO event_history (event_id, actor_id, entity_type, action, details)
         VALUES (?, ?, ?, ?, ?)`,
        [eventId, actorId, entityType, action, details ? JSON.stringify(details) : null],
        (err) => callback(err),
    );
};

const notifyEventRegistrants = (eventId, type, title, message, callback) => {
    db.query(
        `SELECT user_id FROM event_registrations
         WHERE event_id = ? AND status = 'confirmed'
         UNION
         SELECT en.user_id FROM enrollments en
         JOIN tasks t ON t.id = en.task_id
         WHERE t.event_id = ? AND en.status IN ('pending', 'approved')`,
        [eventId, eventId],
        (lookupErr, rows) => {
            if (lookupErr) return callback(lookupErr);
            const recipients = rows || [];
            const insertNext = (index) => {
                if (index >= recipients.length) return callback(null);
                db.query(
                    `INSERT INTO notifications (user_id, event_id, title, message, type)
                     VALUES (?, ?, ?, ?, ?)`,
                    [recipients[index].user_id, eventId, title, message, type],
                    (insertErr) => insertErr ? callback(insertErr) : insertNext(index + 1),
                );
            };
            insertNext(0);
        },
    );
};

const notifyTaskVolunteers = (taskId, eventId, type, title, message, callback) => {
    db.query(
        `SELECT DISTINCT user_id FROM enrollments
         WHERE task_id = ? AND status IN ('pending', 'approved')`,
        [taskId],
        (lookupErr, rows) => {
            if (lookupErr) return callback(lookupErr);
            const recipients = rows || [];
            const insertNext = (index) => {
                if (index >= recipients.length) return callback(null);
                db.query(
                    `INSERT INTO notifications (user_id, event_id, title, message, type)
                     VALUES (?, ?, ?, ?, ?)`,
                    [recipients[index].user_id, eventId, title, message, type],
                    (insertErr) => insertErr ? callback(insertErr) : insertNext(index + 1),
                );
            };
            insertNext(0);
        },
    );
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
        phone,
        area,
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

                const assignedRole = requestedRole;
                const roleStatus = 'approved';

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

                        res.status(201).json({
                            message: 'Account created successfully! You can now log in.',
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
            phone,
            area,
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
                        phone: user.phone,
                        area: user.area,
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
    const params = [new Date().toISOString().slice(0, 10)];
    let sql = `
        SELECT e.id, e.name, e.date, e.start_time, e.end_time, e.location,
               e.area, e.address, e.description, e.category, e.required_roles,
               e.meeting_point, e.reporting_instructions, e.instructions,
               e.image_url, e.registration_deadline, e.status,
               e.volunteers_needed, e.responsible_head_id,
               (SELECT COUNT(*) FROM event_registrations er
                WHERE er.event_id = e.id AND er.status = 'confirmed') AS registered_count,
               CASE WHEN e.volunteers_needed IS NULL THEN NULL
                    WHEN e.volunteers_needed -
                        (SELECT COUNT(*) FROM event_registrations er
                         WHERE er.event_id = e.id AND er.status = 'confirmed') < 0 THEN 0
                    ELSE e.volunteers_needed -
                        (SELECT COUNT(*) FROM event_registrations er
                         WHERE er.event_id = e.id AND er.status = 'confirmed')
               END AS available_slots
        FROM events e
        LEFT JOIN users head ON head.id = e.responsible_head_id
        WHERE e.status = 'published' AND e.date >= ?
    `;
    if (req.query.area) {
        sql += ' AND LOWER(COALESCE(e.area, e.location)) LIKE ?';
        params.push(`%${String(req.query.area).trim().toLowerCase()}%`);
    }
    if (req.query.category) {
        sql += ' AND LOWER(COALESCE(e.category, \'\')) = ?';
        params.push(String(req.query.category).trim().toLowerCase());
    }
    if (req.query.date) {
        if (!isValidIsoDate(String(req.query.date))) {
            return res.status(400).json({ message: 'Enter a valid event date filter' });
        }
        sql += ' AND e.date = ?';
        params.push(String(req.query.date));
    }
    if (req.query.from) {
        if (!isValidIsoDate(String(req.query.from))) {
            return res.status(400).json({ message: 'Enter a valid start date filter' });
        }
        sql += ' AND e.date >= ?';
        params.push(String(req.query.from));
    }
    if (req.query.to) {
        if (!isValidIsoDate(String(req.query.to))) {
            return res.status(400).json({ message: 'Enter a valid end date filter' });
        }
        sql += ' AND e.date <= ?';
        params.push(String(req.query.to));
    }
    if (req.query.available === 'true') {
        sql += ` AND (e.volunteers_needed IS NULL OR
            (SELECT COUNT(*) FROM event_registrations er
             WHERE er.event_id = e.id AND er.status = 'confirmed') < e.volunteers_needed)`;
    }
    sql += ' ORDER BY e.date ASC, e.start_time ASC';

    db.query(sql, params, (err, results) => {
        if (err) {
            console.error(err);
            return res.status(500).json({
                message: 'Database error'
            });
        }
        res.status(200).json(results);
    });
});

app.get('/api/head/events', requireAuth, requireEventStaff, (req, res) => {
    const isAdmin = req.authUser.role === 'Administrator';
    const sql = `
        SELECT e.*, head.name AS head_volunteer_name,
               head.email AS head_volunteer_email,
               COALESCE(e.contact_phone, head.phone) AS head_volunteer_phone,
               (SELECT COUNT(*) FROM event_registrations er
                WHERE er.event_id = e.id AND er.status = 'confirmed') AS registered_count,
               CASE WHEN e.volunteers_needed IS NULL THEN NULL
                    WHEN e.volunteers_needed -
                        (SELECT COUNT(*) FROM event_registrations er
                         WHERE er.event_id = e.id AND er.status = 'confirmed') < 0 THEN 0
                    ELSE e.volunteers_needed -
                        (SELECT COUNT(*) FROM event_registrations er
                         WHERE er.event_id = e.id AND er.status = 'confirmed')
               END AS available_slots
        FROM events e
        LEFT JOIN users head ON head.id = e.responsible_head_id
        ${isAdmin ? '' : 'WHERE e.created_by = ? OR e.responsible_head_id = ?'}
        ORDER BY e.date ASC, e.start_time ASC
    `;
    const params = isAdmin ? [] : [req.authUser.id, req.authUser.id];
    db.query(sql, params, (err, events) => {
        if (err) {
            console.error(err);
            return res.status(500).json({ message: 'Database error' });
        }
        res.status(200).json(events);
    });
});


// ===============================
// CREATE EVENT
// ===============================

app.post('/api/events', requireAuth, requireEventStaff, (req, res) => {
    const body = req.body || {};
    const normalizedName = String(body.name || '').trim();
    const normalizedLocation = String(body.location || '').trim();
    const eventDate = String(body.date || '').trim();
    const startTime = String(body.start_time || '').trim() || null;
    const endTime = String(body.end_time || '').trim() || null;
    const hasVolunteerLimit = body.volunteers_needed != null &&
        String(body.volunteers_needed).trim() !== '';
    const volunteerLimit = hasVolunteerLimit ? Number(body.volunteers_needed) : null;
    const status = body.status == null ? 'draft' : String(body.status);
    const overrideRequested = body.admin_override === true;

    if (!normalizedName || !eventDate || !normalizedLocation) {
        return res.status(400).json({
            message: 'Event name, date and location are required'
        });
    }
    if (!['draft', 'published'].includes(status) ||
        normalizedName.length > 200 ||
        normalizedLocation.length > 255 ||
        !isValidIsoDate(eventDate) ||
        ((startTime || endTime) &&
            (!startTime || !endTime ||
             !/^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$/.test(startTime) ||
             !/^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$/.test(endTime) ||
             startTime >= endTime))) {
        return res.status(400).json({ message: 'Enter a valid event name, date and location' });
    }
    if (hasVolunteerLimit &&
        (!Number.isInteger(volunteerLimit) || volunteerLimit <= 0)) {
        return res.status(400).json({ message: 'Volunteers needed must be a positive whole number' });
    }

    if (overrideRequested && req.authUser.role !== 'Administrator') {
        return res.status(403).json({ message: 'Only an Administrator may override the publishing deadline' });
    }
    if (overrideRequested && status !== 'published') {
        return res.status(400).json({ message: 'Deadline overrides can only be recorded when publishing an event' });
    }
    if (status === 'published' &&
        !isPublishDeadlineMet(eventDate, startTime) &&
        !overrideRequested) {
        return res.status(400).json({
            message: 'Events must be published at least 5 full days before they begin. Save this event as a draft or ask an Administrator to record an exceptional override.'
        });
    }
    const contactPhone = String(body.contact_phone || '').trim() || null;
    const imageUrl = String(body.image_url || '').trim() || null;
    if (imageUrl && (!/^https?:\/\//i.test(imageUrl) || imageUrl.length > 2048)) {
        return res.status(400).json({ message: 'Enter a valid event image URL' });
    }
    const responsibleHeadId = req.authUser.role === 'Administrator'
        ? Number(body.responsible_head_id || 0)
        : req.authUser.id;
    if (!Number.isSafeInteger(responsibleHeadId) || responsibleHeadId <= 0) {
        return res.status(400).json({ message: 'Select a Head Volunteer responsible for this event' });
    }
    db.query(
        'SELECT id FROM users WHERE id = ? AND role = ?',
        [responsibleHeadId, 'Head Volunteer'],
        (headErr, heads) => {
            if (headErr) {
                console.error(headErr);
                return res.status(500).json({ message: 'Database error' });
            }
            if (!heads.length) {
                return res.status(400).json({ message: 'The responsible account must be a Head Volunteer' });
            }
    const sql = `
        INSERT INTO events
        (name, date, location, description, volunteers_needed, category,
         start_time, end_time, area, address, required_roles, meeting_point,
         reporting_instructions, instructions, contact_phone, image_url,
         registration_deadline, status, published_at, created_by, responsible_head_id,
         admin_override, admin_override_by, admin_override_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `;
    const values = [
        normalizedName,
        eventDate,
        normalizedLocation,
        String(body.description || '').trim() || null,
        volunteerLimit,
        String(body.category || '').trim() || null,
        startTime,
        endTime,
        String(body.area || '').trim() || null,
        String(body.address || '').trim() || null,
        String(body.required_roles || '').trim() || null,
        String(body.meeting_point || '').trim() || null,
        String(body.reporting_instructions || '').trim() || null,
        String(body.instructions || '').trim() || null,
        contactPhone,
        imageUrl,
        isValidIsoDate(String(body.registration_deadline || ''))
            ? String(body.registration_deadline) : null,
        status,
        status === 'published' ? new Date().toISOString() : null,
        req.authUser.id,
        responsibleHeadId,
        overrideRequested ? 1 : 0,
        overrideRequested ? req.authUser.id : null,
        overrideRequested ? new Date().toISOString() : null
    ];
    db.query(sql, values, (err, result) => {
            if (err) {
                console.error(err);
                return res.status(500).json({
                    message: 'Database error'
                });
            }
            recordEventHistory(
                result.insertId, req.authUser.id, 'event', 'created',
                { status, override: overrideRequested },
                (historyErr) => {
                    if (historyErr) {
                        console.error(historyErr);
                        return res.status(500).json({ message: 'Event was created but its history could not be recorded' });
                    }
                    res.status(201).json({
                        message: status === 'published' ? 'Event published successfully' : 'Event saved as draft',
                        eventId: result.insertId,
                        status
                    });
                },
            );
        });
    });
});

app.get('/api/events/:eventId', requireAuth, (req, res) => {
    const eventId = Number(req.params.eventId);
    if (!Number.isSafeInteger(eventId) || eventId <= 0) {
        return res.status(400).json({ message: 'Invalid event ID' });
    }
    db.query(
        `SELECT e.id, e.name, e.date, e.start_time, e.end_time, e.location,
                e.description, e.volunteers_needed, e.category, e.area, e.address,
                e.required_roles, e.meeting_point, e.reporting_instructions,
                e.instructions, e.contact_phone, e.image_url,
                e.registration_deadline, e.status,
                head.name AS head_volunteer_name,
                head.email AS head_volunteer_email,
                head.role AS head_volunteer_role,
                COALESCE(e.contact_phone, head.phone) AS head_volunteer_phone,
                (SELECT COUNT(*) FROM event_registrations er
                 WHERE er.event_id = e.id AND er.status = 'confirmed') AS registered_count
         FROM events e
         LEFT JOIN users head ON head.id = e.responsible_head_id
         WHERE e.id = ? AND e.status = 'published'`,
        [eventId],
        (err, events) => {
            if (err) {
                console.error(err);
                return res.status(500).json({ message: 'Database error' });
            }
            if (!events.length) return res.status(404).json({ message: 'Event not found' });
            res.status(200).json(events[0]);
        },
    );
});

app.put('/api/events/:eventId', requireAuth, requireEventStaff, (req, res) => {
    const eventId = Number(req.params.eventId);
    if (!Number.isSafeInteger(eventId) || eventId <= 0) {
        return res.status(400).json({ message: 'Invalid event ID' });
    }
    requireEventManager(eventId, req.authUser.id, (accessErr, event, allowed) => {
        if (accessErr) {
            console.error(accessErr);
            return res.status(500).json({ message: 'Database error' });
        }
        if (!event) return res.status(404).json({ message: 'Event not found' });
        if (!allowed) return res.status(403).json({ message: 'You can only manage events assigned to you or created by you' });

        const body = req.body;
        const date = body.date == null ? String(event.date).slice(0, 10) : String(body.date).trim();
        const startTime = body.start_time == null
            ? event.start_time : String(body.start_time).trim() || null;
        const endTime = body.end_time == null
            ? event.end_time : String(body.end_time).trim() || null;
        const name = body.name == null ? event.name : String(body.name).trim();
        const location = body.location == null ? event.location : String(body.location).trim();
        const status = body.status == null ? event.status : String(body.status);
        const override = body.admin_override === true;

        if (!name || name.length > 200 || !location || location.length > 255 ||
            !isValidIsoDate(date) ||
            !['draft', 'published'].includes(status) ||
            ((startTime || endTime) &&
                (!startTime || !endTime ||
                 !/^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$/.test(String(startTime)) ||
                 !/^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$/.test(String(endTime)) ||
                 String(startTime) >= String(endTime)))) {
            return res.status(400).json({ message: 'Enter valid event details and a later end time' });
        }
        if (override && req.authUser.role !== 'Administrator') {
            return res.status(403).json({ message: 'Only an Administrator may override the publishing deadline' });
        }
        const scheduleChanged = date !== String(event.date).slice(0, 10) ||
            String(startTime || '') !== String(event.start_time || '');
        if (status === 'published' &&
            (event.status !== 'published' || scheduleChanged) &&
            !isPublishDeadlineMet(date, startTime) && !override) {
            return res.status(400).json({
                message: 'Published events must remain at least 5 full days away. Save as a draft or ask an Administrator to record an exceptional override.'
            });
        }

        const assignedHeadId = body.responsible_head_id == null
            ? Number(event.responsible_head_id) : Number(body.responsible_head_id);
        const validateAndSave = () => {
            if (assignedHeadId !== Number(event.responsible_head_id) &&
                req.authUser.role !== 'Administrator') {
                return res.status(403).json({ message: 'Only an Administrator may reassign the responsible Head Volunteer' });
            }
            const assignments = [
                ['name', name], ['date', date], ['location', location],
                ['description', body.description], ['volunteers_needed', body.volunteers_needed],
                ['category', body.category], ['start_time', startTime], ['end_time', endTime],
                ['area', body.area], ['address', body.address], ['required_roles', body.required_roles],
                ['meeting_point', body.meeting_point], ['reporting_instructions', body.reporting_instructions],
                ['instructions', body.instructions], ['contact_phone', body.contact_phone],
                ['image_url', body.image_url], ['registration_deadline', body.registration_deadline]
            ];
            const fields = [];
            const values = [];
            for (const [field, value] of assignments) {
                if (value !== undefined) {
                    if (field === 'volunteers_needed' && value != null &&
                        String(value).trim() !== '' &&
                        (!Number.isInteger(Number(value)) || Number(value) <= 0)) {
                        return res.status(400).json({ message: 'Volunteers needed must be a positive whole number' });
                    }
                    fields.push(`${field} = ?`);
                    if (field === 'volunteers_needed') {
                        values.push(value == null || String(value).trim() === '' ? null : Number(value));
                    } else {
                        values.push(typeof value === 'string' ? value.trim() || null : value);
                    }
                }
            }
            if (body.status !== undefined) {
                fields.push('status = ?');
                values.push(status);
            }
            if (assignedHeadId !== Number(event.responsible_head_id)) {
                fields.push('responsible_head_id = ?');
                values.push(assignedHeadId);
            }
            if (status === 'published' && event.status !== 'published') {
                fields.push('published_at = ?');
                values.push(new Date().toISOString());
            }
            if (body.registration_deadline !== undefined &&
                body.registration_deadline != null &&
                body.registration_deadline !== '' &&
                !isValidIsoDate(String(body.registration_deadline))) {
                return res.status(400).json({ message: 'Enter a valid registration deadline' });
            }
            if (body.image_url != null && body.image_url !== '' &&
                (!/^https?:\/\//i.test(String(body.image_url)) || String(body.image_url).length > 2048)) {
                return res.status(400).json({ message: 'Enter a valid event image URL' });
            }
            if (override) {
                fields.push('admin_override = 1', 'admin_override_by = ?', 'admin_override_at = ?');
                values.push(req.authUser.id, new Date().toISOString());
            }
            values.push(eventId);
            db.query(`UPDATE events SET ${fields.join(', ')} WHERE id = ?`, values, (updateErr) => {
                if (updateErr) {
                    console.error(updateErr);
                    return res.status(500).json({ message: 'Database error' });
                }
                const syncTaskSchedule = (done) => {
                    const steps = [];
                    if (date !== String(event.date).slice(0, 10)) {
                        steps.push(['UPDATE tasks SET date = ? WHERE event_id = ? AND date = ?', [date, eventId, String(event.date).slice(0, 10)]]);
                    }
                    if (String(startTime || '') !== String(event.start_time || '') && startTime) {
                        steps.push(['UPDATE tasks SET start_time = ? WHERE event_id = ? AND start_time = ?', [startTime, eventId, event.start_time]]);
                    }
                    if (String(endTime || '') !== String(event.end_time || '') && endTime) {
                        steps.push(['UPDATE tasks SET end_time = ? WHERE event_id = ? AND end_time = ?', [endTime, eventId, event.end_time]]);
                    }
                    if (location !== event.location) {
                        steps.push(['UPDATE tasks SET location = ? WHERE event_id = ? AND location_is_independent = 0', [location, eventId]]);
                    }
                    const runNext = (index) => {
                        if (index >= steps.length) return done(null);
                        db.query(steps[index][0], steps[index][1], (stepErr) =>
                            stepErr ? done(stepErr) : runNext(index + 1));
                    };
                    runNext(0);
                };
                syncTaskSchedule((syncErr) => {
                    if (syncErr) {
                        console.error(syncErr);
                        return res.status(500).json({ message: 'Event updated but its tasks could not be synchronized' });
                    }
                    recordEventHistory(eventId, req.authUser.id, 'event', 'updated',
                        { before: event, status, override }, (historyErr) => {
                            if (historyErr) {
                                console.error(historyErr);
                                return res.status(500).json({ message: 'Event updated but its history could not be recorded' });
                            }
                            const scheduleChanged = date !== String(event.date).slice(0, 10) ||
                                startTime !== event.start_time || location !== event.location ||
                                assignedHeadId !== Number(event.responsible_head_id);
                            if (!scheduleChanged) {
                                return res.status(200).json({ message: 'Event updated', eventId });
                            }
                            notifyEventRegistrants(eventId, 'event_updated', 'Event details updated',
                                'The date, time, location, or responsible Head Volunteer for this event changed. Open the event for current details.',
                                (notifyErr) => {
                                    if (notifyErr) {
                                        console.error(notifyErr);
                                        return res.status(500).json({ message: 'Event updated but volunteer notifications could not be sent' });
                                    }
                                    res.status(200).json({ message: 'Event updated and volunteers notified', eventId });
                                });
                        });
                });
            });
        };
        if (assignedHeadId === Number(event.responsible_head_id)) return validateAndSave();
        db.query('SELECT id FROM users WHERE id = ? AND role = ?', [assignedHeadId, 'Head Volunteer'], (headErr, heads) => {
            if (headErr) {
                console.error(headErr);
                return res.status(500).json({ message: 'Database error' });
            }
            if (!heads.length) return res.status(400).json({ message: 'The responsible account must be a Head Volunteer' });
            validateAndSave();
        });
    });
});

app.put('/api/events/:eventId/publish', requireAuth, requireEventStaff, (req, res) => {
    const eventId = Number(req.params.eventId);
    requireEventManager(eventId, req.authUser.id, (err, event, allowed) => {
        if (err) {
            console.error(err);
            return res.status(500).json({ message: 'Database error' });
        }
        if (!event) return res.status(404).json({ message: 'Event not found' });
        if (!allowed) return res.status(403).json({ message: 'You can only publish events assigned to you or created by you' });
        const override = req.body && req.body.admin_override === true;
        if (override && req.authUser.role !== 'Administrator') {
            return res.status(403).json({ message: 'Only an Administrator may override the publishing deadline' });
        }
        if (!isPublishDeadlineMet(String(event.date).slice(0, 10), event.start_time) && !override) {
            return res.status(400).json({
                message: 'Events must be published at least 5 full days before they begin. Save this event as a draft or ask an Administrator to record an exceptional override.'
            });
        }
        db.query(
            `UPDATE events SET status = 'published', published_at = ?,
             admin_override = ?, admin_override_by = ?, admin_override_at = ?
             WHERE id = ?`,
            [new Date().toISOString(), override ? 1 : 0,
                override ? req.authUser.id : null, override ? new Date().toISOString() : null, eventId],
            (updateErr) => {
                if (updateErr) {
                    console.error(updateErr);
                    return res.status(500).json({ message: 'Database error' });
                }
                recordEventHistory(eventId, req.authUser.id, 'event', 'published',
                    { override }, (historyErr) => {
                        if (historyErr) {
                            console.error(historyErr);
                            return res.status(500).json({ message: 'Event published but its history could not be recorded' });
                        }
                        res.status(200).json({ message: 'Event published successfully', status: 'published' });
                    });
            },
        );
    });
});

app.put('/api/events/:eventId/cancel', requireAuth, requireEventStaff, (req, res) => {
    const eventId = Number(req.params.eventId);
    requireEventManager(eventId, req.authUser.id, (err, event, allowed) => {
        if (err) {
            console.error(err);
            return res.status(500).json({ message: 'Database error' });
        }
        if (!event) return res.status(404).json({ message: 'Event not found' });
        if (!allowed) return res.status(403).json({ message: 'You can only cancel events assigned to you or created by you' });
        db.query(
            `UPDATE events SET status = 'cancelled', cancelled_at = ? WHERE id = ?`,
            [new Date().toISOString(), eventId],
            (updateErr) => {
                if (updateErr) {
                    console.error(updateErr);
                    return res.status(500).json({ message: 'Database error' });
                }
                db.query(`UPDATE tasks SET status = 'Cancelled' WHERE event_id = ? AND status != 'Completed'`,
                    [eventId], (tasksErr) => {
                        if (tasksErr) {
                            console.error(tasksErr);
                            return res.status(500).json({ message: 'Event cancelled but its tasks could not be updated' });
                        }
                        recordEventHistory(eventId, req.authUser.id, 'event', 'cancelled', null, (historyErr) => {
                            if (historyErr) {
                                console.error(historyErr);
                                return res.status(500).json({ message: 'Event cancelled but its history could not be recorded' });
                            }
                            notifyEventRegistrants(eventId, 'event_cancelled', 'Event cancelled',
                                'This event has been cancelled. Please review your dashboard for updated information.',
                                (notifyErr) => {
                                    if (notifyErr) {
                                        console.error(notifyErr);
                                        return res.status(500).json({ message: 'Event cancelled but volunteer notifications could not be sent' });
                                    }
                                    db.query(`UPDATE event_registrations SET status = 'cancelled' WHERE event_id = ? AND status = 'confirmed'`,
                                        [eventId], (registrationErr) => {
                                            if (registrationErr) {
                                                console.error(registrationErr);
                                                return res.status(500).json({ message: 'Event cancelled but registrations could not be updated' });
                                            }
                                            res.status(200).json({ message: 'Event cancelled and registered volunteers notified' });
                                        });
                                });
                        });
                    });
            },
        );
    });
});

app.post('/api/events/:eventId/register', requireAuth, (req, res) => {
    if (req.authUser.role !== 'Volunteer') {
        return res.status(403).json({ message: 'Only Volunteers can register for events' });
    }
    const eventId = Number(req.params.eventId);
    const selectedLocation = String(req.body.selected_location || '').trim();
    if (!Number.isSafeInteger(eventId) || eventId <= 0 ||
        !selectedLocation || selectedLocation.length > 255) {
        return res.status(400).json({ message: 'A valid event and preferred location are required' });
    }
    withDatabaseTransaction((finish) => {
        const lock = DB_TYPE === 'sqlite' ? '' : ' FOR UPDATE';
        db.query(`SELECT id, date, status, registration_deadline, volunteers_needed
                  FROM events WHERE id = ?${lock}`, [eventId], (eventErr, events) => {
            if (eventErr) return finish(eventErr);
            if (!events.length) return finish(null, { status: 404, message: 'Event not found' });
            const event = events[0];
            const today = new Date().toISOString().slice(0, 10);
            const eventStart = new Date(
                `${String(event.date).slice(0, 10)}T${event.start_time || '23:59:59'}Z`,
            );
            if (event.status !== 'published' || Number.isNaN(eventStart.valueOf()) ||
                eventStart.valueOf() < Date.now()) {
                return finish(null, { status: 409, message: 'This event is not available for registration' });
            }
            if (event.registration_deadline &&
                String(event.registration_deadline).slice(0, 10) < today) {
                return finish(null, { status: 409, message: 'The registration deadline has passed' });
            }
            db.query(
                'SELECT id FROM event_registrations WHERE event_id = ? AND user_id = ?',
                [eventId, req.authUser.id],
                (duplicateErr, registrations) => {
                    if (duplicateErr) return finish(duplicateErr);
                    if (registrations.length) {
                        return finish(null, { status: 409, message: 'You are already registered for this event' });
                    }
                    const save = () => db.query(
                        `INSERT INTO event_registrations (event_id, user_id, selected_location, status)
                         VALUES (?, ?, ?, 'confirmed')`,
                        [eventId, req.authUser.id, selectedLocation],
                        (insertErr, result) => insertErr
                            ? finish(insertErr)
                            : finish(null, { status: 201, registrationId: result.insertId }),
                    );
                    if (event.volunteers_needed == null) return save();
                    db.query(
                        `SELECT COUNT(*) AS registered FROM event_registrations
                         WHERE event_id = ? AND status = 'confirmed'`,
                        [eventId],
                        (countErr, counts) => {
                            if (countErr) return finish(countErr);
                            if (Number(counts[0].registered) >= Number(event.volunteers_needed)) {
                                return finish(null, { status: 409, message: 'This event has no remaining volunteer places' });
                            }
                            save();
                        },
                    );
                },
            );
        });
    }, (err, result) => {
        if (err) {
            if (err.code === 'ER_DUP_ENTRY' || err.code === 'SQLITE_CONSTRAINT' ||
                err.code === 'SQLITE_CONSTRAINT_UNIQUE') {
                return res.status(409).json({ message: 'You are already registered for this event' });
            }
            console.error(err);
            return res.status(500).json({ message: 'Database error' });
        }
        if (result.status !== 201) return res.status(result.status).json({ message: result.message });
        recordEventHistory(eventId, req.authUser.id, 'registration', 'created',
            { selected_location: selectedLocation }, (historyErr) => {
                if (historyErr) {
                    console.error(historyErr);
                    return res.status(500).json({ message: 'Registration saved but its history could not be recorded' });
                }
                db.query(
                    `INSERT INTO notifications (user_id, event_id, title, message, type)
                     SELECT ?, id, 'Registration confirmed',
                            'Your event registration is confirmed. Open the event to see current schedule and Head Volunteer contact details.',
                            'registration_confirmed'
                     FROM events WHERE id = ?`,
                    [req.authUser.id, eventId],
                    (notificationErr) => {
                        if (notificationErr) {
                            console.error(notificationErr);
                            return res.status(500).json({ message: 'Registration saved but its confirmation notification could not be created' });
                        }
                        res.status(201).json({
                            message: 'Event registration confirmed',
                            registrationId: result.registrationId,
                            status: 'confirmed'
                        });
                    },
                );
            });
    });
});

app.get('/api/users/:userId/events', requireAuth, (req, res) => {
    const userId = Number(req.params.userId);
    if (userId !== req.authUser.id) {
        return res.status(403).json({ message: 'You can only view your own event registrations' });
    }
    db.query(
        `SELECT er.id AS registration_id, er.selected_location, er.status AS registration_status,
                er.created_at AS registered_at, e.id AS event_id, e.name AS event_name,
                e.date, e.start_time, e.end_time, e.location, e.area, e.status AS event_status,
                e.image_url, head.name AS head_volunteer_name,
                head.email AS head_volunteer_email,
                COALESCE(e.contact_phone, head.phone) AS head_volunteer_phone
         FROM event_registrations er
         JOIN events e ON e.id = er.event_id
         LEFT JOIN users head ON head.id = e.responsible_head_id
         WHERE er.user_id = ? ORDER BY e.date ASC`,
        [userId],
        (err, events) => {
            if (err) {
                console.error(err);
                return res.status(500).json({ message: 'Database error' });
            }
            res.status(200).json(events);
        },
    );
});

app.get('/api/notifications', requireAuth, (req, res) => {
    db.query(
        `SELECT id, event_id, title, message, type, read_at, created_at
         FROM notifications WHERE user_id = ? ORDER BY created_at DESC`,
        [req.authUser.id],
        (err, notifications) => {
            if (err) {
                console.error(err);
                return res.status(500).json({ message: 'Database error' });
            }
            res.status(200).json(notifications);
        },
    );
});

app.put('/api/notifications/:notificationId/read', requireAuth, (req, res) => {
    const notificationId = Number(req.params.notificationId);
    if (!Number.isSafeInteger(notificationId) || notificationId <= 0) {
        return res.status(400).json({ message: 'Invalid notification ID' });
    }
    db.query(
        `UPDATE notifications SET read_at = ? WHERE id = ? AND user_id = ?`,
        [new Date().toISOString(), notificationId, req.authUser.id],
        (err, result) => {
            if (err) {
                console.error(err);
                return res.status(500).json({ message: 'Database error' });
            }
            if (!result.affectedRows) return res.status(404).json({ message: 'Notification not found' });
            res.status(200).json({ message: 'Notification marked as read' });
        },
    );
});


// ===============================
// GET TASKS FOR AN EVENT
// ===============================

app.get('/api/events/:eventId/tasks', requireAuth, (req, res) => {
    const eventId = Number(req.params.eventId);
    if (!Number.isSafeInteger(eventId) || eventId <= 0) {
        return res.status(400).json({ message: 'Invalid event ID' });
    }

    const sql = `
        SELECT
            t.id,
            t.event_id,
            t.task_name,
            t.description,
            t.date,
            t.start_time,
            t.end_time,
            t.location,
            t.instructions,
            t.volunteers_required,
            t.compensation_type,
            t.compensation_amount,
            t.compensation_currency,
            t.compensation_terms,
            t.additional_requirements,
            t.status,
            (SELECT COUNT(*) FROM enrollments accepted
             WHERE accepted.task_id = t.id AND accepted.status = 'approved') AS accepted_count,
            (SELECT COUNT(*) FROM enrollments pending
             WHERE pending.task_id = t.id AND pending.status = 'pending') AS pending_count,
            CASE WHEN t.volunteers_required IS NULL THEN NULL
                 WHEN t.volunteers_required -
                    (SELECT COUNT(*) FROM enrollments occupied
                     WHERE occupied.task_id = t.id
                       AND occupied.status IN ('pending', 'approved')) < 0 THEN 0
                 ELSE t.volunteers_required -
                    (SELECT COUNT(*) FROM enrollments occupied
                     WHERE occupied.task_id = t.id
                       AND occupied.status IN ('pending', 'approved'))
            END AS remaining_places,
            e.responsible_head_id,
            head.name AS head_volunteer_name,
            head.email AS head_volunteer_email,
            COALESCE(e.contact_phone, head.phone) AS head_volunteer_phone
        FROM tasks t
        JOIN events e ON e.id = t.event_id
        LEFT JOIN users head ON head.id = e.responsible_head_id
        WHERE t.event_id = ?
          AND (e.status = 'published' OR e.created_by = ? OR e.responsible_head_id = ?)
        ORDER BY t.date ASC, t.start_time ASC
    `;

    db.query(sql, [eventId, req.authUser.id, req.authUser.id], (err, results) => {

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

app.post('/api/tasks', requireAuth, requireEventStaff, (req, res) => {

    const body = req.body || {};
    const {
        event_id,
        task_name,
        date,
        start_time,
        end_time,
        location,
        instructions,
        volunteers_required
    } = body;
    const eventId = Number(event_id);
    const taskName = String(task_name || '').trim();
    const taskDate = String(date || '');
    const start = String(start_time || '');
    const end = String(end_time || '');
    const taskLocation = String(location || '').trim();
    const hasVolunteerLimit = volunteers_required != null &&
        String(volunteers_required).trim() !== '';
    const volunteerLimit = hasVolunteerLimit ? Number(volunteers_required) : null;

    const description = String(body.description || '').trim();
    if (!eventId || !taskName || !description || !taskDate || !start || !end || !taskLocation) {
        return res.status(400).json({
            message: 'Event, task name, description, date, times and location are required'
        });
    }
    if (description.length > 2000 ||
        String(instructions || '').trim().length > 2000) {
        return res.status(400).json({ message: 'Task description and instructions must be 2000 characters or fewer' });
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
    if (!hasVolunteerLimit ||
        !Number.isInteger(volunteerLimit) || volunteerLimit <= 0) {
        return res.status(400).json({ message: 'Volunteers required must be a positive whole number' });
    }
    const compensation = validateTaskCompensation(body);
    if (compensation.error) {
        return res.status(400).json({ message: compensation.error });
    }

    const checkSql = `SELECT id, location, status FROM events WHERE id = ?`;

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
        if (checkResults[0].status === 'cancelled' || checkResults[0].status === 'completed') {
            return res.status(409).json({ message: 'Tasks cannot be added to a cancelled or completed event' });
        }
        requireEventManager(eventId, req.authUser.id, (accessErr, event, allowed) => {
            if (accessErr) {
                console.error(accessErr);
                return res.status(500).json({ message: 'Database error' });
            }
            if (!event || !allowed) {
                return res.status(403).json({ message: 'You can only add tasks to events assigned to you or created by you' });
            }
            const status = String(req.body.status || 'Open');
            if (!['Open', 'Assigned', 'In Progress', 'Completed', 'Cancelled'].includes(status)) {
                return res.status(400).json({ message: 'Enter a valid task status' });
            }
            const sql = `
                INSERT INTO tasks
                (event_id, task_name, description, date, start_time, end_time, location,
                 instructions, volunteers_required, status, location_is_independent,
                 compensation_type, compensation_amount, compensation_currency,
                 compensation_terms, additional_requirements)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            `;
            db.query(sql, [
                eventId,
                taskName,
                description,
                taskDate,
                start,
                end,
                taskLocation,
                String(instructions || '').trim() || null,
                volunteerLimit,
                status,
                taskLocation === checkResults[0].location ? 0 : 1,
                compensation.type,
                compensation.amount,
                compensation.currency,
                compensation.terms,
                compensation.requirements
            ], (err, result) => {
                if (err) {
                    console.error(err);
                    return res.status(500).json({
                        message: 'Database error'
                    });
                }
                recordEventHistory(eventId, req.authUser.id, 'task', 'created',
                    { task_id: result.insertId, task_name: taskName, status }, (historyErr) => {
                        if (historyErr) {
                            console.error(historyErr);
                            return res.status(500).json({ message: 'Task created but its history could not be recorded' });
                        }
                        res.status(201).json({
                            message: 'Task created successfully',
                            taskId: result.insertId,
                            status
                        });
                    });
                });
        });
    });
});

app.put('/api/tasks/:taskId', requireAuth, requireEventStaff, (req, res) => {
    const taskId = Number(req.params.taskId);
    if (!Number.isSafeInteger(taskId) || taskId <= 0) {
        return res.status(400).json({ message: 'Invalid task ID' });
    }
    db.query(
        `SELECT t.*, e.location AS event_location, e.status AS event_status
         FROM tasks t JOIN events e ON e.id = t.event_id WHERE t.id = ?`,
        [taskId],
        (lookupErr, rows) => {
            if (lookupErr) {
                console.error(lookupErr);
                return res.status(500).json({ message: 'Database error' });
            }
            if (!rows.length) return res.status(404).json({ message: 'Task not found' });
            const task = rows[0];
            requireEventManager(task.event_id, req.authUser.id, (accessErr, event, allowed) => {
                if (accessErr) {
                    console.error(accessErr);
                    return res.status(500).json({ message: 'Database error' });
                }
                if (!event || !allowed) {
                    return res.status(403).json({ message: 'You can only manage tasks for events assigned to you or created by you' });
                }
                const body = req.body;
                const taskName = body.task_name == null ? task.task_name : String(body.task_name).trim();
                const date = body.date == null ? String(task.date).slice(0, 10) : String(body.date).trim();
                const start = body.start_time == null ? task.start_time : String(body.start_time).trim();
                const end = body.end_time == null ? task.end_time : String(body.end_time).trim();
                const location = body.location == null ? task.location : String(body.location).trim();
                const status = body.status == null ? task.status : String(body.status);
                const description = body.description === undefined
                    ? String(task.description || '').trim()
                    : String(body.description || '').trim();
                if (!taskName || taskName.length > 200 || !description ||
                    description.length > 2000 || !location || location.length > 255 ||
                    !isValidIsoDate(date) ||
                    !/^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$/.test(String(start)) ||
                    !/^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$/.test(String(end)) ||
                    String(start) >= String(end) ||
                    !['Open', 'Assigned', 'In Progress', 'Completed', 'Cancelled'].includes(status)) {
                    return res.status(400).json({ message: 'Enter valid task details and status' });
                }
                const limit = body.volunteers_required === undefined
                    ? task.volunteers_required
                    : body.volunteers_required == null || String(body.volunteers_required).trim() === ''
                        ? null : Number(body.volunteers_required);
                if (limit == null || !Number.isInteger(limit) || limit <= 0) {
                    return res.status(400).json({ message: 'Volunteers required must be a positive whole number' });
                }
                const instructions = body.instructions === undefined
                    ? String(task.instructions || '').trim()
                    : String(body.instructions || '').trim();
                if (instructions.length > 2000) {
                    return res.status(400).json({ message: 'Task instructions must be 2000 characters or fewer' });
                }
                const compensation = validateTaskCompensation(body, task);
                if (compensation.error) {
                    return res.status(400).json({ message: compensation.error });
                }
                const checkCapacity = (done) => {
                    if (limit == null) return done(null);
                    db.query(
                        `SELECT COUNT(*) AS enrolled FROM enrollments
                         WHERE task_id = ? AND status IN ('pending', 'approved')`,
                        [taskId],
                        (countErr, counts) => {
                            if (countErr) return done(countErr);
                            if (Number(counts[0].enrolled) > limit) {
                                return done(null, 'Volunteer limit cannot be lower than the number already enrolled');
                            }
                            done(null);
                        },
                    );
                };
                checkCapacity((capacityErr, capacityMessage) => {
                    if (capacityErr) {
                        console.error(capacityErr);
                        return res.status(500).json({ message: 'Database error' });
                    }
                    if (capacityMessage) return res.status(409).json({ message: capacityMessage });
                    db.query(
                        `UPDATE tasks SET task_name = ?, description = ?, date = ?,
                         start_time = ?, end_time = ?, location = ?, instructions = ?,
                         volunteers_required = ?, status = ?, location_is_independent = ?,
                         compensation_type = ?, compensation_amount = ?,
                         compensation_currency = ?, compensation_terms = ?,
                         additional_requirements = ?
                         WHERE id = ?`,
                        [
                            taskName,
                            description,
                            date,
                            start,
                            end,
                            location,
                            instructions || null,
                            limit,
                            status,
                            location === task.event_location ? 0 : 1,
                            compensation.type,
                            compensation.amount,
                            compensation.currency,
                            compensation.terms,
                            compensation.requirements,
                            taskId
                        ],
                        (updateErr) => {
                            if (updateErr) {
                                console.error(updateErr);
                                return res.status(500).json({ message: 'Database error' });
                            }
                            recordEventHistory(task.event_id, req.authUser.id, 'task', 'updated',
                                { task_id: taskId, task_name: taskName, status },
                                (historyErr) => {
                                    if (historyErr) {
                                        console.error(historyErr);
                                        return res.status(500).json({ message: 'Task updated but its history could not be recorded' });
                                    }
                                    notifyTaskVolunteers(
                                        taskId, task.event_id,
                                        status === 'Cancelled' ? 'task_cancelled' : 'task_updated',
                                        status === 'Cancelled' ? 'Task cancelled' : 'Task updated',
                                        status === 'Cancelled'
                                            ? `The task "${taskName}" has been cancelled.`
                                            : `The task "${taskName}" was updated. Open My Tasks to see the latest schedule and instructions.`,
                                        (notifyErr) => {
                                            if (notifyErr) {
                                                console.error(notifyErr);
                                                return res.status(500).json({ message: 'Task updated but volunteer notifications could not be sent' });
                                            }
                                            res.status(200).json({ message: 'Task updated', taskId, status });
                                        },
                                    );
                                },
                            );
                        },
                    );
                });
            });
        },
    );
});


// ===============================
// ENROLL IN A TASK
// ===============================

app.post('/api/enroll', requireAuth, (req, res) => {

    const { user_id, task_id } = req.body || {};
    const userId = req.authUser.id;
    const taskId = Number(task_id);

    if (!Number.isSafeInteger(taskId) || taskId <= 0) {
        return res.status(400).json({
            message: 'A valid task_id is required'
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
                `SELECT t.id, t.event_id, t.volunteers_required, t.status AS task_status,
                        e.status AS event_status, t.date AS task_date, t.start_time,
                        COALESCE(e.responsible_head_id, e.created_by) AS manager_id
                 FROM tasks t JOIN events e ON e.id = t.event_id
                 WHERE t.id = ?${lockTask}`,
                [taskId],
                (taskErr, tasks) => {
                    if (taskErr) return finish(taskErr);
                    if (tasks.length === 0) {
                        return finish(null, { status: 404, message: 'Task does not exist' });
                    }
                    const availableStart = new Date(
                        `${String(tasks[0].task_date).slice(0, 10)}T${tasks[0].start_time}Z`,
                    );
                    if (tasks[0].event_status !== 'published' ||
                        !['Open', 'Assigned'].includes(tasks[0].task_status) ||
                        Number.isNaN(availableStart.valueOf()) ||
                        availableStart.valueOf() < Date.now()) {
                        return finish(null, { status: 409, message: 'This task is not available for enrollment' });
                    }

                    db.query(
                        'SELECT id, status FROM enrollments WHERE user_id = ? AND task_id = ?',
                        [userId, taskId],
                        (duplicateErr, enrollments) => {
                            if (duplicateErr) return finish(duplicateErr);
                            if (enrollments.length > 0 &&
                                enrollments[0].status !== 'rejected') {
                                return finish(null, {
                                    status: 409,
                                    message: 'You are already enrolled in this task'
                                });
                            }

                            const sendManagerNotice = (enrollmentId) => {
                                const managerId = Number(tasks[0].manager_id);
                                const complete = (notifyErr) => {
                                    if (notifyErr) return finish(notifyErr);
                                    finish(null, { status: 201, enrollmentId });
                                };
                                if (!Number.isSafeInteger(managerId) ||
                                    managerId <= 0 ||
                                    managerId === userId) {
                                    return complete(null);
                                }
                                db.query(
                                    `INSERT INTO notifications (user_id, event_id, title, message, type)
                                     VALUES (?, ?, ?, ?, 'task_enrollment_request')`,
                                    [
                                        managerId,
                                        tasks[0].event_id,
                                        'New task enrollment request',
                                        `A volunteer requested to join task #${taskId}. Review the request in your event dashboard.`
                                    ],
                                    (notifyErr) => complete(notifyErr),
                                );
                            };

                            const saveEnrollment = () => {
                                if (enrollments.length > 0) {
                                    return db.query(
                                        `UPDATE enrollments
                                         SET status = 'pending', created_at = CURRENT_TIMESTAMP
                                         WHERE id = ?`,
                                        [enrollments[0].id],
                                        (updateErr) => updateErr
                                            ? finish(updateErr)
                                            : sendManagerNotice(enrollments[0].id),
                                    );
                                }

                                db.query(
                                    `INSERT INTO enrollments (user_id, task_id, status)
                                     VALUES (?, ?, 'pending')`,
                                    [userId, taskId],
                                    (insertErr, result) => insertErr
                                        ? finish(insertErr)
                                        : sendManagerNotice(result.insertId),
                                );
                            };

                            const capacity = tasks[0].volunteers_required == null
                                ? null
                                : Number(tasks[0].volunteers_required);
                            if (capacity == null) {
                                return saveEnrollment();
                            }

                            if (enrollments.length > 0) {
                                return db.query(
                                    `UPDATE enrollments
                                     SET status = 'pending', created_at = CURRENT_TIMESTAMP
                                     WHERE id = ?
                                       AND (
                                            SELECT COUNT(*) FROM enrollments
                                            WHERE task_id = ? AND status IN ('pending', 'approved')
                                       ) < ?`,
                                    [enrollments[0].id, taskId, capacity],
                                    (updateErr, result) => {
                                        if (updateErr) return finish(updateErr);
                                        const rowsAffected = Number(result?.affectedRows ?? result?.changes ?? 0);
                                        if (rowsAffected === 0) {
                                            return finish(null, {
                                                status: 409,
                                                message: 'This task has no remaining volunteer places'
                                            });
                                        }
                                        sendManagerNotice(enrollments[0].id);
                                    },
                                );
                            }

                            db.query(
                                `INSERT INTO enrollments (user_id, task_id, status)
                                 SELECT ?, ?, 'pending'
                                 WHERE (
                                     SELECT COUNT(*) FROM enrollments
                                     WHERE task_id = ? AND status IN ('pending', 'approved')
                                 ) < ?`,
                                [userId, taskId, taskId, capacity],
                                (insertErr, result) => {
                                    if (insertErr) {
                                        if (insertErr.code === 'ER_DUP_ENTRY' ||
                                            insertErr.code === 'SQLITE_CONSTRAINT' ||
                                            insertErr.code === 'SQLITE_CONSTRAINT_UNIQUE') {
                                            return finish(null, {
                                                status: 409,
                                                message: 'You are already enrolled in this task'
                                            });
                                        }
                                        return finish(insertErr);
                                    }

                                    const rowsAffected = Number(result?.affectedRows ?? result?.changes ?? 0);
                                    if (rowsAffected === 0) {
                                        return finish(null, {
                                            status: 409,
                                            message: 'This task has no remaining volunteer places'
                                        });
                                    }

                                    const enrollmentId = Number(result?.insertId ?? 0);
                                    sendManagerNotice(enrollmentId);
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
            t.description,
            t.status AS task_status,
            e.status AS event_status,
            e.area,
            e.address,
            e.meeting_point,
            e.reporting_instructions,
            e.image_url,
            e.contact_phone,
            er.selected_location,
            head.name AS head_volunteer_name,
            head.email AS head_volunteer_email,
            COALESCE(e.contact_phone, head.phone) AS head_volunteer_phone,
            en.id AS enrollment_id,
            en.status
        FROM enrollments en
        JOIN tasks t ON en.task_id = t.id
        JOIN events e ON t.event_id = e.id
        LEFT JOIN users head ON head.id = e.responsible_head_id
        LEFT JOIN event_registrations er ON er.event_id = e.id AND er.user_id = en.user_id
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
    const phone = String(req.body.phone || '').trim();
    const area = String(req.body.area || '').trim();
    if (!name || !studentId) {
        return res.status(400).json({ message: 'Name and student ID are required' });
    }
    if (name.length > 100 || studentId.length > 100) {
        return res.status(400).json({ message: 'Name and student ID must be 100 characters or fewer' });
    }
    if (phone.length > 40 || area.length > 120) {
        return res.status(400).json({ message: 'Phone must be 40 characters and area 120 characters or fewer' });
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
            'UPDATE users SET name = ?, student_id = ?, phone = ?, area = ? WHERE id = ?',
            [name, studentId, phone || null, area || null, userId],
            (err) => {
                if (err) {
                    console.error(err);
                    return res.status(500).json({ message: 'Database error' });
                }
                res.status(200).json({
                    message: 'Profile updated',
                    user: { id: userId, name, student_id: studentId, phone, area }
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
            phone,
            area,
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

app.get('/api/role-requests', requireAuth, requireAdministrator, (req, res) => {
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

app.put('/api/role-requests/:userId', requireAuth, requireAdministrator, (req, res) => {
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

app.get('/api/tasks/:taskId/volunteers', requireAuth, requireEventStaff, (req, res) => {

    const taskId = Number(req.params.taskId);
    db.query('SELECT event_id FROM tasks WHERE id = ?', [taskId], (lookupErr, tasks) => {
        if (lookupErr) {
            console.error(lookupErr);
            return res.status(500).json({ message: 'Database error' });
        }
        if (!tasks.length) return res.status(404).json({ message: 'Task not found' });
        requireEventManager(tasks[0].event_id, req.authUser.id, (accessErr, event, allowed) => {
            if (accessErr) {
                console.error(accessErr);
                return res.status(500).json({ message: 'Database error' });
            }
            if (!event || !allowed) return res.status(403).json({ message: 'You cannot manage volunteers for this task' });
            const sql = `
        SELECT
            en.id AS enrollment_id,
            u.id AS user_id,
            u.name,
            u.email,
            u.student_id,
            t.task_name,
            t.date,
            e.name AS event_name,
            e.responsible_head_id,
            head.name AS head_volunteer_name,
            head.email AS head_volunteer_email,
            COALESCE(e.contact_phone, head.phone) AS head_volunteer_phone,
            en.status
        FROM enrollments en
        JOIN users u ON en.user_id = u.id
        JOIN tasks t ON en.task_id = t.id
        JOIN events e ON e.id = t.event_id
        LEFT JOIN users head ON head.id = e.responsible_head_id
        WHERE en.task_id = ?
        ORDER BY en.status ASC, en.id DESC
    `;

            db.query(sql, [taskId], (err, results) => {
                if (err) {
                    console.error(err);
                    return res.status(500).json({ message: 'Database error' });
                }
                res.status(200).json(results);
            });
        });
    });
});


// ===============================
// GET ALL ENROLLMENTS (VOLUNTEER REQUESTS)
// ===============================

app.get('/api/enrollments', requireAuth, requireEventStaff, (req, res) => {

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
            e.responsible_head_id,
            head.name AS head_volunteer_name,
            en.status
        FROM enrollments en
        JOIN users u ON en.user_id = u.id
        JOIN tasks t ON en.task_id = t.id
        JOIN events e ON t.event_id = e.id
        LEFT JOIN users head ON head.id = e.responsible_head_id
        WHERE (? = 'Administrator' OR e.created_by = ? OR e.responsible_head_id = ?)
    `;

    const params = [req.authUser.role, req.authUser.id, req.authUser.id];

    if (status) {
        sql += ` AND en.status = ?`;
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

app.put('/api/enrollments/:enrollmentId/status', requireAuth, requireEventStaff, (req, res) => {

    const enrollmentId = req.params.enrollmentId;
    const { status } = req.body;

    const allowed = ['pending', 'approved', 'rejected'];

    if (!status || !allowed.includes(status)) {
        return res.status(400).json({
            message: 'Status must be one of: pending, approved, rejected'
        });
    }

    db.query(
        `SELECT en.id, en.user_id, t.event_id, t.task_name
         FROM enrollments en JOIN tasks t ON t.id = en.task_id
         WHERE en.id = ?`,
        [enrollmentId],
        (lookupErr, rows) => {
            if (lookupErr) {
                console.error(lookupErr);
                return res.status(500).json({ message: 'Database error' });
            }
            if (!rows.length) return res.status(404).json({ message: 'Enrollment not found' });
            const enrollment = rows[0];
            requireEventManager(enrollment.event_id, req.authUser.id, (accessErr, event, allowed) => {
                if (accessErr) {
                    console.error(accessErr);
                    return res.status(500).json({ message: 'Database error' });
                }
                if (!event || !allowed) return res.status(403).json({ message: 'You cannot update enrollments for this event' });
                db.query(
                    `UPDATE enrollments SET status = ? WHERE id = ?`,
                    [status, enrollmentId],
                    (updateErr) => {
                        if (updateErr) {
                            console.error(updateErr);
                            return res.status(500).json({ message: 'Database error' });
                        }
                        db.query(
                            `INSERT INTO notifications (user_id, event_id, title, message, type)
                             VALUES (?, ?, ?, ?, 'registration_updated')`,
                            [enrollment.user_id, enrollment.event_id,
                                status === 'approved' ? 'Task enrollment confirmed' : 'Task enrollment updated',
                                status === 'approved'
                                    ? `Your enrollment for "${enrollment.task_name}" was confirmed.`
                                    : `Your enrollment for "${enrollment.task_name}" is now ${status}.`],
                            (notifyErr) => {
                                if (notifyErr) {
                                    console.error(notifyErr);
                                    return res.status(500).json({ message: 'Enrollment updated but notification could not be created' });
                                }
                                res.status(200).json({
                                    message: `Enrollment ${status}`,
                                    enrollmentId: Number(enrollmentId)
                                });
                            },
                        );
                    },
                );
            });
        },
    );
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
        WHERE e.status = 'published'
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
        WHERE event_id = ? AND EXISTS (
            SELECT 1 FROM events WHERE events.id = announcements.event_id
            AND events.status = 'published'
        )
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

app.post('/api/announcements', requireAuth, requireEventStaff, (req, res) => {

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
        requireEventManager(event_id, req.authUser.id, (accessErr, event, allowed) => {
            if (accessErr) {
                console.error(accessErr);
                return res.status(500).json({ message: 'Database error' });
            }
            if (!event || !allowed) {
                return res.status(403).json({ message: 'You can only announce events assigned to you or created by you' });
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

app.get('/api/help-requests', requireAuth, requireEventStaff, (req, res) => {

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
            e.responsible_head_id,
            hr.message,
            hr.status,
            hr.created_at
        FROM help_requests hr
        JOIN users u ON hr.user_id = u.id
        JOIN events e ON hr.event_id = e.id
        WHERE (? = 'Administrator' OR e.created_by = ? OR e.responsible_head_id = ?)
    `;

    const params = [req.authUser.role, req.authUser.id, req.authUser.id];

    if (status) {
        sql += ` AND hr.status = ?`;
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

app.put('/api/help-requests/:requestId/status', requireAuth, requireEventStaff, (req, res) => {

    const requestId = req.params.requestId;
    const { status } = req.body;

    const allowed = ['open', 'resolved'];

    if (!status || !allowed.includes(status)) {
        return res.status(400).json({
            message: 'Status must be one of: open, resolved'
        });
    }

    db.query('SELECT event_id FROM help_requests WHERE id = ?', [requestId], (lookupErr, rows) => {
        if (lookupErr) {
            console.error(lookupErr);
            return res.status(500).json({ message: 'Database error' });
        }
        if (!rows.length) return res.status(404).json({ message: 'Help request not found' });
        requireEventManager(rows[0].event_id, req.authUser.id, (accessErr, event, allowed) => {
            if (accessErr) {
                console.error(accessErr);
                return res.status(500).json({ message: 'Database error' });
            }
            if (!event || !allowed) return res.status(403).json({ message: 'You cannot update help requests for this event' });
            db.query(`UPDATE help_requests SET status = ? WHERE id = ?`, [status, requestId], (err) => {
                if (err) {
                    console.error(err);
                    return res.status(500).json({ message: 'Database error' });
                }
                res.status(200).json({
                    message: `Help request ${status}`,
                    requestId: Number(requestId)
                });
            });
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