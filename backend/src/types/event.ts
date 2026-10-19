export type EventStatus = 'live' | 'upcoming' | 'draft' | 'past';

export interface EntreeEvent {
  id: string;
  machinenovaEventId?: string;
  name: string;
  venue: string;
  venueAddress: string;
  collection: string;
  description: string;
  date: string; // ISO String: YYYY-MM-DD
  startTime: string; // e.g. "18:00"
  endTime: string; // e.g. "22:00"
  doorsOpenTime: string; // e.g. "17:30"
  tables: number;
  seatsPerTable: number;
  totalCapacity: number;
  passesIssued: number;
  checkedIn: number;
  status: EventStatus;
  imageUrl?: string;
  isPaid: boolean;
  priceBadge?: string;
  attendeeAvatars?: string[];
  city?: string;
  
  // MachineNova specific options
  restrictToJurisdiction?: boolean;
  restrictToRoster?: boolean;
  geoNode?: string;
  organization?: string;
  syncStatus?: 'synced' | 'pending_create' | 'pending_update' | 'pending_delete' | 'local_only';
  lastSyncedAt?: string;
}

export interface CreateEventInput {
  name: string;
  venue?: string;
  venueAddress?: string;
  collection?: string;
  description?: string;
  date: string;
  startTime?: string;
  endTime?: string;
  doorsOpenTime?: string;
  tables?: number;
  seatsPerTable?: number;
  totalCapacity?: number;
  passesIssued?: number;
  status?: EventStatus;
  imageUrl?: string;
  isPaid?: boolean;
  priceBadge?: string;
  city?: string;
  restrictToJurisdiction?: boolean;
  restrictToRoster?: boolean;
  geoNode?: string;
}

export interface UpdateEventInput extends Partial<CreateEventInput> {
  checkedIn?: number;
}
