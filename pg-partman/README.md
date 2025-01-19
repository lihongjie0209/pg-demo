# PostgreSQL 分区表管理工具 (pg_partman)

pg_partman 是一个 PostgreSQL 扩展，用于简化表分区的创建和管理。

## 快速开始

### 启动服务
```bash
docker compose up -d
```

### 停止服务
```bash
docker compose down
```

## 使用说明

### 1. 创建扩展
```sql
CREATE SCHEMA partman;
CREATE EXTENSION pg_partman SCHEMA partman;
```

### 2. 创建分区表示例

#### 按时间分区
```sql
-- 创建主表
CREATE TABLE measurements (
    id          bigint NOT NULL,
    measure_ts  timestamp NOT NULL,
    value       float NOT NULL
) PARTITION BY RANGE (measure_ts);

-- 使用 pg_partman 创建分区
SELECT partman.create_parent(
    p_parent_table => 'public.measurements',
    p_control => 'measure_ts',
    p_type => 'range',
    p_interval => '1 day',
    p_premake => 7
);
```

#### 按范围分区
```sql
-- 创建主表
CREATE TABLE sales (
    id          bigint NOT NULL,
    amount      numeric NOT NULL,
    sale_date   date NOT NULL
) PARTITION BY RANGE (amount);

-- 使用 pg_partman 创建分区
SELECT partman.create_parent(
    p_parent_table => 'public.sales',
    p_control => 'amount',
    p_type => 'range',
    p_interval => '1000',
    p_premake => 4
);
```

### 3. 启用自动维护
```sql
-- 配置自动维护作业
UPDATE partman.part_config 
SET infinite_time_partitions = true,
    retention = '3 months',
    retention_keep_table = false
WHERE parent_table = 'public.measurements';

-- 运行维护
SELECT partman.run_maintenance();
```

## 重要参数说明

- `p_interval`: 分区间隔，使用 PostgreSQL 标准 interval 语法
  - 时间间隔示例：'1 hour', '1 day', '1 week', '1 month', '1 year'
  - 数值间隔示例：'1000', '10000'
- `p_type`: 分区类型，使用 'range' 表示范围分区
- `p_premake`: 预创建的分区数量
- `retention`: 数据保留时间
- `infinite_time_partitions`: 是否无限创建新分区

## 常用维护命令

```sql
-- 查看分区配置
SELECT * FROM partman.show_partitions('public.measurements');

-- 手动创建新分区
SELECT partman.create_partition_time('public.measurements');

-- 删除旧分区
SELECT partman.drop_partition_time('public.measurements');

-- 查看分区信息
SELECT partman.show_partition_info('public.measurements');
```

## 注意事项

1. 确保已在 postgresql.conf 中设置 `shared_preload_libraries = 'pg_partman_bgw'`
2. 分区表创建后，需要定期运行维护命令或启用自动维护
3. 合理设置数据保留策略，避免存储空间耗尽
4. 建议在创建分区表前，先评估数据量和增长速度
5. 时间间隔必须使用 PostgreSQL 标准的 interval 语法，例如 '1 day' 而不是 'daily'

## 高级特性

### 模板表使用

模板表可以预定义分区的结构和索引，提高分区管理效率。

```sql
-- 创建模板表
CREATE TABLE measurements_template (
    LIKE measurements INCLUDING ALL
);

-- 在模板表上创建索引
CREATE INDEX idx_template_ts ON measurements_template(measure_ts);
CREATE INDEX idx_template_value ON measurements_template(value);

-- 使用模板表创建分区
SELECT partman.create_parent(
    p_parent_table => 'public.measurements',
    p_control => 'measure_ts',
    p_type => 'range',
    p_interval => '1 day',
    p_premake => 7,
    p_template_table => 'public.measurements_template'
);
```

#### 模板表特性

1. 继承所有属性：
   - 列定义
   - 约束
   - 索引
   - 存储参数

2. 优势：
   - 统一管理分区表结构
   - 自动应用索引到新分区
   - 减少手动维护工作
   - 提高分区创建效率

### 同步机制配置

```sql
-- 配置自动维护作业
UPDATE partman.part_config SET 
    -- 启用无限分区创建
    infinite_time_partitions = true,
    -- 设置数据保留期限
    retention = '3 months',
    -- 删除旧分区时是否保留表
    retention_keep_table = false,
    -- 自动创建新分区的提前时间
    premake = 7,
    -- 是否自动删除旧分区
    automatic_maintenance = 'on',
    -- 维护作业间隔
    maintenance_interval = '1 hour'
WHERE parent_table = 'public.measurements';
```

#### 监控分区状态
```sql
-- 查看分区配置
SELECT parent_table, control, partition_interval, 
       premake, automatic_maintenance
FROM partman.part_config;

-- 查看分区使用情况
SELECT schemaname, tablename, 
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size,
       pg_stat_get_numscans(schemaname||'.'||tablename::regclass) as number_of_scans
FROM partman.show_partitions('public.measurements');
```

