import mysql from 'mysql2/promise';

import { config } from './config.js';

export function createPool(dbConfig = config.db) {
  return mysql.createPool({
    ...dbConfig,
    connectionLimit: 10,
    // Fechas como texto para no sufrir desplazamientos de zona horaria.
    dateStrings: true,
    timezone: 'Z',
    charset: 'utf8mb4',
  });
}

/** Ejecuta [fn] dentro de una transacción y hace rollback si falla. */
export async function withTransaction(pool, fn) {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const result = await fn(conn);
    await conn.commit();
    return result;
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }
}
