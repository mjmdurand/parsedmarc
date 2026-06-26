# parsedmarc — CLAUDE.md

Déploiement parsedmarc pour la supervision DMARC via O365 shared mailbox.

## Stack

- **parsedmarc** — lit la shared mailbox O365 via MS Graph, indexe dans Elasticsearch
- **Elasticsearch 8.19.7** — stockage des rapports
- **Grafana 10.4.18** — dashboards DMARC

## Commandes essentielles

```bash
# Démarrer la stack
docker compose up -d

# Logs parsedmarc
docker compose logs -f parsedmarc

# Logs Grafana
docker compose logs -f grafana

# Rebuild parsedmarc (après mise à jour requirements.txt)
docker compose build parsedmarc && docker compose up -d parsedmarc

# Vérifier les index Elasticsearch (port non exposé sur l'hôte)
docker compose exec elasticsearch curl -s http://localhost:9200/_cat/indices?v

# Forcer un run immédiat de parsedmarc
docker compose restart parsedmarc
```

## Fichiers clés

| Fichier | Rôle |
|---|---|
| `docker-compose.yml` | Stack complète |
| `parsedmarc/parsedmarc.ini` | Config parsedmarc (auth MS Graph, ES, mailbox) |
| `parsedmarc/requirements.txt` | Version parsedmarc épinglée |
| `parsedmarc/certs/parsedmarc-combined.pem` | Certificat Azure AD (clé privée + cert) |
| `.env` | Secrets (Grafana password) |
| `grafana/provisioning/datasources/elasticsearch.yml` | Datasources Grafana |
| `grafana/dashboards/DMARC_Reports.json` | Dashboard Grafana (patché) |

## Accès

- Grafana : http://localhost:3000 (port configurable via `GRAFANA_PORT` dans `.env`)
- Elasticsearch : interne uniquement (pas de port exposé sur l'hôte)
