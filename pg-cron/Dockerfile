FROM postgres:16

# 设置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone


# 安装pg_cron
RUN apt-get update && apt-get install -y postgresql-16-cron



