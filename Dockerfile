# 使用mongo:5.0.22作为基础镜像
FROM mongo:5.0.22

# 安装必要的工具
RUN apt-get update && apt-get install -y cron python3 python3-pip && \
    pip3 install oss2

# 将备份脚本和恢复脚本添加到容器中
COPY mongo2oss_backup.sh /usr/local/bin/mongo2oss_backup
COPY mongo2oss_restore.sh /usr/local/bin/mongo2oss_restore
COPY mongo2oss_entrypoint.sh /usr/local/bin/mongo2oss_entrypoint

# 使脚本可执行
RUN chmod +x /usr/local/bin/mongo2oss_backup && \
    chmod +x /usr/local/bin/mongo2oss_restore && \
    chmod +x /usr/local/bin/mongo2oss_entrypoint

# 设置环境变量
ENV ENABLE_MONGO2OSS_BACKUP=false \
    MONGO2OSS_BACKUP_DATABASES=test \
    MONGO2OSS_BACKUP_SCHEDULE="0 3 * * *" \
    MONGO2OSS_OSS_AK=yourAccessKeyId \
    MONGO2OSS_OSS_SK=yourAccessKeySecret \
    MONGO2OSS_OSS_ENDPOINT=yourEndpoint \
    MONGO2OSS_OSS_BUCKET=yourBucketName \
    MONGO2OSS_OSS_URI_PREFIX=yourUriPrefix \
    ENABLE_MONGO2OSS_RESTORE=false \
    MONGO2OSS_RESTORE_DATABASES=test

# 容器启动时执行的命令
ENTRYPOINT ["mongo2oss_entrypoint"]
