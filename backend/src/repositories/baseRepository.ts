import pg from 'pg';
import { query, getClient } from '../db/database.js';

export abstract class BaseRepository<T> {
  protected async query<R extends pg.QueryResultRow = any>(
    sql: string,
    params: any[] = []
  ): Promise<pg.QueryResult<R>> {
    return query<R>(sql, params);
  }

  protected async getClient(): Promise<any> {
    return getClient();
  }

  protected abstract mapRow(row: any): T;

  protected mapRows(rows: any[]): T[] {
    return rows.map((r) => this.mapRow(r));
  }
}
