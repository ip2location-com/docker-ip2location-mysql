FROM debian:13-slim

LABEL maintainer="support@ip2location.com"

# Install packages
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y mariadb-server wget unzip

# Add MySQL configuration
ADD custom.cnf /etc/mysql/mariadb.conf.d/999-custom.cnf

# Add scripts
COPY ./app /app
RUN chmod 755 /app/*.sh

WORKDIR /app

# Exposed ENV
ENV TOKEN=FALSE
ENV CODE=FALSE
ENV IP_TYPE=FALSE
ENV MYSQL_PASSWORD=FALSE

# Add VOLUMEs
VOLUME  ["/etc/mysql", "/var/lib/mysql"]

EXPOSE 3306 33060

CMD ["bash", "main.sh"]