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
# or python validate.py --report custom_report.md

# Start API server
make serve  # runs uvicorn api.server:app

# Run tests
make test
```

Environment variables can be placed in `.env` or exported before running. See `.env.example` for details. The `serve` command accepts `--host` and `--port` options to customize the API address.
Ensure `AGENT_API_KEY` is set to protect the REST API. The `run` command accepts
`--report` to specify the output path for `validation_report.md`.
