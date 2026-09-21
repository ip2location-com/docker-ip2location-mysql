FROM debian:13-slim

LABEL maintainer="support@ip2location.com"

# Install packages
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y mariadb-server wget unzip \
	&& rm -rf /var/lib/apt/lists/*

# Add MySQL configuration
ADD app/custom.cnf /etc/mysql/mariadb.conf.d/999-custom.cnf

# Add scripts
COPY ./app /app
RUN chmod 755 /app/*.sh

WORKDIR /app

# The database lives here. Do NOT also declare /etc/mysql as a volume: the
# image bakes its configuration into /etc/mysql/mariadb.conf.d/, and any
# bind mount there would shadow it and silently start MariaDB with stock
# settings (InnoDB back on, query cache back on, ...).
VOLUME  ["/var/lib/mysql"]

EXPOSE 3306 33060

# ENTRYPOINT (not CMD) so that arguments are honoured: `docker run image
# mariadb -u admin -p ...` must reach the client instead of being discarded
# in favour of the setup script.
ENTRYPOINT ["/app/entrypoint.sh"]
