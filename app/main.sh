#!/bin/bash

if [ -n "$NO_COLOR" ]; then
	C_RESET=; C_DIM=; C_BOLD=; C_OK=; C_WARN=; C_ERR=
else
	C_RESET=$'\e[0m'; C_DIM=$'\e[2m'; C_BOLD=$'\e[1m'
	C_OK=$'\e[32m'; C_WARN=$'\e[33m'; C_ERR=$'\e[31m'
fi

STEP_N=0
STEP_WIDTH=58

banner() {
	printf '\n%s  %s%s\n%s  %s%s\n\n' \
		"$C_BOLD" "$1" "$C_RESET" \
		"$C_DIM" "$(printf '─%.0s' $(seq 1 $((${#1} + 2))))" "$C_RESET"
}

step() {
	STEP_N=$((STEP_N + 1))
	printf '  %s%2d.%s ' "$C_DIM" "$STEP_N" "$C_RESET"
	local label="$1"

	[ ${#label} -gt "$STEP_WIDTH" ] && label="${label:0:$((STEP_WIDTH - 3))}..."

	local pad=$((STEP_WIDTH - ${#label})) dots=""
	[ $pad -gt 0 ] && dots="$(printf '·%.0s' $(seq 1 $pad))"

	printf '%s %s%s%s ' "$label" "$C_DIM" "$dots" "$C_RESET"
	printf '%s' "$C_DIM"
}
ok()   { if [ -n "$1" ]; then printf '%s✓%s %s(%s)%s\n' "$C_OK" "$C_RESET" "$C_DIM" "$1" "$C_RESET"; else printf '%s✓%s\n' "$C_OK" "$C_RESET"; fi; }
warn() { printf '%s!%s %s%s%s\n' "$C_WARN" "$C_RESET" "$C_DIM" "$1" "$C_RESET"; }
fail() { printf '%s✗%s %s\n' "$C_ERR" "$C_RESET" "$1"; exit 1; }
note()  { printf '     %s%s%s\n' "$C_DIM" "$1" "$C_RESET"; }
field() { printf '  %s%-9s%s %s\n' "$C_DIM" "$1" "$C_RESET" "$2"; }

group() {
	local n="$1" out=""
	while [ ${#n} -gt 3 ]; do
		out=",${n: -3}${out}"
		n="${n:0:${#n}-3}"
	done
	printf '%s%s' "$n" "$out"
}

summary() {
	printf '\n  %s✓%s %s%s%s\n' "$C_OK" "$C_RESET" "$C_BOLD$C_OK" "$1" "$C_RESET"
	[ -n "$2" ] && printf '    %s%s%s\n' "$C_DIM" "$2" "$C_RESET"
	printf '\n'
}

USER_AGENT="Mozilla/5.0+(compatible; IP2Location/MySQL-Docker; https://hub.docker.com/r/ip2location/mysql)"
CODES=(DB1-LITE DB3-LITE DB5-LITE DB9-LITE DB11-LITE DB1 DB2 DB3 DB4 DB5 DB6 DB7 DB8 DB9 DB10 DB11 DB12 DB13 DB14 DB15 DB16 DB17 DB18 DB19 DB20 DB21 DB22 DB23 DB24 DB25 DB26)

trim() { local v="${1//$'\r'/}"; v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"; printf '%s' "$v"; }

TOKEN="$(trim "$TOKEN")"
CODE="$(trim "$CODE")"
IP_TYPE="$(trim "$IP_TYPE")"
CODE_INPUT="$CODE"

if [ -f /ip2location.conf ]; then
	CONF_TOKEN="$(grep '^TOKEN=' /ip2location.conf | cut -d= -f2-)"
	CONF_CODE="$(grep '^CODE=' /ip2location.conf | cut -d= -f2-)"
	CONF_IP_TYPE="$(grep '^IP_TYPE=' /ip2location.conf | cut -d= -f2-)"
	CONF_PASSWORD="$(grep '^MYSQL_PASSWORD=' /ip2location.conf | cut -d= -f2-)"

	if [ -n "$CODE_INPUT" ] && [ "$CODE_INPUT" != "$CONF_CODE" ]; then
		echo " > NOTE: CODE has changed from '$CONF_CODE' to '$CODE_INPUT', but the database"
		echo " >       is already installed. The existing data is kept. To install"
		echo " >       '$CODE_INPUT' instead, start a fresh container with an empty /var/lib/mysql."
	fi
	if [ -n "$TOKEN" ] && [ "$TOKEN" != "$CONF_TOKEN" ]; then
		echo " > NOTE: TOKEN has changed but is not re-applied to an existing install."
	fi
	if [ -n "$IP_TYPE" ] && [ "$IP_TYPE" != "$CONF_IP_TYPE" ]; then
		echo " > NOTE: IP_TYPE has changed from '$CONF_IP_TYPE' to '$IP_TYPE', but the"
		echo " >       database is already installed and is not converted in place."
		echo " >       To install '$IP_TYPE', start a fresh container with an empty"
		echo " >       /var/lib/mysql. Running ./update.sh keeps '$CONF_IP_TYPE'."
	fi
	if [ -n "$MYSQL_PASSWORD" ] && [ "$MYSQL_PASSWORD" != "$CONF_PASSWORD" ]; then
		echo " > NOTE: MYSQL_PASSWORD has changed but the existing admin password is kept."
		echo " >       Change it with: mariadb -e \"SET PASSWORD FOR 'admin'@'%' = PASSWORD('...')\""
	fi

	/etc/init.d/mariadb restart >/dev/null 2>&1
	tail -f /dev/null
fi

[ -z "$TOKEN" ] && fail "Missing download token. Pass it with -e TOKEN=..."
[ -z "$CODE" ] && fail "Missing database code. Pass it with -e CODE=... (e.g. DB1-LITE)"

if [ -z "$MYSQL_PASSWORD" ]; then
	MYSQL_PASSWORD="$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-12})"
fi

FOUND=""
for i in "${CODES[@]}"; do
	if [ "$i" == "$CODE" ] ; then
		FOUND="$CODE"
	fi
done

if [ -z "$FOUND" ]; then
	fail "Download code '$CODE' is invalid. See the README for the list of supported codes."
fi

CODE=$(echo $CODE | sed 's/-//')

if [ "$IP_TYPE" == "IPV6" ]; then
	IP_TYPE="IPV6"
	SUFFIX="CSVIPV6"
else
	[ -n "$IP_TYPE" ] && [ "$IP_TYPE" != "IPV4" ] && echo " > IP_TYPE '$IP_TYPE' is not recognised, using IPV4."
	IP_TYPE="IPV4"
	SUFFIX="CSV"
fi

banner "IP2Location Database Setup"
field "Database" "ip2location_database"
field "Code" "$CODE_INPUT"
field "IP type" "$IP_TYPE"

rm -rf /_tmp && mkdir /_tmp && cd /_tmp

echo ""
step "Download IP2Location $IP_TYPE database"

ARCHIVE="database.zip"
wget -qO "$ARCHIVE" --user-agent="$USER_AGENT" "https://www.ip2location.com/download?token=${TOKEN}&code=${CODE}${SUFFIX}" > /dev/null 2>&1

[ ! -z "$(grep 'NO PERMISSION' "$ARCHIVE")" ] && fail "DENIED"
[ ! -z "$(grep '5 TIMES' "$ARCHIVE")" ] && fail "QUOTA EXCEEDED"

unzip -t "$ARCHIVE" >/dev/null 2>&1

[ $? -ne 0 ] && fail "FILE CORRUPTED"

ok

CSV=$(unzip -l "$ARCHIVE" | sort -nr | grep -Eio 'IP(V6)?.*CSV' | head -n 1)

step "Decompress the downloaded archive"

FIRST="$(unzip -p "$ARCHIVE" "$CSV" 2>/dev/null | head -n 1)"

[ -z "$(echo "$FIRST" | grep -E '^"?[0-9]+"?,')" ] && fail "Unexpected CSV layout: $FIRST"

unzip -p "$ARCHIVE" "$CSV" | sed -E 's/^"?[0-9]+"?,//' > "$CSV"

if [ ! -f "$CSV" ]; then
	fail "ERROR"
fi

ok

/etc/init.d/mariadb start > /dev/null 2>&1

step "Create database \"ip2location_database\""
RESPONSE="$(mariadb -e 'CREATE DATABASE IF NOT EXISTS ip2location_database' 2>&1)"

[ ! -z "$(echo $RESPONSE)" ] && fail "$RESPONSE" || ok

step "Create table \"ip2location_database_tmp\""

RESPONSE="$(mariadb ip2location_database -e 'DROP TABLE IF EXISTS ip2location_database_tmp' 2>&1)"

case "$CODE" in
	DB1|DB1LITE )
		FIELDS=''
	;;

	DB2 )
		FIELDS=',`isp` VARCHAR(255) NOT NULL'
	;;

	DB3|DB3LITE )
		FIELDS=',`region_name` VARCHAR(128) NOT NULL,`city_name` VARCHAR(128) NOT NULL'
	;;

	DB4 )
		FIELDS=',`region_name` VARCHAR(128) NOT NULL,`city_name` VARCHAR(128) NOT NULL,`isp` VARCHAR(255) NOT NULL'
	;;

	DB5|DB5LITE )
		FIELDS=',`region_name` VARCHAR(128) NOT NULL,`city_name` VARCHAR(128) NOT NULL,`latitude` DOUBLE NULL DEFAULT NULL,`longitude` DOUBLE NULL DEFAULT NULL'
	;;

	DB6 )
		FIELDS=',`region_name` VARCHAR(128) NOT NULL,`city_name` VARCHAR(128) NOT NULL,`latitude` DOUBLE NULL DEFAULT NULL,`longitude` DOUBLE NULL DEFAULT NULL,`isp` VARCHAR(255) NOT NULL'
	;;

	DB7 )
		FIELDS=',`region_name` VARCHAR(128) NOT NULL,`city_name` VARCHAR(128) NOT NULL,`isp` VARCHAR(255) NOT NULL,`domain` VARCHAR(128) NOT NULL'
	;;

	DB8 )
		FIELDS=',`region_name` VARCHAR(128) NOT NULL,`city_name` VARCHAR(128) NOT NULL,`latitude` DOUBLE NULL DEFAULT NULL,`longitude` DOUBLE NULL DEFAULT NULL,`isp` VARCHAR(255) NOT NULL,`domain` VARCHAR(128) NOT NULL'
	;;

	DB9|DB9LITE )
		FIELDS=',`region_name` VARCHAR(128) NOT NULL,`city_name` VARCHAR(128) NOT NULL,`latitude` DOUBLE NULL DEFAULT NULL,`longitude` DOUBLE NULL DEFAULT NULL,`zip_code` VARCHAR(30) NULL DEFAULT NULL'
	;;

	DB10 )
		FIELDS=',`region_name` VARCHAR(128) NOT NULL,`city_name` VARCHAR(128) NOT NULL,`latitude` DOUBLE NULL DEFAULT NULL,`longitude` DOUBLE NULL DEFAULT NULL,`zip_code` VARCHAR(30) NULL DEFAULT NULL,`isp` VARCHAR(255) NOT NULL,`domain` VARCHAR(128) NOT NULL'
	;;

	DB11|DB11LITE )
		FIELDS=',`region_name` VARCHAR(128) NOT NULL,`city_name` VARCHAR(128) NOT NULL,`latitude` DOUBLE NULL DEFAULT NULL,`longitude` DOUBLE NULL DEFAULT NULL,`zip_code` VARCHAR(30) NULL DEFAULT NULL,`time_zone` VARCHAR(8) NULL DEFAULT NULL'
	;;

	DB12 )
		FIELDS=',`region_name` VARCHAR(128) NOT NULL,`city_name` VARCHAR(128) NOT NULL,`latitude` DOUBLE NULL DEFAULT NULL,`longitude` DOUBLE NULL DEFAULT NULL,`zip_code` VARCHAR(30) NULL DEFAULT NULL,`time_zone` VARCHAR(8) NULL DEFAULT NULL,`isp` VARCHAR(255) NOT NULL,`domain` VARCHAR(128) NOT NULL'
	;;

	DB13 )
		FIELDS=',`region_name` VARCHAR(128) NOT NULL,`city_name` VARCHAR(128) NOT NULL,`latitude` DOUBLE NULL DEFAULT NULL,`longitude` DOUBLE NULL DEFAULT NULL,`time_zone` VARCHAR(8) NULL DEFAULT NULL,`net_speed` VARCHAR(8) NOT NULL'
	;;

	DB14 )
		FIELDS=',`region_name` VARCHAR(128) NOT NULL,`city_name` VARCHAR(128) NOT NULL,`latitude` DOUBLE NULL DEFAULT NULL,`longitude` DOUBLE NULL DEFAULT NULL,`zip_code` VARCHAR(30) NULL DEFAULT NULL,`time_zone` VARCHAR(8) NULL DEFAULT NULL,`isp` VARCHAR(255) NOT NULL,`domain` VARCHAR(128) NOT NULL,`net_speed` VARCHAR(8) NOT NULL'
	;;

	DB15 )
		FIELDS=',`region_name` VARCHAR(128) NOT NULL,`city_name` VARCHAR(128) NOT NULL,`latitude` DOUBLE NULL DEFAULT NULL,`longitude` DOUBLE NULL DEFAULT NULL,`zip_code` VARCHAR(30) NULL DEFAULT NULL,`time_zone` VARCHAR(8) NULL DEFAULT NULL,`idd_code` VARCHAR(5) NOT NULL,`area_code` VARCHAR(30) NOT NULL'
	;;

	DB16 )
		FIELDS=',`region_name` VARCHAR(128) NOT NULL,`city_name` VARCHAR(128) NOT NULL,`latitude` DOUBLE NULL DEFAULT NULL,`longitude` DOUBLE NULL DEFAULT NULL,`zip_code` VARCHAR(30) NULL DEFAULT NULL,`time_zone` VARCHAR(8) NULL DEFAULT NULL,`isp` VARCHAR(255) NOT NULL,`domain` VARCHAR(128) NOT NULL,`net_speed` VARCHAR(8) NOT NULL,`idd_code` VARCHAR(5) NOT NULL,`area_code` VARCHAR(30) NOT NULL'
	;;

	DB17 )
		FIELDS=',`region_name` VARCHAR(128) NOT NULL,`city_name` VARCHAR(128) NOT NULL,`latitude` DOUBLE NULL DEFAULT NULL,`longitude` DOUBLE NULL DEFAULT NULL,`time_zone` VARCHAR(8) NULL DEFAULT NULL,`net_speed` VARCHAR(8) NOT NULL,`weather_station_code` VARCHAR(10) NOT NULL,`weather_station_name` VARCHAR(128) NOT NULL'
	;;

	DB18 )
		FIELDS=',`region_name` VARCHAR(128) NOT NULL,`city_name` VARCHAR(128) NOT NULL,`latitude` DOUBLE NULL DEFAULT NULL,`longitude` DOUBLE NULL DEFAULT NULL,`zip_code` VARCHAR(30) NULL DEFAULT NULL,`time_zone` VARCHAR(8) NULL DEFAULT NULL,`isp` VARCHAR(255) NOT NULL,`domain` VARCHAR(128) NOT NULL,`net_speed` VARCHAR(8) NOT NULL,`idd_code` VARCHAR(5) NOT NULL,`area_code` VARCHAR(30) NOT NULL,`weather_station_code` VARCHAR(10) NOT NULL,`weather_station_name` VARCHAR(128) NOT NULL'
	;;

	DB19 )
		FIELDS=',`region_name` VARCHAR(128) NOT NULL,`city_name` VARCHAR(128) NOT NULL,`latitude` DOUBLE NULL DEFAULT NULL,`longitude` DOUBLE NULL DEFAULT NULL,`isp` VARCHAR(255) NOT NULL,`domain` VARCHAR(128) NOT NULL,`mcc` VARCHAR(128) NULL DEFAULT NULL,`mnc` VARCHAR(128) NULL DEFAULT NULL,`mobile_brand` VARCHAR(128) NULL DEFAULT NULL'
	;;

	DB20 )
		FIELDS=',`region_name` VARCHAR(128) NOT NULL,`city_name` VARCHAR(128) NOT NULL,`latitude` DOUBLE NULL DEFAULT NULL,`longitude` DOUBLE NULL DEFAULT NULL,`zip_code` VARCHAR(30) NULL DEFAULT NULL,`time_zone` VARCHAR(8) NULL DEFAULT NULL,`isp` VARCHAR(255) NOT NULL,`domain` VARCHAR(128) NOT NULL,`net_speed` VARCHAR(8) NOT NULL,`idd_code` VARCHAR(5) NOT NULL,`area_code` VARCHAR(30) NOT NULL,`weather_station_code` VARCHAR(10) NOT NULL,`weather_station_name` VARCHAR(128) NOT NULL,`mcc` VARCHAR(128) NULL DEFAULT NULL,`mnc` VARCHAR(128) NULL DEFAULT NULL,`mobile_brand` VARCHAR(128) NULL DEFAULT NULL'
	;;

	DB21 )
		FIELDS=',`region_name` VARCHAR(128) NOT NULL,`city_name` VARCHAR(128) NOT NULL,`latitude` DOUBLE NULL DEFAULT NULL,`longitude` DOUBLE NULL DEFAULT NULL,`zip_code` VARCHAR(30) NULL DEFAULT NULL,`time_zone` VARCHAR(8) NULL DEFAULT NULL,`idd_code` VARCHAR(5) NOT NULL,`area_code` VARCHAR(30) NOT NULL,`elevation` INT(10) NOT NULL'
	;;

	DB22 )
		FIELDS=',`region_name` VARCHAR(128) NOT NULL,`city_name` VARCHAR(128) NOT NULL,`latitude` DOUBLE NULL DEFAULT NULL,`longitude` DOUBLE NULL DEFAULT NULL,`zip_code` VARCHAR(30) NULL DEFAULT NULL,`time_zone` VARCHAR(8) NULL DEFAULT NULL,`isp` VARCHAR(255) NOT NULL,`domain` VARCHAR(128) NOT NULL,`net_speed` VARCHAR(8) NOT NULL,`idd_code` VARCHAR(5) NOT NULL,`area_code` VARCHAR(30) NOT NULL,`weather_station_code` VARCHAR(10) NOT NULL,`weather_station_name` VARCHAR(128) NOT NULL,`mcc` VARCHAR(128) NULL DEFAULT NULL,`mnc` VARCHAR(128) NULL DEFAULT NULL,`mobile_brand` VARCHAR(128) NULL DEFAULT NULL,`elevation` INT(10) NOT NULL'
	;;

	DB23 )
		FIELDS=',`region_name` VARCHAR(128) NOT NULL,`city_name` VARCHAR(128) NOT NULL,`latitude` DOUBLE NULL DEFAULT NULL,`longitude` DOUBLE NULL DEFAULT NULL,`isp` VARCHAR(255) NOT NULL,`domain` VARCHAR(128) NOT NULL,`mcc` VARCHAR(128) NULL DEFAULT NULL,`mnc` VARCHAR(128) NULL DEFAULT NULL,`mobile_brand` VARCHAR(128) NULL DEFAULT NULL,`usage_type` VARCHAR(11) NOT NULL'
	;;

	DB24 )
		FIELDS=',`region_name` VARCHAR(128) NOT NULL,`city_name` VARCHAR(128) NOT NULL,`latitude` DOUBLE NULL DEFAULT NULL,`longitude` DOUBLE NULL DEFAULT NULL,`zip_code` VARCHAR(30) NULL DEFAULT NULL,`time_zone` VARCHAR(8) NULL DEFAULT NULL,`isp` VARCHAR(255) NOT NULL,`domain` VARCHAR(128) NOT NULL,`net_speed` VARCHAR(8) NOT NULL,`idd_code` VARCHAR(5) NOT NULL,`area_code` VARCHAR(30) NOT NULL,`weather_station_code` VARCHAR(10) NOT NULL,`weather_station_name` VARCHAR(128) NOT NULL,`mcc` VARCHAR(128) NULL DEFAULT NULL,`mnc` VARCHAR(128) NULL DEFAULT NULL,`mobile_brand` VARCHAR(128) NULL DEFAULT NULL,`elevation` INT(10) NOT NULL,`usage_type` VARCHAR(11) NOT NULL'
	;;

	DB25 )
		FIELDS=',`region_name` VARCHAR(128) NOT NULL,`city_name` VARCHAR(128) NOT NULL,`latitude` DOUBLE NULL DEFAULT NULL,`longitude` DOUBLE NULL DEFAULT NULL,`zip_code` VARCHAR(30) NULL DEFAULT NULL,`time_zone` VARCHAR(8) NULL DEFAULT NULL,`isp` VARCHAR(255) NOT NULL,`domain` VARCHAR(128) NOT NULL,`net_speed` VARCHAR(8) NOT NULL,`idd_code` VARCHAR(5) NOT NULL,`area_code` VARCHAR(30) NOT NULL,`weather_station_code` VARCHAR(10) NOT NULL,`weather_station_name` VARCHAR(128) NOT NULL,`mcc` VARCHAR(128) NULL DEFAULT NULL,`mnc` VARCHAR(128) NULL DEFAULT NULL,`mobile_brand` VARCHAR(128) NULL DEFAULT NULL,`elevation` INT(10) NOT NULL,`usage_type` VARCHAR(11) NOT NULL,`address_type` CHAR(1) NULL DEFAULT NULL,`category` VARCHAR(10) NULL DEFAULT NULL'
	;;

	DB26 )
		FIELDS=',`region_name` VARCHAR(128) NOT NULL,`city_name` VARCHAR(128) NOT NULL,`latitude` DOUBLE NULL DEFAULT NULL,`longitude` DOUBLE NULL DEFAULT NULL,`zip_code` VARCHAR(30) NULL DEFAULT NULL,`time_zone` VARCHAR(8) NULL DEFAULT NULL,`isp` VARCHAR(255) NOT NULL,`domain` VARCHAR(128) NOT NULL,`net_speed` VARCHAR(8) NOT NULL,`idd_code` VARCHAR(5) NOT NULL,`area_code` VARCHAR(30) NOT NULL,`weather_station_code` VARCHAR(10) NOT NULL,`weather_station_name` VARCHAR(128) NOT NULL,`mcc` VARCHAR(128) NULL DEFAULT NULL,`mnc` VARCHAR(128) NULL DEFAULT NULL,`mobile_brand` VARCHAR(128) NULL DEFAULT NULL,`elevation` INT(10) NOT NULL,`usage_type` VARCHAR(11) NOT NULL,`address_type` CHAR(1) NULL DEFAULT NULL,`category` VARCHAR(10) NULL DEFAULT NULL,`district` VARCHAR(128) NULL DEFAULT NULL,`asn` VARCHAR(10) NULL DEFAULT NULL,`as` VARCHAR(256) NULL DEFAULT NULL,`as_domain` VARCHAR(128) NULL DEFAULT NULL,`as_usage_type` VARCHAR(11) NULL DEFAULT NULL,`as_cidr` VARCHAR(43) NULL DEFAULT NULL'
	;;
