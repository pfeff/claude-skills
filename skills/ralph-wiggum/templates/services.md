# Services

External services required by this project.

## Docker Compose

| Setting | Value |
|---------|-------|
| enabled | `{{docker_compose_enabled}}` |
| file | `{{docker_compose_file}}` |

## Health Checks

| Service | Command | Timeout |
|---------|---------|---------|
| {{service_name}} | `{{health_check_command}}` | {{timeout_seconds}}s |

Run health checks after `docker compose up -d` to verify services are ready.
