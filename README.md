# Home backup with rsync

[![pt-BR](https://img.shields.io/badge/lang-pt--BR-green)](README.pt-BR.md)

Script for incremental backup of the home directory to an external SSD using `rsync`.

## Files

- `backup-home.sh`: main backup script.
- `config/backup-home.exclude`: default exclusion patterns for rsync.

## Requirements

- `rsync`
- `flock` (usually included in `util-linux`)

## Quick start

```bash
chmod +x backup-home.sh
./backup-home.sh --mount /media/$USER/SSD_NAME
```

## Options

| Option               | Description                                                         |
| -------------------- | ------------------------------------------------------------------- |
| `--dry-run`          | Shows what would be copied without making any changes.              |
| `--mount PATH`       | Mount point of the external SSD.                                    |
| `--dest-name NAME`   | Name of the destination folder inside the SSD.                      |
| `--exclude FILE`     | File with rsync exclusion patterns.                                 |
| `--skip-mount-check` | Skips mountpoint validation (useful for testing).                   |
| `-h, --help`         | Displays help.                                                      |

## Environment variables

All options can also be set via environment variables:

| Variable       | Default                                 | CLI equivalent    |
| -------------- | --------------------------------------- | ----------------- |
| `SOURCE_DIR`   | `$HOME/`                                | —                 |
| `BACKUP_MOUNT` | `/media/$USER/SSD LINUX EXT41`          | `--mount`         |
| `DEST_NAME`    | `$(hostname)-home-backup`               | `--dest-name`     |
| `EXCLUDE_FILE` | `<script_dir>/config/backup-home.exclude` | `--exclude`       |
| `LOG_DIR`      | script directory                        | —                 |
| `LOCK_FILE`    | `/tmp/backup-home-rsync.lock`           | —                 |

## Examples

### Dry-run (recommended on first use)

```bash
./backup-home.sh --mount /media/$USER/SSD_NAME --dry-run
```

### Custom destination folder name

```bash
./backup-home.sh \
  --mount /media/$USER/SSD_NAME \
  --dest-name main-home-backup
```

### Using environment variables

```bash
BACKUP_MOUNT=/media/$USER/SSD_NAME DEST_NAME=my-backup ./backup-home.sh
```

## Features

- **Incremental backup** with `rsync --archive`, preserving hard links, ACLs, xattrs and numeric IDs.
- **Mirroring**: files deleted from the source are removed from the destination (`--delete-delay`).
- **Partial transfers**: resumes interrupted copies (`--partial`).
- **Single filesystem**: does not cross mount points (`--one-file-system`).
- **Mount validation**: checks if the destination is a mountpoint before starting (can be disabled with `--skip-mount-check`).
- **Execution lock**: prevents simultaneous runs via `flock`.
- **Timestamped logs**: each run generates a `backup-YYYYMMDD-HHMMSS.log` file.
- **Automatic log rotation**: keeps only the 3 most recent logs, removing older ones after the backup completes.
- **Dry-run mode**: simulates the backup without modifying any files.
- **Pre-flight checks**: verifies dependencies (`rsync`, `flock`), source existence, exclusion file and write permissions on the destination.

