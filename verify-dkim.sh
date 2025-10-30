#!/bin/bash

# Kolory
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== DKIM Key Verification ==="
echo ""

verify_domain() {
    local domain=$1
    local private_key_path="/tmp/docker-mailserver/rspamd/dkim/rsa-2048-mail-${domain}.private.txt"

    echo -e "${YELLOW}Checking ${domain}...${NC}"

    # Pobierz klucz publiczny z DNS (usuń wszystkie whitespace, cudzysłowy, v=DKIM1 itp)
    dns_key=$(dig +short mail._domainkey.${domain} TXT | tr -d '\n\t\r " ' | sed 's/v=DKIM1;k=rsa;p=//')

    if [ -z "$dns_key" ]; then
        echo -e "${RED}✗ DNS record not found for ${domain}${NC}"
        return 1
    fi

    # Pobierz klucz publiczny z pliku .public.txt w kontenerze (wieloliniowy)
    container_key=$(docker exec mailserver cat /tmp/docker-mailserver/rspamd/dkim/rsa-2048-mail-${domain}.public.txt | sed -n '/p=/,/)/p' | tr -d '\n\t "' | sed 's/.*p=//' | sed 's/).*//')

    if [ -z "$container_key" ]; then
        echo -e "${RED}✗ Cannot read private key for ${domain}${NC}"
        return 1
    fi

    # Sprawdź rozmiar klucza
    key_size=$(docker exec mailserver bash -c "openssl rsa -in ${private_key_path} -text -noout 2>&1 | grep 'Private-Key' | grep -oP '\d+'")

    echo "  Key size: ${key_size} bit"

    # Porównaj klucze
    if [ "$dns_key" == "$container_key" ]; then
        echo -e "${GREEN}✓ Keys match perfectly!${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}✗ Keys DO NOT match!${NC}"
        echo "  DNS key length: ${#dns_key}"
        echo "  Container key length: ${#container_key}"
        echo ""
        return 1
    fi
}

# Sprawdź obie domeny
verify_domain "sieciowiec.xyz"
verify_domain "rapidmaker.pl"

echo "=== Verification Complete ==="
