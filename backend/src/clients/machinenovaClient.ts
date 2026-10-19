import axios, { AxiosInstance, AxiosRequestConfig } from 'axios';
import { config } from '../config/env.js';
import {
  MachineNovaEvent,
  MachineNovaParticipant,
  MachineNovaScanResult,
  MachineNovaRosterEntry,
  MachineNovaEventStatistics,
  MachineNovaResponse,
} from '../types/machinenova.js';

export class MachineNovaClient {
  private client: AxiosInstance;
  private sessionCookie: string | null = null;
  private isAuthenticated = false;

  constructor() {
    this.client = axios.create({
      baseURL: config.machinenova.baseUrl,
      timeout: config.machinenova.timeoutMs,
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      withCredentials: true,
    });

    // Request interceptor to inject auth cookies or token headers
    this.client.interceptors.request.use((reqConfig) => {
      if (config.machinenova.apiKey && config.machinenova.apiSecret) {
        reqConfig.headers.Authorization = `token ${config.machinenova.apiKey}:${config.machinenova.apiSecret}`;
      } else if (this.sessionCookie) {
        reqConfig.headers.Cookie = this.sessionCookie;
      }
      return reqConfig;
    });

    // Response interceptor to catch Set-Cookie for session persistence
    this.client.interceptors.response.use(
      (response) => {
        const setCookieHeader = response.headers['set-cookie'];
        if (setCookieHeader && Array.isArray(setCookieHeader)) {
          this.sessionCookie = setCookieHeader.map((c) => c.split(';')[0]).join('; ');
        }
        return response;
      },
      (error) => {
        return Promise.reject(error);
      }
    );
  }

  public isConfigured(): boolean {
    return Boolean(
      (config.machinenova.apiKey && config.machinenova.apiSecret) ||
      (config.machinenova.username && config.machinenova.password)
    );
  }

  public async login(): Promise<boolean> {
    if (!config.machinenova.username || !config.machinenova.password) {
      return false;
    }

    try {
      const response = await this.client.post<MachineNovaResponse>(
        '/api/method/login',
        {
          usr: config.machinenova.username,
          pwd: config.machinenova.password,
        }
      );

      if (response.status === 200) {
        this.isAuthenticated = true;
        return true;
      }
      return false;
    } catch (err: any) {
      console.warn('MachineNova authentication attempt failed:', err?.response?.data || err.message);
      this.isAuthenticated = false;
      return false;
    }
  }

  public async getCurrentUser(): Promise<any> {
    const response = await this.client.get<MachineNovaResponse>(
      '/api/method/checkin.api.users.me'
    );
    return response.data.message;
  }

  public async getOrganization(slug: string): Promise<any> {
    const response = await this.client.get<MachineNovaResponse>(
      '/api/method/checkin.api.organizations.get_by_slug',
      { params: { slug } }
    );
    return response.data.message;
  }

  public async getBranding(slug: string): Promise<any> {
    const response = await this.client.get<MachineNovaResponse>(
      '/api/method/checkin.api.organizations.get_branding',
      { params: { slug } }
    );
    return response.data.message;
  }

  // --- EVENTS ---

  public async listEvents(options?: {
    page?: number;
    limit?: number;
    allOrgs?: boolean;
  }): Promise<{ events: MachineNovaEvent[]; page: number; limit: number; count: number }> {
    const response = await this.client.get<MachineNovaResponse<{ events: MachineNovaEvent[]; page: number; limit: number; count: number }>>(
      '/api/method/checkin.api.events.list_events',
      {
        params: {
          page: options?.page ?? 1,
          limit: options?.limit ?? 100,
          ...(options?.allOrgs ? { all_orgs: 1 } : {}),
        },
      }
    );
    return response.data.message ?? { events: [], page: 1, limit: 0, count: 0 };
  }

  public async getEvent(eventId: string): Promise<MachineNovaEvent | null> {
    const response = await this.client.get<MachineNovaResponse<MachineNovaEvent>>(
      '/api/method/checkin.api.events.get_event',
      { params: { event_id: eventId } }
    );
    return response.data.message ?? null;
  }

  public async createEvent(data: {
    eventName: string;
    organization?: string;
    geoNode?: string;
    eventStartDate?: string;
    eventEndDate?: string;
    restrictToJurisdiction?: boolean;
    restrictToRoster?: boolean;
  }): Promise<MachineNovaEvent> {
    const response = await this.client.post<MachineNovaResponse<MachineNovaEvent>>(
      '/api/method/checkin.api.events.create_event',
      {
        event_name: data.eventName,
        organization: data.organization || config.machinenova.orgSlug,
        geo_node: data.geoNode,
        event_start_date: data.eventStartDate,
        event_end_date: data.eventEndDate,
        restrict_to_jurisdiction: data.restrictToJurisdiction ? 1 : 0,
        restrict_to_roster: data.restrictToRoster ? 1 : 0,
      }
    );
    return response.data.message as MachineNovaEvent;
  }

