#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage:
  backup-home.sh [options]

Options:
  --dry-run             Show what would be copied without making changes.
  --mount PATH          Mount point of the external SSD.
  --dest-name NAME      Name of the destination folder inside the SSD.
  --exclude FILE        File with rsync exclusion patterns.
  --skip-mount-check    Skip mountpoint validation (useful for testing).
  -h, --help            Display this help.

Optional environment variables:
  SOURCE_DIR            Backup source (default: $HOME/)
  BACKUP_MOUNT          Same as --mount
  DEST_NAME             Same as --dest-name
  EXCLUDE_FILE          Same as --exclude
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SOURCE_DIR:-$HOME/}"
BACKUP_MOUNT="${BACKUP_MOUNT:-/media/$USER/SSD LINUX EXT41}"
DEST_NAME="${DEST_NAME:-$(hostname)-home-backup}"
EXCLUDE_FILE="${EXCLUDE_FILE:-$SCRIPT_DIR/config/backup-home.exclude}"
LOG_DIR="${LOG_DIR:-$SCRIPT_DIR}"
LOCK_FILE="${LOCK_FILE:-/tmp/backup-home-rsync.lock}"
DRY_RUN=0
SKIP_MOUNT_CHECK=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --mount)
      BACKUP_MOUNT="$2"
      shift 2
      ;;
    --dest-name)
      DEST_NAME="$2"
      shift 2
      ;;
    --exclude)
      EXCLUDE_FILE="$2"
      shift 2
      ;;
    --skip-mount-check)
      SKIP_MOUNT_CHECK=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Invalid option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

for cmd in rsync flock; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: required command not found: $cmd" >&2
    exit 1
  fi
done

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Error: source does not exist: $SOURCE_DIR" >&2
  exit 1
fi

if [[ ! -f "$EXCLUDE_FILE" ]]; then
  echo "Error: exclusion file not found: $EXCLUDE_FILE" >&2
  exit 1
fi

if [[ "$SKIP_MOUNT_CHECK" -eq 0 ]] && ! mountpoint -q "$BACKUP_MOUNT"; then
  echo "Error: destination is not mounted: $BACKUP_MOUNT" >&2
  echo "Hint: use --mount to set the correct external SSD path." >&2
  exit 1
fi

mkdir -p "$BACKUP_MOUNT" "$LOG_DIR"
DEST_DIR="$BACKUP_MOUNT/$DEST_NAME"
mkdir -p "$DEST_DIR"

if [[ ! -w "$DEST_DIR" ]]; then
  echo "Error: no write permission on destination: $DEST_DIR" >&2
  exit 1
fi

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "Error: a backup is already running." >&2
  exit 1
fi

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/backup-$TIMESTAMP.log"

# shellcheck disable=SC2054
RSYNC_OPTS=(
  --archive
  --hard-links
  --acls
  --xattrs
  --numeric-ids
  --delete-delay
  --partial
  --human-readable
  --one-file-system
  --exclude-from="$EXCLUDE_FILE"
  --info=name1,stats2,progress2
  --log-file="$LOG_FILE"
  --log-file-format=""
)

if [[ "$DRY_RUN" -eq 1 ]]; then
  RSYNC_OPTS+=(--dry-run)
fi

echo "Starting backup:"
echo "  Source:      $SOURCE_DIR"
echo "  Destination: $DEST_DIR"
echo "  Excludes:    $EXCLUDE_FILE"
echo "  Log:         $LOG_FILE"

time sudo rsync "${RSYNC_OPTS[@]}" "$SOURCE_DIR" "$DEST_DIR"

echo "Backup completed successfully at $(date '+%Y-%m-%d %H:%M:%S')"

# Keep only the 3 most recent logs
cd "$LOG_DIR" && ls -1t backup-*.log 2>/dev/null | tail -n +4 | xargs -r rm --

