import { Request, Response } from 'express';
import { machinenovaClient } from '../clients/machinenovaClient.js';
import { config } from '../config/env.js';
import { query } from '../db/database.js';

export class AuthController {
  public async login(req: Request, res: Response): Promise<void> {
    const { username, password } = req.body;
    if (username && password) {
      config.machinenova.username = username;
      config.machinenova.password = password;
    }

    const success = await machinenovaClient.login();
    if (!success) {
      res.status(401).json({
        success: false,
        message: 'Invalid credentials or failed to connect to MachineNova upstream',
      });
      return;
    }

    try {
      const me = await machinenovaClient.getCurrentUser();
      res.json({
        success: true,
        message: 'Authenticated with MachineNova',
        user: me,
      });
    } catch {
      res.json({
        success: true,
        message: 'Authenticated with MachineNova',
      });
    }
  }

  public async getMe(req: Request, res: Response): Promise<void> {
    if (!machinenovaClient.isConfigured()) {
      res.json({
        authenticated: false,
        mode: 'local',
        message: 'Running in local / offline mode without upstream MachineNova credentials.',
      });
      return;
    }

    try {
      const user = await machinenovaClient.getCurrentUser();
      res.json({
        authenticated: true,
        mode: 'machinenova_live',
        user,
      });
    } catch (err: any) {
      res.status(502).json({
        authenticated: false,
        mode: 'machinenova_error',
        error: err.message,
      });
    }
  }

  public async getProfile(req: Request, res: Response): Promise<void> {
    try {
      let profileResult = await query('SELECT * FROM user_profile LIMIT 1');
      if (profileResult.rows.length === 0) {
        await query(`
          INSERT INTO user_profile (id, full_name, email, role, organization, phone, scanner_speed, haptic_feedback)
          VALUES ('default-user', 'Kelvin Matheka', 'kelvin@entree.app', 'Event Owner', 'Entrée', '+254 700 000 000', 'High sensitivity', TRUE)
          ON CONFLICT (id) DO NOTHING
        `);
        profileResult = await query('SELECT * FROM user_profile LIMIT 1');
      }
      const rawUser = profileResult.rows[0];

      const statsResult = await query(`
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

      let pendingSyncs = 0;
      try {
        const queueResult = await query("SELECT COUNT(*) as count FROM sync_queue WHERE status = 'pending'");
        pendingSyncs = parseInt(queueResult.rows[0]?.count || '0', 10);
      } catch (_) {}

      let upstreamUser = null;
      if (machinenovaClient.isConfigured()) {
        try {
          upstreamUser = await machinenovaClient.getCurrentUser();
        } catch (_) {}
      }

      res.json({
        success: true,
        profile: {
          id: rawUser.id,
          fullName: rawUser.full_name,
          email: rawUser.email,
          role: rawUser.role,
          organization: rawUser.organization,
          phone: rawUser.phone,
          avatarUrl: rawUser.avatar_url,
          scannerSpeed: rawUser.scanner_speed,
          hapticFeedback: Boolean(rawUser.haptic_feedback),
          updatedAt: rawUser.updated_at,
        },
        stats: {
          totalEvents,
          totalCapacity,
          totalCheckedIn,
          totalPasses,
          checkInRate,
          pendingSyncs,
        },
        upstream: {
          configured: machinenovaClient.isConfigured(),
          mode: machinenovaClient.isConfigured() ? 'machinenova_live' : 'local',
          target: config.machinenova.baseUrl,
          frontend: config.machinenova.frontendUrl,
          user: upstreamUser,
        },
      });
    } catch (err: any) {
      console.error('[AUTH] Failed to get profile:', err.message);
      res.status(500).json({ success: false, error: err.message });
    }
  }

  public async updateProfile(req: Request, res: Response): Promise<void> {
    try {
      const {
        fullName,
        email,
        role,
        organization,
        phone,
        scannerSpeed,
        hapticFeedback,
      } = req.body;

      const profileResult = await query('SELECT id FROM user_profile LIMIT 1');
      const userId = profileResult.rows[0]?.id || 'default-user';

      await query(
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
          fullName ?? 'Kelvin Matheka',
          email ?? 'kelvin@entree.app',
          role ?? 'Event Director',
          organization ?? 'Entrée',
          phone ?? '+254 700 000 000',
          scannerSpeed ?? 'High sensitivity',
          hapticFeedback !== undefined ? Boolean(hapticFeedback) : true,
        ]
      );

      const updated = await query('SELECT * FROM user_profile WHERE id = $1', [userId]);
      const row = updated.rows[0];

      res.json({
        success: true,
        message: 'Profile updated successfully',
        profile: {
          id: row.id,
          fullName: row.full_name,
          email: row.email,
          role: row.role,
          organization: row.organization,
          phone: row.phone,
          avatarUrl: row.avatar_url,
          scannerSpeed: row.scanner_speed,
          hapticFeedback: Boolean(row.haptic_feedback),
          updatedAt: row.updated_at,
        },
      });
    } catch (err: any) {
      console.error('[AUTH] Failed to update profile:', err.message);
      res.status(500).json({ success: false, error: err.message });
    }
  }

  public async getStatus(req: Request, res: Response): Promise<void> {
    res.json({
      service: 'Entrée Backend API',
      version: '1.0.0',
      uptime: process.uptime(),
      upstream: {
        target: config.machinenova.baseUrl,
        frontend: config.machinenova.frontendUrl,
        configured: machinenovaClient.isConfigured(),
      },
    });
  }
}

export const authController = new AuthController();

