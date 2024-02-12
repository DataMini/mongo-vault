#!/bin/bash
# MongoDB 备份脚本：为每个数据库创建单独的备份文件

# 检查必要的环境变量
if [ -z "$MONGO_VAULT_OSS_AK" ] || [ -z "$MONGO_VAULT_OSS_SK" ] || [ -z "$MONGO_VAULT_OSS_BUCKET" ] || [ -z "$MONGO_VAULT_OSS_URI_PREFIX" ] || [ -z "$MONGO_VAULT_OSS_ENDPOINT" ]; then
  echo "One or more environment variables required for backup are missing."
  exit 1
fi

# 配置 OSS 工具
ossutil64 config -e $MONGO_VAULT_OSS_ENDPOINT -i $MONGO_VAULT_OSS_AK -k $MONGO_VAULT_OSS_SK

# 定义备份目录
CURRENT_MONTH=$(date +%Y-%m)
CURRENT_TIME=$(date +%Y%m%d%H%M%S)
BACKUP_PATH="$MONGO_VAULT_OSS_URI_PREFIX/$CURRENT_MONTH/$CURRENT_TIME"

# 获取所有数据库列表或使用指定的数据库
if [ -z "$MONGO_VAULT_BACKUP_DATABASES" ]; then
  DATABASES=$(mongo --quiet --eval "db.adminCommand('listDatabases').databases.map(db => db.name).join(' ')")
else
  DATABASES=$(echo $MONGO_VAULT_BACKUP_DATABASES | tr ',' ' ')
fi

# 为每个数据库执行备份
for DB in $DATABASES; do
  mongodump --db $DB --archive --gzip | ossutil64 cp - oss://$MONGO_VAULT_OSS_BUCKET/$BACKUP_PATH/${DB}.gz
done

echo "Backup completed. Files are stored in $BACKUP_PATH."
