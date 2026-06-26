# parsedmarc — Supervision DMARC

Stack de supervision DMARC basée sur [parsedmarc](https://github.com/domainaware/parsedmarc), déployée via Docker Compose.

## Architecture

```
dmarc@example.com (O365 shared mailbox)
        ↓ MS Graph API (Certificate auth)
    parsedmarc
        ↓
  Elasticsearch 8.19.7
        ↓
  Grafana 10.4.18  →  http://localhost:3000
```

## Prérequis

- Docker + Docker Compose
- Accès admin Entra ID (Azure AD) pour créer une app registration
- Une shared mailbox O365 dédiée (ex: `dmarc-reports@example.com`)

## Création de l'app Entra ID

### 1. App registration

Dans [Entra ID > App registrations](https://entra.microsoft.com/) :

1. **New registration** — nom : `parsedmarc`, type : Single tenant
2. Noter le **Tenant ID** et **Application (client) ID**

### 2. Permission API

Dans **API permissions** :

1. Add permission → Microsoft Graph → Application permissions
2. Ajouter `Mail.ReadWrite`
3. **Grant admin consent**

### 3. Certificat (si client secrets bloqués par la policy tenant)

```bash
# Générer clé + certificat auto-signé (2 ans)
openssl req -x509 -newkey rsa:2048 -keyout certs/parsedmarc-key.pem \
  -out certs/parsedmarc-cert.pem -days 730 -nodes \
  -subj "/CN=parsedmarc"

# Fichier combiné requis par azure.identity
cat certs/parsedmarc-key.pem certs/parsedmarc-cert.pem > certs/parsedmarc-combined.pem
```

Dans **Certificates & secrets > Certificates** : uploader `certs/parsedmarc-cert.pem`.

### 4. Restreindre l'accès à la shared mailbox (Exchange Online)

Par défaut, une app avec `Mail.ReadWrite` a accès à toutes les boîtes. Pour la restreindre :

```powershell
# Créer un mail-enabled security group
New-DistributionGroup -Name "parsedmarc-scope" -Type "Security" `
  -PrimarySmtpAddress "parsedmarc-scope@example.com"

# Ajouter la shared mailbox au groupe
Add-DistributionGroupMember -Identity "parsedmarc-scope@example.com" `
  -Member "dmarc-reports@example.com"

# Créer la policy de restriction (utiliser le Client ID de l'app)
New-ApplicationAccessPolicy -AppId "<CLIENT_ID>" `
  -PolicyScopeGroupId "parsedmarc-scope@example.com" `
  -AccessRight RestrictAccess `
  -Description "Restrict parsedmarc to DMARC mailbox only"

# Vérifier (après propagation ~1-2h)
Test-ApplicationAccessPolicy -AppId "<CLIENT_ID>" `
  -MailboxId "dmarc-reports@example.com"
```

## Installation

### 1. Configurer les secrets

```bash
cp .env.example .env
# Remplir PARSEDMARC_MSGRAPH_TENANT_ID, CLIENT_ID, MAILBOX, GRAFANA_PASSWORD
```

### 2. Créer parsedmarc.ini

```bash
cp parsedmarc.ini.example parsedmarc.ini
# Remplir tenant_id, client_id, mailbox
```

### 3. Déposer le certificat

```bash
mkdir -p certs
# Copier parsedmarc-key.pem et parsedmarc-cert.pem dans certs/
cat certs/parsedmarc-key.pem certs/parsedmarc-cert.pem > certs/parsedmarc-combined.pem
```

### 4. Démarrer

```bash
docker compose up -d --build
```

## Commandes utiles

```bash
# Logs parsedmarc
docker compose logs -f parsedmarc

# Forcer un run immédiat
docker compose restart parsedmarc

# Vérifier les index Elasticsearch
curl -s http://localhost:9200/_cat/indices?v

# Grafana (port configurable via GRAFANA_PORT dans .env)
open http://localhost:3000
```

## Fichiers

| Fichier | Rôle | Commité |
|---|---|---|
| `docker-compose.yml` | Stack complète | ✅ |
| `parsedmarc.ini` | Config avec credentials | ❌ gitignored |
| `parsedmarc.ini.example` | Template sans credentials | ✅ |
| `.env` | Secrets (tenant, client, passwords) | ❌ gitignored |
| `.env.example` | Template `.env` | ✅ |
| `certs/` | Clé privée + certificat Azure AD | ❌ gitignored |
| `grafana/dashboards/` | Dashboard Grafana patché | ❌ gitignored |
| `AGENTS.md` | Documentation technique détaillée | ✅ |

## Cycle de traitement

parsedmarc interroge la shared mailbox via MS Graph toutes les 6h, indexe les rapports dans Elasticsearch, puis s'arrête jusqu'au prochain cycle (`sleep 21600`).

## Voir aussi

- [AGENTS.md](AGENTS.md) — décisions techniques, pièges connus, détail des patches Grafana
- [parsedmarc docs](https://domainaware.github.io/parsedmarc/)
