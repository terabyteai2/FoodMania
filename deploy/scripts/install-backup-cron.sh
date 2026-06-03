#!/usr/bin/env bash
# Install a daily 03:15 UTC Postgres backup cron on the VPS.
# Run once on the server as root after bootstrap:
#
#   bash /var/www/rastarant/deploy/scripts/install-backup-cron.sh

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-/var/www/rastarant}"
CRON_LINE="15 3 * * * BACKUP_DIR=/var/backups/rastarant ${REPO_ROOT}/deploy/scripts/backup-postgres.sh >> /var/log/rastarant-backup.log 2>&1"

mkdir -p /var/backups/rastarant
touch /var/log/rastarant-backup.log
chmod 600 /var/log/rastarant-backup.log

if crontab -l 2>/dev/null | grep -Fq 'backup-postgres.sh'; then
  echo "Backup cron already installed."
  exit 0
fi

( crontab -l 2>/dev/null || true; echo "${CRON_LINE}" ) | crontab -
echo "Installed daily backup cron:"
echo "  ${CRON_LINE}"
