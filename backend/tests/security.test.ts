import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import { generateToken, getRolePermissions } from '../src/middleware/auth.js';
import jwt from 'jsonwebtoken';
import { config } from '../src/config/env.js';

describe('Security & RBAC Authentication', () => {
  test('getRolePermissions returns correct permissions for admin', () => {
    const adminPerms = getRolePermissions('admin');
    assert.ok(adminPerms.includes('events:read'));
    assert.ok(adminPerms.includes('events:write'));
    assert.ok(adminPerms.includes('events:delete'));
    assert.ok(adminPerms.includes('scan:checkin'));
    assert.ok(adminPerms.includes('sync:trigger'));
  });

  test('getRolePermissions returns restricted permissions for scanner', () => {
    const scannerPerms = getRolePermissions('scanner');
    assert.ok(scannerPerms.includes('scan:verify'));
    assert.ok(scannerPerms.includes('scan:checkin'));
    assert.ok(!scannerPerms.includes('events:write'));
    assert.ok(!scannerPerms.includes('events:delete'));
  });

  test('generateToken encodes valid JWT with assigned permissions', () => {
    const token = generateToken({
      id: 'test-scanner-1',
      username: 'scanner1',
      role: 'scanner',
    });

    assert.ok(token);
    const decoded: any = jwt.verify(token, config.security.jwtSecret);
    assert.equal(decoded.id, 'test-scanner-1');
    assert.equal(decoded.username, 'scanner1');
    assert.equal(decoded.role, 'scanner');
    assert.ok(Array.isArray(decoded.permissions));
    assert.ok(decoded.permissions.includes('scan:checkin'));
  });
});
