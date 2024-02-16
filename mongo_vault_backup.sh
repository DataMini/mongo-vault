#!/bin/bash
# MongoDB 备份脚本：为每个数据库创建单独的备份文件

# 定义日志前缀
LOG_PREFIX="[MongoVaultBackup]"

# 定义带前缀的日志函数
log() {
    # 获取当前时间，格式为 YYYY-MM-DD HH:MM:SS
    local current_time=$(date "+%Y-%m-%d %H:%M:%S")
    # 输出日志，包含时间戳和日志前缀
    echo "$current_time $LOG_PREFIX $@"
}



# 检查必要的环境变量
if [ -z "$MONGO_VAULT_OSS_AK" ] || [ -z "$MONGO_VAULT_OSS_SK" ] || [ -z "$MONGO_VAULT_OSS_BUCKET" ] || [ -z "$MONGO_VAULT_OSS_URI_PREFIX" ] || [ -z "$MONGO_VAULT_OSS_ENDPOINT" ]; then
  log "One or more environment variables required for backup are missing."
  exit 0
fi

# 配置 OSS 工具
log "Configuring OSS tool..."
ossutil config -e $MONGO_VAULT_OSS_ENDPOINT -i $MONGO_VAULT_OSS_AK -k $MONGO_VAULT_OSS_SK

# 定义备份目录
CURRENT_MONTH=$(date +%Y-%m)
CURRENT_TIME=$(date +%Y%m%d-%H%M%S)
BACKUP_PATH="$MONGO_VAULT_OSS_URI_PREFIX/$CURRENT_MONTH/$CURRENT_TIME"
log "This backup is $BACKUP_PATH."

# 创建临时备份目录
TEMP_BACKUP_DIR=/tmp/mongo_vault_backup/$CURRENT_TIME
mkdir -p $TEMP_BACKUP_DIR


# 定义要跳过的数据库名称数组
SKIP_DATABASES=("admin" "config" "local")

# 函数：检查数据库是否应该被跳过
should_skip() {
  local db=$1
  for skip_db in "${SKIP_DATABASES[@]}"; do
    if [ "$db" == "$skip_db" ]; then
      return 0 # 找到匹配，应该跳过
    fi
  done
  return 1 # 没有找到匹配，不应该跳过
}

if [ -z "$MONGO_INITDB_ROOT_USERNAME" ] || [ -z "$MONGO_INITDB_ROOT_PASSWORD" ]; then
  user_and_pass_args=""
else
  user_and_pass_args="-u $MONGO_INITDB_ROOT_USERNAME -p $MONGO_INITDB_ROOT_PASSWORD --authenticationDatabase admin"
fi


# 获取所有数据库列表或使用指定的数据库
if [ -z "$MONGO_VAULT_BACKUP_DATABASES" ]; then
  DATABASES=$(mongo --quiet $user_and_pass_args --eval "db.getMongo().getDBNames().join(' ');" | tail -n1)
  log "No databases specified, backing up all databases. Found databases: $DATABASES"
else
  log "Backing up specified databases: $MONGO_VAULT_BACKUP_DATABASES"
  DATABASES=$(echo $MONGO_VAULT_BACKUP_DATABASES | tr ',' ' ')
fi

# 为每个数据库执行备份
for db in $DATABASES; do
  if should_skip "$db"; then
    log "Skipping backup for database $db."
    continue
  fi

  log "Backing up database $db..."
  mongodump $user_and_pass_args --db $db --archive="$TEMP_BACKUP_DIR"/"$db".gz --gzip > /dev/null 2>&1

  # 检查备份操作是否成功
  if [ $? -eq 0 ]; then
    log "MongoDB backup for database $db completed successfully."

    # 使用 ossutil 将备份文件上传到 OSS
    ossutil cp "$TEMP_BACKUP_DIR"/"$db".gz oss://"$MONGO_VAULT_OSS_BUCKET"/"$BACKUP_PATH"/"$db".gz >/dev/null 2>&1

    # 检查上传操作是否成功
    if [ $? -eq 0 ]; then
      log "Backup file uploaded to OSS successfully."
    else
      log "Failed to upload backup file to OSS."
    fi

    # 删除临时备份文件
    rm "$TEMP_BACKUP_DIR"/"$db".gz
  else
    log "Failed to backup MongoDB database $db ."
  fi
done

log "Backup completed: $BACKUP_PATH."
