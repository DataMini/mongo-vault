#!/bin/bash
# MongoDB 恢复脚本：从最后一次备份中恢复指定的数据库

# 检查必要的环境变量
if [ -z "$MONGO2OSS_OSS_AK" ] || [ -z "$MONGO2OSS_OSS_SK" ] || [ -z "$MONGO2OSS_OSS_BUCKET" ] || [ -z "$MONGO2OSS_OSS_URI_PREFIX" ] || [ -z "$MONGO2OSS_OSS_ENDPOINT" ]; then
  echo "One or more environment variables required for restoration are missing."
  exit 1
fi

# 配置 OSS 工具
ossutil64 config -e $MONGO2OSS_OSS_ENDPOINT -i $MONGO2OSS_OSS_AK -k $MONGO2OSS_OSS_SK

# 查找最新的月份目录
LATEST_MONTH_DIR=$(ossutil64 ls oss://$MONGO2OSS_OSS_BUCKET/$MONGO2OSS_OSS_URI_PREFIX/ | awk '{print $NF}' | sort -r | head -n 1)

# 在最新的月份目录中查找最新的备份目录
LATEST_BACKUP_DIR=$(ossutil64 ls $LATEST_MONTH_DIR | awk '{print $NF}' | sort -r | head -n 1)

# 解析需要恢复的数据库列表
DB_MAP="$1"
[ -z "$DB_MAP" ] && DB_MAP=$MONGO2OSS_RESTORE_DATABASES

# 恢复数据库
if [ -z "$DB_MAP" ]; then
  # 没有指定数据库，恢复该备份目录下的所有数据库
  ossutil64 cp -r $LATEST_BACKUP_DIR /tmp/mongo2oss_restore/ --include "*.gz"
  for BACKUP_FILE in /tmp/mongo2oss_restore/*.gz; do
    DB_NAME=$(basename $BACKUP_FILE .gz)
    if mongo $DB_NAME --eval "db.stats()" >/dev/null 2>&1; then
      echo "Database $DB_NAME exists, skipping."
    else
      mongorestore --gzip --archive=$BACKUP_FILE
    fi
  done
else
  # 恢复指定的数据库
  IFS=',' read -ra DB_NAMES <<< "$DB_MAP"
  for DB_NAME in "${DB_NAMES[@]}"; do
    BACKUP_FILE_PATH="$LATEST_BACKUP_DIR/${DB_NAME}.gz"
    if ossutil64 stat $BACKUP_FILE_PATH >/dev/null 2>&1; then
      ossutil64 cp $BACKUP_FILE_PATH /tmp/${DB_NAME}.gz
      mongorestore --gzip --archive=/tmp/${DB_NAME}.gz
    else
      echo "Backup file for database $DB_NAME not found."
    fi
  done
fi

echo "Restoration completed."
