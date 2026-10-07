-- Foco: esquema MySQL 8 / MariaDB 10.4+
-- La prioridad NO se guarda: la app la calcula a partir de los campos de tasks.
-- Los ejes impacto / urgencia / ansiedad van de 1 a 5.

CREATE TABLE IF NOT EXISTS users (
  id            CHAR(36)     NOT NULL PRIMARY KEY,
  nombre        VARCHAR(100) NOT NULL,
  email         VARCHAR(255) NOT NULL,
  password_hash VARCHAR(100) NOT NULL,
  avatar_url    VARCHAR(500) NULL,
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_users_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS projects (
  id           CHAR(36)     NOT NULL PRIMARY KEY,
  user_id      CHAR(36)     NOT NULL,
  nombre       VARCHAR(200) NOT NULL,
  fecha_limite DATE         NULL,
  estado       ENUM('activo','pausado','terminado') NOT NULL DEFAULT 'activo',
  created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_projects_user (user_id),
  CONSTRAINT fk_projects_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS tasks (
  id              CHAR(36)      NOT NULL PRIMARY KEY,
  user_id         CHAR(36)      NOT NULL,
  project_id      CHAR(36)      NULL,
  titulo          VARCHAR(200)  NOT NULL,
  descripcion     TEXT          NOT NULL,
  fecha_limite    DATE          NULL,
  horas_estimadas DECIMAL(5,2)  NOT NULL DEFAULT 1.00,
  estado          ENUM('pendiente','en_progreso','completada') NOT NULL DEFAULT 'pendiente',
  categoria       ENUM('trabajo','estudio','personal','salud','proyecto') NOT NULL DEFAULT 'proyecto',
  impacto         TINYINT       NOT NULL DEFAULT 3,
  urgencia        TINYINT       NOT NULL DEFAULT 3,
  ansiedad        TINYINT       NOT NULL DEFAULT 3,
  activa          BOOLEAN       NOT NULL DEFAULT FALSE,
  completada_en   DATETIME      NULL,
  created_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_tasks_user_estado (user_id, estado),
  KEY idx_tasks_user_fecha (user_id, fecha_limite),
  CONSTRAINT chk_tasks_impacto  CHECK (impacto  BETWEEN 1 AND 5),
  CONSTRAINT chk_tasks_urgencia CHECK (urgencia BETWEEN 1 AND 5),
  CONSTRAINT chk_tasks_ansiedad CHECK (ansiedad BETWEEN 1 AND 5),
  CONSTRAINT fk_tasks_user    FOREIGN KEY (user_id)    REFERENCES users(id)    ON DELETE CASCADE,
  CONSTRAINT fk_tasks_project FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Una tarea depende de otra: mientras la dependencia no esté completada,
-- la tarea aparece como "bloqueada".
CREATE TABLE IF NOT EXISTS task_dependencies (
  task_id       CHAR(36) NOT NULL,
  depends_on_id CHAR(36) NOT NULL,
  PRIMARY KEY (task_id, depends_on_id),
  CONSTRAINT chk_dep_distinta CHECK (task_id <> depends_on_id),
  CONSTRAINT fk_dep_task    FOREIGN KEY (task_id)       REFERENCES tasks(id) ON DELETE CASCADE,
  CONSTRAINT fk_dep_depende FOREIGN KEY (depends_on_id) REFERENCES tasks(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS achievements (
  id          VARCHAR(50)  NOT NULL PRIMARY KEY,
  titulo      VARCHAR(100) NOT NULL,
  descripcion VARCHAR(255) NOT NULL,
  emoji       VARCHAR(16)  NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS user_achievements (
  user_id        CHAR(36)    NOT NULL,
  achievement_id VARCHAR(50) NOT NULL,
  unlocked_at    DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, achievement_id),
  CONSTRAINT fk_ua_user FOREIGN KEY (user_id)        REFERENCES users(id)        ON DELETE CASCADE,
  CONSTRAINT fk_ua_ach  FOREIGN KEY (achievement_id) REFERENCES achievements(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS calendar_accounts (
  id            CHAR(36)     NOT NULL PRIMARY KEY,
  user_id       CHAR(36)     NOT NULL,
  provider      VARCHAR(20)  NOT NULL DEFAULT 'google',
  google_email  VARCHAR(255) NOT NULL,
  access_token  TEXT         NOT NULL,
  refresh_token TEXT         NULL,
  token_expiry  DATETIME     NULL,
  scope         VARCHAR(500) NULL,
  sync_token    VARCHAR(500) NULL,
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_cal_account (user_id, google_email),
  CONSTRAINT fk_cal_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS calendar_events (
  id                  CHAR(36)     NOT NULL PRIMARY KEY,
  user_id             CHAR(36)     NOT NULL,
  calendar_account_id CHAR(36)     NULL,
  task_id             CHAR(36)     NULL,
  google_event_id     VARCHAR(255) NULL,
  titulo              VARCHAR(255) NOT NULL,
  inicio              DATETIME     NOT NULL,
  fin                 DATETIME     NOT NULL,
  source              ENUM('google_sync','foco_planned') NOT NULL,
  ocupado             BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_event_google (calendar_account_id, google_event_id),
  KEY idx_events_user_rango (user_id, inicio, fin),
  CONSTRAINT fk_ev_user    FOREIGN KEY (user_id)             REFERENCES users(id)             ON DELETE CASCADE,
  CONSTRAINT fk_ev_account FOREIGN KEY (calendar_account_id) REFERENCES calendar_accounts(id) ON DELETE CASCADE,
  CONSTRAINT fk_ev_task    FOREIGN KEY (task_id)             REFERENCES tasks(id)             ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Debe coincidir con lib/models/achievement.dart
INSERT IGNORE INTO achievements (id, titulo, descripcion, emoji) VALUES
  ('primer_cierre',   'Primer cierre',             'Completaste tu primera tarea.',              '✅'),
  ('primer_proyecto', 'Primer proyecto terminado', 'Cerraste una tarea de categoría Proyecto.',  '🏆'),
  ('antes_de_fecha',  'Entrega anticipada',        'Terminaste algo antes de su fecha límite.',  '⏱️'),
  ('enfoque_3_dias',  '3 días de enfoque',         'Cerraste algo 3 días seguidos.',             '🔥'),
  ('mente_despejada', 'Mente despejada',           'Cerraste una tarea con ansiedad alta (≥ 4).','🧠'),
  ('cinco_cierres',   'Cinco cerradas',            'Completaste 5 tareas en total.',             '🌟');
