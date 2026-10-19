import { v4 as uuidv4 } from 'uuid';
import { query } from '../db/database.js';
import { machinenovaClient } from '../clients/machinenovaClient.js';
import { EntreeEvent, CreateEventInput, UpdateEventInput } from '../types/event.js';

export class EventService {
  private mapDbRowToEvent(row: any): EntreeEvent {
    return {
      id: row.id,
      machinenovaEventId: row.machinenova_event_id || undefined,
      name: row.name,
      venue: row.venue || 'Main Venue',
      venueAddress: row.venue_address || '',
      collection: row.collection || 'GENERAL EVENT',
      description: row.description || '',
      date: row.date,
      startTime: row.start_time || '18:00',
      endTime: row.end_time || '22:00',
      doorsOpenTime: row.doors_open_time || '17:30',
      tables: Number(row.tables ?? 10),
      seatsPerTable: Number(row.seats_per_table ?? 10),
      totalCapacity: Number(row.total_capacity ?? 100),
      passesIssued: Number(row.passes_issued ?? 0),
      checkedIn: Number(row.checked_in ?? 0),
      status: row.status as any,
      imageUrl: row.image_url || undefined,
      isPaid: Boolean(row.is_paid),
      priceBadge: row.price_badge || undefined,
      city: row.city || undefined,
      restrictToJurisdiction: Boolean(row.restrict_to_jurisdiction),
      restrictToRoster: Boolean(row.restrict_to_roster),
      geoNode: row.geo_node || undefined,
      organization: row.organization || undefined,
      syncStatus: row.sync_status || 'synced',
      lastSyncedAt: row.last_synced_at ? new Date(row.last_synced_at).toISOString() : undefined,
    };
  }

  public async listEvents(options?: {
    status?: string;
    search?: string;
    refreshFromMachineNova?: boolean;
  }): Promise<EntreeEvent[]> {
    if (options?.refreshFromMachineNova && machinenovaClient.isConfigured()) {
      try {
        await this.syncEventsFromMachineNova();
      } catch (err: any) {
        console.warn('[EVENT_SERVICE] MachineNova event sync skipped or failed:', err.message);
      }
    }

    let sql = 'SELECT * FROM events WHERE 1=1';
    const params: any[] = [];
    let paramIndex = 1;

    if (options?.status) {
      sql += ` AND status = $${paramIndex++}`;
      params.push(options.status);
    }

    if (options?.search) {
      sql += ` AND (name ILIKE $${paramIndex} OR venue ILIKE $${paramIndex} OR collection ILIKE $${paramIndex})`;
      params.push(`%${options.search}%`);
      paramIndex++;
    }

    sql += ' ORDER BY date ASC, start_time ASC';

    const res = await query(sql, params);
    return res.rows.map((r) => this.mapDbRowToEvent(r));
  }

  public async getEventById(id: string): Promise<EntreeEvent | null> {
    const res = await query(
      'SELECT * FROM events WHERE id = $1 OR machinenova_event_id = $2',
      [id, id]
    );
    if (res.rows.length === 0) return null;
    return this.mapDbRowToEvent(res.rows[0]);
  }

