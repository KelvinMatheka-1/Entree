import { test, describe, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { TestServer } from '../helpers/testServer.js';

describe('Endpoints: Scan & Check-In API (/api/v1/events/:eventId)', () => {
  const server = new TestServer();

  before(async () => {
    await server.start();
  });

  after(async () => {
    await server.stop();
  });

  test('GET /api/v1/events/:eventId/scan returns ready status for valid un-checked-in guest', async () => {
    // HS-0080 (Sofia Rodriguez) is notArrived in initial seeds
    const res = await server.request('/api/v1/events/evt-001/scan?passId=HS-0080');

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.equal(res.body.verification.canCheckIn, true);
    assert.equal(res.body.verification.status, 'ready');
    assert.ok(res.body.verification.guest);
    assert.equal(res.body.verification.guest.fullName, 'Sofia Rodriguez');
  });

  test('GET /api/v1/events/:eventId/scan returns already_checked_in for checked-in guest', async () => {
    // HS-0086 (Maya Bennett) is checkedIn in initial seeds
    const res = await server.request('/api/v1/events/evt-001/scan?passId=HS-0086');

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.equal(res.body.verification.canCheckIn, false);
    assert.equal(res.body.verification.status, 'already_checked_in');
  });

  test('GET /api/v1/events/:eventId/scan returns 400 when passId query param is missing', async () => {
    const res = await server.request('/api/v1/events/evt-001/scan');

    assert.equal(res.status, 400);
    assert.equal(res.body.success, false);
    assert.equal(res.body.code, 'VALIDATION_ERROR');
  });

  test('GET /api/v1/events/:eventId/scan rejects unknown pass when roster restriction is enabled', async () => {
    // evt-001 has restrictToRoster: true
    const res = await server.request('/api/v1/events/evt-001/scan?passId=UNREGISTERED-PASS-XYZ');

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.equal(res.body.verification.canCheckIn, false);
    assert.equal(res.body.verification.status, 'not_on_roster');
  });

  test('POST /api/v1/events/:eventId/checkin successfully checks in guest', async () => {
    const res = await server.request('/api/v1/events/evt-001/checkin', {
      method: 'POST',
      body: { passId: 'HS-0080', operatorId: 'test-gate-1' },
    });

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.equal(res.body.guest.status, 'checkedIn');
    assert.ok(res.body.guest.checkInTime);
  });

  test('POST /api/v1/events/:eventId/checkin handles already checked in idempotency', async () => {
    // Try checking in HS-0080 again
    const res = await server.request('/api/v1/events/evt-001/checkin', {
      method: 'POST',
      body: { passId: 'HS-0080' },
    });

    assert.equal(res.status, 200);
    assert.equal(res.body.success, false);
    assert.ok(res.body.message.includes('Already checked in'));
  });

  test('POST /api/v1/events/:eventId/checkin returns 400 when passId is missing', async () => {
    const res = await server.request('/api/v1/events/evt-001/checkin', {
      method: 'POST',
      body: {},
    });

    assert.equal(res.status, 400);
    assert.equal(res.body.success, false);
    assert.equal(res.body.code, 'VALIDATION_ERROR');
  });

  test('POST /api/v1/events/:eventId/undo-checkin successfully reverts check-in', async () => {
    const res = await server.request('/api/v1/events/evt-001/undo-checkin', {
      method: 'POST',
      body: { passId: 'HS-0080' },
    });

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.equal(res.body.message, 'Check-in reverted successfully');

    // Confirm scan shows ready again
    const scanAfter = await server.request('/api/v1/events/evt-001/scan?passId=HS-0080');
    assert.equal(scanAfter.body.verification.canCheckIn, true);
    assert.equal(scanAfter.body.verification.status, 'ready');
  });

  test('POST /api/v1/events/:eventId/undo-checkin returns message when pass is not checked in', async () => {
    // HS-0080 is now notArrived
    const res = await server.request('/api/v1/events/evt-001/undo-checkin', {
      method: 'POST',
      body: { passId: 'HS-0080' },
    });

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.equal(res.body.message, 'Could not revert check-in');
  });

  test('POST /api/v1/events/:eventId/undo-checkin returns 400 when passId is missing', async () => {
    const res = await server.request('/api/v1/events/evt-001/undo-checkin', {
      method: 'POST',
      body: {},
    });

    assert.equal(res.status, 400);
    assert.equal(res.body.success, false);
    assert.equal(res.body.code, 'VALIDATION_ERROR');
  });
});
