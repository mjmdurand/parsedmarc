# AGENTS.md — Documentation technique pour agents IA

## Architecture

```
dmarc@example.com (O365 shared mailbox)
        ↓ MS Graph API (Certificate auth)
    parsedmarc
        ↓
  Elasticsearch 8.19.7
        ↓
  Grafana 10.4.18
```

## Authentification Azure AD

- **App** : app registration Entra ID (voir README pour la procédure)
- **Tenant ID** : dans `.env` (`PARSEDMARC_MSGRAPH_TENANT_ID`)
- **Client ID** : dans `.env` (`PARSEDMARC_MSGRAPH_CLIENT_ID`)
- **Auth method** : `Certificate` (pas `client_credentials` — valeur invalide pour mailsuite)
- **Certificat** : `certs/parsedmarc-combined.pem` (clé privée + cert concaténés)
- **Permission API** : `Mail.ReadWrite` Application (pas `Mail.Read` — parsedmarc crée un dossier Archive)
- **Application Access Policy** : `RestrictAccess` sur un mail-enabled security group
  - Le groupe contient uniquement la shared mailbox DMARC
  - Policy Exchange Online, pas Entra ID

## Décisions et pièges connus

### parsedmarc auth_method
La valeur correcte est `Certificate` (avec majuscule). `client_credentials` n'est pas reconnu par mailsuite — voir `mailsuite/mailbox/graph.py` classe `AuthMethod`.

### Certificat PEM combiné
Azure AD Certificate auth (`azure.identity.CertificateCredential`) nécessite un seul fichier PEM contenant clé privée ET certificat :
```bash
cat certs/parsedmarc-key.pem certs/parsedmarc-cert.pem > certs/parsedmarc-combined.pem
```

### Application Access Policy et shared mailbox
La policy `RestrictAccess` nécessite un **mail-enabled security group** comme scope (pas une adresse de boîte directement). Créé via :
```powershell
New-DistributionGroup -Name "parsedmarc-scope" -Type "Security" -PrimarySmtpAddress "parsedmarc-scope@example.com"
Add-DistributionGroupMember -Identity "parsedmarc-scope@example.com" -Member "dmarc-reports@example.com"
```
La propagation peut prendre 1-2h. `Test-ApplicationAccessPolicy` peut retourner "Allowed" avant que l'enforcement API soit effectif.

### Grafana 10.x — plugin Elasticsearch
`grafana/grafana:latest` (11.x+) tente de mettre à jour le plugin Elasticsearch bundled mais échoue (permission denied sur `/usr/share/grafana/data/plugins-bundled/`), rendant le plugin inutilisable. **Utiliser `grafana/grafana:10.4.18`**.

### Grafana datasource — interval Monthly
`interval: Monthly` dans `jsonData` de la datasource Elasticsearch fait que Grafana génère des index comme `dmarc_aggregate-2026.06` (`.` comme séparateur). Les vrais index parsedmarc utilisent `-` (`dmarc_aggregate-2026-06`). **Ne pas mettre `interval` dans la datasource** — utiliser uniquement le wildcard `dmarc_aggregate*`.

### Dashboard DMARC_Reports.json — modifications appliquées
Le fichier `grafana/dashboards/DMARC_Reports.json` est le dashboard officiel parsedmarc avec les patches suivants :
1. **Migration piechart** : `grafana-piechart-panel` → `piechart` natif Grafana 10 (Angular deprecated)
2. **Format datasource panels** : `"datasource": "$datasourceag"` → `{"type": "elasticsearch", "uid": "$datasourceag"}` (format Grafana 10)
3. **date_histogram interval** : `fixed_interval: "auto"` → `interval: "$__interval"` (évite "too many buckets" ES 8.x)
4. **Piechart reducer** : ajout `reduceOptions.calcs: ["sum"]` (sinon "No data" sur les donuts)
5. **Variables datasource** : `current.value` patché à `parsedmarc-aggregate` / `parsedmarc-forensic`

### parsedmarc cycle exit/restart
Avec MS Graph, parsedmarc traite les emails en batch et exit proprement (code 0). Ce n'est pas un mode watch continu. Le container est configuré pour tourner toutes les 6h via `sleep 21600` dans la commande.

## Mise à jour parsedmarc

1. Modifier la version dans `requirements.txt`
2. `docker compose build parsedmarc`
3. `docker compose up -d parsedmarc`

## Structure des index Elasticsearch

| Index | Contenu |
|---|---|
| `dmarc_aggregate-YYYY-MM` | Rapports agrégés RUA |
| `dmarc_forensic-YYYY-MM` | Rapports forensics RUF |
| `smtp_tls-YYYY-MM` | Rapports SMTP TLS |

Champ de temps : `date_range` (tableau de 2 dates : début et fin de la période du rapport).

## DNS DMARC example.com

Enregistrement TXT à maintenir sur `_dmarc.example.com` :
```
v=DMARC1; p=none; rua=mailto:dmarc-reports@example.com; ruf=mailto:dmarc-reports@example.com; fo=1
```
Évolution recommandée : `p=none` → `p=quarantine` → `p=reject` une fois l'alignement validé.
