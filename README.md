# dynatrace-security-lab — README (pt-BR / EN)

> 🚨 **Aviso importante:** este projeto **intencionalmente** contém vulnerabilidades para fins de treinamento. Use **apenas** em ambientes de laboratório isolados. **Não** exponha a infraestrutura em produção ou sem proteção. Sempre restrinja acesso por Security Group / firewall e pare a instância quando não estiver em uso.

---

# 🇧🇷 Português (Brasil) — Manual completo

## 📌 Visão geral

**dynatrace-security-lab** é um laboratório didático que fornece:

* Um app vulnerável (Node.js + SQLite) com endpoints intencionalmente inseguros (SQLi, XSS, execução de comandos).
* Um proxy NGINX que oferece HTTP/HTTPS (suporta certificado autoassinado).
* Interface web simples (`/lab`) para interagir com endpoints sem usar `curl`.
* Scripts de ataque (SQLi, XSS, command injection) e um simulador de “usuários” que gera tráfego.
* Automação `install.sh` para instalar facilmente em Ubuntu/EC2.

---

## 🚀 Instalação rápida (one-liner)

> Substitua `<your.domain.or.ip>` por seu domínio ou IP público, ou remova `--domain` para usar certificado autoassinado.
> O repo no exemplo usa `CassioCirino`; ajuste se seu usuário for diferente.

```bash
sudo bash -c "apt update && apt install -y curl"
curl -sSL https://raw.githubusercontent.com/CassioCirino/dynatrace-security-lab/main/install.sh | sudo bash -s -- --repo https://github.com/CassioCirino/dynatrace-security-lab.git --domain <your.domain.or.ip>
```

Se não tiver domínio:

```bash
curl -sSL https://raw.githubusercontent.com/CassioCirino/dynatrace-security-lab/main/install.sh | sudo bash -s -- --repo https://github.com/CassioCirino/dynatrace-security-lab.git
```

---

## 🔧 O que o instalador faz

* Instala Docker e Docker Compose plugin.
* Clona o repositório em `/opt/dynatrace-security-lab`.
* Gera certificado autoassinado (se `--domain` não for informado).
* Cria arquivo SQLite e ajusta permissões (apenas para lab).
* Sobe containers: `nginx` (80/443) + `vuln-app` (3000).
* Registra um `systemd` service para iniciar o stack no boot.

---

## 🛡️ Segurança (leia antes de abrir ao público)

* Use **Security Group** ou firewall para permitir acesso apenas do(s) IP(s) dos alunos.
* Se expor na Internet, **FAÇA APENAS** para um período controlado e pause a EC2 após a aula.
* O app contém endpoints perigosos (`/echo` executa comandos!). **Não** use em redes públicas sem isolamento.
* Para acesso seguro sem abrir portas, utilize **SSH tunnel**:

  ```bash
  ssh -i key.pem -L 3000:localhost:3000 ubuntu@<EC2_IP>
  # depois no browser: http://localhost:3000/lab
  ```

---

## 🧭 Como usar o front (`/lab`) — Manual do Instrutor e do Aluno

### Acessar a interface

Abra no navegador:

* `https://<domain_or_ip>/` ou `https://<domain_or_ip>/lab`
* Se estiver usando SSH tunnel: `http://localhost:3000/lab`

### O layout (o que aparece)

A página `/lab` contém formulários para:

* **Buscar produto (SQLi)** → envia GET para `/product?id=<valor>`
* **Pesquisar (SQLi)** → envia GET para `/search?q=<texto>`
* **Reflected XSS** → envia GET para `/xss?msg=<texto>` e renderiza HTML
* **Command (lab only)** → envia GET para `/echo?cmd=<comando>` e mostra saída

Os resultados aparecem em um `iframe` embutido.

### Exemplos de payloads (apenas em lab)

* SQL Injection (produto):

  * `1' OR '1'='1`
* Pesquisa (forçar retorno):

  * `' OR '1'='1`
* XSS refletido:

  * `<script>alert('XSS')</script>`
* Command exec (apenas lab, cuidado!):

  * `echo hello_lab`
  * **Não execute** payloads que leiam arquivos sensíveis do sistema (ex.: `/etc/shadow`) — mantenha o lab seguro.

### Fluxo de aula sugerido (40–60 min)

1. **Introdução teórica** — explicar RASP / RAP, Application Security, riscos.
2. **Exploração GUI** — alunos usam `/lab` para enviar queries simples.
3. **Gerar ataque controlado** — instrutor executa `attack-scripts/sqli.sh` e `xss.sh` (mostre primeiro o modo *Monitor* no Dynatrace).
4. **Observação no Dynatrace** — abra `Application Security → Attacks` e mostre detecções.
5. **Montar painel** — demonstrar criação de dashboard com tiles: Vulnerabilities, Attacks, Exposure by Service.
6. (Opcional) **Ativar Block** — só em laboratório: mude RAP para *Block* e repita a injeção para mostrar bloqueio.
7. **Encerramento** — parar a stack ou pausar EC2.

---

## 🧪 Scripts e automações (onde rodar e como)

Os scripts estão em `/opt/dynatrace-security-lab/attack-scripts` no host após instalação.

* Rodar SQLi:

  ```bash
  cd /opt/dynatrace-security-lab/attack-scripts
  ./sqli.sh http://localhost:3000   # se rodando na própria EC2
  ```
* Rodar XSS:

  ```bash
  ./xss.sh http://localhost:3000
  ```
* Rodar command injection (Python):

  ```bash
  python3 cmd_inject.py http://localhost:3000
  ```
* Simular usuários (gera tráfego de navegação):

  ```bash
  ./simulate-users.sh http://localhost 100 0.1
  ```

---

