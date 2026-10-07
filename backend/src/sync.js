import { Router } from 'express';
import { z } from 'zod';

import { requireAuth } from './auth.js';
import { withTransaction } from './db.js';
import { HttpError } from './errors.js';

const MAX_ITEMS = 2000;

const id = z.string().trim().min(1).max(36);
const eje = z.number().int().min(1).max(5);
const fecha = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Usa el formato AAAA-MM-DD');
const instante = z.iso.datetime({ offset: true });

const taskSchema = z.object({
  id,
  titulo: z.string().trim().min(1).max(200),
  descripcion: z.string().max(5000).default(''),
  fechaLimite: fecha.nullable().default(null),
  horasEstimadas: z.number().min(0).max(999).default(1),
  estado: z.enum(['pendiente', 'en_progreso', 'completada']).default('pendiente'),
  categoria: z.enum(['trabajo', 'estudio', 'personal', 'salud', 'proyecto']).default('proyecto'),
  impacto: eje.default(3),
  urgencia: eje.default(3),
  ansiedad: eje.default(3),
  activa: z.boolean().default(false),
  dependencias: z.array(id).max(50).default([]),
  completadaEn: instante.nullable().default(null),
  creada: instante.optional(),
});

const projectSchema = z.object({
  id,
  nombre: z.string().trim().min(1).max(200),
  fechaLimite: fecha.nullable().default(null),
  estado: z.enum(['activo', 'pausado', 'terminado']).default('activo'),
  creada: instante.optional(),
});

const tasksBody = z.object({ tasks: z.array(taskSchema).max(MAX_ITEMS) });
const projectsBody = z.object({ projects: z.array(projectSchema).max(MAX_ITEMS) });
const achievementsBody = z.object({ achievements: z.array(z.string().max(50)).max(100) });

// ---- Conversión de fechas (la base guarda UTC sin zona) ----

const toSqlDateTime = (iso) => new Date(iso).toISOString().slice(0, 19).replace('T', ' ');
const fromSqlDateTime = (value) => (value ? `${value.replace(' ', 'T')}Z` : null);

function taskFromRow(row, deps) {
  return {
    id: row.id,
    titulo: row.titulo,
    descripcion: row.descripcion,
    fechaLimite: row.fecha_limite,
    horasEstimadas: Number(row.horas_estimadas),
    estado: row.estado,
    categoria: row.categoria,
    impacto: row.impacto,
    urgencia: row.urgencia,
    ansiedad: row.ansiedad,
    activa: Boolean(row.activa),
    dependencias: deps,
    completadaEn: fromSqlDateTime(row.completada_en),
    creada: fromSqlDateTime(row.created_at),
  };
}

function projectFromRow(row) {
  return {
    id: row.id,
    nombre: row.nombre,
    fechaLimite: row.fecha_limite,
    estado: row.estado,
    creada: fromSqlDateTime(row.created_at),
  };
}

/** Rechaza ids que ya pertenecen a otro usuario (evita sobrescribir datos ajenos). */
async function assertOwnership(conn, table, ids, userId) {
  if (ids.length === 0) return;
  const [rows] = await conn.query(
    `SELECT id FROM ${table} WHERE id IN (?) AND user_id <> ? FOR UPDATE`,
    [ids, userId],
  );
  if (rows.length > 0) {
    throw new HttpError(409, 'Algunos identificadores ya están en uso');
  }
}

