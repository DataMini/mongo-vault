#!/bin/bash
set -e

# 启动 MongoDB 服务
docker-entrypoint.sh mongod &

MONGO_PID=$!

# 配置自动备份
if [ "$ENABLE_MONGO2OSS_BACKUP" = "true" ]; then
    (crontab -l 2>/dev/null; echo "$MONGO2OSS_BACKUP_SCHEDULE /usr/local/bin/mongo2oss_backup") | crontab -
    cron -f &
fi

# 检查是否启用了恢复模式
if [ "$ENABLE_MONGO2OSS_RESTORE" = "true" ]; then
    # 等待 MongoDB 完全启动
    sleep 10
    /usr/local/bin/mongo2oss_restore
fi

# 等待 MongoDB 进程
wait $MONGO_PID
