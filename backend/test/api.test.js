import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { after, before, describe, test } from 'node:test';

process.env.AUTH_RATE_LIMIT = '1000';

const { config } = await import('../src/config.js');
const { createApp } = await import('../src/app.js');
const { createPool } = await import('../src/db.js');
const { initDatabase } = await import('../src/scripts/init-db.js');

const dbConfig = { ...config.db, database: 'foco_test' };
let pool;
let server;
let baseUrl;

async function api(method, path, { token, body } = {}) {
  const res = await fetch(`${baseUrl}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  return { status: res.status, body: text ? JSON.parse(text) : null };
}

async function registrar(nombre = 'Ana') {
  const email = `${randomUUID()}@foco.test`;
  const res = await api('POST', '/api/auth/register', {
    body: { nombre, email, password: 'clave-segura-123' },
  });
  assert.equal(res.status, 201);
  return { ...res.body, email };
}

const tarea = (overrides = {}) => ({
  id: randomUUID(),
  titulo: 'Terminar Geotón',
  descripcion: 'Propuesta minería ilegal',
  fechaLimite: '2026-10-09',
  horasEstimadas: 6,
  estado: 'pendiente',
  categoria: 'proyecto',
  impacto: 4,
  urgencia: 5,
  ansiedad: 4,
  activa: true,
  dependencias: [],
  completadaEn: null,
  ...overrides,
});

before(async () => {
  await initDatabase(dbConfig);
  pool = createPool(dbConfig);
  await pool.query('DELETE FROM users');
  server = createApp(pool).listen(0);
  await new Promise((r) => server.once('listening', r));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  await new Promise((r) => server.close(r));
  await pool.end();
});

describe('autenticación', () => {
  test('registro devuelve un JWT y el usuario', async () => {
    const { token, user } = await registrar('Naho');
    assert.match(token, /^[\w-]+\.[\w-]+\.[\w-]+$/);
    assert.equal(user.nombre, 'Naho');
    assert.equal('password_hash' in user, false);
  });

  test('no permite dos cuentas con el mismo email (sin importar mayúsculas)', async () => {
    const { email } = await registrar();
    const res = await api('POST', '/api/auth/register', {
      body: { nombre: 'Otra', email: email.toUpperCase(), password: 'clave-segura-123' },
    });
    assert.equal(res.status, 409);
  });

  test('rechaza contraseñas cortas', async () => {
    const res = await api('POST', '/api/auth/register', {
      body: { nombre: 'Ana', email: 'corta@foco.test', password: '123' },
    });
    assert.equal(res.status, 400);
  });

  test('login con contraseña correcta e incorrecta', async () => {
    const { email } = await registrar();
    const ok = await api('POST', '/api/auth/login', {
      body: { email, password: 'clave-segura-123' },
    });
    assert.equal(ok.status, 200);
    assert.ok(ok.body.token);

    const mal = await api('POST', '/api/auth/login', { body: { email, password: 'otra-clave' } });
    assert.equal(mal.status, 401);

    const noExiste = await api('POST', '/api/auth/login', {
      body: { email: 'nadie@foco.test', password: 'clave-segura-123' },
    });
    assert.equal(noExiste.status, 401);
    assert.equal(noExiste.body.error, mal.body.error);
  });

  test('/me exige un token válido', async () => {
    const { token, user } = await registrar();
    assert.equal((await api('GET', '/api/auth/me')).status, 401);
    assert.equal((await api('GET', '/api/auth/me', { token: 'x.y.z' })).status, 401);
    const me = await api('GET', '/api/auth/me', { token });
    assert.equal(me.status, 200);
    assert.equal(me.body.user.id, user.id);
  });

  test('eliminar la cuenta exige la contraseña y borra sus datos', async () => {
    const { token, email } = await registrar();
    await api('PUT', '/api/sync/tasks', { token, body: { tasks: [tarea()] } });

    const mal = await api('DELETE', '/api/auth/me', { token, body: { password: 'otra-clave' } });
    assert.equal(mal.status, 403);

    const ok = await api('DELETE', '/api/auth/me', {
      token,
      body: { password: 'clave-segura-123' },
    });
    assert.equal(ok.status, 204);

    const [users] = await pool.query('SELECT id FROM users WHERE email = ?', [email]);
    assert.equal(users.length, 0);
    assert.equal((await api('GET', '/api/auth/me', { token })).status, 401);
    const login = await api('POST', '/api/auth/login', {
      body: { email, password: 'clave-segura-123' },
    });
    assert.equal(login.status, 401);
  });
});

describe('sincronización', () => {
  test('guarda y devuelve tareas con sus dependencias', async () => {
    const { token } = await registrar();
    const base = tarea();
    const dependiente = tarea({ titulo: 'Publicar resultados', dependencias: [base.id] });

    const put = await api('PUT', '/api/sync/tasks', { token, body: { tasks: [base, dependiente] } });
    assert.equal(put.status, 200);

    const { body } = await api('GET', '/api/sync', { token });
    assert.equal(body.tasks.length, 2);
    const leida = body.tasks.find((t) => t.id === dependiente.id);
    assert.deepEqual(leida.dependencias, [base.id]);
    assert.equal(body.tasks.find((t) => t.id === base.id).fechaLimite, '2026-10-09');
  });

  test('actualiza, borra las que faltan y conserva la fecha de cierre', async () => {
    const { token } = await registrar();
    const a = tarea();
    const b = tarea({ titulo: 'Curso AWS' });
    await api('PUT', '/api/sync/tasks', { token, body: { tasks: [a, b] } });

    const cerrada = { ...a, estado: 'completada', completadaEn: '2026-10-07T16:30:00.000Z' };
    await api('PUT', '/api/sync/tasks', { token, body: { tasks: [cerrada] } });

    const { body } = await api('GET', '/api/sync', { token });
    assert.equal(body.tasks.length, 1);
    assert.equal(body.tasks[0].estado, 'completada');
    assert.equal(body.tasks[0].completadaEn, '2026-10-07T16:30:00Z');
  });

  test('valida que los ejes estén entre 1 y 5', async () => {
    const { token } = await registrar();
    const res = await api('PUT', '/api/sync/tasks', {
      token,
      body: { tasks: [tarea({ impacto: 8 })] },
    });
    assert.equal(res.status, 400);
  });

  test('un usuario no puede sobrescribir ni ver tareas de otro', async () => {
    const ana = await registrar('Ana');
    const beto = await registrar('Beto');
    const deAna = tarea();
    await api('PUT', '/api/sync/tasks', { token: ana.token, body: { tasks: [deAna] } });

    const ataque = await api('PUT', '/api/sync/tasks', {
      token: beto.token,
      body: { tasks: [{ ...deAna, titulo: 'Hackeado' }] },
    });
    assert.equal(ataque.status, 409);

    const deBeto = await api('GET', '/api/sync', { token: beto.token });
    assert.equal(deBeto.body.tasks.length, 0);

    const deAnaLeidas = await api('GET', '/api/sync', { token: ana.token });
    assert.equal(deAnaLeidas.body.tasks[0].titulo, 'Terminar Geotón');
  });

  test('los logros son acumulativos e ignoran ids desconocidos', async () => {
    const { token } = await registrar();
    await api('PUT', '/api/sync/achievements', {
      token,
      body: { achievements: ['primer_cierre', 'no_existe'] },
    });
    await api('PUT', '/api/sync/achievements', { token, body: { achievements: ['cinco_cierres'] } });

    const { body } = await api('GET', '/api/sync', { token });
    assert.deepEqual(body.achievements.sort(), ['cinco_cierres', 'primer_cierre']);
  });

  test('sin token no hay acceso', async () => {
    assert.equal((await api('GET', '/api/sync')).status, 401);
  });
});
