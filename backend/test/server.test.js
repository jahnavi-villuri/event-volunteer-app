const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { after, before, test } = require('node:test');
const bcrypt = require('bcryptjs');
const sqlite3 = require('sqlite3').verbose();

const tempDirectory = fs.mkdtempSync(path.join(os.tmpdir(), 'event-volunteer-'));
const databasePath = path.join(tempDirectory, 'test.db');
process.env.DB_TYPE = 'sqlite';
process.env.SQLITE_DB_PATH = databasePath;
process.env.AUTH_TOKEN_SECRET = 'test-only-auth-secret-that-is-long-enough';

const { app, closeDatabase, getDatabase, initializeDatabase } = require('../server');
let server;
let baseUrl;

const request = async (pathname, { method = 'GET', body, token } = {}) => {
  const response = await fetch(`${baseUrl}${pathname}`, {
    method,
    signal: AbortSignal.timeout(5000),
    headers: {
      ...(body ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  return { status: response.status, body: await response.json() };
};

const insertHeadUser = async () => {
  const password = 'admin-password-123';
  const passwordHash = await bcrypt.hash(password, 10);
  const connection = new sqlite3.Database(databasePath);
  const userId = await new Promise((resolve, reject) => {
    connection.run(
      `INSERT INTO users (name, email, student_id, password, role)
       VALUES (?, ?, ?, ?, ?)`,
      ['Head Volunteer', 'head@example.test', 'HEAD-1', passwordHash, 'Head Volunteer'],
      function (error) {
        if (error) reject(error);
        else resolve(this.lastID);
      },
    );
  });
  await new Promise((resolve, reject) =>
    connection.close((error) => (error ? reject(error) : resolve())),
  );
  return { userId, password };
};

before(async () => {
  const legacyConnection = new sqlite3.Database(databasePath);
  await new Promise((resolve, reject) => {
    legacyConnection.exec(
      `CREATE TABLE users (
         id INTEGER PRIMARY KEY AUTOINCREMENT,
         name TEXT NOT NULL,
         email TEXT UNIQUE NOT NULL,
         student_id TEXT NOT NULL,
         password TEXT NOT NULL,
         role TEXT NOT NULL DEFAULT 'Volunteer',
         created_at TEXT DEFAULT CURRENT_TIMESTAMP
       );
       INSERT INTO users (name, email, student_id, password, role)
       VALUES ('Legacy Volunteer', 'legacy@example.test', 'LEG-1', 'legacy-password', 'Volunteer');`,
      (error) => (error ? reject(error) : resolve()),
    );
  });
  await new Promise((resolve, reject) =>
    legacyConnection.close((error) => (error ? reject(error) : resolve())),
  );
  await initializeDatabase();
  server = await new Promise((resolve) => {
    const listeningServer = app.listen(0, '127.0.0.1', () => resolve(listeningServer));
  });
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  if (server) {
    await new Promise((resolve, reject) =>
      server.close((error) => (error ? reject(error) : resolve())),
    );
  }
  await closeDatabase();
  fs.rmSync(tempDirectory, { recursive: true, force: true });
});

test('SQLite persistence, authentication, permissions, and event workflows', async () => {
  const schema = getDatabase();
  const foreignKeys = await new Promise((resolve, reject) =>
    schema.get('PRAGMA foreign_keys', (error, row) =>
      error ? reject(error) : resolve(row.foreign_keys),
    ),
  );
  const schemaVersion = await new Promise((resolve, reject) =>
    schema.get('PRAGMA user_version', (error, row) =>
      error ? reject(error) : resolve(row.user_version),
    ),
  );
  assert.equal(foreignKeys, 1);
  assert.equal(schemaVersion, 4);
  const migratedPassword = await new Promise((resolve, reject) =>
    schema.get(
      'SELECT password FROM users WHERE email = ?',
      ['legacy@example.test'],
      (error, row) => (error ? reject(error) : resolve(row.password)),
    ),
  );
  assert.notEqual(migratedPassword, 'legacy-password');
  assert.ok(migratedPassword.startsWith('$2'));

  const legacyLogin = await request('/api/login', {
    method: 'POST',
    body: { email: 'legacy@example.test', password: 'legacy-password' },
  });
  assert.equal(legacyLogin.status, 200);

  // Validation: Missing role returns 400
  const missingRole = await request('/api/register', {
    method: 'POST',
    body: {
      name: 'No Role',
      email: 'norole@example.test',
      student_id: 'NOROLE-1',
      password: 'password123',
    },
  });
  assert.equal(missingRole.status, 400);

  // Validation: Invalid role returns 400
  const invalidRole = await request('/api/register', {
    method: 'POST',
    body: {
      name: 'Bad Role',
      email: 'badrole@example.test',
      student_id: 'BADROLE-1',
      password: 'password123',
      role: 'SuperAdmin',
    },
  });
  assert.equal(invalidRole.status, 400);

  const headRegistration = await request('/api/register', {
    method: 'POST',
    body: {
      name: 'Self-activated Head',
      email: 'self-head@example.test',
      student_id: 'HEAD-SELF-1',
      password: 'head-password',
      role: 'Head Volunteer',
    },
  });
  assert.equal(headRegistration.status, 201);
  assert.equal(headRegistration.body.role, 'Head Volunteer');
  assert.equal(headRegistration.body.role_status, 'approved');
  const selfHeadLogin = await request('/api/login', {
    method: 'POST',
    body: { email: 'self-head@example.test', password: 'head-password' },
  });
  assert.equal(selfHeadLogin.status, 200);
  assert.equal(selfHeadLogin.body.user.role, 'Head Volunteer');

  const registration = await request('/api/register', {
    method: 'POST',
    body: {
      name: 'Test Volunteer',
      email: ' Volunteer@Example.Test ',
      student_id: 'VOL-1',
      password: 'volunteer-password',
      role: 'Volunteer',
    },
  });
  assert.equal(registration.status, 201);
  assert.equal(registration.body.role, 'Volunteer');
  assert.equal(registration.body.role_requested, 'Volunteer');
  assert.equal(registration.body.role_status, 'approved');

  const duplicate = await request('/api/register', {
    method: 'POST',
    body: {
      name: 'Duplicate',
      email: 'volunteer@example.test',
      student_id: 'VOL-2',
      password: 'other-password',
      role: 'Volunteer',
    },
  });
  assert.equal(duplicate.status, 409);

  const invalidLogin = await request('/api/login', {
    method: 'POST',
    body: { email: 'volunteer@example.test', password: 'incorrect' },
  });
  assert.equal(invalidLogin.status, 401);

  const login = await request('/api/login', {
    method: 'POST',
    body: { email: 'VOLUNTEER@example.test', password: 'volunteer-password' },
  });
  assert.equal(login.status, 200);
  assert.ok(login.body.token);
  assert.equal(login.body.user.role, 'Volunteer');
  const volunteerToken = login.body.token;
  const volunteerId = login.body.user.id;

  const blockedWithoutLogin = await request('/api/events', {
    method: 'POST',
    body: { name: 'Unauthorized event', date: '2030-06-01', location: 'Hall' },
  });
  assert.equal(blockedWithoutLogin.status, 401);

  const blockedPrivilegeEscalation = await request('/api/events', {
    method: 'POST',
    token: volunteerToken,
    body: { name: 'Unauthorized event', date: '2030-06-01', location: 'Hall' },
  });
  assert.equal(blockedPrivilegeEscalation.status, 403);

  const head = await insertHeadUser();
  const headLogin = await request('/api/login', {
    method: 'POST',
    body: { email: 'head@example.test', password: head.password },
  });
  assert.equal(headLogin.status, 200);
  const headToken = headLogin.body.token;

  const invalidEvent = await request('/api/events', {
    method: 'POST',
    token: headToken,
    body: { name: 'Invalid date', date: '2030-02-30', location: 'Hall' },
  });
  assert.equal(invalidEvent.status, 400);

  const profileUpdate = await request(`/api/users/${volunteerId}/profile`, {
    method: 'PUT',
    token: volunteerToken,
    body: { name: 'Updated Volunteer', student_id: 'VOL-UPDATED' },
  });
  assert.equal(profileUpdate.status, 200);
  assert.equal(profileUpdate.body.user.name, 'Updated Volunteer');

  const otherProfileUpdate = await request(`/api/users/${head.userId}/profile`, {
    method: 'PUT',
    token: volunteerToken,
    body: { name: 'Impersonated', student_id: 'HEAD-1' },
  });
  assert.equal(otherProfileUpdate.status, 403);

  const eventResponse = await request('/api/events', {
    method: 'POST',
    token: headToken,
    body: {
      name: 'Persistence Test Event',
      date: '2030-06-01',
      location: 'Community Hall',
      description: 'Created during the isolated test',
      status: 'published',
      category: 'Community',
      start_time: '09:00:00',
      end_time: '12:00:00',
      area: 'Downtown',
      volunteers_needed: 1,
    },
  });
  assert.equal(eventResponse.status, 201);
  const eventId = eventResponse.body.eventId;

  const nearDate = new Date(Date.now() + 2 * 24 * 60 * 60 * 1000)
    .toISOString()
    .slice(0, 10);
  const tooSoon = await request('/api/events', {
    method: 'POST',
    token: headToken,
    body: {
      name: 'Last-minute event',
      date: nearDate,
      start_time: '09:00:00',
      end_time: '11:00:00',
      location: 'Community Hall',
      status: 'published',
    },
  });
  assert.equal(tooSoon.status, 400);
  assert.match(tooSoon.body.message, /5 full days/);

  const draft = await request('/api/events', {
    method: 'POST',
    token: headToken,
    body: {
      name: 'Deadline draft',
      date: nearDate,
      location: 'Community Hall',
      status: 'draft',
    },
  });
  assert.equal(draft.status, 201);
  const earlyPublish = await request(`/api/events/${draft.body.eventId}/publish`, {
    method: 'PUT',
    token: headToken,
  });
  assert.equal(earlyPublish.status, 400);
  const laterDate = new Date(Date.now() + 10 * 24 * 60 * 60 * 1000)
    .toISOString()
    .slice(0, 10);
  const rescheduledDraft = await request(`/api/events/${draft.body.eventId}`, {
    method: 'PUT',
    token: headToken,
    body: {
      date: laterDate,
      start_time: '09:00:00',
      end_time: '11:00:00',
      status: 'draft',
    },
  });
  assert.equal(rescheduledDraft.status, 200);
  const publishDraft = await request(`/api/events/${draft.body.eventId}/publish`, {
    method: 'PUT',
    token: headToken,
  });
  assert.equal(publishDraft.status, 200);

  const invalidTask = await request('/api/tasks', {
    method: 'POST',
    token: headToken,
    body: {
      event_id: eventId,
      task_name: 'Invalid time range',
      date: '2030-06-01',
      start_time: '12:00:00',
      end_time: '11:00:00',
      location: 'Main entrance',
    },
  });
  assert.equal(invalidTask.status, 400);

  const invalidCompensationTask = await request('/api/tasks', {
    method: 'POST',
    token: headToken,
    body: {
      event_id: eventId,
      task_name: 'Invalid compensation',
      description: 'Support attendees at the entrance.',
      date: '2030-06-01',
      start_time: '09:00:00',
      end_time: '11:00:00',
      location: 'Main entrance',
      volunteers_required: 2,
      compensation_type: 'unpaid',
      compensation_amount: 100,
    },
  });
  assert.equal(invalidCompensationTask.status, 400);

  const taskResponse = await request('/api/tasks', {
    method: 'POST',
    token: headToken,
    body: {
      event_id: eventId,
      task_name: 'Welcome desk',
      description: 'Welcome attendees and guide them to registration.',
      date: '2030-06-01',
      start_time: '09:00:00',
      end_time: '11:00:00',
      location: 'Main entrance',
      volunteers_required: 1,
      compensation_type: 'fixed',
      compensation_amount: 750,
      compensation_currency: 'INR',
      compensation_terms: 'Paid after the event concludes.',
      additional_requirements: 'Comfortable speaking with attendees.',
    },
  });
  assert.equal(taskResponse.status, 201);
  const taskId = taskResponse.body.taskId;
  const eventTasks = await request(`/api/events/${eventId}/tasks`, {
    token: volunteerToken,
  });
  assert.equal(eventTasks.status, 200);
  assert.equal(eventTasks.body[0].remaining_places, 1);
  assert.equal(eventTasks.body[0].compensation_type, 'fixed');
  assert.equal(Number(eventTasks.body[0].compensation_amount), 750);
  assert.equal(
    eventTasks.body[0].additional_requirements,
    'Comfortable speaking with attendees.',
  );
  const eventList = await request('/api/events');
  assert.equal(eventList.status, 200);
  assert.ok(eventList.body.some((event) => event.id === eventId));
  assert.ok(eventList.body.every((event) => event.status === 'published'));

  const areaEvents = await request('/api/events?area=Downtown&category=community&available=true');
  assert.equal(areaEvents.status, 200);
  assert.ok(areaEvents.body.some((event) => event.id === eventId));

  const eventRegistration = await request(`/api/events/${eventId}/register`, {
    method: 'POST',
    token: volunteerToken,
    body: { selected_location: 'North entrance' },
  });
  assert.equal(eventRegistration.status, 201);
  const duplicateEventRegistration = await request(`/api/events/${eventId}/register`, {
    method: 'POST',
    token: volunteerToken,
    body: { selected_location: 'North entrance' },
  });
  assert.equal(duplicateEventRegistration.status, 409);
  const notifications = await request('/api/notifications', { token: volunteerToken });
  assert.ok(notifications.body.some((notification) => notification.type === 'registration_confirmed'));
  const registrations = await request(`/api/users/${volunteerId}/events`, { token: volunteerToken });
  assert.equal(registrations.status, 200);
  assert.equal(registrations.body[0].selected_location, 'North entrance');
  assert.equal(registrations.body[0].head_volunteer_name, 'Head Volunteer');

  const enrollment = await request('/api/enroll', {
    method: 'POST',
    token: volunteerToken,
    body: { user_id: volunteerId, task_id: taskId },
  });
  assert.equal(enrollment.status, 201);
  const headTaskNotifications = await request('/api/notifications', {
    token: headToken,
  });
  assert.ok(
    headTaskNotifications.body.some(
      (notification) =>
        notification.type === 'task_enrollment_request' &&
        notification.event_id === eventId,
    ),
  );

  const duplicateEnrollment = await request('/api/enroll', {
    method: 'POST',
    token: volunteerToken,
    body: { user_id: volunteerId, task_id: taskId },
  });
  assert.equal(duplicateEnrollment.status, 409);

  const rejection = await request(`/api/enrollments/${enrollment.body.enrollmentId}/status`, {
    method: 'PUT',
    token: headToken,
    body: { status: 'rejected' },
  });
  assert.equal(rejection.status, 200);
  const renewedEnrollment = await request('/api/enroll', {
    method: 'POST',
    token: volunteerToken,
    body: { user_id: volunteerId, task_id: taskId },
  });
  assert.equal(renewedEnrollment.status, 201);
  assert.equal(renewedEnrollment.body.enrollmentId, enrollment.body.enrollmentId);

  const secondRegistration = await request('/api/register', {
    method: 'POST',
    body: {
      name: 'Second Volunteer',
      email: 'second@example.test',
      student_id: 'VOL-2',
      password: 'second-password',
      role: 'Volunteer',
    },
  });
  assert.equal(secondRegistration.status, 201);
  const secondLogin = await request('/api/login', {
    method: 'POST',
    body: { email: 'second@example.test', password: 'second-password' },
  });
  assert.equal(secondLogin.status, 200);

  const fullEventRegistration = await request(`/api/events/${eventId}/register`, {
    method: 'POST',
    token: secondLogin.body.token,
    body: { selected_location: 'South entrance' },
  });
  assert.equal(fullEventRegistration.status, 409);

  const fullTask = await request('/api/enroll', {
    method: 'POST',
    token: secondLogin.body.token,
    body: { task_id: taskId },
  });
  assert.equal(fullTask.status, 409);

  const concurrentTaskResponse = await request('/api/tasks', {
    method: 'POST',
    token: headToken,
    body: {
      event_id: eventId,
      task_name: 'Concurrent enrollment task',
      description: 'Manage participant check-ins and event questions.',
      date: '2030-06-01',
      start_time: '12:00:00',
      end_time: '13:00:00',
      location: 'Main entrance',
      volunteers_required: 1,
    },
  });
  assert.equal(concurrentTaskResponse.status, 201);
  const concurrentTaskId = concurrentTaskResponse.body.taskId;
  const concurrentEnrollments = await Promise.all([
    request('/api/enroll', {
      method: 'POST',
      token: volunteerToken,
      body: { task_id: concurrentTaskId },
    }),
    request('/api/enroll', {
      method: 'POST',
      token: secondLogin.body.token,
      body: { task_id: concurrentTaskId },
    }),
  ]);
  assert.deepEqual(
    concurrentEnrollments.map((response) => response.status).sort(),
    [201, 409],
  );
  const capacityAfterConcurrentRequests = await request(
    `/api/events/${eventId}/tasks`,
    { token: headToken },
  );
  const concurrentTask = capacityAfterConcurrentRequests.body.find(
    (task) => task.id === concurrentTaskId,
  );
  assert.equal(concurrentTask.pending_count, 1);
  assert.equal(concurrentTask.remaining_places, 0);

  const impersonation = await request('/api/enroll', {
    method: 'POST',
    token: volunteerToken,
    body: { user_id: head.userId, task_id: taskId },
  });
  assert.equal(impersonation.status, 403);

  const ownTasks = await request(`/api/users/${volunteerId}/tasks`, {
    token: volunteerToken,
  });
  assert.equal(ownTasks.status, 200);
  assert.equal(ownTasks.body.length, 1);

  const otherUsersTasks = await request(`/api/users/${head.userId}/tasks`, {
    token: volunteerToken,
  });
  assert.equal(otherUsersTasks.status, 403);

  const announcement = await request('/api/announcements', {
    method: 'POST',
    token: headToken,
    body: { event_id: eventId, title: 'Welcome', message: 'Thank you for joining.' },
  });
  assert.equal(announcement.status, 201);

  const helpRequest = await request('/api/help-requests', {
    method: 'POST',
    token: volunteerToken,
    body: { user_id: volunteerId, event_id: eventId, message: 'Where should I meet?' },
  });
  assert.equal(helpRequest.status, 201);

  const readOnlyAccessDenied = await request('/api/help-requests', {
    token: volunteerToken,
  });
  assert.equal(readOnlyAccessDenied.status, 403);

  const legacyConnection = new sqlite3.Database(databasePath);
  await new Promise((resolve, reject) =>
    legacyConnection.run('PRAGMA user_version = 0', (error) =>
      error ? reject(error) : resolve(),
    ),
  );
  await new Promise((resolve, reject) =>
    legacyConnection.close((error) => (error ? reject(error) : resolve())),
  );
  await closeDatabase();
  await initializeDatabase();
  const migratedVersion = await new Promise((resolve, reject) =>
    getDatabase().get('PRAGMA user_version', (error, row) =>
      error ? reject(error) : resolve(row.user_version),
    ),
  );
  assert.equal(migratedVersion, 4);
  const persistedTasks = await request(`/api/users/${volunteerId}/tasks`, {
    token: volunteerToken,
  });
  assert.equal(persistedTasks.status, 200);
  assert.equal(persistedTasks.body[0].task_name, 'Welcome desk');
  assert.equal(persistedTasks.body[0].status, 'pending');
  assert.equal(persistedTasks.body[0].head_volunteer_email, 'head@example.test');
  const persistedAnnouncements = await request('/api/announcements');
  assert.ok(
    persistedAnnouncements.body.some((item) => item.title === 'Welcome'),
  );
  const persistedHelpRequests = await request('/api/help-requests', {
    token: headToken,
  });
  assert.equal(persistedHelpRequests.status, 200);
  assert.ok(
    persistedHelpRequests.body.some(
      (item) => item.message === 'Where should I meet?',
    ),
  );
  const resolveHelp = await request(
    `/api/help-requests/${helpRequest.body.requestId}/status`,
    {
      method: 'PUT',
      token: headToken,
      body: { status: 'resolved' },
    },
  );
  assert.equal(resolveHelp.status, 200);
  const persistedLogin = await request('/api/login', {
    method: 'POST',
    body: { email: 'volunteer@example.test', password: 'volunteer-password' },
  });
  assert.equal(persistedLogin.status, 200);
  assert.equal(persistedLogin.body.user.name, 'Updated Volunteer');
  assert.equal(persistedLogin.body.user.student_id, 'VOL-UPDATED');

  // Health check endpoint
  const health = await request('/api/health');
  assert.equal(health.status, 200);
  assert.equal(health.body.status, 'ok');

  // Verify unauthorized user cannot list role requests
  const blockedRoleRequests = await request('/api/role-requests', {
    token: volunteerToken,
  });
  assert.equal(blockedRoleRequests.status, 403);

  // Head Volunteers no longer approve other Head Volunteer accounts.
  const headRoleRequests = await request('/api/role-requests', {
    token: headToken,
  });
  const approvalResponse = await request(`/api/role-requests/${volunteerId}`, {
    method: 'PUT',
    token: headToken,
    body: { action: 'approve' },
  });
  assert.equal(headRoleRequests.status, 403);
  assert.equal(approvalResponse.status, 403);
  const postApprovalLogin = await request('/api/login', {
    method: 'POST',
    body: { email: 'volunteer@example.test', password: 'volunteer-password' },
  });
  assert.equal(postApprovalLogin.status, 200);
  assert.equal(postApprovalLogin.body.user.role, 'Volunteer');
  assert.equal(postApprovalLogin.body.user.role_status, 'approved');
});
