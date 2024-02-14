#!/bin/bash
set -e

# 启动 MongoDB 服务
echo "Starting MongoDB service..."
docker-entrypoint.sh mongod &
echo "MongoDB service started."

MONGO_PID=$!

# 配置自动备份
if [ "$ENABLE_MONGO_VAULT_BACKUP" = "true" ]; then
    echo "Backup mode is enable, configuring cron job..."
    (crontab -l 2>/dev/null; echo "$MONGO_VAULT_BACKUP_SCHEDULE /usr/local/bin/mongo_vault_backup") | crontab -
    echo "Cron job configured."
    cron -f &
    echo "Cron service started."
else
    echo "Backup mode is disable."
fi

# 检查是否启用了恢复模式
if [ "$ENABLE_MONGO_VAULT_RESTORE" = "true" ]; then
    # 等待 MongoDB 完全启动
    echo "Restore mode is enable, waiting for MongoDB to start..."
    sleep 10
    echo "Restoring databases..."
    /usr/local/bin/mongo_vault_restore
    echo "Restoration completed."
else
    echo "Restore mode is disable."
fi

# 等待 MongoDB 进程
wait $MONGO_PID
