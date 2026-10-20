# event_volunteer

A Flutter Windows + Node.js (Express) + MySQL volunteer event management system for college events.

## Architecture

```text
Flutter Windows
      |
      | HTTP REST (localhost:3000)
      v
Node.js + Express backend
      |
      | mysql2
      v
MySQL (volunteer_db)
```

- Backend: `backend/server.js`, credentials in `backend/.env` (never committed).
- MySQL is the default authoritative store for users, events, tasks, enrollments, announcements, and help requests.
- The MySQL bootstrap limits its application account to the configured database and does not grant global database privileges.
- `DB_TYPE=sqlite` selects the backend's local SQLite store instead; it is not synchronized with MySQL.
- Passwords are bcrypt-hashed. Existing legacy plaintext password values are converted to bcrypt hashes in place at backend startup, without deleting their accounts. The API returns a signed, short-lived bearer token at login; private routes enforce account ownership and Head Volunteer permissions.
- Theme preference is stored locally on the device with `shared_preferences`. Passwords and server records are not copied to Flutter's local preferences.

### Database and access

Set `AUTH_TOKEN_SECRET` in `backend/.env` to a private random value of at least 32 characters so tokens remain valid across backend restarts. When it is omitted, the backend generates a process-local random secret and existing sessions are invalidated the next time the backend restarts.

The SQLite backend uses `SQLITE_DB_PATH` when set, or `backend/volunteer.db` otherwise. It enables foreign keys, applies additive `CREATE TABLE/INDEX IF NOT EXISTS` schema initialization, and records schema version `1` in `PRAGMA user_version`; startup does not drop or recreate existing tables. MySQL records its baseline in `schema_migrations`. Take a filesystem backup before manually editing either database.

Self-service registration creates Volunteer accounts only. A database administrator must grant Head Volunteer access to a trusted account; never expose that operation to the client:

```sql
UPDATE users SET role = 'Head Volunteer' WHERE email = 'trusted@example.com';
```

## Completed Features

### Student

- Register / Login (role-based)
- View events loaded from MySQL
- View event details and available tasks
- Enroll in a task (no duplicate enrollments allowed - returns HTTP 409)
- See enrollment status (pending / approved / rejected)
- My Tasks screen (enrolled tasks with date, times, location, instructions, status)
- Announcements (all + per event)
- Contact Head Volunteer (structured help request)

### Head Volunteer

- Role-based Dashboard
- Create Event
- Manage Events (view tasks, add tasks, view volunteers per task)
- Volunteer Requests (approve / reject enrollments)
- Announcements (create + publish)
- Help Requests (view and mark resolved)

## API Endpoints

| Method | Endpoint | Purpose |
| ------ | -------- | ------- |
| POST | /api/register | Register user (bcrypt hashed) |
| POST | /api/login | Login user |
| PUT | /api/users/:userId/profile | Update own name and student ID |
| GET | /api/events | List events |
| POST | /api/events | Create event |
| GET | /api/events/:eventId/tasks | Tasks for an event |
| POST | /api/tasks | Create task for an event |
| POST | /api/enroll | Enroll a user in a task |
| GET | /api/users/:userId/tasks | Enrolled tasks for a user |
| GET | /api/tasks/:taskId/volunteers | Volunteers of a task |
| GET | /api/enrollments | All enrollment requests |
| PUT | /api/enrollments/:enrollmentId/status | Approve / reject |
| GET | /api/announcements | All announcements |
| GET | /api/events/:eventId/announcements | Announcements for an event |
| POST | /api/announcements | Create announcement |
| POST | /api/help-requests | Submit help request |
| GET | /api/help-requests | All help requests |
| PUT | /api/help-requests/:requestId/status | Resolve help request |

## Database (volunteer_db)

Tables: `users`, `events`, `tasks`, `enrollments`, `announcements`, `help_requests`; MySQL additionally uses `schema_migrations`.

## Run

```bash
# backend
cd backend
npm test
node server.js

# flutter
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

To use SQLite instead of MySQL for a single local backend instance, set `DB_TYPE=sqlite` in `backend/.env` before `node server.js`. Restarting the backend or Flutter app does not clear its records. Verify persistence by registering, logging out, restarting, and logging in with the same account; existing user and event records remain in the authoritative backend database.

## Getting Started

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
