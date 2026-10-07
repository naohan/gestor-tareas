import { createApp } from './app.js';
import { config } from './config.js';
import { createPool } from './db.js';

const pool = createPool();
const app = createApp(pool);

const server = app.listen(config.port, () => {
  console.log(`API de Foco escuchando en http://localhost:${config.port}`);
});

function shutdown() {
  server.close(() => pool.end().finally(() => process.exit(0)));
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
