# MongoVault（带有自动备份和恢复功能的 MongoDB 镜像）
本文档介绍如何使用 `datamini/mongo-vault` 镜像运行 MongoDB 数据库，并同时自动化备份数据到阿里云 OSS，以及如何从备份中恢复数据。

该镜像基于 mongo:5.0.22。


## 功能1. 运行一个新的MongoDB，自动在每天3点备份并保存到云端

使用以下命令：

```bash
docker run -d \
  --name mongo_vault_instance \
  -e MONGO_INITDB_ROOT_USERNAME=datamini \
  -e MONGO_INITDB_ROOT_PASSWORD=1234 \
  -e ENABLE_MONGO_VAULT_BACKUP=true \
  -e MONGO_VAULT_BACKUP_DATABASES="db1,db2" \
  -e MONGO_VAULT_BACKUP_SCHEDULE="0 3 * * *" \
  -e MONGO_VAULT_OSS_AK=yourAccessKeyId \
  -e MONGO_VAULT_OSS_SK=yourAccessKeySecret \
  -e MONGO_VAULT_OSS_ENDPOINT=yourOssEndpoint \
  -e MONGO_VAULT_OSS_BUCKET=yourBucketName \
  -e MONGO_VAULT_OSS_URI_PREFIX=yourUriPrefix \
  datamini/mongo-vault
```

或者使用如下的 `docker-compose.yml` 文件运行一个MongoDB实例：

```yaml
version: '3.8'
services:
  mongo_vault_instance:
    image: datamini/mongo-vault
    environment:
      MONGO_INITDB_ROOT_USERNAME: datamini
      MONGO_INITDB_ROOT_PASSWORD: 1234
      ENABLE_MONGO_VAULT_BACKUP: "true"
      MONGO_VAULT_BACKUP_DATABASES: "db1,db2"
      MONGO_VAULT_BACKUP_SCHEDULE: "0 3 * * *"
      MONGO_VAULT_OSS_AK: yourAccessKeyId
      MONGO_VAULT_OSS_SK: yourAccessKeySecret
      MONGO_VAULT_OSS_ENDPOINT: yourOssEndpoint
      MONGO_VAULT_OSS_BUCKET: yourBucketName
      MONGO_VAULT_OSS_URI_PREFIX: yourUriPrefix
```

注意：
1. `ENABLE_MONGO_VAULT_BACKUP` 为true，意味着将打开数据库的自动备份。
2. `MONGO_VAULT_BACKUP_DATABASES` 为需要备份的数据库列表，以`,`分隔。
3. `MONGO_VAULT_BACKUP_SCHEDULE` 为备份任务的定时规则，使用Cron表达式。
4. `MONGO_VAULT_OSS_AK`、`MONGO_VAULT_OSS_SK`、`MONGO_VAULT_OSS_ENDPOINT`、`MONGO_VAULT_OSS_BUCKET`、`MONGO_VAULT_OSS_URI_PREFIX` 为阿里云OSS的相关配置。
5. 备份文件在OSS中的目录结构为：`MONGO_VAULT_OSS_URI_PREFIX/2024-02/20240201033000/`。
6. `MONGO_INITDB_ROOT_USERNAME` 和 `MONGO_INITDB_ROOT_PASSWORD` 为MongoDB的root用户的用户名和密码。继承自mongo官方镜像，使用说明参考 [https://hub.docker.com/_/mongo](https://hub.docker.com/_/mongo)

## 功能2. 使用最新的备份文件来创建并运行一个新的MongoDB

使用以下命令：

```bash
docker run -d \
  --name mongodb_restored \
  -e MONGO_INITDB_ROOT_USERNAME=datamini \
  -e MONGO_INITDB_ROOT_PASSWORD=1234 \
  -e ENABLE_MONGO_VAULT_RESTORE=true \
  -e MONGO_VAULT_RESTORE_DATABASES="db1,db2" \
  -e MONGO_VAULT_OSS_AK=yourAccessKeyId \
  -e MONGO_VAULT_OSS_SK=yourAccessKeySecret \
  -e MONGO_VAULT_OSS_ENDPOINT=yourOssEndpoint \
  -e MONGO_VAULT_OSS_BUCKET=yourBucketName \
  -e MONGO_VAULT_OSS_URI_PREFIX=yourUriPrefix \
  datamini/mongo-vault
```

或者使用如下的 `docker-compose.yml` 文件运行一个MongoDB实例：

```yaml
version: '3.8'
services:
  mongodb_restored:
    image: datamini/mongo-vault
    environment:
      MONGO_INITDB_ROOT_USERNAME: datamini
      MONGO_INITDB_ROOT_PASSWORD: 1234
      ENABLE_MONGO_VAULT_RESTORE: "true"
      MONGO_VAULT_RESTORE_DATABASES: "db1,db2"
      MONGO_VAULT_OSS_AK: yourAccessKeyId
      MONGO_VAULT_OSS_SK: yourAccessKeySecret
      MONGO_VAULT_OSS_ENDPOINT: yourOssEndpoint
      MONGO_VAULT_OSS_BUCKET: yourBucketName
      MONGO_VAULT_OSS_URI_PREFIX: yourUriPrefix
```

注意：
1. `ENABLE_MONGO_VAULT_RESTORE`为true，意味着以恢复模式启动新的数据库实例，启动之后立刻开始恢复数据。
2. `MONGO_VAULT_RESTORE_DATABASES` 若为空，则默认恢复最近一次备份中的全部DB，但会跳过已经存在的DB。 

## 功能3. 将某个数据库的最新备份恢复到一个正在运行的MongoDB中，并更改数据库名

使用以下命令：

```bash
docker exec -it mongo_vault_instance mongo_vault_restore --databases=db1:newdb1,db2:newdb2 
```

这里，`--databases` 是一个以`,`分隔的数据库列表，每个数据库的原名和新名用`:`分隔（如果不需要改名，则只需给出原名）。

如果没有指定 `--databases` 参数，将使用 `MONGO_VAULT_RESTORE_DATABASES` 环境变量的值。如果都没有，则默认恢复全部的DB到该实例，但会跳过已存在的DB。


# 注意事项
- 备份时，请根据实际需求调整MONGO_VAULT_BACKUP_DATABASES 和 MONGO_VAULT_BACKUP_SCHEDULE
- 恢复时，请确认是恢复出一个新的实例，还是将数据恢复到现有实例中的新的DB


通过遵循上述步骤，您可以轻松地管理MongoDB的备份和恢复任务，确保数据的安全性和可用性。
