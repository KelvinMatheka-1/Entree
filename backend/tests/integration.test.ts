import { test, describe, before } from 'node:test';
import assert from 'node:assert/strict';
import { initDatabase } from '../src/db/database.js';
import { seedInitialData } from '../src/db/seed.js';
import { container } from '../src/container.js';

describe('Database, Repositories & Service Layer Integration', () => {
  before(async () => {
    await initDatabase();
    await seedInitialData();
  });

  test('eventRepository lists seeded events', async () => {
    const events = await container.eventRepository.findAll();
    assert.ok(events.length >= 5);
    const event = events.find((e) => e.id === 'evt-001');
    assert.ok(event);
    assert.equal(event.name, 'Urban Chameleon: Contemporary Street Art Expo');
  });

  test('guestRepository finds guests by eventId', async () => {
    const guests = await container.guestRepository.findByEventId('evt-001');
    assert.ok(guests.length > 0);
  });

  test('eventService creates a new event', async () => {
    const newEvent = await container.eventService.createEvent({
      name: 'Hackathon 2026',
      date: '2026-11-15',
      venue: 'Innovation Hub',
      tables: 5,
      seatsPerTable: 8,
    });

    assert.ok(newEvent.id);
    assert.equal(newEvent.name, 'Hackathon 2026');
    assert.equal(newEvent.totalCapacity, 40);

    const fetched = await container.eventService.getEventById(newEvent.id);
    assert.ok(fetched);
    assert.equal(fetched.name, 'Hackathon 2026');
  });

  test('guestService adds and counts guests', async () => {
    const guest = await container.guestService.addGuest('evt-001', {
      fullName: 'Alice Walker',
      passId: 'PASS-ALICE-1',
      email: 'alice@test.com',
    });

    assert.equal(guest.fullName, 'Alice Walker');
    assert.equal(guest.passId, 'PASS-ALICE-1');

    const stats = await container.guestService.getEventGuestStats('evt-001');
    assert.ok(stats.total > 0);
  });

  test('scanService verifies and executes check-in flow', async () => {
    const verifyBefore = await container.scanService.verifyScan('evt-001', 'PASS-ALICE-1');
    assert.equal(verifyBefore.canCheckIn, true);
    assert.equal(verifyBefore.status, 'ready');

    const checkInRes = await container.scanService.checkIn({
      eventId: 'evt-001',
      passId: 'PASS-ALICE-1',
      fullName: 'Alice Walker',
    });
    assert.equal(checkInRes.success, true);
    assert.equal(checkInRes.guest.status, 'checkedIn');

    const verifyAfter = await container.scanService.verifyScan('evt-001', 'PASS-ALICE-1');
    assert.equal(verifyAfter.canCheckIn, false);
    assert.equal(verifyAfter.status, 'already_checked_in');

    const undoRes = await container.scanService.undoCheckIn('evt-001', 'PASS-ALICE-1');
    assert.equal(undoRes, true);

    const verifyReverted = await container.scanService.verifyScan('evt-001', 'PASS-ALICE-1');
    assert.equal(verifyReverted.canCheckIn, true);
  });

  test('userRepository manages profile and system stats', async () => {
    const profile = await container.userRepository.getOrCreateDefaultProfile();
    assert.ok(profile.id);

    const updated = await container.userRepository.updateProfile({
      fullName: 'Chief Organizer',
      organization: 'Entree HQ',
    });
    assert.equal(updated.fullName, 'Chief Organizer');
    assert.equal(updated.organization, 'Entree HQ');

    const stats = await container.userRepository.getSystemStats(0);
    assert.ok(stats.totalEvents > 0);
  });
});
