import { createApp } from '../../src/app.js';
import { initDatabase } from '../../src/db/database.js';
import { seedInitialData } from '../../src/db/seed.js';
import { Server } from 'http';
import { AddressInfo } from 'net';

export interface TestResponse<T = any> {
  status: number;
  headers: Headers;
  body: T;
}

export class TestServer {
  private server: Server | null = null;
  public baseUrl = '';

  public async start(): Promise<string> {
    process.env.NODE_ENV = 'test';
    await initDatabase();
    await seedInitialData();

    const app = createApp();

    return new Promise((resolve) => {
      this.server = app.listen(0, '127.0.0.1', () => {
        const addr = this.server!.address() as AddressInfo;
        this.baseUrl = `http://127.0.0.1:${addr.port}`;
        resolve(this.baseUrl);
      });
    });
  }

  public async stop(): Promise<void> {
    if (this.server) {
      await new Promise<void>((resolve) => {
        this.server!.close(() => resolve());
      });
      this.server = null;
    }
  }

  public async request<T = any>(
    path: string,
    options?: {
      method?: string;
      headers?: Record<string, string>;
      body?: any;
    }
  ): Promise<TestResponse<T>> {
    const url = `${this.baseUrl}${path}`;
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      ...(options?.headers || {}),
    };

    const res = await fetch(url, {
      method: options?.method || 'GET',
      headers,
      body: options?.body ? JSON.stringify(options.body) : undefined,
    });

    const text = await res.text();
    let body: any;
    try {
      body = JSON.parse(text);
    } catch {
      body = text;
    }

    return {
      status: res.status,
      headers: res.headers,
      body,
    };
  }
}
