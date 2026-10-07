const env = process.env;

const isProduction = env.NODE_ENV === 'production';

const jwtSecret = env.JWT_SECRET ?? '';
if (jwtSecret.length < 32) {
  throw new Error(
    'JWT_SECRET debe tener al menos 32 caracteres. Copia .env.example a .env y genera uno.',
  );
}

export const config = {
  isProduction,
  port: Number(env.PORT ?? 3000),
  corsOrigin: env.CORS_ORIGIN ? env.CORS_ORIGIN.split(',').map((o) => o.trim()) : '*',
  jwt: {
    secret: jwtSecret,
    expiresIn: env.JWT_EXPIRES_IN ?? '7d',
  },
  db: {
    host: env.DB_HOST ?? '127.0.0.1',
    port: Number(env.DB_PORT ?? 3306),
    user: env.DB_USER ?? 'root',
    password: env.DB_PASSWORD ?? '',
    database: env.DB_NAME ?? 'foco',
  },
};
