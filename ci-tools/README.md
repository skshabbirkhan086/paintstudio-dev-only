# Optional local DevOps tools sandbox

`docker-compose.yml` starts a local **Jenkins controller, SonarQube Community Build, Nexus Repository, and Vault dev server**. All externally mapped ports bind to `127.0.0.1` (not a public interface). The Vault **dev server** is deliberately insecure: no persistent vault, no TLS, and a root token. It is suitable **only to explore the UI/CLI locally**, not to protect live AWS/Nexus credentials. For an integrated CI run, configure a real secured Vault server/AppRole and a dedicated build agent as described in `DEV_RUNBOOK.md`.

```bash
cp .env.example .env
# set new passwords / throwaway Vault token
# Docker Desktop: allocate >= 10-12 GB RAM; SonarQube needs host limits such as vm.max_map_count.
docker compose up -d
```

Open Jenkins http://localhost:8081, SonarQube http://localhost:9000, Nexus http://localhost:8082, Vault http://localhost:8200. Retrieve first-time Jenkins password via `docker compose exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword`. Nexus initial admin secret resides in its named volume; `docker compose exec nexus cat /nexus-data/admin.password` (may need to wait for initialization).

This sandbox **does not** magically provide `.NET 10`, Checkov, Vault AppRole, Jenkins AWS IAM, Sonar webhook reachability, Nexus hosted repository, or agents in the Jenkins image. Install dedicated agents with the prerequisites in the runbook. Local Vault dev token should not be inserted in production Jenkins credentials, and `vault.example.com` / `nexus.example.com` in Jenkinsfile are placeholders to update to reachable **secured** service addresses.

To stop: `docker compose down`. To permanently delete all sandbox data: `docker compose down -v`.
