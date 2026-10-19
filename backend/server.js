const express = require('express');
const cors = require('cors');
const mysql = require('mysql2');
const bcrypt = require('bcryptjs');
require('dotenv').config();

const app = express();

app.use(cors());
app.use(express.json());


// ===============================
// MYSQL CONNECTION
// ===============================

const db = mysql.createConnection({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    port: process.env.DB_PORT,
    dateStrings: true
});

db.connect((err) => {
    if (err) {
        console.log('MySQL connection failed:');
        console.log(err);
        return;
    }

    console.log('MySQL connected successfully!');
});

const BCRYPT_PREFIX = '$2';

// ===============================
// HOME
// ===============================

app.get('/', (req, res) => {
    res.send('Volunteer backend is running!');
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
        role
    } = req.body;

    if (!name || !email || !student_id || !password || !role) {
        return res.status(400).json({
            message: 'All fields are required'
        });
    }

    bcrypt.hash(String(password), 10, (hashErr, hash) => {
        if (hashErr) {
            return res.status(500).json({
                message: 'Failed to secure password'
            });
        }

        const sql = `
            INSERT INTO users
            (name, email, student_id, password, role)
            VALUES (?, ?, ?, ?, ?)
        `;

        db.query(
            sql,
            [name, email, student_id, hash, role],
            (err, result) => {

                if (err) {

                    if (err.code === 'ER_DUP_ENTRY') {
                        return res.status(409).json({
                            message: 'Email already registered'
                        });
                    }

                    console.log(err);

                    return res.status(500).json({
                        message: 'Database error'
                    });
                }

                res.status(201).json({
                    message: 'Registration successful',
                    userId: result.insertId
                });
            }
        );
    });
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

    const sql = `
        SELECT
            id,
            name,
            email,
            student_id,
            password,
            role
        FROM users
        WHERE email = ?
    `;

    db.query(
        sql,
        [email],
        (err, results) => {

            if (err) {
                console.log(err);

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
                    user: {
                        id: user.id,
                        name: user.name,
                        email: user.email,
                        student_id: user.student_id,
                        role: user.role
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

app.post('/api/events', (req, res) => {

    const {
        name,
        date,
        location,
        description,
        volunteers_needed
    } = req.body;

    if (!name || !date || !location) {
        return res.status(400).json({
            message: 'Event name, date and location are required'
        });
    }

    const sql = `
        INSERT INTO events
        (name, date, location, description, volunteers_needed)
        VALUES (?, ?, ?, ?, ?)
    `;

    db.query(
        sql,
        [name, date, location, description || null, volunteers_needed || null],
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

app.post('/api/tasks', (req, res) => {

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

    if (!event_id || !task_name || !date || !start_time || !end_time || !location) {
        return res.status(400).json({
            message: 'Event, task name, date, times and location are required'
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
            INSERT INTO tasks
            (event_id, task_name, date, start_time, end_time, location, instructions, volunteers_required)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `;

        db.query(
            sql,
            [event_id, task_name, date, start_time, end_time, location, instructions || null, volunteers_required || null],
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

app.post('/api/enroll', (req, res) => {

    const {
        user_id,
        task_id
    } = req.body;

    if (!user_id || !task_id) {
        return res.status(400).json({
            message: 'user_id and task_id are required'
        });
    }

    const checkUserSql = `SELECT id FROM users WHERE id = ?`;
    const checkTaskSql = `SELECT id FROM tasks WHERE id = ?`;

    db.query(checkUserSql, [user_id], (userErr, userResults) => {

        if (userErr) {
            console.log(userErr);

            return res.status(500).json({
                message: 'Database error'
            });
        }

        if (userResults.length === 0) {
            return res.status(400).json({
                message: 'User does not exist'
            });
        }

        db.query(checkTaskSql, [task_id], (taskErr, taskResults) => {

            if (taskErr) {
                console.log(taskErr);

                return res.status(500).json({
                    message: 'Database error'
                });
            }

            if (taskResults.length === 0) {
                return res.status(400).json({
                    message: 'Task does not exist'
                });
            }

            const duplicateSql = `
                SELECT id FROM enrollments
                WHERE user_id = ? AND task_id = ? AND status IN ('pending', 'approved')
            `;

            db.query(duplicateSql, [user_id, task_id], (dupErr, dupResults) => {

                if (dupErr) {
                    console.log(dupErr);

                    return res.status(500).json({
                        message: 'Database error'
                    });
                }

                if (dupResults.length > 0) {
                    return res.status(409).json({
                        message: 'You are already enrolled in this task'
                    });
                }

                const sql = `
                    INSERT INTO enrollments
                    (user_id, task_id, status)
                    VALUES (?, ?, 'pending')
                `;

                db.query(sql, [user_id, task_id], (err, result) => {

                    if (err) {
                        console.log(err);

                        return res.status(500).json({
                            message: 'Database error'
                        });
                    }

                    res.status(201).json({
                        message: 'Enrollment submitted',
                        enrollmentId: result.insertId,
                        status: 'pending'
                    });
                });
            });
        });
    });
});


// ===============================
// GET ENROLLED TASKS FOR A USER (MY TASKS)
// ===============================

app.get('/api/users/:userId/tasks', (req, res) => {

    const userId = req.params.userId;

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


// ===============================
// GET VOLUNTEERS FOR A TASK
// ===============================

app.get('/api/tasks/:taskId/volunteers', (req, res) => {

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

app.get('/api/enrollments', (req, res) => {

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

app.put('/api/enrollments/:enrollmentId/status', (req, res) => {

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

app.post('/api/announcements', (req, res) => {

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
            VALUES (?, ?, ?, NOW())
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

app.post('/api/help-requests', (req, res) => {

    const {
        user_id,
        event_id,
        message
    } = req.body;

    if (!user_id || !event_id || !message) {
        return res.status(400).json({
            message: 'user_id, event_id and message are required'
        });
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
            VALUES (?, ?, ?, 'open', NOW())
        `;

        db.query(sql, [user_id, event_id, message], (err, result) => {

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

app.get('/api/help-requests', (req, res) => {

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

app.put('/api/help-requests/:requestId/status', (req, res) => {

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

const PORT = process.env.PORT || 3000;

app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on http://0.0.0.0:${PORT}`);
});