  public async createEvent(input: CreateEventInput): Promise<EntreeEvent> {
    const id = `evt-${uuidv4().substring(0, 8)}`;
    let machinenovaEventId: string | undefined;
    let syncStatus: 'synced' | 'pending_create' | 'local_only' = 'local_only';

    if (machinenovaClient.isConfigured()) {
      try {
        const mnEvent = await machinenovaClient.createEvent({
          eventName: input.name,
          geoNode: input.geoNode,
          eventStartDate: input.date,
          restrictToJurisdiction: input.restrictToJurisdiction,
          restrictToRoster: input.restrictToRoster,
        });
        machinenovaEventId = mnEvent.name;
        syncStatus = 'synced';
      } catch (err: any) {
        console.warn('[EVENT_SERVICE] Failed to create event upstream, queuing for offline sync:', err.message);
        syncStatus = 'pending_create';
        await this.queueSyncAction('CREATE_EVENT', { id, input });
      }
    }

    const tables = input.tables ?? 10;
    const seatsPerTable = input.seatsPerTable ?? 10;
    const totalCapacity = input.totalCapacity ?? tables * seatsPerTable;

    const sql = `
      INSERT INTO events (
        id, machinenova_event_id, name, venue, venue_address, collection, description,
        date, start_time, end_time, doors_open_time, tables, seats_per_table,
        total_capacity, passes_issued, checked_in, status, image_url, is_paid,
        price_badge, city, restrict_to_jurisdiction, restrict_to_roster, geo_node,
        sync_status, last_synced_at
      ) VALUES (
        $1, $2, $3, $4, $5, $6, $7,
        $8, $9, $10, $11, $12, $13,
        $14, $15, $16, $17, $18, $19,
        $20, $21, $22, $23, $24,
        $25, $26
      )
    `;

    await query(sql, [
      id,
      machinenovaEventId || null,
      input.name,
      input.venue || '',
      input.venueAddress || '',
      input.collection || 'GENERAL EVENT',
      input.description || '',
      input.date,
      input.startTime || '18:00',
      input.endTime || '22:00',
      input.doorsOpenTime || '17:30',
      tables,
      seatsPerTable,
      totalCapacity,
      input.passesIssued ?? 0,
      0,
      input.status || 'upcoming',
      input.imageUrl || null,
      input.isPaid === false ? false : true,
      input.priceBadge || (input.isPaid === false ? 'Free' : '$ Paid'),
      input.city || '',
      input.restrictToJurisdiction ? true : false,
      input.restrictToRoster ? true : false,
      input.geoNode || null,
      syncStatus,
      syncStatus === 'synced' ? new Date() : null,
    ]);

    return (await this.getEventById(id))!;
  }

  public async updateEvent(id: string, input: UpdateEventInput): Promise<EntreeEvent | null> {
    const existing = await this.getEventById(id);
    if (!existing) return null;

    let syncStatus = existing.syncStatus;
    if (existing.machinenovaEventId && machinenovaClient.isConfigured()) {
      try {
        await machinenovaClient.updateEvent({
          eventId: existing.machinenovaEventId,
          eventName: input.name,
          isActive: input.status ? input.status !== 'past' : undefined,
          restrictToJurisdiction: input.restrictToJurisdiction,
          restrictToRoster: input.restrictToRoster,
        });
        syncStatus = 'synced';
      } catch (err: any) {
        console.warn('[EVENT_SERVICE] MachineNova update event failed, queuing:', err.message);
        syncStatus = 'pending_update';
        await this.queueSyncAction('UPDATE_EVENT', {
          id,
          machinenovaEventId: existing.machinenovaEventId,
          input,
        });
      }
    }

    const updates: string[] = [];
    const params: any[] = [];
    let pIdx = 1;

    if (input.name !== undefined) { updates.push(`name = $${pIdx++}`); params.push(input.name); }
    if (input.venue !== undefined) { updates.push(`venue = $${pIdx++}`); params.push(input.venue); }
    if (input.venueAddress !== undefined) { updates.push(`venue_address = $${pIdx++}`); params.push(input.venueAddress); }
    if (input.collection !== undefined) { updates.push(`collection = $${pIdx++}`); params.push(input.collection); }
    if (input.description !== undefined) { updates.push(`description = $${pIdx++}`); params.push(input.description); }
    if (input.date !== undefined) { updates.push(`date = $${pIdx++}`); params.push(input.date); }
    if (input.startTime !== undefined) { updates.push(`start_time = $${pIdx++}`); params.push(input.startTime); }
    if (input.endTime !== undefined) { updates.push(`end_time = $${pIdx++}`); params.push(input.endTime); }
    if (input.doorsOpenTime !== undefined) { updates.push(`doors_open_time = $${pIdx++}`); params.push(input.doorsOpenTime); }
    if (input.tables !== undefined) { updates.push(`tables = $${pIdx++}`); params.push(input.tables); }
    if (input.seatsPerTable !== undefined) { updates.push(`seats_per_table = $${pIdx++}`); params.push(input.seatsPerTable); }
    if (input.totalCapacity !== undefined) { updates.push(`total_capacity = $${pIdx++}`); params.push(input.totalCapacity); }
    if (input.passesIssued !== undefined) { updates.push(`passes_issued = $${pIdx++}`); params.push(input.passesIssued); }
    if (input.checkedIn !== undefined) { updates.push(`checked_in = $${pIdx++}`); params.push(input.checkedIn); }
    if (input.status !== undefined) { updates.push(`status = $${pIdx++}`); params.push(input.status); }
    if (input.imageUrl !== undefined) { updates.push(`image_url = $${pIdx++}`); params.push(input.imageUrl); }
    if (input.isPaid !== undefined) { updates.push(`is_paid = $${pIdx++}`); params.push(input.isPaid); }
    if (input.priceBadge !== undefined) { updates.push(`price_badge = $${pIdx++}`); params.push(input.priceBadge); }
    if (input.city !== undefined) { updates.push(`city = $${pIdx++}`); params.push(input.city); }
    if (input.restrictToJurisdiction !== undefined) { updates.push(`restrict_to_jurisdiction = $${pIdx++}`); params.push(input.restrictToJurisdiction); }
    if (input.restrictToRoster !== undefined) { updates.push(`restrict_to_roster = $${pIdx++}`); params.push(input.restrictToRoster); }

    updates.push(`sync_status = $${pIdx++}`); params.push(syncStatus);
    updates.push('updated_at = CURRENT_TIMESTAMP');

    if (updates.length > 0) {
      params.push(id);
      await query(`UPDATE events SET ${updates.join(', ')} WHERE id = $${pIdx}`, params);
    }

    return this.getEventById(id);
  }

