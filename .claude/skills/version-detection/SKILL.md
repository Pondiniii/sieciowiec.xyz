---
name: version-detection
description: Detect latest versions of Docker services using WebSearch and GitHub API
---

## Purpose

Watchtower and similar tools can miss version updates, especially major version bumps or when services use specific version tags. This skill provides a reliable method to detect the latest stable releases for all containerized services using WebSearch and GitHub API.

## When to Use

- During routine maintenance runs to check for updates
- When Watchtower reports no updates but you suspect new versions exist
- Before planning major upgrades to understand version gaps
- When verifying if a service is truly at the latest stable release
- To detect major vs minor version changes (for risk assessment)

## Why This Matters

**Real Example from 2025-10-28**:
- Watchtower showed: Mailserver 14.0.0 (no updates)
- Reality: Mailserver 15.1.0 was available (MAJOR bump)
- Gap: 1+ major versions behind (released 2025-08-12)
- Risk: Missing security fixes and features for 2.5 months

Watchtower limitations:
- Can't detect major version jumps when using specific tags
- Doesn't work with `latest` tag properly
- Requires registry polling which may be rate-limited
- Won't suggest major versions if pinned to minor versions

## Commands/Workflow

### Step 1: Identify Services and Their Repositories

Current services (as of 2025-10-28):
```bash
# Extract images from docker-compose.yml
grep "image:" /srv/sieciowiec.xyz/docker-compose.yml
```

Service mapping:
| Service | Image | GitHub Repo |
|---------|-------|-------------|
| Traefik | traefik:v* | traefik/traefik |
| CrowdSec | crowdsecurity/crowdsec:v* | crowdsecurity/crowdsec |
| Mailserver | docker-mailserver:* | docker-mailserver/docker-mailserver |
| Blog | static-web-server:* | static-web-server/static-web-server |
| Obsidian | couchdb:* | apache/couchdb |

### Step 2: Use WebSearch for Latest Release

**Method 1: GitHub Releases Page**
```bash
# Search pattern for each service
WebSearch query: "traefik latest release github 2025"
WebSearch query: "crowdsec latest release github 2025"
WebSearch query: "docker-mailserver latest release github 2025"
```

Tips:
- Include current year to get recent results
- Look for "Releases" page or "Latest release" tag
- Avoid pre-release, beta, or RC versions

### Step 3: Verify with GitHub API (Most Reliable)

**GitHub API for Latest Release**:
```bash
# General pattern
curl -s https://api.github.com/repos/{owner}/{repo}/releases/latest | jq -r '.tag_name'

# Specific examples used on 2025-10-28:
curl -s https://api.github.com/repos/traefik/traefik/releases/latest | jq -r '.tag_name'
# Output: v3.5.4

curl -s https://api.github.com/repos/crowdsecurity/crowdsec/releases/latest | jq -r '.tag_name'
# Output: v1.7.3

curl -s https://api.github.com/repos/docker-mailserver/docker-mailserver/releases/latest | jq -r '.tag_name'
# Output: 15.1.0 (MAJOR BUMP from 14.0.0)

curl -s https://api.github.com/repos/static-web-server/static-web-server/releases/latest | jq -r '.tag_name'
# Output: v2.39.0
```

**If jq is not available**:
```bash
curl -s https://api.github.com/repos/traefik/traefik/releases/latest | grep '"tag_name"' | cut -d'"' -f4
```

### Step 4: Compare Versions

**Version comparison logic**:
```bash
# Current version (from docker-compose.yml)
CURRENT="14.0.0"

# Latest version (from GitHub API)
LATEST="15.1.0"

# Manual comparison
echo "Current: $CURRENT"
echo "Latest: $LATEST"

# Detect major version change
CURRENT_MAJOR=$(echo $CURRENT | cut -d. -f1)
LATEST_MAJOR=$(echo $LATEST | cut -d. -f1)

if [ "$CURRENT_MAJOR" != "$LATEST_MAJOR" ]; then
  echo "WARNING: MAJOR version bump detected ($CURRENT_MAJOR -> $LATEST_MAJOR)"
  echo "Review changelog before updating"
else
  echo "MINOR/PATCH update (safe to apply)"
fi
```

### Step 5: Check Release Date and Stability

```bash
# Get release date from GitHub API
curl -s https://api.github.com/repos/docker-mailserver/docker-mailserver/releases/latest | jq -r '.published_at'
# Output: 2025-08-12T10:30:00Z

# Calculate age
# If release is > 1 month old and no follow-up releases, likely stable
# If release is < 1 week old, consider waiting for hotfixes
```

**Stability assessment rules**:
- Release > 1 month old + no critical issues = SAFE
- Release < 1 week old = WAIT (potential hotfixes coming)
- Multiple patch releases in short time = UNSTABLE, wait for stability
- Major version with long gap = SAFE (tested in production)

## Examples from 2025-10-28 Maintenance

### Example 1: Detecting Mailserver Major Bump

**Context**: docker-compose.yml had `docker-mailserver:14.0.0`

