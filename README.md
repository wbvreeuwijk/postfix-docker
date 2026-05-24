# postfix‑docker

[![Docker Pulls](https://img.shields.io/docker/pulls/basvanreeuwijk/postfix-docker)](https://hub.docker.com/r/basvanreeuwijk/postfix-docker)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

## Overview
A **lightweight Docker image** that bundles **Postfix** together with **OpenDKIM** (via the `cyrus‑sasl` stack) for reliable, container‑native mail relay. It is built on **Alpine 3.20**, runs as a **non‑root user**, and is fully **OCI‑labelled** for reproducibility.

## Features
- Minimal footprint (~30 MB) based on Alpine Linux.
- Built‑in **Supervisor** to keep both Postfix and syslog running.
- **Health‑check** that validates the Postfix daemon is alive.
- Configurable timezone (defaults to `Europe/Amsterdam`).
- Exposes the standard **submission port 125**.
- Volume‑mounted `/etc/postfix` for persisting configuration and DKIM keys.
- Runs as a **dedicated `mailuser`** for security.

## Quickstart
```bash
# Clone the repository
git clone https://github.com/basvanreeuwijk/postfix-docker.git
cd postfix-docker

# Build the image (the digest is optional; replace <digest> if you pinned it)
docker build -t basvanreeuwijk/postfix-docker .

# Run a container
docker run -d \
    --name my‑postfix \
    -p 125:125 \
    -v $(pwd)/postfix-config:/etc/postfix \
    basvanreeuwijk/postfix-docker
```
The container will start **Supervisor**, which in turn launches Postfix (`/opt/postfix.sh`) and a basic syslog daemon.

## Configuration
All standard Postfix parameters can be set with `postconf` inside the container or by editing files under the **mounted volume** `/etc/postfix`.

| Setting | Description |
|---------|-------------|
| `mydestination` | Domains that this server will accept mail for (empty by default). |
| `relay_domains` | Domains that this server will relay mail to (empty by default). |
| `mynetworks` | Trusted networks – default includes localhost and common private ranges. |
| `smtpd_helo_restrictions` | Controls HELO validation. |
| `smtpd_helo_required` | Enforces HELO/EHLO on incoming connections. |

You can add OpenDKIM configuration files (e.g., `opendkim.conf`, `KeyTable`, `SigningTable`) into the volume; Postfix will pick them up automatically.

## Dockerfile Highlights
- **Pinned base image**: `FROM alpine:3.20@sha256:<digest>` ensures immutable builds.
- **Single‑layer `apk add --no-cache`** reduces image size.
- **Non‑root user** `mailuser` created via `addgroup`/`adduser`.
- **Configuration files** (`supervisord.conf`, `postfix.sh`) are copied from the repo instead of generated with `echo`.
- **Health‑check** verifies the Postfix process is alive.

## Contributing
1. Fork the repository.
2. Create a feature branch (`git checkout -b feat/your‑feature`).
3. Make your changes and ensure the Docker build succeeds.
4. Submit a Pull Request.

All contributions are welcome – especially improvements to security, documentation, or adding support for additional mail protocols.

## License
This project is licensed under the **MIT License** – see the `LICENSE` file for details.
