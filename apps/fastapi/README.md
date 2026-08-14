# FastAPI - Community Profile: User Configuration Checklist

This profile is marked `provider: community`. It is a **template** - you MUST
customize before deploying. The platform will validate schema correctness but
cannot guarantee the profile matches your application's actual requirements.

## Before you deploy

- [ ] **Image**: Replace `app_fastapi_image` in `vars.yml` with your real image
  (e.g. `ghcr.io/my-org/my-backend:v1.2.3`). Do NOT use `:latest` in production.
- [ ] **Port**: Verify `app_fastapi_host_port` and `app_fastapi_internal_port`
  match the port your FastAPI app listens on.
- [ ] **Domain**: Confirm `app_fastapi_domain` matches your DNS/Caddy routing.
- [ ] **Health endpoint**: Ensure your app exposes `GET /health` returning 200.
  If your health endpoint differs, update `monitoring.health_endpoint` in `profile.yml`.
- [ ] **Secrets**: Add required secrets to the SOPS file
  (`inventory/group_vars/all/secrets.sops.yml`). The pre-flight
  assertion will block deploy if declared keys are missing from SOPS.
- [ ] **Database**: If your app uses Postgres/MySQL, update `backup.db_type`
  and `backup.db_name` in `profile.yml` to enable automated backups. The
  default is `db_type: custom` (backup role skips).
- [ ] **DR tier**: Set `dr_tier` to `critical` if this service is required for
  business continuity. Default is `standard`.
- [ ] **Variables**: Review `vars.yml`. Add volume mounts, env
  vars, or additional services (Redis, worker) your app needs.
- [ ] **Syntax check**: Run `make lint` after making changes.

## Schema contract

This profile follows the 11-field schema. Any field NOT in the
allowed set will be rejected. To add custom metadata, use `compliance_tags`
(e.g. `[nist,ac-2, mycorp,policy-7]`).

## Questions?

See `apps/chatwoot/` for a complete database-backed example, or
`apps/openwebui/` for a lightweight single-service example.
