import { test, describe, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { TestServer } from '../helpers/testServer.js';

describe('Endpoints: Events API (/api/v1/events)', () => {
  const server = new TestServer();

  before(async () => {
    await server.start();
  });

  after(async () => {
    await server.stop();
  });

  test('GET /api/v1/events returns 200 with list of events', async () => {
    const res = await server.request('/api/v1/events');

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.ok(typeof res.body.count === 'number');
    assert.ok(Array.isArray(res.body.events));
    assert.ok(res.body.events.length >= 5);
  });

  test('GET /api/v1/events?status=live filters events by status', async () => {
    const res = await server.request('/api/v1/events?status=live');

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.ok(res.body.events.every((e: any) => e.status === 'live'));
  });

  test('GET /api/v1/events?search=Chameleon filters events by search query', async () => {
    const res = await server.request('/api/v1/events?search=Chameleon');

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.ok(res.body.events.length > 0);
    assert.ok(res.body.events[0].name.includes('Chameleon'));
  });

  test('GET /api/v1/events/:id returns 200 for existing event', async () => {
    const res = await server.request('/api/v1/events/evt-001');

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.equal(res.body.event.id, 'evt-001');
    assert.equal(res.body.event.name, 'Urban Chameleon: Contemporary Street Art Expo');
  });

  test('GET /api/v1/events/:id returns 404 for non-existent event', async () => {
    const res = await server.request('/api/v1/events/evt-does-not-exist');

    assert.equal(res.status, 404);
    assert.equal(res.body.success, false);
    assert.equal(res.body.code, 'NOT_FOUND');
  });

  test('POST /api/v1/events creates new event and returns 201', async () => {
    const newEvent = {
      name: 'Future Mobility Summit 2026',
      date: '2026-11-28',
      venue: 'Sarit Expo Center',
      tables: 15,
      seatsPerTable: 8,
      status: 'upcoming',
      isPaid: false,
    };

    const res = await server.request('/api/v1/events', {
      method: 'POST',
      body: newEvent,
    });

    assert.equal(res.status, 201);
    assert.equal(res.body.success, true);
    assert.ok(res.body.event.id);
    assert.equal(res.body.event.name, 'Future Mobility Summit 2026');
    assert.equal(res.body.event.totalCapacity, 120);
  });

  test('POST /api/v1/events returns 400 when required fields are missing', async () => {
    const res = await server.request('/api/v1/events', {
      method: 'POST',
      body: { venue: 'Empty Name and Date' },
    });

    assert.equal(res.status, 400);
    assert.equal(res.body.success, false);
    assert.equal(res.body.code, 'VALIDATION_ERROR');
    assert.ok(Array.isArray(res.body.details));
  });

  test('PUT /api/v1/events/:id updates event fields', async () => {
    const updatePayload = {
      name: 'Urban Chameleon Expo (Updated Title)',
      description: 'Updated description for contemporary art expo.',
    };

    const res = await server.request('/api/v1/events/evt-001', {
      method: 'PUT',
      body: updatePayload,
    });

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.equal(res.body.event.name, 'Urban Chameleon Expo (Updated Title)');
    assert.equal(res.body.event.description, 'Updated description for contemporary art expo.');
  });

  test('PUT /api/v1/events/:id returns 404 for non-existent event', async () => {
    const res = await server.request('/api/v1/events/evt-ghost-update', {
      method: 'PUT',
      body: { name: 'Cannot Update' },
    });

    assert.equal(res.status, 404);
    assert.equal(res.body.success, false);
    assert.equal(res.body.code, 'NOT_FOUND');
  });

  test('GET /api/v1/events/:id/stats returns 200 aggregate stats', async () => {
    const res = await server.request('/api/v1/events/evt-001/stats');

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.ok(res.body.event);
    assert.ok(res.body.stats);
    assert.ok(typeof res.body.stats.total === 'number');
    assert.ok(typeof res.body.stats.checkedIn === 'number');
  });

  test('GET /api/v1/events/:id/stats returns 404 for non-existent event', async () => {
    const res = await server.request('/api/v1/events/evt-ghost-stats/stats');

    assert.equal(res.status, 404);
    assert.equal(res.body.success, false);
    assert.equal(res.body.code, 'NOT_FOUND');
  });

  test('DELETE /api/v1/events/:id deletes event successfully', async () => {
    // Create an event to delete
    const created = await server.request('/api/v1/events', {
      method: 'POST',
      body: { name: 'Temporary Event to Delete', date: '2026-12-31' },
    });
    const idToDelete = created.body.event.id;

    const delRes = await server.request(`/api/v1/events/${idToDelete}`, {
      method: 'DELETE',
    });

    assert.equal(delRes.status, 200);
    assert.equal(delRes.body.success, true);
    assert.equal(delRes.body.message, 'Event deleted successfully');

    // Confirm it is gone
    const fetchAfter = await server.request(`/api/v1/events/${idToDelete}`);
    assert.equal(fetchAfter.status, 404);
  });

  test('DELETE /api/v1/events/:id returns 404 for non-existent event', async () => {
    const res = await server.request('/api/v1/events/evt-ghost-delete', {
      method: 'DELETE',
    });

    assert.equal(res.status, 404);
    assert.equal(res.body.success, false);
    assert.equal(res.body.code, 'NOT_FOUND');
  });
});
