#!/bin/bash
# MongoDB 备份脚本：为每个数据库创建单独的备份文件

# 检查必要的环境变量
if [ -z "$MONGO_VAULT_OSS_AK" ] || [ -z "$MONGO_VAULT_OSS_SK" ] || [ -z "$MONGO_VAULT_OSS_BUCKET" ] || [ -z "$MONGO_VAULT_OSS_URI_PREFIX" ] || [ -z "$MONGO_VAULT_OSS_ENDPOINT" ]; then
  echo "One or more environment variables required for backup are missing."
  exit 1
fi

# 配置 OSS 工具
echo "Configuring OSS tool..."
ossutil config -e $MONGO_VAULT_OSS_ENDPOINT -i $MONGO_VAULT_OSS_AK -k $MONGO_VAULT_OSS_SK

# 定义备份目录
CURRENT_MONTH=$(date +%Y-%m)
CURRENT_TIME=$(date +%Y%m%d%H%M%S)
BACKUP_PATH="$MONGO_VAULT_OSS_URI_PREFIX/$CURRENT_MONTH/$CURRENT_TIME"
echo "Backup path is $BACKUP_PATH."

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

# 获取所有数据库列表或使用指定的数据库
if [ -z "$MONGO_VAULT_BACKUP_DATABASES" ]; then
  DATABASES=$(mongo --quiet -u $MONGO_INITDB_ROOT_USERNAME -p $MONGO_INITDB_ROOT_PASSWORD --authenticationDatabase admin --eval "db.getMongo().getDBNames().join(' ');" | tail -n1)
  echo "No databases specified, backing up all databases. Found databases: $DATABASES"
else
  echo "Backing up specified databases: $MONGO_VAULT_BACKUP_DATABASES"
  DATABASES=$(echo $MONGO_VAULT_BACKUP_DATABASES | tr ',' ' ')
fi

# 为每个数据库执行备份
for DB in $DATABASES; do
  if should_skip "$DB"; then
    echo "Skipping backup for database $DB."
    continue
  fi

  echo "Backing up database $DB..."
  mongodump -u $MONGO_INITDB_ROOT_USERNAME -p $MONGO_INITDB_ROOT_PASSWORD --authenticationDatabase admin --db $DB --archive=$TEMP_BACKUP_DIR/${DB}.gz --gzip

  # mongodump -u $MONGO_INITDB_ROOT_USERNAME -p $MONGO_INITDB_ROOT_PASSWORD --authenticationDatabase admin --db $DB --archive --gzip | ossutil cp - oss://$MONGO_VAULT_OSS_BUCKET/$BACKUP_PATH/${DB}.gz
  # 检查备份操作是否成功
  if [ $? -eq 0 ]; then
    echo "MongoDB backup for database $DB completed successfully."

    # 使用 ossutil 将备份文件上传到 OSS
    ossutil cp $TEMP_BACKUP_DIR/${DB}.gz oss://$MONGO_VAULT_OSS_BUCKET/$BACKUP_PATH/${DB}.gz

    # 检查上传操作是否成功
    if [ $? -eq 0 ]; then
      echo "Backup file uploaded to OSS successfully."
    else
      echo "Failed to upload backup file to OSS."
    fi

    # 删除临时备份文件
    rm $TEMP_BACKUP_DIR/${DB}.gz
  else
    echo "Failed to backup MongoDB database $DB ."
  fi
done

echo "Backup completed. Files are stored in $BACKUP_PATH."
