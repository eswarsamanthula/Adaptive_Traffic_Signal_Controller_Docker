# Docker experiment

This Compose deployment runs the copied traffic system as follows:

- `publisher` streams the copied dataset continuously, refreshing each reading's timestamp so the controller treats replayed data as live.
- `controller` runs the traffic decision service and writes history to the existing SQLite schema in the persistent `traffic-data` volume.
- `actuator` validates simulated signal commands and publishes acknowledgements over MQTT.
- `mqtt` is the internal Mosquitto broker. It has no host port mapping.
- `node-red` provides the dashboard, Testing Lab, MQTT ingest, and Node-RED SQLite flow. Its editor port is bound to `127.0.0.1:1880` on the host.
- `database-init` is a one-shot schema/volume-permission initializer; its normal `Exited (0)` status is expected.

The controller, publisher, actuator, and database initializer share one Python application image. Node-RED and Mosquitto use separate images because they are independent runtimes. The local-only tunnel overlay adds an Nginx dashboard allowlist/authentication gateway and `cloudflared`.

## Requirements and start

Install Docker Desktop with the Linux container engine and Compose v2. From this directory:

```powershell
docker compose up -d
docker compose ps
```

The primary dashboard and Testing Lab are at <http://127.0.0.1:1880/dashboard>. The secondary Node-RED component view is at <http://127.0.0.1:1880/ui/>. The editor is local-only at <http://127.0.0.1:1880/>. The broker is available to Compose services as `mqtt:1883`; do not publish it to the host or internet.

There are currently no required environment variables. Container MQTT/database paths and service settings are in `config/docker-settings.yaml`; simulation loop behavior is in that file. Replay speed/limit are set in the `publisher.command` in `docker-compose.yml` (`--speed 60 --limit 0`).

## Persistence and restart behavior

Named volumes preserve Mosquitto state (`mosquitto-data`), Node-RED user/flow data (`node-red-data`), and SQLite history (`traffic-data`). A new laptop creates empty volumes and fresh SQLite history; historical DB contents from this laptop are not bundled into the images. Dataset and ML assets needed by the runtime are packaged in the application image. `mqtt`, `actuator`, `controller`, `publisher`, and `node-red` use `restart: unless-stopped`; `database-init` is a one-shot job with `restart: "no"`. Controller startup waits for healthy MQTT, successful database initialization, and the actuator process to start.

Stop containers while keeping volumes:

```powershell
docker compose down
```

Start again with `docker compose up -d`. Do not use `docker compose down --volumes` if you need retained SQLite history; that command deletes all three named volumes.

## Optional Cloudflare Quick Tunnel (local laptop only)

The tunnel overlay is intentionally not part of the portable Compose file. It exposes only the dashboard paths through an Nginx gateway protected by HTTP Basic Authentication. It returns 404 for the Node-RED editor and all other paths. The editor remains local-only. The username is `dashboard`; the generated plaintext password is in the ignored local file `tunnel/auth/dashboard-password.txt`, and its bcrypt hash is in `tunnel/auth/htpasswd`. Both files are excluded from the Docker build context by `.dockerignore` and from Git by `.gitignore`. Do not send either file to anyone or include them in an image.

The gateway uses Docker's embedded DNS resolver for the Node-RED upstream, so it follows Node-RED if its container gets a new IP after restart. If a stopped Quick Tunnel returns Error 1033, start the stack again and use the newly generated URL; Quick Tunnel URLs expire when `cloudflared` stops.

Start the base system and the local tunnel overlay:

```powershell
docker compose -f docker-compose.yml -f docker-compose.tunnel.yml up -d
```

Get the temporary public URL from:

```powershell
docker compose -f docker-compose.yml -f docker-compose.tunnel.yml logs -f cloudflared
```

Open `<temporary-trycloudflare-url>/dashboard` and use the locally issued dashboard username/password. Quick Tunnel URLs are temporary and can change when `cloudflared` restarts. The URL is public; share it and its password only with intended viewers. Stop only the tunnel services with:

```powershell
docker compose -f docker-compose.yml -f docker-compose.tunnel.yml stop cloudflared dashboard-gateway
```

Stop the whole deployment (volumes remain) with:

```powershell
docker compose -f docker-compose.yml -f docker-compose.tunnel.yml down
```

To stop every service while keeping the containers and volumes for a later restart:

```powershell
docker compose -f docker-compose.yml -f docker-compose.tunnel.yml stop
```

## Another laptop without the source project

The portable `docker-compose.yml` references these public Docker Hub images:

- [`eswarsamanthula/traffic-controller-app:1.1.0`](https://hub.docker.com/r/eswarsamanthula/traffic-controller-app/tags)
- [`eswarsamanthula/traffic-controller-nodered:1.0.0`](https://hub.docker.com/r/eswarsamanthula/traffic-controller-nodered/tags)
- [`eswarsamanthula/traffic-controller-mqtt:1.0.0`](https://hub.docker.com/r/eswarsamanthula/traffic-controller-mqtt/tags)

All three listed image tags have been published. The 1.1.0 application image contains the live-timestamp replay change and continuous loop settings. They are public, so a Docker Hub login is not needed to pull them.

To run on another laptop without the source project, send your friend only this `docker-compose.yml` (not the source tree, tunnel overlay, or authentication files). They need Docker Desktop with internet access. In PowerShell, from the folder containing the Compose file, run:

```powershell
docker compose pull
docker compose up -d
docker compose ps
```

Then open <http://127.0.0.1:1880/dashboard>. To stop while retaining their data:

```powershell
docker compose down
```

A laptop-specific test has not been performed. The Python image supports the live controller/actuator/publisher runtime; offline model training and evaluation require the full development project and its development dependencies.

## Local image build and diagnostics

To rebuild and publish an application-image update from this folder:

```powershell
docker build -t eswarsamanthula/traffic-controller-app:1.1.0 .
docker login --username eswarsamanthula
docker push eswarsamanthula/traffic-controller-app:1.1.0
```

Use new version tags when publishing changed Node-RED or Mosquitto images; rebuild them with `node_red/Dockerfile` or `mqtt/Dockerfile` and update their Compose tags to match.

Compose diagnostics:

```powershell
docker compose ps
docker compose logs -f mqtt actuator controller publisher node-red
docker compose config
```
