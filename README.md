# dynatrace-security-lab

Lab educacional: app vulnerável + nginx reverse proxy (HTTP/HTTPS) + attack scripts + simulation.

**WARNING:** This project intentionally contains vulnerabilities. Use only in isolated lab environments.

## Quick install (after you push to GitHub)

On a fresh Ubuntu machine:
```bash
sudo bash -c "apt update && apt install -y curl"
curl -sSL https://raw.githubusercontent.com/<your-user>/dynatrace-security-lab/main/install.sh | sudo bash -s -- --repo https://github.com/<your-user>/dynatrace-security-lab.git
```

If you don't have domain, omit `--domain` and a self-signed cert will be generated.

## After install
- Access: https://<domain_or_ip>/ (self-signed cert if no domain)
- Attack scripts: `/opt/dynatrace-security-lab/vuln-app/attack-scripts`
- To simulate users: `simulate-users.sh`
- Install Dynatrace OneAgent to the host to capture telemetry and enable Application Security (RAP) in Monitor mode.

## Security recommendations
- Restrict access by firewall/Security Group to your IP(s).
- Stop the stack after training: `sudo systemctl stop dynatrace-security-lab` and/or `docker compose down`
