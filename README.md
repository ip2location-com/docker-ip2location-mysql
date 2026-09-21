docker-ip2location-mysql
========================

A ready-to-run MySQL server preloaded with an [IP2Location](https://www.ip2location.com) geolocation database. Supports the commercial packages and the free [LITE](https://lite.ip2location.com) package. Register for an account first as download token is required.



## Usage

```bash
docker network create ip2location-network

docker run --name ip2location \
  --network ip2location-network \
  -d \
  -e TOKEN={DOWNLOAD_TOKEN} \
  -e CODE={DOWNLOAD_CODE} \
  -e IP_TYPE=IPV4 \
  -e MYSQL_PASSWORD={MYSQL_PASSWORD} \
  ip2location/mysql

docker logs -f ip2location      # Wait for "✓ Setup completed"
```

**ENV Variables**

| Variable | Description |
|---|---|
| `TOKEN` | Download token. Required. |
| `CODE` | Database code. Required. See below. |
| `IP_TYPE` | `IPV4` (default) or `IPV6`. |
| `MYSQL_PASSWORD` | Password for the `admin` user. Random if omitted. |

**`CODE`** — LITE: `DB1-LITE`, `DB3-LITE`, `DB5-LITE`, `DB9-LITE`, `DB11-LITE`.
Commercial: `DB1` … `DB26`.

Only one address family is installed per container. To switch, start a fresh container with an empty `/var/lib/mysql` — an existing install is not converted in place, and re-running with different settings prints a note explaining that.

The admin password is written to `/ip2location.conf` inside the container, so `docker logs` and `docker exec` access are equivalent to knowing it.

To start over:

```bash
docker rm -f ip2location
docker volume rm ip2location-data        # if you used -v ip2location-data:/var/lib/mysql
```



## Query for IP Information

A built-in `IP_ATON()` converts an address to that number, so you can query with the address directly:

```sql
SELECT * FROM `ip2location_database` WHERE IP_ATON('8.8.8.8') <= ip_to LIMIT 1;
```

```
 country_code | country_name
--------------+--------------------------
 US           | United States of America
```

`IP_ATON()` handles both IPv4 and IPv6, so the same query works whichever `IP_TYPE` you installed. It is created during setup. No row returned means the address is not in the database.



## Connect from an Application

Put your application on the same network and reach the container by name (`ip2location`):

```bash
docker run --network ip2location-network -t -i {YOUR_APPLICATION}
```

The client binary is `mariadb`, not `mysql`.



## Update IP2Location Database

```bash
docker exec -it ip2location /update.sh
```

Downloads a fresh copy and swaps it in, so queries keep working against the old data until the swap. The daily download quota is limited. If you get `[QUOTA EXCEEDED]` error, please try again after 24 hours.



## Articles and Tutorials

[IP2Location Articles and Tutorials](https://blog.ip2location.com)
