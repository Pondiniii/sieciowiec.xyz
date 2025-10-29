#!/bin/bash
# Extract certificates for mail.sieciowiec.xyz from acme.json
# This is needed because docker-mailserver v15 only extracts SSL_DOMAIN cert

set -e

ACME_JSON="/srv/sieciowiec.xyz/volumes/traefik/letsencrypt/acme.json"
CERT_DIR="/srv/sieciowiec.xyz/volumes/mailserver/config/ssl"
DOMAIN="mail.sieciowiec.xyz"

echo "Extracting certificate for $DOMAIN from acme.json..."

# Create cert directory
mkdir -p "$CERT_DIR"

# Extract cert and key using jq
jq -r ".letsencrypt.Certificates[] | select(.domain.main==\"$DOMAIN\") | .certificate" "$ACME_JSON" | base64 -d > "$CERT_DIR/$DOMAIN.crt"
jq -r ".letsencrypt.Certificates[] | select(.domain.main==\"$DOMAIN\") | .key" "$ACME_JSON" | base64 -d > "$CERT_DIR/$DOMAIN.key"

# Set permissions
chmod 644 "$CERT_DIR/$DOMAIN.crt"
chmod 600 "$CERT_DIR/$DOMAIN.key"

echo "✅ Certificate extracted to $CERT_DIR/"
ls -lh "$CERT_DIR"