**Step 1 - WebSearch**:
```
Query: "docker-mailserver latest release github 2025"
Result: Found v15.1.0 released on August 12, 2025
```

**Step 2 - GitHub API Verification**:
```bash
curl -s https://api.github.com/repos/docker-mailserver/docker-mailserver/releases/latest | jq -r '.tag_name'
# Output: 15.1.0
```

**Step 3 - Version Analysis**:
- Current: 14.0.0 (MAJOR version 14)
- Latest: 15.1.0 (MAJOR version 15)
- Change type: MAJOR BUMP
- Release date: 2025-08-12 (2.5 months ago)
- Stability: HIGH (tested in wild for 2.5 months)

**Step 4 - Changelog Review**:
```
WebSearch query: "docker-mailserver 15.0.0 changelog breaking changes"
Found breaking changes:
- Removed saslauthd mechanism support for pam, shadow, mysql
- Refactored getmail6
- Deprecated Rspamd config file path check removed
```

**Decision**: Proceed with update (stable, well-tested, breaking changes don't affect our setup)

### Example 2: CrowdSec Minor Update

**Context**: docker-compose.yml had `crowdsec:v1.7.0`

**GitHub API Check**:
```bash
curl -s https://api.github.com/repos/crowdsecurity/crowdsec/releases/latest | jq -r '.tag_name'
# Output: v1.7.3
```

**Analysis**:
- Current: v1.7.0
- Latest: v1.7.3
- Change type: PATCH updates (1.7.0 -> 1.7.3)
- Risk level: LOW (patch releases are typically safe)

**Decision**: Safe to update immediately

### Example 3: Traefik Already Latest

**Context**: docker-compose.yml had `traefik:v3.5.4`

**GitHub API Check**:
```bash
curl -s https://api.github.com/repos/traefik/traefik/releases/latest | jq -r '.tag_name'
# Output: v3.5.4
```

**Analysis**: Already at latest version, no action needed

## Troubleshooting

### Issue: GitHub API Rate Limiting

**Symptom**:
```bash
curl https://api.github.com/repos/traefik/traefik/releases/latest
# {"message":"API rate limit exceeded"}
```

**Solution**: Use GitHub token (if available):
```bash
curl -H "Authorization: token YOUR_GITHUB_TOKEN" \
  https://api.github.com/repos/traefik/traefik/releases/latest | jq -r '.tag_name'
```

Or use WebSearch as fallback

### Issue: Version Tag Format Varies

**Problem**: Some repos use `v1.2.3`, others use `1.2.3`

**Solution**: Strip the 'v' prefix for comparison:
```bash
VERSION=$(curl -s https://api.github.com/repos/owner/repo/releases/latest | jq -r '.tag_name')
VERSION_CLEAN=${VERSION#v}  # Remove leading 'v' if present
```

### Issue: Can't Find GitHub Repository

**Problem**: Docker Hub image doesn't clearly indicate source repo

**Solution**: Search Docker Hub or image description:
```bash
# Docker Hub API (limited info)
curl -s https://hub.docker.com/v2/repositories/{namespace}/{image}/tags

# Or WebSearch
WebSearch query: "{image-name} github repository"
```

### Issue: Service Uses Docker Hub, Not GitHub

**Problem**: Some images (like official postgres, nginx) don't have GitHub releases

**Solution**: Check Docker Hub tags page:
```bash
# Use WebSearch
WebSearch query: "couchdb docker hub tags latest"

# Or Docker Hub API
curl -s "https://hub.docker.com/v2/repositories/library/couchdb/tags?page_size=10" | jq -r '.results[].name'
```

## Lessons Learned (2025-10-28)

### What Worked Well:
1. GitHub API is most reliable source (no HTML parsing needed)
2. WebSearch provides good context (release notes, breaking changes)
3. Combining both methods catches everything Watchtower misses
4. Checking release date helps assess stability

### What Was Tricky:
1. Watchtower completely missed the Mailserver 14->15 major bump
2. Version tag formats vary (v1.2.3 vs 1.2.3)
3. Some services use semantic versioning, others don't
4. Need to manually check for breaking changes in major bumps

### Best Practices:
1. Always check GitHub API first (most accurate)
2. Use WebSearch to find changelog/breaking changes
3. For major bumps, review release notes before updating
4. Document the version gap and release date in reports
5. If major version is >1 month old with no hotfixes, likely stable

## Automation Potential

**Future enhancement**: Create a script to check all services:

```bash
#!/bin/bash
# check-versions.sh

REPOS=(
  "traefik/traefik"
  "crowdsecurity/crowdsec"
  "docker-mailserver/docker-mailserver"
  "static-web-server/static-web-server"
)

for REPO in "${REPOS[@]}"; do
  LATEST=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | jq -r '.tag_name')
  echo "$REPO: $LATEST"
done
```

This would speed up future maintenance runs significantly.

## Related Skills

- `major-version-upgrade` - How to handle major version bumps safely
- `disk-cleanup` - Often needed before pulling new images
