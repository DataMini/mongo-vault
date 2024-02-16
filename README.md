# MongoVault（带有自动备份和恢复功能的 MongoDB 镜像）

本文档介绍如何使用 `datamini/mongo-vault` 运行 MongoDB 数据库进行自动备份和恢复。备份文件支持保存在Cloud Storage中，目前支持阿里云OSS。

优势：
1. 省钱。阿里云上最便宜的MongoDB，一个月要1800元。
2. 省事。Docker运行MongoDB简单，但数据没备份心慌慌。这个镜像可以自动帮你完成备份，只需要设置备份的频率、OSS的Bucket即可。
3. 功能虽然谈不上丰富，但简单、完整、够用。数据库和备份恢复工具集成到一个镜像里。
   您可以：
   - 拉起MongoDB实例的时候开启自动备份
   - 拉起MongoDB实例的时候按照要求恢复数据
   - 拉起MongoDB实例的时候先恢复数据，同时开启自动备份
   - 随时手动查看备份的文件列表（进入容器）
   - 随时手动恢复数据（进入容器）

该镜像基于 mongo:5.0.22。


# QuickStart

1. 运行一个可以自动备份的MongoDB实例

    ```bash
    docker run -d \
      --name mongo_vault_instance \
      -e ENABLE_MONGO_VAULT_BACKUP=true \
      -e MONGO_VAULT_OSS_AK=LTAENx0nrenExlYsTspz2 \
      -e MONGO_VAULT_OSS_SK=nFewnENWONDssofnwen1oX \
      -e MONGO_VAULT_OSS_ENDPOINT=oss-cn-shenzhen-internal.aliyuncs.com \
      datamini/mongo-vault
    ```

2. 查看备份列表

    进入MongoDB所在的容器执行命令`mongo_vault_list_backup`进行查看。
    
    ```bash
    docker exec -it mongo_vault_instance mongo_vault_list_backup
    ```

3. 使用最新的备份恢复出来一个新的MongoDB实例

    ```bash
    docker run -d \
      --name mongo_vault_restored_instance \
      -e ENABLE_MONGO_VAULT_RESTORE=true \
      -e MONGO_VAULT_OSS_AK=LTAENx0nrenExlYsTspz2 \
      -e MONGO_VAULT_OSS_SK=nFewnENWONDssofnwen1oX \
      -e MONGO_VAULT_OSS_ENDPOINT=oss-cn-shenzhen-internal.aliyuncs.com \
      datamini/mongo-vault
    ```

4. 将 `db1` 的最新备份恢复到一个正在运行的MongoDB中，并改名为 `newdb1`

    ```bash
    docker exec -it mongo_vault_instance mongo_vault_restore --databases=db1:newdb1
    ```
    这里，`--databases` 同环境变量 `MONGO_VAULT_RESTORE_DATABASES`，且优先级更高。

# 参数说明