esac

RESPONSE="$(mariadb ip2location_database -e 'DROP TABLE IF EXISTS ip2location_database_tmp' 2>&1)"

[ ! -z "$(echo $RESPONSE)" ] && fail "$RESPONSE"

RESPONSE="$(mariadb ip2location_database -e 'CREATE TABLE ip2location_database_tmp (`ip_to` DECIMAL(39,0) UNSIGNED NOT NULL,`country_code` CHAR(2) NOT NULL,`country_name` VARCHAR(64) NOT NULL'"$FIELDS"',INDEX `idx_ip_to` (`ip_to`)) ENGINE=MyISAM' 2>&1)"

[ ! -z "$(echo $RESPONSE)" ] && fail "$RESPONSE" || ok

step "Load the CSV into the database"
RESPONSE="$(mariadb ip2location_database -e 'LOAD DATA LOCAL INFILE '\'''$CSV''\'' INTO TABLE ip2location_database_tmp FIELDS TERMINATED BY '\'','\'' ENCLOSED BY '\''\"'\'' LINES TERMINATED BY '\''\r\n'\''' 2>&1)"
[ ! -z "$(echo $RESPONSE)" ] && fail "$RESPONSE" || ok

ROWS="$(mariadb ip2location_database -N -e 'SELECT COUNT(*) FROM ip2location_database_tmp' 2>/dev/null)"

