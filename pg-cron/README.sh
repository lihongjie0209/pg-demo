# pg-cron

## 启动

```
docker compose up -d
```

## 停止

```
docker compose down
```


## 插件管理

```

postgres-# CREATE EXTENSION pg_cron;  # 安装pg_cron, 默认情况下安装在postgres数据库中， 而且只能安装在一个数据库中



# 查看pg_cron插件的表

postgres-# \dt cron.*
              List of relations
 Schema |      Name       | Type  |  Owner   
--------+-----------------+-------+----------
 cron   | job             | table | postgres
 cron   | job_run_details | table | postgres
(2 rows)


```


## 测试定时任务

```

CREATE TABLE IF NOT EXISTS test_cron (
    id SERIAL PRIMARY KEY,
    execution_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

SELECT cron.schedule(
    'test_every_10min',                           -- 任务名称
    '*/10 * * * * *',                          -- cron表达式（每10分钟）
    $$INSERT INTO test_cron(execution_time) VALUES (CURRENT_TIMESTAMP)$$  -- 要执行的SQL
);


SELECT * FROM cron.job;

SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 5;


SELECT cron.unschedule('test_every_10min');

```