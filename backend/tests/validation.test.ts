import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import { CreateEventSchema, UpdateEventSchema } from '../src/validators/eventValidators.js';
import { AddGuestSchema } from '../src/validators/guestValidators.js';
import { CheckInBodySchema } from '../src/validators/scanValidators.js';

describe('Zod DTO & Validation Schemas', () => {
  test('CreateEventSchema validates valid payload and sets defaults', () => {
    const valid = {
      name: 'Nairobi Tech Summit',
      date: '2026-11-20',
    };

    const parsed = CreateEventSchema.parse(valid);
    assert.equal(parsed.name, 'Nairobi Tech Summit');
    assert.equal(parsed.date, '2026-11-20');
    assert.equal(parsed.venue, 'Main Venue');
    assert.equal(parsed.tables, 10);
    assert.equal(parsed.status, 'upcoming');
  });

  test('CreateEventSchema throws when required fields are missing', () => {
    assert.throws(() => {
      CreateEventSchema.parse({ name: '' });
    });
  });

  test('AddGuestSchema validates valid guest payload', () => {
    const valid = {
      fullName: 'Jane Doe',
      email: 'jane@example.com',
      phone: '+254700000000',
    };

    const parsed = AddGuestSchema.parse(valid);
    assert.equal(parsed.fullName, 'Jane Doe');
    assert.equal(parsed.email, 'jane@example.com');
    assert.equal(parsed.tableNumber, '01');
  });

  test('CheckInBodySchema requires passId', () => {
    assert.throws(() => {
      CheckInBodySchema.parse({});
    });

    const parsed = CheckInBodySchema.parse({ passId: 'PASS-999' });
    assert.equal(parsed.passId, 'PASS-999');
  });
});
