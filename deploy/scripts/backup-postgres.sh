#!/usr/bin/env bash
# Dump the Rastarant Postgres database to a timestamped file.
# Run on the VPS (cron) or locally with DATABASE_URL / deploy secrets.
#
#   bash deploy/scripts/backup-postgres.sh
#
# Env:
#   BACKUP_DIR   — output directory (default: /var/backups/rastarant)
#   KEEP_DAYS    — delete backups older than N days (default: 14)
#   DATABASE_URL — postgres connection URL (optional if /var/www/rastarant/backend/.env exists)

set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/var/backups/rastarant}"
KEEP_DAYS="${KEEP_DAYS:-14}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_FILE="${BACKUP_DIR}/rastarant-${STAMP}.sql.gz"

if [[ -z "${DATABASE_URL:-}" && -f /var/www/rastarant/backend/.env ]]; then
  DATABASE_URL="$(grep -E '^DATABASE_URL=' /var/www/rastarant/backend/.env | cut -d= -f2- | tr -d '"' | tr -d "'")"
fi

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL is not set and backend .env was not found." >&2
  exit 1
fi

# pg_dump expects postgresql:// not the asyncpg driver suffix
PG_URL="${DATABASE_URL/postgresql+asyncpg:\/\//postgresql:\/\/}"

mkdir -p "${BACKUP_DIR}"
pg_dump "${PG_URL}" --no-owner --no-acl | gzip -9 > "${OUT_FILE}"
chmod 600 "${OUT_FILE}"

find "${BACKUP_DIR}" -name 'rastarant-*.sql.gz' -type f -mtime +"${KEEP_DAYS}" -delete 2>/dev/null || true

echo "Backup written: ${OUT_FILE} ($(du -h "${OUT_FILE}" | awk '{print $1}'))"
