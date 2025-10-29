# Agent Version Check Workflow

## Overview
Agent must check GitHub releases and Docker Hub APIs to detect new versions, including major version bumps.

## Service Version Check Commands

### 1. Traefik (GitHub)
```bash
# Get latest version
LATEST=$(curl -sL https://api.github.com/repos/traefik/traefik/releases/latest | jq -r '.tag_name')
CURRENT="v3.5.4"
echo "Traefik: $CURRENT -> $LATEST"
```

### 2. CrowdSec (GitHub)
```bash
# Get latest version
LATEST=$(curl -sL https://api.github.com/repos/crowdsecurity/crowdsec/releases/latest | jq -r '.tag_name')
CURRENT="v1.7.0"
echo "CrowdSec: $CURRENT -> $LATEST"
```

### 3. Docker Mailserver (GitHub)
```bash
# Get latest version
LATEST=$(curl -sL https://api.github.com/repos/docker-mailserver/docker-mailserver/releases/latest | jq -r '.tag_name')
CURRENT="14.0.0"
echo "Mailserver: $CURRENT -> $LATEST"
```

### 4. Static Web Server (GitHub)
```bash
# Get latest version
LATEST=$(curl -sL https://api.github.com/repos/static-web-server/static-web-server/releases/latest | jq -r '.tag_name')
CURRENT="v2.38.1"
echo "Static-web-server: $CURRENT -> $LATEST"
```

### 5. CouchDB (Docker Hub)
```bash
# Get latest stable version (semver only)
LATEST=$(curl -sL https://hub.docker.com/v2/repositories/library/couchdb/tags?page_size=100 | \
  jq -r '.results[].name' | \
  grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | \
  sort -V | \
  tail -1)
CURRENT="3.5.0"
echo "CouchDB: $CURRENT -> $LATEST"
```

### 6. RapidMaker (Local Build)
```bash
# Skip - local build, no registry check
echo "RapidMaker: local build (skip)"
```

## Complete Check Script

```bash
#!/bin/bash

echo "=== Checking for updates ==="

# Traefik
TRAEFIK_LATEST=$(curl -sL https://api.github.com/repos/traefik/traefik/releases/latest | jq -r '.tag_name')
echo "Traefik: v3.5.4 -> $TRAEFIK_LATEST"

# CrowdSec
CROWDSEC_LATEST=$(curl -sL https://api.github.com/repos/crowdsecurity/crowdsec/releases/latest | jq -r '.tag_name')
echo "CrowdSec: v1.7.0 -> $CROWDSEC_LATEST"

# Mailserver
MAILSERVER_LATEST=$(curl -sL https://api.github.com/repos/docker-mailserver/docker-mailserver/releases/latest | jq -r '.tag_name')
echo "Mailserver: 14.0.0 -> $MAILSERVER_LATEST"

# Static Web Server
SWS_LATEST=$(curl -sL https://api.github.com/repos/static-web-server/static-web-server/releases/latest | jq -r '.tag_name')
echo "Static-web-server: v2.38.1 -> $SWS_LATEST"

# CouchDB
COUCHDB_LATEST=$(curl -sL https://hub.docker.com/v2/repositories/library/couchdb/tags?page_size=100 | \
  jq -r '.results[].name' | \
  grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | \
  sort -V | \
  tail -1)
echo "CouchDB: 3.5.0 -> $COUCHDB_LATEST"
```

## Version Comparison Logic

```bash
# Function to compare versions
compare_versions() {
  local current=$1
  local latest=$2

  # Remove 'v' prefix if present
  current=${current#v}
  latest=${latest#v}

  if [ "$current" = "$latest" ]; then
    echo "UP_TO_DATE"
  else
    # Check if major version changed
    current_major=$(echo $current | cut -d. -f1)
    latest_major=$(echo $latest | cut -d. -f1)

    if [ "$current_major" != "$latest_major" ]; then
      echo "MAJOR_UPDATE"
    else
      echo "MINOR_UPDATE"
    fi
  fi
}

# Example usage
STATUS=$(compare_versions "14.0.0" "15.1.0")
echo "Status: $STATUS"  # Output: MAJOR_UPDATE
```

## Agent Update Workflow

1. **Check all versions** using above commands
2. **Categorize updates**:
   - UP_TO_DATE: Skip
   - MINOR_UPDATE: Safe to auto-update
   - MAJOR_UPDATE: Flag for review, update with caution
3. **Backup** docker-compose.yml
4. **Update** docker-compose.yml with new versions
5. **Pull** new images: `docker-compose pull`
6. **Recreate** containers: `docker-compose up -d --force-recreate`
7. **Health check** all services
8. **Rollback** if any service fails
9. **Document** changes and commit

## Rate Limiting

GitHub API: 60 requests/hour (unauthenticated)
Docker Hub API: No strict limit for reads

Agent should cache results and not check more than once per maintenance run.

## Error Handling

```bash
# Example with error handling
LATEST=$(curl -sL --max-time 10 https://api.github.com/repos/traefik/traefik/releases/latest | jq -r '.tag_name' 2>/dev/null)

if [ -z "$LATEST" ] || [ "$LATEST" = "null" ]; then
  echo "ERROR: Failed to fetch Traefik version"
  # Fall back to docker-compose.yml current version
  LATEST="v3.5.4"
fi
```

## Current State (2025-10-28)

| Service | Current | Latest Available | Action Needed |
|---------|---------|------------------|---------------|
| Traefik | v3.5.4 | v3.5.4 | None |
| CrowdSec | v1.7.0 | v1.7.3 | Minor update |
| Mailserver | 14.0.0 | v15.1.0 | MAJOR update |
| Static-web-server | v2.38.1 | v2.39.0 | Minor update |
| CouchDB | 3.5.0 | 3.5.0 | None |
| RapidMaker | local | N/A | Local build |
