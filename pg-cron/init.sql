-- 创建扩展
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 授权
GRANT USAGE ON SCHEMA cron TO postgres; 