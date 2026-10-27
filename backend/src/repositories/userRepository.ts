import { BaseRepository } from './baseRepository.js';

export interface UserProfile {
  id: string;
  fullName: string;
  email: string;
  role: string;
  organization: string;
  phone: string;
  avatarUrl?: string;
  scannerSpeed: string;
  hapticFeedback: boolean;
  createdAt?: string;
  updatedAt?: string;
}

export interface UpdateUserProfileParams {
  fullName?: string;
  email?: string;
  role?: string;
  organization?: string;
  phone?: string;
  avatarUrl?: string;
  scannerSpeed?: string;
  hapticFeedback?: boolean;
}

export interface SystemStats {
  totalEvents: number;
  totalCapacity: number;
  totalCheckedIn: number;
  totalPasses: number;
  checkInRate: string;
  pendingSyncs: number;
}

export class UserRepository extends BaseRepository<UserProfile> {
  protected mapRow(row: any): UserProfile {
    return {
      id: row.id,
      fullName: row.full_name,
      email: row.email,
      role: row.role,
      organization: row.organization,
      phone: row.phone,
      avatarUrl: row.avatar_url || undefined,
      scannerSpeed: row.scanner_speed,
      hapticFeedback: Boolean(row.haptic_feedback),
      createdAt: row.created_at ? new Date(row.created_at).toISOString() : undefined,
      updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : undefined,
    };
  }

  public async getOrCreateDefaultProfile(): Promise<UserProfile> {
    let profileResult = await this.query('SELECT * FROM user_profile LIMIT 1');
    if (profileResult.rows.length === 0) {
      await this.query(`
        INSERT INTO user_profile (id, full_name, email, role, organization, phone, scanner_speed, haptic_feedback)
        VALUES ('default-user', 'Kelvin Matheka', 'kelvin@entree.app', 'Event Owner', 'Entree', '+254 700 000 000', 'High sensitivity', TRUE)
        ON CONFLICT (id) DO NOTHING
      `);
      profileResult = await this.query('SELECT * FROM user_profile LIMIT 1');
    }
    return this.mapRow(profileResult.rows[0]);
  }

  public async updateProfile(params: UpdateUserProfileParams): Promise<UserProfile> {
    const existing = await this.getOrCreateDefaultProfile();
    const userId = existing.id;

    await this.query(
      `
      INSERT INTO user_profile (id, full_name, email, role, organization, phone, scanner_speed, haptic_feedback, updated_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, CURRENT_TIMESTAMP)
      ON CONFLICT (id) DO UPDATE SET
        full_name = COALESCE($2, user_profile.full_name),
        email = COALESCE($3, user_profile.email),
        role = COALESCE($4, user_profile.role),
        organization = COALESCE($5, user_profile.organization),
        phone = COALESCE($6, user_profile.phone),
        scanner_speed = COALESCE($7, user_profile.scanner_speed),
        haptic_feedback = COALESCE($8, user_profile.haptic_feedback),
        updated_at = CURRENT_TIMESTAMP
      `,
      [
        userId,
        params.fullName ?? existing.fullName,
        params.email ?? existing.email,
        params.role ?? existing.role,
        params.organization ?? existing.organization,
        params.phone ?? existing.phone,
        params.scannerSpeed ?? existing.scannerSpeed,
        params.hapticFeedback !== undefined ? params.hapticFeedback : existing.hapticFeedback,
      ]
    );

    const updated = await this.query('SELECT * FROM user_profile WHERE id = $1', [userId]);
    return this.mapRow(updated.rows[0]);
  }

  public async getSystemStats(pendingSyncs = 0): Promise<SystemStats> {
    const statsResult = await this.query(`
      SELECT 
        COUNT(*) as total_events,
        COALESCE(SUM(total_capacity), 0) as total_capacity,
        COALESCE(SUM(checked_in), 0) as total_checked_in,
        COALESCE(SUM(passes_issued), 0) as total_passes
      FROM events
    `);

    const sRow = statsResult.rows[0] || {};
    const totalEvents = parseInt(sRow.total_events || '0', 10);
    const totalCapacity = parseInt(sRow.total_capacity || '0', 10);
    const totalCheckedIn = parseInt(sRow.total_checked_in || '0', 10);
    const totalPasses = parseInt(sRow.total_passes || '0', 10);
    const checkInRate = totalPasses > 0 
      ? ((totalCheckedIn / totalPasses) * 100).toFixed(1) + '%'
      : totalCapacity > 0
        ? ((totalCheckedIn / totalCapacity) * 100).toFixed(1) + '%'
        : '0.0%';

    return {
      totalEvents,
      totalCapacity,
      totalCheckedIn,
      totalPasses,
      checkInRate,
      pendingSyncs,
    };
  }
}

export const userRepository = new UserRepository();
