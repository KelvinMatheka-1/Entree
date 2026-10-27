import { test, describe, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { TestServer } from '../helpers/testServer.js';

describe('Endpoints: Guests API (/api/v1/events/:eventId/guests)', () => {
  const server = new TestServer();

  before(async () => {
    await server.start();
  });

  after(async () => {
    await server.stop();
  });

  test('GET /api/v1/events/:eventId/guests returns list of guests', async () => {
    const res = await server.request('/api/v1/events/evt-001/guests');

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.ok(typeof res.body.count === 'number');
    assert.ok(Array.isArray(res.body.guests));
    assert.ok(res.body.guests.length > 0);
  });

  test('GET /api/v1/events/:eventId/guests?status=notArrived filters guests', async () => {
    const res = await server.request('/api/v1/events/evt-001/guests?status=notArrived');

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.ok(res.body.guests.every((g: any) => g.status === 'notArrived'));
  });

  test('GET /api/v1/events/:eventId/guests?search=Maya filters by name', async () => {
    const res = await server.request('/api/v1/events/evt-001/guests?search=Maya');

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.ok(res.body.guests.length > 0);
    assert.ok(res.body.guests[0].fullName.includes('Maya'));
  });

  test('POST /api/v1/events/:eventId/guests adds new guest to event', async () => {
    const newGuest = {
      fullName: 'Sarah Jenkins',
      email: 'sarah.j@example.com',
      phone: '+254711223344',
      tableNumber: '04',
      tableName: 'VIP Section',
      admission: 'VIP Pass',
    };

    const res = await server.request('/api/v1/events/evt-001/guests', {
      method: 'POST',
      body: newGuest,
    });

    assert.equal(res.status, 201);
    assert.equal(res.body.success, true);
    assert.ok(res.body.guest.id);
    assert.equal(res.body.guest.fullName, 'Sarah Jenkins');
    assert.equal(res.body.guest.email, 'sarah.j@example.com');
    assert.equal(res.body.guest.status, 'notArrived');
  });

  test('POST /api/v1/events/:eventId/guests returns 400 when fullName is missing', async () => {
    const res = await server.request('/api/v1/events/evt-001/guests', {
      method: 'POST',
      body: { email: 'noname@example.com' },
    });

    assert.equal(res.status, 400);
    assert.equal(res.body.success, false);
    assert.equal(res.body.code, 'VALIDATION_ERROR');
  });

  test('POST /api/v1/events/:eventId/guests returns 404 for non-existent event', async () => {
    const res = await server.request('/api/v1/events/evt-invalid-event/guests', {
      method: 'POST',
      body: { fullName: 'Orphan Guest' },
    });

    assert.equal(res.status, 404);
    assert.equal(res.body.success, false);
    assert.equal(res.body.code, 'NOT_FOUND');
  });

  test('GET /api/v1/events/:eventId/guests/stats returns guest attendance stats', async () => {
    const res = await server.request('/api/v1/events/evt-001/guests/stats');

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.ok(typeof res.body.stats.total === 'number');
    assert.ok(typeof res.body.stats.checkedIn === 'number');
    assert.ok(typeof res.body.stats.expected === 'number');
  });

  test('GET /api/v1/events/:eventId/guests/stats returns 404 for non-existent event', async () => {
    const res = await server.request('/api/v1/events/evt-ghost-event/guests/stats');

    assert.equal(res.status, 404);
    assert.equal(res.body.success, false);
    assert.equal(res.body.code, 'NOT_FOUND');
  });
});