  public async deleteEvent(id: string): Promise<boolean> {
    const existing = await this.getEventById(id);
    if (!existing) return false;

    if (existing.machinenovaEventId && machinenovaClient.isConfigured()) {
      try {
        await machinenovaClient.deleteEvent(existing.machinenovaEventId);
      } catch (err: any) {
        console.warn('[EVENT_SERVICE] MachineNova delete event failed, queuing:', err.message);
        await this.queueSyncAction('DELETE_EVENT', {
          id,
          machinenovaEventId: existing.machinenovaEventId,
        });
      }
    }

    const res = await query('DELETE FROM events WHERE id = $1', [id]);
    return (res.rowCount ?? 0) > 0;
  }

  public async syncEventsFromMachineNova(): Promise<number> {
    const { events } = await machinenovaClient.listEvents({ limit: 200 });
    let count = 0;

    const sql = `
      INSERT INTO events (
        id, machinenova_event_id, name, venue, collection, date,
        restrict_to_jurisdiction, restrict_to_roster, status, sync_status, last_synced_at
      ) VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8, $9, 'synced', CURRENT_TIMESTAMP
      )
      ON CONFLICT (machinenova_event_id) DO UPDATE SET
        name = EXCLUDED.name,
        date = EXCLUDED.date,
        restrict_to_jurisdiction = EXCLUDED.restrict_to_jurisdiction,
        restrict_to_roster = EXCLUDED.restrict_to_roster,
        sync_status = 'synced',
        last_synced_at = CURRENT_TIMESTAMP
    `;

    for (const mn of events) {
      const id = `evt-mn-${mn.name.toLowerCase().replace(/[^a-z0-9]/g, '-')}`;
      const venue = mn.geo_node || 'Campaign Operations Center';
      const collection = 'MACHINENOVA INTELLIGENCE';
      const date = mn.event_start_date ? mn.event_start_date.split(' ')[0] : new Date().toISOString().split('T')[0];
      const restrictJur = Boolean(mn.restrict_to_jurisdiction);
      const restrictRos = Boolean(mn.restrict_to_roster);
      const status = mn.is_active ? 'live' : 'upcoming';

      await query(sql, [
        id,
        mn.name,
        mn.event_name,
        venue,
        collection,
        date,
        restrictJur,
        restrictRos,
        status,
      ]);
      count++;
    }

    return count;
  }

  private async queueSyncAction(action: string, payload: any): Promise<void> {
    await query(
      `INSERT INTO sync_queue (id, action, payload, status)
       VALUES ($1, $2, $3, 'pending')`,
      [uuidv4(), action, payload]
    );
  }
}

export const eventService = new EventService();
