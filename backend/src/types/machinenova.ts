export interface MachineNovaResponse<T = any> {
  message?: T;
  data?: T;
  exception?: string;
  exc_type?: string;
  _server_messages?: string;
}

export interface MachineNovaEvent {
  name: string; // Frappe document ID, e.g. "EVT-2026-0001"
  event_name: string;
  organization?: string;
  geo_node?: string;
  event_start_date?: string;
  event_end_date?: string;
  restrict_to_jurisdiction?: number; // 0 or 1
  restrict_to_roster?: number; // 0 or 1
  is_active?: number;
  created_by?: string;
  creation?: string;
  modified?: string;
  total_checkins?: number;
  unique_participants?: number;
}

export interface MachineNovaParticipant {
  name?: string;
  event: string;
  id_number: string;
  full_name: string;
  dob?: string;
  sex?: string;
  phone?: string;
  registered_geo_node?: string;
  county?: string;
  constituency?: string;
  ward?: string;
  polling_center?: string;
  registration_status?: string;
  checkin_time?: string;
  checked_in_by?: string;
}

export type MachineNovaScanStatus =
  | 'ready'
  | 'already_checked_in'
  | 'not_on_roster'
  | 'outside_jurisdiction'
  | 'forbidden'
  | 'error';

export interface MachineNovaScanResult {
  status: MachineNovaScanStatus;
  message?: string;
  outside_jurisdiction?: boolean;
  participant?: {
    id_number: string;
    full_name: string;
    dob?: string;
    sex?: string;
    phone?: string;
    county?: string;
    constituency?: string;
    ward?: string;
    polling_center?: string;
    registration_status?: string;
    checkin_time?: string;
    checked_in_by?: string;
  };
}

export interface MachineNovaRosterEntry {
  name?: string;
  event: string;
  id_number: string;
  full_name: string;
  phone?: string;
  email?: string;
  table_number?: string;
  table_name?: string;
  notes?: string;
}

export interface MachineNovaEventStatistics {
  total_checkins: number;
  unique_participants: number;
  in_region_count?: number;
  out_of_region_count?: number;
  in_region_rate?: number;
  peak_hour?: string;
  gender_mix?: {
    male: number;
    female: number;
    unknown?: number;
  };
  hourly_breakdown?: Array<{ hour: string; count: number }>;
}
