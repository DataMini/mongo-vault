#!/bin/bash
# 列出最近一个月备份文件的脚本

# 检查必要的环境变量
if [ -z "$MONGO_VAULT_OSS_AK" ] || [ -z "$MONGO_VAULT_OSS_SK" ] || [ -z "$MONGO_VAULT_OSS_BUCKET" ] || [ -z "$MONGO_VAULT_OSS_URI_PREFIX" ] || [ -z "$MONGO_VAULT_OSS_ENDPOINT" ]; then
  echo "One or more environment variables required for listing backups are missing."
  exit 1
fi

# 配置 OSS 工具
ossutil config -e $MONGO_VAULT_OSS_ENDPOINT -i $MONGO_VAULT_OSS_AK -k $MONGO_VAULT_OSS_SK

# 计算当前月份和上一个月份
CURRENT_MONTH=$(date +%Y-%m)
LAST_MONTH=$(date +%Y-%m --date="1 month ago")

# 列出上一个月份
echo "Listing backups for $LAST_MONTH..."
ossutil ls oss://$MONGO_VAULT_OSS_BUCKET/$MONGO_VAULT_OSS_URI_PREFIX/$LAST_MONTH/ |grep oss | awk '{print $1,$2,$8}'

# 列出当前月份
echo "Listing backups for $CURRENT_MONTH..."
ossutil ls oss://$MONGO_VAULT_OSS_BUCKET/$MONGO_VAULT_OSS_URI_PREFIX/$CURRENT_MONTH/ |grep oss | awk '{print $1,$2,$8}'

echo "Backup listing completed."
