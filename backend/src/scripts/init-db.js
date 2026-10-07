import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

import mysql from 'mysql2/promise';

import { config } from '../config.js';

/** Crea la base de datos (si no existe) y aplica db/schema.sql. Es idempotente. */
export async function initDatabase(dbConfig = config.db) {
  const { database, ...server } = dbConfig;
  if (!/^[A-Za-z0-9_]+$/.test(database)) {
    throw new Error(`Nombre de base de datos inválido: ${database}`);
  }

  const conn = await mysql.createConnection({ ...server, multipleStatements: true });
  try {
    await conn.query(
      `CREATE DATABASE IF NOT EXISTS \`${database}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`,
    );
    await conn.query(`USE \`${database}\``);
    const sql = await readFile(new URL('../../db/schema.sql', import.meta.url), 'utf8');
    await conn.query(sql);
  } finally {
    await conn.end();
  }
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  initDatabase()
    .then(() => console.log(`Base de datos "${config.db.database}" lista.`))
    .catch((err) => {
      console.error('No se pudo inicializar la base de datos:', err.message);
      process.exit(1);
    });
}
