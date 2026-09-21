FROM debian:13-slim

LABEL maintainer="support@ip2location.com"

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y mariadb-server wget unzip \
	&& rm -rf /var/lib/apt/lists/*

ADD app/custom.cnf /etc/mysql/mariadb.conf.d/999-custom.cnf

COPY ./app /app

ADD app/update.sh /update.sh
RUN chmod 755 /app/*.sh /update.sh

WORKDIR /app

VOLUME  ["/var/lib/mysql"]

EXPOSE 3306 33060

ENTRYPOINT ["/app/entrypoint.sh"]