export function syncRouter(pool) {
  const router = Router();
  router.use(requireAuth);

  router.get('/', async (req, res) => {
    const uid = req.userId;
    const [taskRows] = await pool.query(
      'SELECT * FROM tasks WHERE user_id = ? ORDER BY created_at',
      [uid],
    );
    const [depRows] = await pool.query(
      `SELECT d.task_id, d.depends_on_id FROM task_dependencies d
         JOIN tasks t ON t.id = d.task_id WHERE t.user_id = ?`,
      [uid],
    );
    const [projectRows] = await pool.query(
      'SELECT * FROM projects WHERE user_id = ? ORDER BY created_at',
      [uid],
    );
    const [achRows] = await pool.query(
      'SELECT achievement_id FROM user_achievements WHERE user_id = ?',
      [uid],
    );

    const deps = new Map();
    for (const r of depRows) {
      if (!deps.has(r.task_id)) deps.set(r.task_id, []);
      deps.get(r.task_id).push(r.depends_on_id);
    }

    res.json({
      tasks: taskRows.map((r) => taskFromRow(r, deps.get(r.id) ?? [])),
      projects: projectRows.map(projectFromRow),
      achievements: achRows.map((r) => r.achievement_id),
    });
  });

  /** Reemplaza el conjunto completo de tareas del usuario por el recibido. */
  router.put('/tasks', async (req, res) => {
    const { tasks } = tasksBody.parse(req.body);
    const uid = req.userId;
    const ids = tasks.map((t) => t.id);
    if (new Set(ids).size !== ids.length) {
      throw new HttpError(400, 'Hay tareas con el id repetido');
    }

    await withTransaction(pool, async (conn) => {
      await assertOwnership(conn, 'tasks', ids, uid);

      if (tasks.length > 0) {
        const values = tasks.map((t) => [
          t.id,
          uid,
          t.titulo,
          t.descripcion,
          t.fechaLimite,
          t.horasEstimadas,
          t.estado,
          t.categoria,
          t.impacto,
          t.urgencia,
          t.ansiedad,
          t.activa,
          t.completadaEn ? toSqlDateTime(t.completadaEn) : null,
          toSqlDateTime(t.creada ?? new Date().toISOString()),
        ]);
        await conn.query(
          `INSERT INTO tasks (id, user_id, titulo, descripcion, fecha_limite, horas_estimadas,
             estado, categoria, impacto, urgencia, ansiedad, activa, completada_en, created_at)
           VALUES ?
           ON DUPLICATE KEY UPDATE
             titulo = VALUES(titulo), descripcion = VALUES(descripcion),
             fecha_limite = VALUES(fecha_limite), horas_estimadas = VALUES(horas_estimadas),
             estado = VALUES(estado), categoria = VALUES(categoria),
             impacto = VALUES(impacto), urgencia = VALUES(urgencia), ansiedad = VALUES(ansiedad),
             activa = VALUES(activa), completada_en = VALUES(completada_en)`,
          [values],
        );
        await conn.query('DELETE FROM tasks WHERE user_id = ? AND id NOT IN (?)', [uid, ids]);
      } else {
        await conn.query('DELETE FROM tasks WHERE user_id = ?', [uid]);
      }

      await conn.query(
        `DELETE d FROM task_dependencies d JOIN tasks t ON t.id = d.task_id WHERE t.user_id = ?`,
        [uid],
      );
      // Solo se aceptan dependencias entre tareas del propio usuario.
      const propias = new Set(ids);
      const pares = [];
      for (const t of tasks) {
        for (const dep of new Set(t.dependencias)) {
          if (dep !== t.id && propias.has(dep)) pares.push([t.id, dep]);
        }
      }
      if (pares.length > 0) {
        await conn.query('INSERT INTO task_dependencies (task_id, depends_on_id) VALUES ?', [
          pares,
        ]);
      }
    });

    res.json({ ok: true, total: tasks.length });
  });

  router.put('/projects', async (req, res) => {
    const { projects } = projectsBody.parse(req.body);
    const uid = req.userId;
    const ids = projects.map((p) => p.id);

    await withTransaction(pool, async (conn) => {
      await assertOwnership(conn, 'projects', ids, uid);
      if (projects.length > 0) {
        const values = projects.map((p) => [
          p.id,
          uid,
          p.nombre,
          p.fechaLimite,
          p.estado,
          toSqlDateTime(p.creada ?? new Date().toISOString()),
        ]);
        await conn.query(
          `INSERT INTO projects (id, user_id, nombre, fecha_limite, estado, created_at)
           VALUES ?
           ON DUPLICATE KEY UPDATE nombre = VALUES(nombre),
             fecha_limite = VALUES(fecha_limite), estado = VALUES(estado)`,
          [values],
        );
        await conn.query('DELETE FROM projects WHERE user_id = ? AND id NOT IN (?)', [uid, ids]);
      } else {
        await conn.query('DELETE FROM projects WHERE user_id = ?', [uid]);
      }
    });

    res.json({ ok: true, total: projects.length });
  });

  /** Registra logros desbloqueados. Es acumulativo: nunca borra logros. */
  router.put('/achievements', async (req, res) => {
    const { achievements } = achievementsBody.parse(req.body);
    if (achievements.length > 0) {
      const [validos] = await pool.query('SELECT id FROM achievements WHERE id IN (?)', [
        achievements,
      ]);
      if (validos.length > 0) {
        await pool.query(
          'INSERT IGNORE INTO user_achievements (user_id, achievement_id) VALUES ?',
          [validos.map((r) => [req.userId, r.id])],
        );
      }
    }
    res.json({ ok: true });
  });

  return router;
}