  public async updateEvent(data: {
    eventId: string;
    eventName?: string;
    isActive?: boolean;
    restrictToJurisdiction?: boolean;
    restrictToRoster?: boolean;
  }): Promise<any> {
    const payload: Record<string, any> = { event_id: data.eventId };
    if (data.eventName !== undefined) payload.event_name = data.eventName;
    if (data.isActive !== undefined) payload.is_active = data.isActive ? 1 : 0;
    if (data.restrictToJurisdiction !== undefined) payload.restrict_to_jurisdiction = data.restrictToJurisdiction ? 1 : 0;
    if (data.restrictToRoster !== undefined) payload.restrict_to_roster = data.restrictToRoster ? 1 : 0;

    const response = await this.client.post<MachineNovaResponse>(
      '/api/method/checkin.api.events.update_event',
      payload
    );
    return response.data.message;
  }

  public async deleteEvent(eventId: string): Promise<any> {
    const response = await this.client.post<MachineNovaResponse>(
      '/api/method/checkin.api.events.delete_event',
      { event_id: eventId }
    );
    return response.data.message;
  }

  // --- SCAN & CHECK-IN ---

  public async scanForCheckin(
    eventId: string,
    idNumber: string
  ): Promise<MachineNovaScanResult> {
    const response = await this.client.get<MachineNovaResponse<MachineNovaScanResult>>(
      '/api/method/checkin.api.scan.scan_for_checkin',
      {
        params: {
          event: eventId,
          id_number: idNumber,
        },
      }
    );
    return (
      response.data.message ?? {
        status: 'error',
        message: 'No response from verification endpoint',
      }
    );
  }

  public async checkin(data: {
    event: string;
    idNumber: string;
    fullName: string;
    dob?: string;
    sex?: string;
    phone?: string;
    registeredGeoNode?: string;
    county?: string;
    constituency?: string;
    ward?: string;
    pollingCenter?: string;
    registrationStatus?: string;
  }): Promise<MachineNovaParticipant> {
    const response = await this.client.post<MachineNovaResponse<MachineNovaParticipant>>(
      '/api/method/checkin.api.participants.checkin',
      {
        event: data.event,
        id_number: data.idNumber,
        full_name: data.fullName,
        dob: data.dob,
        sex: data.sex,
        phone: data.phone,
        registered_geo_node: data.registeredGeoNode,
        county: data.county,
        constituency: data.constituency,
        ward: data.ward,
        polling_center: data.pollingCenter,
        registration_status: data.registrationStatus,
      }
    );
    return response.data.message as MachineNovaParticipant;
  }

  public async listParticipants(eventId: string): Promise<MachineNovaParticipant[]> {
    const response = await this.client.get<MachineNovaResponse<MachineNovaParticipant[]>>(
      '/api/method/checkin.api.participants.list_by_event',
      { params: { event: eventId } }
    );
    return response.data.message ?? [];
  }

  // --- ROSTER / GUEST LIST ---

  public async listRoster(
    eventId: string,
    options?: { page?: number; limit?: number; q?: string }
  ): Promise<{ entries: MachineNovaRosterEntry[]; total: number; page: number; limit: number }> {
    const response = await this.client.get<MachineNovaResponse<{ entries: MachineNovaRosterEntry[]; total: number; page: number; limit: number }>>(
      '/api/method/checkin.api.roster.list_roster',
      {
        params: {
          event: eventId,
          page: options?.page ?? 1,
          limit: options?.limit ?? 100,
          q: options?.q,
        },
      }
    );
    return response.data.message ?? { entries: [], total: 0, page: 1, limit: 0 };
  }

  public async uploadRoster(
    eventId: string,
    rows: any[],
    mode: 'append' | 'replace' = 'append'
  ): Promise<any> {
    const response = await this.client.post<MachineNovaResponse>(
      '/api/method/checkin.api.roster.upload_roster',
      {
        event: eventId,
        rows: JSON.stringify(rows),
        mode,
      }
    );
    return response.data.message;
  }

  public async removeRosterEntry(eventId: string, idNumber: string): Promise<any> {
    const response = await this.client.post<MachineNovaResponse>(
      '/api/method/checkin.api.roster.remove_entry',
      {
        event: eventId,
        id_number: idNumber,
      }
    );
    return response.data.message;
  }

  public async clearRoster(eventId: string): Promise<any> {
    const response = await this.client.post<MachineNovaResponse>(
      '/api/method/checkin.api.roster.clear_roster',
      { event: eventId }
    );
    return response.data.message;
  }

  // --- ANALYTICS ---

  public async getEventStatistics(eventId: string): Promise<MachineNovaEventStatistics> {
    const response = await this.client.get<MachineNovaResponse<MachineNovaEventStatistics>>(
      '/api/method/checkin.api.analytics.event_statistics',
      { params: { event: eventId } }
    );
    return response.data.message ?? { total_checkins: 0, unique_participants: 0 };
  }
}

export const machinenovaClient = new MachineNovaClient();
