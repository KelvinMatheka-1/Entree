import { test, describe, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { TestServer } from '../helpers/testServer.js';

describe('Endpoint: Health & System Diagnostics', () => {
  const server = new TestServer();

  before(async () => {
    await server.start();
  });

  after(async () => {
    await server.stop();
  });

  test('GET /health returns 200 healthy status with security headers', async () => {
    const res = await server.request('/health');

    assert.equal(res.status, 200);
    assert.equal(res.body.status, 'healthy');
    assert.equal(res.body.service, 'Entree MachineNova Event Backend');
    assert.ok(res.body.time);

    // Verify Helmet security headers
    assert.equal(res.headers.get('x-content-type-options'), 'nosniff');
    assert.equal(res.headers.get('x-frame-options'), 'SAMEORIGIN');
    assert.ok(res.headers.get('content-security-policy'));
  });

  test('GET /api/v1/auth/status returns 200 service metadata', async () => {
    const res = await server.request('/api/v1/auth/status');

    assert.equal(res.status, 200);
    assert.equal(res.body.service, 'Entree Backend API');
    assert.equal(res.body.version, '1.0.0');
    assert.ok(typeof res.body.uptime === 'number');
    assert.ok(res.body.upstream);
  });
});
