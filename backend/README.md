# Entree Backend - Built around the MachineNova Event API

A Node.js and TypeScript backend built to bridge the Entree event check-in application with the MachineNova Event and Checkin infrastructure (checkin-backend.machinenova.com / machinenova.com), backed by PostgreSQL.

---

## Overview

MachineNova is an event intelligence and field check-in platform utilizing Frappe RPC endpoints. This backend service acts as a dedicated application server and API proxy for the Entree Flutter app, providing:

1. **Direct MachineNova Upstream Integration**:
   - checkin.api.events.list_events
   - checkin.api.events.get_event
   - checkin.api.events.create_event
   - checkin.api.events.update_event
   - checkin.api.events.delete_event
   - checkin.api.scan.scan_for_checkin (Live ID and Pass lookup)
   - checkin.api.participants.checkin (Real-time check-in recording)
   - checkin.api.roster.* (Attendee roster and guest list management)
   - checkin.api.analytics.event_statistics (Turnout, in-region rates, and hourly flow)

2. **PostgreSQL Persistence and Offline-First Sync**:
   - Connection-pooled PostgreSQL database with parameterized queries.
   - High-speed local cache for events, guest rosters, and scan audit logs.
   - Built-in Background Sync Worker that queues mutations (CREATE_EVENT, CHECKIN, UPDATE_EVENT) when network drops or credentials are unverified, and automatically flushes them upstream when reconnected.

3. **Hybrid Operating Mode**:
   - Operates in Local Mode with pre-seeded demo data.
   - Automatically switches to Live MachineNova Mode when credentials (MACHINENOVA_USERNAME/PASSWORD or MACHINENOVA_API_KEY/SECRET) are configured.

---

## Tech Stack

- Runtime: Node.js (v20+ / v24 LTS)
- Language: TypeScript 5.8
- Framework: Express 4
- Database: PostgreSQL 16 (via pg connection pool)
- Containerization: Docker (multi-stage) and Docker Compose
- HTTP Client: Axios with session cookie jar and Token auth
- Dev Runner: tsx (TypeScript Execution with Hot-Reload)

---

## Running with Docker and PostgreSQL

### Start via Docker Compose

```bash
docker compose up -d
```

This starts:
1. PostgreSQL 16 on port 5432 with health checks.
2. Entree backend service on port 4000.

### Check Service Status and Logs

```bash
docker compose ps
docker compose logs -f backend
```

### Stop Services

```bash
docker compose down
```

---

## Manual Setup (Without Docker)

### 1. Install Dependencies

```bash
cd backend
npm install
```

### 2. Configure Environment

Copy the example environment configuration:

```bash
cp .env.example .env
```

Ensure a PostgreSQL database is running and adjust the database URL:

```env
PORT=4000
HOST=0.0.0.0
NODE_ENV=development

DATABASE_URL=postgres://postgres:postgrespassword@localhost:5432/entree_db
PGHOST=localhost
PGPORT=5432
PGUSER=postgres
PGPASSWORD=postgrespassword
PGDATABASE=entree_db

# Optional MachineNova credentials
MACHINENOVA_BASE_URL=https://checkin-backend.machinenova.com
MACHINENOVA_FRONTEND_URL=https://checkin.machinenova.com
MACHINENOVA_ORG_SLUG=
MACHINENOVA_USERNAME=
MACHINENOVA_PASSWORD=
MACHINENOVA_API_KEY=
MACHINENOVA_API_SECRET=
```

### 3. Run in Development Mode

```bash
npm run dev
```

### 4. Build and Start for Production

```bash
npm run build
npm start
```

---

## API Reference

Base URL: `http://localhost:4000/api/v1`

### 1. System and Authentication
- `GET /health` - Health check, server uptime, and status.
- `POST /api/v1/auth/login` - Authenticate against MachineNova (/api/method/login).
- `GET /api/v1/auth/me` - Get current user information (checkin.api.users.me).
- `GET /api/v1/auth/status` - Upstream connectivity and configuration status.

### 2. Events (/api/v1/events)
- `GET /` - List events. Query params:
  - `status`: Filter by live, upcoming, draft, past.
  - `search`: Search name, venue, collection.
  - `refresh=true`: Force upstream sync from MachineNova.
- `GET /:id` - Get single event with live attendance numbers.
- `POST /` - Create an event (pushed to MachineNova and stored in PostgreSQL).
- `PUT /:id` - Update event details.
- `DELETE /:id` - Delete event.
- `GET /:id/stats` - Real-time event statistics.

### 3. Guest Roster (/api/v1/events/:eventId/guests)
- `GET /` - List guests for an event. Query params:
  - `status`: checkedIn | notArrived.
  - `search`: Filter by name, email, pass ID.
- `POST /` - Add guest / pass holder to event roster.
- `GET /stats` - Total, expected, arrived, in-region vs out-of-region counts.

### 4. Scanning and Check-in (/api/v1/events/:eventId)
- `GET /scan?passId=<id>` - Verify a QR code pass or National ID against MachineNova. Returns:
  - `canCheckIn`: Boolean flag indicating readiness.
  - `status`: ready | already_checked_in | not_on_roster | outside_jurisdiction.
  - `message`: User-friendly status message.
  - `guest`: Resolved attendee record.
- `POST /checkin` - Execute check-in for pass ID. Records time, increments count, pushes to MachineNova.
- `POST /undo-checkin` - Revert a check-in scanned by mistake.

### 5. Offline Sync (/api/v1/sync)
- `GET /status` - View pending, failed, and completed background sync jobs.
- `POST /trigger` - Manually trigger immediate queue processing.

---

## Connecting the Flutter App

The Flutter client has an integrated `ApiService` (`lib/services/api_service.dart`):

```dart
// Default base URL:
ApiService.baseUrl = 'http://localhost:4000/api/v1';

// For Android emulator:
ApiService.baseUrl = 'http://10.0.2.2:4000/api/v1';

// For physical device over Wi-Fi:
ApiService.baseUrl = 'http://<YOUR_LAN_IP>:4000/api/v1';
```

If the backend server is stopped, the Flutter app automatically and gracefully falls back to local in-memory data, ensuring uninterrupted operation in offline or testing environments.
