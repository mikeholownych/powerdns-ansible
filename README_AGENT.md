# AuditAgent

AuditAgent scans an Ansible collection or playbook directory and generates a `validation_report.md` highlighting missing files, undefined variables, and placeholder content.

## Features

- CLI and REST API interfaces
- JSON structured logging
- API key authentication
- Rate limiting
- Audit logs written to `logs/`
- Asynchronous API endpoints with rate limiting
- Docker and docker-compose support

## Usage

```bash
# Install dependencies
make install

# Run audit
make run
# or python validate.py

# Start API server
make serve  # runs uvicorn api.server:app

# Run tests
make test
```

Environment variables can be placed in `.env` or exported before running. See `.env.example` for details. The `serve` command accepts `--host` and `--port` options to customize the API address.
