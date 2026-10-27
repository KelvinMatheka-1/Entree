import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import {
  AppError,
  BadRequestError,
  UnauthorizedError,
  ForbiddenError,
  NotFoundError,
  ConflictError,
  ValidationError,
  BadGatewayError,
} from '../src/errors/index.js';

describe('Custom Error Hierarchy', () => {
  test('AppError sets operational defaults', () => {
    const err = new AppError('General operational error', 500, 'SERVER_ERROR');
    assert.equal(err.message, 'General operational error');
    assert.equal(err.statusCode, 500);
    assert.equal(err.code, 'SERVER_ERROR');
    assert.equal(err.isOperational, true);
  });

  test('BadRequestError defaults to 400', () => {
    const err = new BadRequestError('Invalid parameter');
    assert.equal(err.statusCode, 400);
    assert.equal(err.code, 'BAD_REQUEST');
  });

  test('UnauthorizedError defaults to 401', () => {
    const err = new UnauthorizedError();
    assert.equal(err.statusCode, 401);
    assert.equal(err.code, 'UNAUTHORIZED');
  });

  test('ForbiddenError defaults to 403', () => {
    const err = new ForbiddenError();
    assert.equal(err.statusCode, 403);
    assert.equal(err.code, 'FORBIDDEN');
  });

  test('NotFoundError defaults to 404', () => {
    const err = new NotFoundError('Event not found');
    assert.equal(err.statusCode, 404);
    assert.equal(err.code, 'NOT_FOUND');
  });

  test('ConflictError defaults to 409', () => {
    const err = new ConflictError('Resource already exists');
    assert.equal(err.statusCode, 409);
    assert.equal(err.code, 'CONFLICT');
  });

  test('ValidationError holds structured details', () => {
    const details = [{ field: 'name', message: 'Name is required' }];
    const err = new ValidationError('Validation failed', details);
    assert.equal(err.statusCode, 400);
    assert.equal(err.code, 'VALIDATION_ERROR');
    assert.deepEqual(err.details, details);
  });

  test('BadGatewayError defaults to 502', () => {
    const err = new BadGatewayError('Upstream MachineNova failed');
    assert.equal(err.statusCode, 502);
    assert.equal(err.code, 'BAD_GATEWAY');
  });
});
