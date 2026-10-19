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
- Passwords are hashed with `bcryptjs` on registration and login.

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

Tables: `users`, `events`, `tasks`, `enrollments`, `announcements`, `help_requests`.

## Run

```bash
# backend
cd backend
node server.js

# flutter
flutter analyze
flutter run -d windows
```

## Getting Started

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
