#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
Uso:
  backup-home.sh [opcoes]

Opcoes:
  --dry-run             Mostra o que seria copiado, sem alterar nada.
  --mount PATH          Ponto de montagem do SSD externo.
  --dest-name NOME      Nome da pasta de destino dentro do SSD.
  --exclude FILE        Arquivo com padroes de exclusao do rsync.
  --skip-mount-check    Nao valida se o destino e um mountpoint (util para testes).
  -h, --help            Exibe esta ajuda.

Variaveis de ambiente opcionais:
  SOURCE_DIR            Origem do backup (padrao: $HOME/)
  BACKUP_MOUNT          Igual a --mount
  DEST_NAME             Igual a --dest-name
  EXCLUDE_FILE          Igual a --exclude
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
      echo "Opcao invalida: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

for cmd in rsync flock; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Erro: comando obrigatorio nao encontrado: $cmd" >&2
    exit 1
  fi
done

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Erro: origem nao existe: $SOURCE_DIR" >&2
  exit 1
fi

if [[ ! -f "$EXCLUDE_FILE" ]]; then
  echo "Erro: arquivo de exclusao nao existe: $EXCLUDE_FILE" >&2
  exit 1
fi

if [[ "$SKIP_MOUNT_CHECK" -eq 0 ]] && ! mountpoint -q "$BACKUP_MOUNT"; then
  echo "Erro: destino nao esta montado: $BACKUP_MOUNT" >&2
  echo "Dica: ajuste --mount para o caminho correto do SSD externo." >&2
  exit 1
fi

mkdir -p "$BACKUP_MOUNT" "$LOG_DIR"
DEST_DIR="$BACKUP_MOUNT/$DEST_NAME"
mkdir -p "$DEST_DIR"

if [[ ! -w "$DEST_DIR" ]]; then
  echo "Erro: sem permissao de escrita no destino: $DEST_DIR" >&2
  exit 1
fi

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "Erro: ja existe um backup em execucao." >&2
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

echo "Iniciando backup:"
echo "  Origem:  $SOURCE_DIR"
echo "  Destino: $DEST_DIR"
echo "  Excludes: $EXCLUDE_FILE"
echo "  Log: $LOG_FILE"

time sudo rsync "${RSYNC_OPTS[@]}" "$SOURCE_DIR" "$DEST_DIR"

echo "Backup concluido com sucesso em $(date '+%Y-%m-%d %H:%M:%S')"

# Manter somente os 3 ultimos logs
cd "$LOG_DIR" && ls -1t backup-*.log 2>/dev/null | tail -n +4 | xargs -r rm --

