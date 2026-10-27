import jwt from 'jsonwebtoken';
import { config } from '../config/env.js';
import { machinenovaClient, MachineNovaClient } from '../clients/machinenovaClient.js';
import { userRepository, UserRepository, UpdateUserProfileParams, UserProfile, SystemStats } from '../repositories/userRepository.js';
import { syncQueueRepository, SyncQueueRepository } from '../repositories/syncQueueRepository.js';
import { UnauthorizedError, BadGatewayError } from '../errors/index.js';
import { ROLE_PERMISSIONS, UserRole } from '../middleware/auth.js';

export interface LoginResult {
  success: boolean;
  message: string;
  token?: string;
  user?: any;
}

export interface ProfileResponse {
  profile: UserProfile;
  stats: SystemStats;
  upstream: {
    configured: boolean;
    mode: 'machinenova_live' | 'local';
    target: string;
    frontend: string;
    user: any;
  };
}

export class AuthService {
  constructor(
    private userRepo: UserRepository = userRepository,
    private queueRepo: SyncQueueRepository = syncQueueRepository,
    private client: MachineNovaClient = machinenovaClient
  ) {}

  public async login(username?: string, password?: string): Promise<LoginResult> {
    if (username && password) {
      config.machinenova.username = username;
      config.machinenova.password = password;
    }

    const success = await this.client.login();
    if (!success) {
      throw new UnauthorizedError('Invalid credentials or failed to connect to MachineNova upstream');
    }

    let upstreamUser: any = null;
    try {
      upstreamUser = await this.client.getCurrentUser();
    } catch (_) {
      // Upstream user info retrieval is optional
    }

    const role: UserRole = 'admin';
    const permissions = ROLE_PERMISSIONS[role];
    const token = jwt.sign(
      {
        userId: upstreamUser?.name || 'admin-user',
        username: username || 'admin',
        role,
        permissions,
      },
      config.security.jwtSecret,
      { expiresIn: config.security.jwtExpiresIn } as jwt.SignOptions
    );

    return {
      success: true,
      message: 'Authenticated successfully with MachineNova',
      token,
      user: upstreamUser,
    };
  }

  public async getMe(): Promise<{ authenticated: boolean; mode: string; message?: string; user?: any; error?: string }> {
    if (!this.client.isConfigured()) {
      return {
        authenticated: false,
        mode: 'local',
        message: 'Running in local / offline mode without upstream MachineNova credentials.',
      };
    }

    try {
      const user = await this.client.getCurrentUser();
      return {
        authenticated: true,
        mode: 'machinenova_live',
        user,
      };
    } catch (err: any) {
      throw new BadGatewayError(`MachineNova upstream user verification failed: ${err.message}`);
    }
  }

  public async getProfile(): Promise<ProfileResponse> {
    const rawUser = await this.userRepo.getOrCreateDefaultProfile();
    const pendingSyncs = await this.queueRepo.getPendingCount().catch(() => 0);
    const stats = await this.userRepo.getSystemStats(pendingSyncs);

    let upstreamUser = null;
    if (this.client.isConfigured()) {
      try {
        upstreamUser = await this.client.getCurrentUser();
      } catch (_) {
        // upstream call safe fallback
      }
    }

    return {
      profile: rawUser,
      stats,
      upstream: {
        configured: this.client.isConfigured(),
        mode: this.client.isConfigured() ? 'machinenova_live' : 'local',
        target: config.machinenova.baseUrl,
        frontend: config.machinenova.frontendUrl,
        user: upstreamUser,
      },
    };
  }

  public async updateProfile(params: UpdateUserProfileParams): Promise<UserProfile> {
    return this.userRepo.updateProfile(params);
  }

  public getStatus() {
    return {
      service: 'Entree Backend API',
      version: '1.0.0',
      uptime: process.uptime(),
      upstream: {
        target: config.machinenova.baseUrl,
        frontend: config.machinenova.frontendUrl,
        configured: this.client.isConfigured(),
      },
    };
  }
}

export const authService = new AuthService();
