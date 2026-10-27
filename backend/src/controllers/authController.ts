import { Request, Response } from 'express';
import { authService as defaultAuthService, AuthService } from '../services/authService.js';
import { asyncHandler } from '../common/asyncHandler.js';
import { ApiResponse } from '../common/apiResponse.js';

export class AuthController {
  constructor(private authService: AuthService = defaultAuthService) {}

  public login = asyncHandler(async (req: Request, res: Response) => {
    const { username, password } = req.body;
    const result = await this.authService.login(username, password);

    ApiResponse.success(
      res,
      {
        token: result.token,
        user: result.user,
      },
      { message: result.message }
    );
  });

  public getMe = asyncHandler(async (req: Request, res: Response) => {
    const result = await this.authService.getMe();
    res.json(result);
  });

  public getProfile = asyncHandler(async (req: Request, res: Response) => {
    const data = await this.authService.getProfile();
    ApiResponse.success(res, {
      profile: data.profile,
      stats: data.stats,
      upstream: data.upstream,
    });
  });

  public updateProfile = asyncHandler(async (req: Request, res: Response) => {
    const profile = await this.authService.updateProfile(req.body);
    ApiResponse.success(
      res,
      { profile },
      { message: 'Profile updated successfully' }
    );
  });

  public getStatus = asyncHandler(async (req: Request, res: Response) => {
    const status = this.authService.getStatus();
    res.json(status);
  });
}

export const authController = new AuthController();
