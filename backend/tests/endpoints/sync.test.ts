import { test, describe, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { TestServer } from '../helpers/testServer.js';

describe('Endpoints: Offline Sync API (/api/v1/sync)', () => {
  const server = new TestServer();

  before(async () => {
    await server.start();
  });

  after(async () => {
    await server.stop();
  });

  test('GET /api/v1/sync/status returns offline queue counts and status', async () => {
    const res = await server.request('/api/v1/sync/status');

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.ok('upstreamConfigured' in res.body);
    assert.ok(res.body.queue);
    assert.ok(typeof res.body.queue.pending === 'number');
    assert.ok(typeof res.body.queue.processing === 'number');
    assert.ok(typeof res.body.queue.failed === 'number');
    assert.ok(typeof res.body.queue.completed === 'number');
    assert.ok(Array.isArray(res.body.queue.recentJobs));
  });

  test('POST /api/v1/sync/trigger triggers manual sync process', async () => {
    const res = await server.request('/api/v1/sync/trigger', {
      method: 'POST',
    });

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.equal(res.body.message, 'Sync process completed');
    assert.ok(res.body.result);
    assert.ok(typeof res.body.result.processed === 'number');
    assert.ok(typeof res.body.result.succeeded === 'number');
    assert.ok(typeof res.body.result.failed === 'number');
  });
});
