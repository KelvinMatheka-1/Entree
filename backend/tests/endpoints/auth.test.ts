import { test, describe, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { TestServer } from '../helpers/testServer.js';

describe('Endpoints: Auth & Profile API (/api/v1/auth)', () => {
  const server = new TestServer();

  before(async () => {
    await server.start();
  });

  after(async () => {
    await server.stop();
  });

  test('POST /api/v1/auth/login returns 400 when username/password are empty', async () => {
    const res = await server.request('/api/v1/auth/login', {
      method: 'POST',
      body: {},
    });

    assert.equal(res.status, 400);
    assert.equal(res.body.success, false);
    assert.equal(res.body.code, 'VALIDATION_ERROR');
  });

  test('POST /api/v1/auth/login returns 401 when upstream credentials are invalid or unreachable', async () => {
    const res = await server.request('/api/v1/auth/login', {
      method: 'POST',
      body: { username: 'invalid_user', password: 'wrong_password' },
    });

    assert.equal(res.status, 401);
    assert.equal(res.body.success, false);
    assert.equal(res.body.code, 'UNAUTHORIZED');
  });

  test('GET /api/v1/auth/me returns local mode status when offline', async () => {
    const res = await server.request('/api/v1/auth/me');

    assert.equal(res.status, 200);
    assert.ok('authenticated' in res.body);
    assert.ok('mode' in res.body);
  });

  test('GET /api/v1/auth/profile returns user profile, stats, and upstream config', async () => {
    const res = await server.request('/api/v1/auth/profile');

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.ok(res.body.profile);
    assert.equal(res.body.profile.id, 'default-user');
    assert.ok(res.body.stats);
    assert.ok(typeof res.body.stats.totalEvents === 'number');
    assert.ok(typeof res.body.stats.checkInRate === 'string');
    assert.ok(res.body.upstream);
  });

  test('PUT /api/v1/auth/profile updates profile settings', async () => {
    const update = {
      fullName: 'Kelvin Matheka (Lead Director)',
      organization: 'Entree International',
      phone: '+254700112233',
      scannerSpeed: 'Ultra sensitivity',
      hapticFeedback: false,
    };

    const res = await server.request('/api/v1/auth/profile', {
      method: 'PUT',
      body: update,
    });

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.equal(res.body.profile.fullName, 'Kelvin Matheka (Lead Director)');
    assert.equal(res.body.profile.organization, 'Entree International');
    assert.equal(res.body.profile.phone, '+254700112233');
    assert.equal(res.body.profile.scannerSpeed, 'Ultra sensitivity');
    assert.equal(res.body.profile.hapticFeedback, false);
  });

  test('PUT /api/v1/auth/profile validates email format', async () => {
    const res = await server.request('/api/v1/auth/profile', {
      method: 'PUT',
      body: { email: 'not-an-email-address' },
    });

    assert.equal(res.status, 400);
    assert.equal(res.body.success, false);
    assert.equal(res.body.code, 'VALIDATION_ERROR');
  });
});
