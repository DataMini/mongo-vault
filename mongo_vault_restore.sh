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

if [ -z "$DB_MAP" ]; then
  echo "Using database map from environment variable."
  DB_MAP=$MONGO_VAULT_RESTORE_DATABASES
else
  echo "Using database map from argument."
fi


# 检查是否设置了数据库列表环境变量
if [ -z "$DB_MAP" ]; then
  echo "No specific databases to restore, restoring all databases from $LATEST_BACKUP_DIR."
  ossutil cp -r $LATEST_BACKUP_DIR /tmp/mongo_vault_restore/ --include "*.gz"
  for BACKUP_FILE in /tmp/mongo_vault_restore/*.gz; do
    DB_NAME=$(basename $BACKUP_FILE .gz)
    echo "Restoring database $DB_NAME from $BACKUP_FILE..."
    if mongo -u $MONGO_INITDB_ROOT_USERNAME -p $MONGO_INITDB_ROOT_PASSWORD $DB_NAME --eval "db.stats()" >/dev/null 2>&1; then
      echo "Database $DB_NAME exists, skipping."
    else
      echo "Restoring database $DB_NAME..."
      mongorestore -u $MONGO_INITDB_ROOT_USERNAME -p $MONGO_INITDB_ROOT_PASSWORD --gzip --archive=$BACKUP_FILE
      echo "Database $DB_NAME restored."
    fi
  done
else
  echo "Restoring specified databases: $DB_MAP"
  IFS=',' read -ra DB_PAIRS <<< "$DB_MAP"
  for PAIR in "${DB_PAIRS[@]}"; do
    IFS=':' read -ra NAMES <<< "$PAIR"
    ORIG_NAME="${NAMES[0]}"
    NEW_NAME="${NAMES[1]:-$ORIG_NAME}" # 使用提供的新名称或者如果未提供则使用原名称
    BACKUP_FILE_PATH="$LATEST_BACKUP_DIR/${ORIG_NAME}.gz"
    echo "Restoring database $ORIG_NAME to $NEW_NAME from $BACKUP_FILE_PATH..."
    if ossutil stat $BACKUP_FILE_PATH >/dev/null 2>&1; then
      echo "Downloading backup file for database $ORIG_NAME..."
      ossutil cp $BACKUP_FILE_PATH /tmp/${ORIG_NAME}.gz
      if mongo -u $MONGO_INITDB_ROOT_USERNAME -p $MONGO_INITDB_ROOT_PASSWORD $NEW_NAME --eval "db.stats()" >/dev/null 2>&1; then
        echo "Database $NEW_NAME exists, skipping."
      else
        echo "Restoring database $ORIG_NAME as $NEW_NAME..."
        mongorestore -u $MONGO_INITDB_ROOT_USERNAME -p $MONGO_INITDB_ROOT_PASSWORD --gzip --archive=/tmp/${ORIG_NAME}.gz --nsFrom="${ORIG_NAME}.*" --nsTo="${NEW_NAME}.*"
        echo "Database $ORIG_NAME restored as $NEW_NAME."
      fi
    else
      echo "Backup file for database $ORIG_NAME not found."
    fi
  done
fi

echo "Restoration completed."
