import { randomUUID } from 'node:crypto';

import bcrypt from 'bcryptjs';
import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import jwt from 'jsonwebtoken';
import { z } from 'zod';

import { config } from './config.js';
import { HttpError } from './errors.js';

const BCRYPT_COST = 10;

// Se compara contra este hash cuando el email no existe, para que el tiempo de
// respuesta no revele qué emails están registrados.
const DUMMY_HASH = bcrypt.hashSync('foco-dummy-password', BCRYPT_COST);

const emailSchema = z.string().trim().toLowerCase().max(255).pipe(z.email('Email inválido'));

const registerSchema = z.object({
  nombre: z.string().trim().min(1, 'Escribe tu nombre').max(100),
  email: emailSchema,
  // bcrypt solo usa los primeros 72 bytes.
  password: z.string().min(8, 'La contraseña debe tener al menos 8 caracteres').max(72),
});

const loginSchema = z.object({
  email: emailSchema,
  password: z.string().min(1).max(72),
});

function signToken(user) {
  return jwt.sign({ email: user.email }, config.jwt.secret, {
    subject: user.id,
    expiresIn: config.jwt.expiresIn,
    algorithm: 'HS256',
  });
}

function publicUser(row) {
  return { id: row.id, nombre: row.nombre, email: row.email, avatarUrl: row.avatar_url ?? null };
}

/** Exige un `Authorization: Bearer <jwt>` válido y deja el id en req.userId. */
export function requireAuth(req, _res, next) {
  const header = req.get('authorization') ?? '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) {
    return next(new HttpError(401, 'Falta el token de acceso'));
  }
  try {
    const payload = jwt.verify(token, config.jwt.secret, { algorithms: ['HS256'] });
    req.userId = payload.sub;
    return next();
  } catch {
    return next(new HttpError(401, 'Token inválido o caducado'));
  }
}

export function authRouter(pool) {
  const router = Router();

  router.use(
    rateLimit({
      windowMs: 15 * 60 * 1000,
      limit: Number(process.env.AUTH_RATE_LIMIT ?? 20),
      standardHeaders: 'draft-8',
      legacyHeaders: false,
      skip: (req) => req.method === 'GET' && req.path === '/me',
      message: { error: 'Demasiados intentos. Espera unos minutos.' },
    }),
  );

  router.post('/register', async (req, res) => {
    const data = registerSchema.parse(req.body);

    const [existing] = await pool.query('SELECT id FROM users WHERE email = ?', [data.email]);
    if (existing.length > 0) {
      throw new HttpError(409, 'Ya existe una cuenta con ese email');
    }

    const user = {
      id: randomUUID(),
      nombre: data.nombre,
      email: data.email,
      avatar_url: null,
    };
    const hash = await bcrypt.hash(data.password, BCRYPT_COST);
    try {
      await pool.query(
        'INSERT INTO users (id, nombre, email, password_hash) VALUES (?, ?, ?, ?)',
        [user.id, user.nombre, user.email, hash],
      );
    } catch (err) {
      if (err.code === 'ER_DUP_ENTRY') {
        throw new HttpError(409, 'Ya existe una cuenta con ese email');
      }
      throw err;
    }

    res.status(201).json({ token: signToken(user), user: publicUser(user) });
  });

  router.post('/login', async (req, res) => {
    const data = loginSchema.parse(req.body);

    const [rows] = await pool.query(
      'SELECT id, nombre, email, avatar_url, password_hash FROM users WHERE email = ?',
      [data.email],
    );
    const row = rows[0];
    const ok = await bcrypt.compare(data.password, row?.password_hash ?? DUMMY_HASH);
    if (!row || !ok) {
      throw new HttpError(401, 'Email o contraseña incorrectos');
    }

    res.json({ token: signToken(row), user: publicUser(row) });
  });

  router.get('/me', requireAuth, async (req, res) => {
    const [rows] = await pool.query(
      'SELECT id, nombre, email, avatar_url FROM users WHERE id = ?',
      [req.userId],
    );
    if (rows.length === 0) throw new HttpError(401, 'La cuenta ya no existe');
    res.json({ user: publicUser(rows[0]) });
  });

  /** Elimina la cuenta y todos sus datos (tareas, proyectos, logros). */
  router.delete('/me', requireAuth, async (req, res) => {
    const { password } = z.object({ password: z.string().min(1).max(72) }).parse(req.body ?? {});
    const [rows] = await pool.query('SELECT password_hash FROM users WHERE id = ?', [req.userId]);
    if (rows.length === 0) throw new HttpError(401, 'La cuenta ya no existe');
    if (!(await bcrypt.compare(password, rows[0].password_hash))) {
      throw new HttpError(403, 'Contraseña incorrecta');
    }
    await pool.query('DELETE FROM users WHERE id = ?', [req.userId]);
    res.status(204).end();
  });

  return router;
}
