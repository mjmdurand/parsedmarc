#!/bin/bash
set -e

mkdir -p grafana/provisioning/datasources \
         grafana/provisioning/dashboards \
         grafana/dashboards

echo "Téléchargement du dashboard Grafana parsedmarc..."
curl -fsSL \
  https://raw.githubusercontent.com/domainaware/parsedmarc/master/dashboards/grafana/Grafana-DMARC_Reports.json \
  -o grafana/dashboards/DMARC_Reports.json

echo "OK — lance maintenant : docker compose up -d --build"
