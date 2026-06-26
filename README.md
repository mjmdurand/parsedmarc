# parsedmarc — Supervision DMARC example.com

Stack de supervision DMARC basée sur [parsedmarc](https://github.com/domainaware/parsedmarc), déployée via Docker Compose.

## Architecture

```
dmarc-reports@example.com (O365 shared mailbox)
        ↓ MS Graph API (Certificate auth)
    parsedmarc
        ↓
  Elasticsearch 8.19.7
        ↓
  Grafana 10.4.18  →  http://localhost:3000
```

## Prérequis

- Docker + Docker Compose
- Accès à l'app Azure AD (`parsedmarc`) avec permission `Mail.ReadWrite`
- Certificat Azure AD (clé privée + certificat PEM)

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

### 4. Télécharger le dashboard Grafana

```bash
./setup.sh
```

### 5. Démarrer

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

# Grafana
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
| `grafana/dashboards/` | Dashboard (généré par `setup.sh`) | ❌ gitignored |
| `AGENTS.md` | Documentation technique détaillée | ✅ |

## Cycle de traitement

parsedmarc interroge la shared mailbox via MS Graph toutes les 6h, indexe les rapports dans Elasticsearch, puis s'arrête jusqu'au prochain cycle (`sleep 21600`).

## Voir aussi

- [AGENTS.md](AGENTS.md) — décisions techniques, pièges connus, détail des patches Grafana
- [parsedmarc docs](https://domainaware.github.io/parsedmarc/)
