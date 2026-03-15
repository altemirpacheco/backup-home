# Backup da home com rsync

Script para backup incremental da pasta home para um SSD externo usando `rsync`.

## Arquivos

- `backup-home.sh`: script principal de backup.
- `config/backup-home.exclude`: lista de exclusoes padrao para o rsync.

## Requisitos

- `rsync`
- `flock` (geralmente incluso no `util-linux`)

## Uso rapido

```bash
chmod +x backup-home.sh
./backup-home.sh --mount /media/$USER/NOME_DO_SSD
```

## Opcoes

| Opcao               | Descricao                                                           |
| -------------------- | ------------------------------------------------------------------- |
| `--dry-run`          | Mostra o que seria copiado, sem alterar nada.                       |
| `--mount PATH`       | Ponto de montagem do SSD externo.                                   |
| `--dest-name NOME`   | Nome da pasta de destino dentro do SSD.                             |
| `--exclude FILE`     | Arquivo com padroes de exclusao do rsync.                           |
| `--skip-mount-check` | Nao valida se o destino e um mountpoint (util para testes).         |
| `-h, --help`         | Exibe a ajuda.                                                      |

## Variaveis de ambiente

Todas as opcoes tambem podem ser definidas via variaveis de ambiente:

| Variavel       | Padrao                                  | Equivalente CLI  |
| -------------- | --------------------------------------- | ----------------- |
| `SOURCE_DIR`   | `$HOME/`                                | —                 |
| `BACKUP_MOUNT` | `/media/$USER/SSD LINUX EXT41`          | `--mount`         |
| `DEST_NAME`    | `$(hostname)-home-backup`               | `--dest-name`     |
| `EXCLUDE_FILE` | `<script_dir>/config/backup-home.exclude` | `--exclude`       |
| `LOG_DIR`      | diretorio do script                     | —                 |
| `LOCK_FILE`    | `/tmp/backup-home-rsync.lock`           | —                 |

## Exemplos

### Dry-run (recomendado no primeiro uso)

```bash
./backup-home.sh --mount /media/$USER/NOME_DO_SSD --dry-run
```

### Nome personalizado da pasta de destino

```bash
./backup-home.sh \
  --mount /media/$USER/NOME_DO_SSD \
  --dest-name backup-home-principal
```

### Usando variaveis de ambiente

```bash
BACKUP_MOUNT=/media/$USER/NOME_DO_SSD DEST_NAME=meu-backup ./backup-home.sh
```

## Funcionalidades

- **Backup incremental** com `rsync --archive`, preservando hard links, ACLs, xattrs e IDs numericos.
- **Espelhamento**: arquivos removidos na origem sao removidos no destino (`--delete-delay`).
- **Transferencia parcial**: retoma copias interrompidas (`--partial`).
- **Restricao a um filesystem**: nao atravessa pontos de montagem (`--one-file-system`).
- **Validacao de montagem**: verifica se o destino e um mountpoint antes de iniciar (desativavel com `--skip-mount-check`).
- **Lock de execucao**: impede execucoes simultaneas via `flock`.
- **Logs com timestamp**: cada execucao gera um arquivo `backup-YYYYMMDD-HHMMSS.log`.
- **Rotacao automatica de logs**: mantem somente os 3 ultimos logs, removendo os mais antigos ao final do backup.
- **Modo dry-run**: simula o backup sem alterar nenhum arquivo.
- **Validacoes previas**: checa dependencias (`rsync`, `flock`), existencia da origem, arquivo de exclusao e permissao de escrita no destino.

