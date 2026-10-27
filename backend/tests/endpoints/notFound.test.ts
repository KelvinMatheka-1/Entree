import { test, describe, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { TestServer } from '../helpers/testServer.js';

describe('Endpoints: 404 Route Fallback & Central Error Handling', () => {
  const server = new TestServer();

  before(async () => {
    await server.start();
  });

  after(async () => {
    await server.stop();
  });

  test('GET /unknown-route returns 404 with structured error', async () => {
    const res = await server.request('/unknown-route');

    assert.equal(res.status, 404);
    assert.equal(res.body.success, false);
    assert.equal(res.body.code, 'NOT_FOUND');
    assert.ok(res.body.message.includes('Cannot GET /unknown-route'));
  });

  test('POST /api/v1/invalid/endpoint returns 404 with structured error', async () => {
    const res = await server.request('/api/v1/invalid/endpoint', {
      method: 'POST',
      body: { data: 'test' },
    });

    assert.equal(res.status, 404);
    assert.equal(res.body.success, false);
    assert.equal(res.body.code, 'NOT_FOUND');
  });
});