| 参数名称 | 描述                                                                                                                                     | 默认              | 是否必需 |
|----------|----------------------------------------------------------------------------------------------------------------------------------------|-----------------|------|
| `MONGO_INITDB_ROOT_USERNAME` | MongoDB的root用户的用户名。继承 mongo 镜像                                                                                                         | ""               | 否    |
| `MONGO_INITDB_ROOT_PASSWORD` | MongoDB的root用户的密码。 继承 mongo 镜像                                                                                                             |  ""               | 否    |
| `ENABLE_MONGO_VAULT_BACKUP` | 是否启用自动备份功能。  true或false。                                                                                                               | false           | 否    |
| `MONGO_VAULT_BACKUP_DATABASES` | 需要备份的数据库列表，以`,`分隔。                                                                                                                     | 备份所有数据库         | 否    |
| `MONGO_VAULT_BACKUP_SCHEDULE` | 备份任务的Cron表达式。                                                                                                                          | 0 3 * * * （每天3点） | 否    |
| `ENABLE_MONGO_VAULT_RESTORE` | 是否以恢复模式启动数据库实例，运行数据库之后立刻开始恢复数据。    true或false。                                                                                         | false           | 否    |
| `MONGO_VAULT_RESTORE_DATABASES` | 需要恢复的数据库列表，以`,`分隔；数据库的原名和新名用`:`分隔；如（db1:newdb1,db2:newdb2)。若未提供新名，则直接用原名恢复。默认恢复所有数据库。为避免数据被覆盖，MongoVault会跳过已经存在的DB，因此强烈建议在恢复时指定新的数据库名。 | 恢复所有数据库         | 否    |
| `MONGO_VAULT_OSS_AK` | 阿里云OSS的AccessKeyId。                                                                                                                    | ""              | 是    |
| `MONGO_VAULT_OSS_SK` | 阿里云OSS的AccessKeySecret。                                                                                                                | ""              | 是    |
| `MONGO_VAULT_OSS_ENDPOINT` | 阿里云OSS的Endpoint。                                                                                                                       | ""              | 是    |
| `MONGO_VAULT_OSS_BUCKET` | 阿里云OSS的Bucket名称。                                                                                                                       | mongo_backups   | 否    |
| `MONGO_VAULT_OSS_URI_PREFIX` | OSS中备份文件的存储前缀。备份文件在OSS中的目录结构为：`MONGO_VAULT_OSS_URI_PREFIX/2024-02/20240201033000/`。                                                    | backups_my_db01 | 否    |
| `TZ` | 时区。                                                                                                                                    | Asia/Shanghai   | 否    |


**注意事项**
  - 备份时，请根据实际需求调整 `MONGO_VAULT_BACKUP_DATABASES` 和 `MONGO_VAULT_BACKUP_SCHEDULE`
  - 恢复时，请确认是`恢复出一个新的实例`，还是将数据`恢复到现有实例中的新的DB`


# 示例

使用最新的备份恢复出来一个新的MongoDB实例，并开启自动备份
    
```bash
docker run -d \
  --name mongodb_restored \
  -e MONGO_INITDB_ROOT_USERNAME=admin \
  -e MONGO_INITDB_ROOT_PASSWORD=1234 \
  -e ENABLE_MONGO_VAULT_BACKUP=true \
  -e MONGO_VAULT_BACKUP_DATABASES="db1,db2" \
  -e MONGO_VAULT_BACKUP_SCHEDULE="0 3 * * *" \
  -e ENABLE_MONGO_VAULT_RESTORE=true \
  -e MONGO_VAULT_RESTORE_DATABASES="db1,db2" \
  -e MONGO_VAULT_OSS_AK=LTAENx0nrenExlYsTspz2 \
  -e MONGO_VAULT_OSS_SK=nFewnENWONDssofnwen1oX \
  -e MONGO_VAULT_OSS_ENDPOINT=oss-cn-shenzhen-internal.aliyuncs.com \
  -e MONGO_VAULT_OSS_BUCKET=mongo_backups \
  -e MONGO_VAULT_OSS_URI_PREFIX=my_user_db_prod \
  datamini/mongo-vault
```

或者使用如下的 `docker-compose.yml` 文件运行：

```yaml
services:
  mongodb_restored:
    image: datamini/mongo-vault
    environment:
      MONGO_INITDB_ROOT_USERNAME: admin
      MONGO_INITDB_ROOT_PASSWORD: 1234
      ENABLE_MONGO_VAULT_BACKUP: "true"
      MONGO_VAULT_BACKUP_DATABASES: db1,db2
      MONGO_VAULT_BACKUP_SCHEDULE: "0 3 * * *"
      ENABLE_MONGO_VAULT_RESTORE: "true"
      MONGO_VAULT_RESTORE_DATABASES: db1,db2
      MONGO_VAULT_OSS_AK: LTAENx0nrenExlYsTspz2
      MONGO_VAULT_OSS_SK: nFewnENWONDssofnwen1oX
      MONGO_VAULT_OSS_ENDPOINT: oss-cn-shenzhen-internal.aliyuncs.com
      MONGO_VAULT_OSS_BUCKET: mongo_backups
      MONGO_VAULT_OSS_URI_PREFIX: my_user_db_prod
```
