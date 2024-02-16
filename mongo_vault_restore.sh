#!/bin/bash
# MongoDB 恢复脚本：从最后一次备份中恢复指定的数据库

# 定义日志前缀
LOG_PREFIX="[MongoVaultRestore]"

# 定义带前缀的日志函数
log() {
    # 获取当前时间，格式为 YYYY-MM-DD HH:MM:SS
    local current_time=$(date "+%Y-%m-%d %H:%M:%S")
    # 输出日志，包含时间戳和日志前缀
    echo "$current_time $LOG_PREFIX $@"
}



# 检查必要的环境变量
if [ -z "$MONGO_VAULT_OSS_AK" ] || [ -z "$MONGO_VAULT_OSS_SK" ] || [ -z "$MONGO_VAULT_OSS_BUCKET" ] || [ -z "$MONGO_VAULT_OSS_URI_PREFIX" ] || [ -z "$MONGO_VAULT_OSS_ENDPOINT" ]; then
  log "One or more environment variables required for restoration are missing."
  exit 1
fi

# 配置 OSS 工具
log "Configuring OSS tool..."
ossutil config -e $MONGO_VAULT_OSS_ENDPOINT -i $MONGO_VAULT_OSS_AK -k $MONGO_VAULT_OSS_SK

# 查找最新的月份目录并检查是否存在任何对象
OBJECT_COUNT=$(ossutil ls oss://$MONGO_VAULT_OSS_BUCKET/$MONGO_VAULT_OSS_URI_PREFIX/ | grep "Object Number is:" | awk '{print $NF}')
if [ "$OBJECT_COUNT" == "0" ]; then
  log "No backup directories found. Exiting..."
  exit 1
fi

# 查找最新的月份目录
LATEST_MONTH_DIR=$(ossutil ls -d oss://$MONGO_VAULT_OSS_BUCKET/$MONGO_VAULT_OSS_URI_PREFIX/ | grep "oss://" | sort -r | head -n 1)

# 在最新的月份目录中查找最新的备份目录
LATEST_BACKUP_DIR=$(ossutil ls -d $LATEST_MONTH_DIR | grep "oss://" | sort -r | head -n 1)
log "Latest backup is $LATEST_BACKUP_DIR"

# 解析需要恢复的数据库列表
DB_MAP=""

# 解析命令行参数
for arg in "$@"
do
    case $arg in
        --databases=*)
        DB_MAP="${arg#*=}"
        shift # 移除当前参数
        ;;
        *)
        # 处理其他参数
        shift
        ;;
    esac
done

if [ -z "$DB_MAP" ]; then
  # log "Using databases from environment variable. $DB_MAP"
  DB_MAP=$MONGO_VAULT_RESTORE_DATABASES
fi

# 创建临时备份目录
CURRENT_TIME=$(date +%Y%m%d-%H%M%S)
TEMP_RESTORE_DIR=/tmp/mongo_vault_restore/$CURRENT_TIME
mkdir -p "$TEMP_RESTORE_DIR"


if [ -z "$MONGO_INITDB_ROOT_USERNAME" ] || [ -z "$MONGO_INITDB_ROOT_PASSWORD" ]; then
  user_and_pass_args=""
else
  user_and_pass_args="-u $MONGO_INITDB_ROOT_USERNAME -p $MONGO_INITDB_ROOT_PASSWORD --authenticationDatabase admin"
fi


# 检查是否设置了数据库列表环境变量
if [ -z "$DB_MAP" ]; then
  log "No specific databases to restore, restoring all databases from $LATEST_BACKUP_DIR."
  ossutil cp -r "$LATEST_BACKUP_DIR" "$TEMP_RESTORE_DIR" --include "*.gz" >/dev/null
  for backup_file in "$TEMP_RESTORE_DIR"/*.gz; do
    db_name=$(basename "$backup_file" .gz)
    log "Restoring $backup_file..."
    if mongo $user_and_pass_args $db_name --eval "db.stats()" >/dev/null; then
      log "Database $db_name exists, skipping."
    else
      mongorestore $user_and_pass_args --gzip --archive="$backup_file" >/dev/null
      log "Database $db_name restored."
    fi
  done
else
  log "Restoring specified databases: $DB_MAP"
  IFS=',' read -ra DB_PAIRS <<< "$DB_MAP"
  for pair in "${DB_PAIRS[@]}"; do
    IFS=':' read -ra names <<< "$pair"
    orig_name="${names[0]}"
    new_name="${names[1]:-$orig_name}" # 使用提供的新名称或者如果未提供则使用原名称
    backup_file_path="$LATEST_BACKUP_DIR${orig_name}.gz"
    log "Restoring database $orig_name to $new_name from $backup_file_path..."
    if ossutil stat "$backup_file_path" >/dev/null 2>&1; then
      log "Downloading backup file for database $orig_name to $TEMP_RESTORE_DIR/${orig_name}.gz"
      ossutil cp "$backup_file_path" "$TEMP_RESTORE_DIR"/"$orig_name".gz >/dev/null

      collections=$(mongo $user_and_pass_args $new_name --eval "db.getCollectionNames()" --quiet | tail -n 1)
      if [ "$collections" == "[ ]" ] ; then
        log "Restoring database $orig_name as $new_name..."
        mongorestore $user_and_pass_args --gzip --archive="$TEMP_RESTORE_DIR"/"${orig_name}".gz --nsFrom="${orig_name}.*" --nsTo="${new_name}.*" >/dev/null
        log "Database $orig_name restored as $new_name."
      else
        log "Database $new_name exists, skipping."
      fi
    else
      log "Backup file for database $orig_name not found."
    fi
  done
fi

log "Restoration completed."
