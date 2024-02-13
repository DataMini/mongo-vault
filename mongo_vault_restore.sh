#!/bin/bash
# MongoDB 恢复脚本：从最后一次备份中恢复指定的数据库

# 检查必要的环境变量
if [ -z "$MONGO_VAULT_OSS_AK" ] || [ -z "$MONGO_VAULT_OSS_SK" ] || [ -z "$MONGO_VAULT_OSS_BUCKET" ] || [ -z "$MONGO_VAULT_OSS_URI_PREFIX" ] || [ -z "$MONGO_VAULT_OSS_ENDPOINT" ]; then
  echo "One or more environment variables required for restoration are missing."
  exit 1
fi

# 配置 OSS 工具
echo "Configuring OSS tool..."
ossutil config -e $MONGO_VAULT_OSS_ENDPOINT -i $MONGO_VAULT_OSS_AK -k $MONGO_VAULT_OSS_SK

# 查找最新的月份目录
LATEST_MONTH_DIR=$(ossutil ls oss://$MONGO_VAULT_OSS_BUCKET/$MONGO_VAULT_OSS_URI_PREFIX/ | awk '{print $NF}' | sort -r | head -n 1)

# 在最新的月份目录中查找最新的备份目录
LATEST_BACKUP_DIR=$(ossutil ls $LATEST_MONTH_DIR | awk '{print $NF}' | sort -r | head -n 1)
echo "Latest backup directory is $LATEST_BACKUP_DIR."

# 解析需要恢复的数据库列表
DB_MAP="$1"
# [ -z "$DB_MAP" ] && DB_MAP=$MONGO_VAULT_RESTORE_DATABASES || echo "Using database map from argument."

if [ -z "$DB_MAP" ]; then
  echo "Using database map from environment variable."
  DB_MAP=$MONGO_VAULT_RESTORE_DATABASES
else
  echo "Using database map from argument."
fi

# 恢复数据库
if [ -z "$DB_MAP" ]; then
  # 没有指定数据库，恢复该备份目录下的所有数据库
  echo "No database specified, restoring all databases from $LATEST_BACKUP_DIR."
  ossutil cp -r $LATEST_BACKUP_DIR /tmp/mongo_vault_restore/ --include "*.gz"
  for BACKUP_FILE in /tmp/mongo_vault_restore/*.gz; do
    DB_NAME=$(basename $BACKUP_FILE .gz)
    echo "Restoring database $DB_NAME from $BACKUP_FILE..."
    if mongo $DB_NAME --eval "db.stats()" >/dev/null 2>&1; then
      echo "Database $DB_NAME exists, skipping."
    else
      echo "Restoring database $DB_NAME..."
      mongorestore --gzip --archive=$BACKUP_FILE
      echo "Database $DB_NAME restored."
    fi
  done
else
  # 恢复指定的数据库
  echo "Restoring specified databases: $DB_MAP"
  IFS=',' read -ra DB_NAMES <<< "$DB_MAP"
  for DB_NAME in "${DB_NAMES[@]}"; do
    BACKUP_FILE_PATH="$LATEST_BACKUP_DIR/${DB_NAME}.gz"
    echo "Restoring database $DB_NAME from $BACKUP_FILE_PATH..."
    if ossutil stat $BACKUP_FILE_PATH >/dev/null 2>&1; then
      echo "Downloading backup file for database $DB_NAME..."
      ossutil cp $BACKUP_FILE_PATH /tmp/${DB_NAME}.gz
      echo "Restoring database $DB_NAME..."
      mongorestore --gzip --archive=/tmp/${DB_NAME}.gz
      echo "Database $DB_NAME restored."
    else
      echo "Backup file for database $DB_NAME not found."
    fi
  done
fi

echo "Restoration completed."
