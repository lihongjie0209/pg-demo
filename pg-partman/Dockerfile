FROM postgres:16

# 安装 pg_partman 扩展
RUN apt-get update \
    && apt-get install -y postgresql-16-partman \
    && rm -rf /var/lib/apt/lists/*

