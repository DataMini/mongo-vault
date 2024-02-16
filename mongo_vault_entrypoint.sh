#!/bin/bash

# 定义日志前缀
LOG_PREFIX="[MongoVaultMain]"

# 定义带前缀的日志函数
log() {
    # 获取当前时间，格式为 YYYY-MM-DD HH:MM:SS
    local current_time=$(date "+%Y-%m-%d %H:%M:%S")
    # 输出日志，包含时间戳和日志前缀
    echo "$current_time $LOG_PREFIX $@"
}



log "Starting mongo_vault_entrypoint..."
set -e

# 启动 MongoDB 服务
log "Starting MongoDB service..."
docker-entrypoint.sh mongod &
MONGO_PID=$!
log "MongoDB service started."


# 配置自动备份
if [ "$ENABLE_MONGO_VAULT_BACKUP" = "true" ]; then
    # 保存env
    printenv > /etc/environment
    log "Backup mode is enable, configuring cron job..."
    echo "$MONGO_VAULT_BACKUP_SCHEDULE bash -c 'source /etc/environment; /usr/local/bin/mongo_vault_backup' >> /mongo_vault_backup.log 2>&1" > /crontab.conf
    crontab /crontab.conf
    log "Cron job configured."
    cron &
    touch /mongo_vault_backup.log ; tail -f /mongo_vault_backup.log &
    log "Cron service started. Backup schedule is $MONGO_VAULT_BACKUP_SCHEDULE."
else
    log "Backup mode is disable."
fi

# 检查是否启用了恢复模式
if [ "$ENABLE_MONGO_VAULT_RESTORE" = "true" ]; then
    # 等待 MongoDB 完全启动
    log "Restore mode is enable, waiting for MongoDB to start..."
    sleep 15
    log "Restoring databases..."
    /usr/local/bin/mongo_vault_restore
    log "Restoration completed."
else
    log "Restore mode is disable."
fi

# 等待 MongoDB 进程
wait $MONGO_PID