#### 同步机制说明

1. 自动维护：
   - 预创建新分区
   - 删除过期分区
   - 定期运行维护任务

2. 维护任务：
   - 由 background worker 执行
   - 按 maintenance_interval 间隔运行
   - 处理所有启用了自动维护的分区表

3. 监控和调优：
   - 通过 pg_stat_activity 查看维护任务
   - 调整 maintenance_interval 避免资源竞争
   - 监控分区大小和数量

### 高级参数说明

- `p_template_table`: 模板表名，用于定义新分区的结构和索引
- `maintenance_interval`: 维护作业运行间隔
- `automatic_maintenance`: 是否启用自动维护
- `retention_keep_table`: 删除分区时是否保留表结构

### 高级功能注意事项

1. 使用模板表时，修改模板表不会影响已存在的分区
2. 自动维护任务可能会影响数据库性能，建议在低峰期运行
3. 维护间隔设置需要考虑数据增长速度和系统负载
4. 建议定期检查维护任务的执行状态和效果
5. 模板表的索引会影响新分区创建的性能

### 模板表同步

当需要修改原始表结构时，需要同步更改到模板表以确保新分区包含这些更改。

```sql
-- 1. 修改原始表
ALTER TABLE measurements ADD COLUMN description text;
ALTER TABLE measurements ALTER COLUMN value TYPE double precision;
CREATE INDEX idx_measure_desc ON measurements(description);

-- 2. 同步到模板表
ALTER TABLE measurements_template ADD COLUMN description text;
ALTER TABLE measurements_template ALTER COLUMN value TYPE double precision;
CREATE INDEX idx_measure_desc ON measurements_template(description);

-- 3. 更新分区配置使用新模板
UPDATE partman.part_config 
SET template_table = 'public.measurements_template'
WHERE parent_table = 'public.measurements';

-- 4. 运行维护以应用更改
SELECT partman.run_maintenance();
```

#### 同步注意事项

1. 顺序要求：
   - 先修改原始表
   - 然后同步到模板表
   - 最后更新分区配置

2. 现有分区：
   - 模板表的更改不会自动应用到现有分区
   - 需要手动更新现有分区
   ```sql
   -- 更新现有分区
   SELECT partman.apply_template_to_children(
       p_parent_table => 'public.measurements',
       p_include_indexes => true
   );
   ```

3. 索引同步：
   - 新索引需要在模板表上创建
   - 可以使用 apply_template_to_children 同步到现有分区
   - 注意大表添加索引可能需要较长时间

4. 约束同步：
   - 约束需要同时在原始表和模板表上添加
   - 确保约束名称在所有分区中唯一
   ```sql
   -- 添加约束示例
   ALTER TABLE measurements 
   ADD CONSTRAINT chk_value_range CHECK (value BETWEEN 0 AND 1000);
   
   ALTER TABLE measurements_template 
   ADD CONSTRAINT chk_value_range CHECK (value BETWEEN 0 AND 1000);
   ```

5. 最佳实践：
   - 维护一个同步脚本记录所有结构变更
   - 在非高峰期执行同步操作
   - 大型更改建议分批执行
   - 重要更改前先在测试环境验证

### 维护任务运行机制

pg_partman 提供两种运行维护任务的方式：

1. 后台工作进程（Background Worker）
```sql
-- 启用后台自动维护
UPDATE partman.part_config SET 
    automatic_maintenance = 'on',
    maintenance_interval = '1 hour'
WHERE parent_table = 'public.measurements';
```

2. 手动/定时调用
```sql
-- 手动运行维护
SELECT partman.run_maintenance();

-- 使用 pg_cron 定时运行（需要安装 pg_cron 扩展）
SELECT cron.schedule('partman-maintenance', '0 * * * *', 'SELECT partman.run_maintenance()');
```

#### 维护任务说明

1. Background Worker:
   - 需要在 postgresql.conf 中设置 `shared_preload_libraries = 'pg_partman_bgw'`
   - 通过 automatic_maintenance 和 maintenance_interval 控制
   - 服务器重启后自动运行
   - 适合单机部署

2. 手动/定时方式:
   - 更灵活的调度控制
   - 可以与其他维护任务协调
   - 适合集群环境
   - 可以通过外部工具（如 crontab）或 pg_cron 调度

#### 选择建议

1. 单机环境：
   - 推荐使用 Background Worker
   - 配置简单，自动运行
   - 无需额外组件

2. 集群环境：
   - 推荐使用 pg_cron 或外部调度
   - 避免多个节点同时运行维护任务
   - 可以更好地控制运行时间

3. 特殊需求：
   - 需要精确控制运行时间
   - 与其他维护任务有依赖关系
   - 需要错误处理和通知
   - 推荐使用外部调度方案



