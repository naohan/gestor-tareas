#!/usr/bin/env bash
# Trae los cambios de GitHub: el código de la API (rama main) y la web ya
# compilada por GitHub Actions (rama web). Lo ejecuta cada minuto el
# temporizador gestor-tareas-actualizar.timer.
set -euo pipefail

# Todo va dentro de main() para que bash lea el script completo antes de que
# `git reset` lo pueda reemplazar a mitad de ejecución.
main() {
  local base=/var/www/gestor-tareas
  local app="$base/app" web="$base/web"

  cd "$app"
  git fetch -q origin main
  local antes
  antes=$(git rev-parse HEAD)
  if [[ "$antes" != "$(git rev-parse origin/main)" ]]; then
    git reset -q --hard origin/main
    if ! git diff --quiet "$antes" HEAD -- backend/package-lock.json; then
      (cd backend && npm ci --omit=dev --no-audit --no-fund)
    fi
    (cd backend && npm run -s db:init)
    pm2 restart gestor-tareas-api --update-env >/dev/null
    echo "API actualizada a $(git rev-parse --short HEAD)"
  fi

  if [[ ! -d "$web/.git" ]]; then
    git ls-remote --exit-code -q origin web >/dev/null || return 0
    git clone -q --single-branch -b web "$(git remote get-url origin)" "$web"
    echo "Web descargada: $(git -C "$web" log -1 --format=%s)"
    return 0
  fi

  cd "$web"
  git fetch -q origin web
  if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/web)" ]]; then
    git reset -q --hard origin/web
    echo "Web actualizada: $(git log -1 --format=%s)"
  fi
}

main "$@"
exit
