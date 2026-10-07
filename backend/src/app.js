import cors from 'cors';
import express from 'express';
import helmet from 'helmet';

import { authRouter } from './auth.js';
import { config } from './config.js';
import { errorHandler } from './errors.js';
import { syncRouter } from './sync.js';

export function createApp(pool) {
  const app = express();

  app.disable('x-powered-by');
  app.use(helmet());
  app.use(cors({ origin: config.corsOrigin }));
  app.use(express.json({ limit: '2mb' }));

  app.get('/api/health', async (_req, res) => {
    await pool.query('SELECT 1');
    res.json({ ok: true });
  });

  app.use('/api/auth', authRouter(pool));
  app.use('/api/sync', syncRouter(pool));

  app.use((_req, res) => res.status(404).json({ error: 'Ruta no encontrada' }));
  app.use(errorHandler);

  return app;
}