## 🔎 Integração com Dynatrace (passos essenciais)

1. No tenant Dynatrace: `Deploy Dynatrace → OneAgent` → baixe instalador.
2. Na EC2 (host): rode o instalador do OneAgent (com o token do tenant).
3. Aguarde alguns minutos: o host e os serviços devem aparecer em **Transactions & services**.
4. Ative **Application Security** (RAP) para o serviço `vuln-app` em modo **Monitor** inicialmente.
5. Gere ataques (scripts ou `/lab`) e observe `Application Security → Attacks` e `Vulnerabilities`.
6. Use DQL no Grail para montar queries/visualizações (templates estão no material de curso).

---

## 🧰 Administração básica do lab

* Parar o stack:

  ```bash
  sudo systemctl stop dynatrace-security-lab
  ```
* Iniciar manualmente:

  ```bash
  cd /opt/dynatrace-security-lab
  sudo docker compose up -d --build
  ```
* Remover:

  ```bash
  sudo docker compose down
  sudo rm -rf /opt/dynatrace-security-lab
  ```

---

## 📚 Recursos e boas práticas

* Sempre treine com **modo Monitor** antes de usar *Block*.
* Documente variáveis utilizadas na aula (endereço do lab, horário, IPs liberados).
* Após aula, **pare** a máquina ou remova exposição pública.

---

# 🇺🇸 English — Full README (mirror / instructor guide)

## Overview

**dynatrace-security-lab** is a training lab that provides:

* A vulnerable Node.js + SQLite application with deliberate flaws (SQLi, XSS, command execution).
* NGINX reverse proxy serving HTTP/HTTPS (self-signed or domain cert).
* Simple web UI (`/lab`) to interact with endpoints without `curl`.
* Attack scripts and a user-simulation script to generate traffic.
* `install.sh` for one-command deployment on Ubuntu/EC2.

> ⚠️ Use only in isolated lab environments. Do not expose to production or unprotected public networks.

---

## Quick install (one-liner)

Replace `<your.domain.or.ip>` or omit `--domain` to use a self-signed cert.

```bash
sudo bash -c "apt update && apt install -y curl"
curl -sSL https://raw.githubusercontent.com/CassioCirino/dynatrace-security-lab/main/install.sh | sudo bash -s -- --repo https://github.com/CassioCirino/dynatrace-security-lab.git --domain <your.domain.or.ip>
```

If no domain:

```bash
curl -sSL https://raw.githubusercontent.com/CassioCirino/dynatrace-security-lab/main/install.sh | sudo bash -s -- --repo https://github.com/CassioCirino/dynatrace-security-lab.git
```

---

## What the installer does

* Installs Docker & Docker Compose plugin.
* Clones repo to `/opt/dynatrace-security-lab`.
* Generates a self-signed certificate if needed.
* Creates SQLite DB file and sets permissive permissions (lab-only).
* Launches `nginx` + `vuln-app` containers and registers `systemd` unit for auto-start.

---

## Security notes

* Restrict access with Security Group / firewall to allowed IPs.
* If you must open to the Internet, do it only temporarily and monitor.
* Use SSH tunneling instead of opening ports when possible:

  ```bash
  ssh -i key.pem -L 3000:localhost:3000 ubuntu@<EC2_IP>
  # then browse http://localhost:3000/lab
  ```

---

## Using the front-end (`/lab`) — Quick user manual

### Access

* `https://<domain_or_ip>/lab` or `https://<domain_or_ip>/`
* If using SSH tunnel: `http://localhost:3000/lab`

### Forms & endpoints

* **Product (SQLi)**: GET `/product?id=<value>`
* **Search (SQLi)**: GET `/search?q=<text>`
* **Reflected XSS**: GET `/xss?msg=<text>`
* **Command (lab only)**: GET `/echo?cmd=<command>` (dangerous!)

### Example payloads (lab only)

* SQLi: `1' OR '1'='1`
* XSS: `<script>alert('XSS')</script>`
* Command: `echo hello_lab` (do not fetch sensitive files)

### Instructor flow suggestion

1. Present theory (RASP/RAP, Dynatrace Application Security).
2. Let students explore `/lab`.
3. Run attack scripts and observe Dynatrace detections.
4. Build a dashboard with Vulnerabilities, Attacks, Exposure by service.
5. (Optional) Toggle *Block* in RAP for a live demo of blocking behavior.

---

## Scripts & where to find them

After install: `/opt/dynatrace-security-lab/attack-scripts`

* `./sqli.sh` — SQLi tests
* `./xss.sh` — XSS test
* `python3 cmd_inject.py` — command exec test
* `./simulate-users.sh` — simulate navigation/traffic

---

## Dynatrace integration (essentials)

1. Deploy OneAgent on the EC2 host (Tenant → Deploy → OneAgent).
2. Wait for host & services to appear in Dynatrace.
3. Enable **Application Security** (RAP) in **Monitor** mode for `vuln-app`.
4. Generate test attacks and review `Application Security → Attacks` and `Vulnerabilities`.
5. Use DQL/Grail to create security/business correlation queries.

---

## Admin & housekeeping

* Stop:

  ```bash
  sudo systemctl stop dynatrace-security-lab
  ```
* Start:

  ```bash
  cd /opt/dynatrace-security-lab
  sudo docker compose up -d --build
  ```
* Remove:

  ```bash
  sudo docker compose down
  sudo rm -rf /opt/dynatrace-security-lab
  ```

---

## Final notes

* This repo purposely contains vulnerabilities for teaching. Use responsibly.
* Prefer restricting access and pausing the EC2 after sessions.
* If you want, I can add Let's Encrypt automation (requires domain and open port 80) or a GitHub `gh` script to create the repo automatically.



Qual desses você prefere agora?
