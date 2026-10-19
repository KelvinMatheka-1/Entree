import { Request, Response } from 'express';
import { machinenovaClient } from '../clients/machinenovaClient.js';
import { config } from '../config/env.js';

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
