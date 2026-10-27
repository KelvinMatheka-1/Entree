import { Response } from 'express';

export interface ApiResponseOptions {
  statusCode?: number;
  message?: string;
  count?: number;
  meta?: Record<string, any>;
  [key: string]: any;
}

export class ApiResponse {
  /**
   * Send a successful JSON response with consistent structure.
   */
  public static success(
    res: Response,
    payload: Record<string, any> = {},
    options: ApiResponseOptions = {}
  ): void {
    const statusCode = options.statusCode || 200;
    const responseBody: Record<string, any> = {
      success: true,
      ...(options.message ? { message: options.message } : {}),
      ...(options.count !== undefined ? { count: options.count } : {}),
      ...(options.meta ? { meta: options.meta } : {}),
      ...payload,
    };

    res.status(statusCode).json(responseBody);
  }

  /**
   * Send a created (201) JSON response.
   */
  public static created(
    res: Response,
    payload: Record<string, any> = {},
    message = 'Resource created successfully'
  ): void {
    this.success(res, payload, { statusCode: 201, message });
  }

  /**
   * Send an error response.
   */
  public static error(
    res: Response,
    message: string,
    statusCode = 500,
    code?: string,
    details?: any
  ): void {
    res.status(statusCode).json({
      success: false,
      message,
      ...(code ? { code } : {}),
      ...(details ? { details } : {}),
    });
  }
}