[ -n "$ROWS" ] && [ "$ROWS" -gt 0 ] 2>/dev/null || fail "No rows were loaded from $CSV."

step "Drop table \"ip2location_database\""

RESPONSE="$(mariadb ip2location_database -e 'DROP TABLE IF EXISTS ip2location_database' 2>&1)"

[ ! -z "$(echo $RESPONSE)" ] && fail "$RESPONSE" || ok

step "Activate ip2location_database"

RESPONSE="$(mariadb ip2location_database -e 'RENAME TABLE ip2location_database_tmp TO ip2location_database' 2>&1)"

[ ! -z "$(echo $RESPONSE)" ] && fail "$RESPONSE" || ok

step "Create user \"admin\""

mariadb -e "CREATE USER admin@'%' IDENTIFIED BY '$MYSQL_PASSWORD'" > /dev/null 2>&1
mariadb -e "GRANT ALL PRIVILEGES ON *.* TO admin@'%' WITH GRANT OPTION" > /dev/null 2>&1

ok

step "Create function \"IP_ATON\""

mariadb ip2location_database << 'SQL' > /dev/null 2>&1
DROP FUNCTION IF EXISTS IP_ATON;
DELIMITER $$
CREATE FUNCTION IP_ATON(ip VARCHAR(45)) RETURNS DECIMAL(39,0) DETERMINISTIC
BEGIN
	IF INET6_ATON(ip) IS NULL THEN RETURN NULL; END IF;
	IF IS_IPV6(ip) THEN
		RETURN CAST(CONV(HEX(SUBSTR(INET6_ATON(ip),1,8)),16,10) AS DECIMAL(39,0))
		* CAST(18446744073709551616 AS DECIMAL(39,0))
		+ CAST(CONV(HEX(SUBSTR(INET6_ATON(ip),9,8)),16,10) AS DECIMAL(39,0));
	END IF;
	RETURN CONV(HEX(INET6_ATON(ip)),16,10);
END$$
DELIMITER ;
SQL

RESPONSE="$(mariadb ip2location_database -e 'SELECT IP_ATON("8.8.8.8")' -N 2>&1)"

[ "$RESPONSE" == "134744072" ] && ok || fail "$RESPONSE"

ROWS="$(mariadb ip2location_database -N -e 'SELECT COUNT(*) FROM ip2location_database' 2>/dev/null)"

summary "Setup completed" "$(group "$ROWS") records loaded from $CODE_INPUT ($IP_TYPE)"
field "Host" "ip2location"
field "Database" "ip2location_database"
field "User" "admin"
field "Password" "$MYSQL_PASSWORD"
printf '\n  %smariadb -h ip2location -u admin --password="%s" ip2location_database%s\n' "$C_DIM" "$MYSQL_PASSWORD" "$C_RESET"
printf '\n'

echo "MYSQL_PASSWORD=$MYSQL_PASSWORD" > /ip2location.conf
echo "TOKEN=$TOKEN" >> /ip2location.conf
echo "CODE=$CODE_INPUT" >> /ip2location.conf
echo "IP_TYPE=$IP_TYPE" >> /ip2location.conf

rm -rf /_tmp

tail -f /dev/null
