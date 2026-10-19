export type GuestCheckInStatus = 'checkedIn' | 'notArrived';

export interface EntreeGuest {
  id: string;
  eventId: string;
  passId: string; // The QR code content / Ticket code / National ID
  fullName: string;
  email: string;
  phone?: string;
  tableNumber: string;
  tableName: string;
  status: GuestCheckInStatus;
  checkInTime?: string;
  admission: string;
  guestCount: number;
  
  // MachineNova Voter / Participant attributes
  dob?: string;
  sex?: string;
  county?: string;
  constituency?: string;
  ward?: string;
  pollingCenter?: string;
  isOutsideJurisdiction?: boolean;
  registrationStatus?: string;
  syncStatus?: 'synced' | 'pending_checkin' | 'pending_add' | 'local_only';
  lastSyncedAt?: string;
}

export interface CheckInRequest {
  eventId: string;
  passId: string; // ID number or QR payload
  operatorId?: string;
  fullName?: string;
  phone?: string;
  tableNumber?: string;
  tableName?: string;
  county?: string;
  constituency?: string;
  ward?: string;
  pollingCenter?: string;
}

export interface ScanVerificationResult {
  canCheckIn: boolean;
  status: 'ready' | 'already_checked_in' | 'not_on_roster' | 'outside_jurisdiction' | 'invalid_pass';
  message: string;
  guest?: EntreeGuest;
  outsideJurisdiction?: boolean;
  serverCheckinTime?: string;
}
