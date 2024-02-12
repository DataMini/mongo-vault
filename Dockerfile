# 使用mongo:5.0.22作为基础镜像
FROM mongo:5.0.22

# 安装必要的工具
RUN apt-get update && apt-get install -y cron python3 python3-pip && \
    pip3 install oss2

# 将备份脚本和恢复脚本添加到容器中
COPY mongo_vault_backup.sh /usr/local/bin/mongo_vault_backup
COPY mongo_vault_restore.sh /usr/local/bin/mongo_vault_restore
COPY mongo_vault_entrypoint.sh /usr/local/bin/mongo_vault_entrypoint

# 使脚本可执行
RUN chmod +x /usr/local/bin/mongo_vault_backup && \
    chmod +x /usr/local/bin/mongo_vault_restore && \
    chmod +x /usr/local/bin/mongo_vault_entrypoint

# 设置环境变量
ENV ENABLE_MONGO_VAULT_BACKUP=false \
    MONGO_VAULT_BACKUP_DATABASES=test \
    MONGO_VAULT_BACKUP_SCHEDULE="0 3 * * *" \
    MONGO_VAULT_OSS_AK=yourAccessKeyId \
    MONGO_VAULT_OSS_SK=yourAccessKeySecret \
    MONGO_VAULT_OSS_ENDPOINT=yourEndpoint \
    MONGO_VAULT_OSS_BUCKET=yourBucketName \
    MONGO_VAULT_OSS_URI_PREFIX=yourUriPrefix \
    ENABLE_MONGO_VAULT_RESTORE=false \
    MONGO_VAULT_RESTORE_DATABASES=test

# 容器启动时执行的命令
ENTRYPOINT ["mongo_vault_entrypoint"]
