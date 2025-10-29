---
name: major-version-upgrade
description: Handle major version upgrades (X.0.0 → Y.0.0) safely with backup and rollback strategy
---

## Purpose

Major version upgrades (e.g., v14.x → v15.x) carry higher risk than minor/patch updates due to breaking changes, deprecated features, and architectural changes. This skill provides a systematic approach to handle major upgrades safely while maintaining the ability to rollback if issues occur.

## When to Use

### Identifying Major Version Changes

**Semantic Versioning (MAJOR.MINOR.PATCH)**:
- **MAJOR** (X.0.0 → Y.0.0): Breaking changes, may require configuration updates
- **MINOR** (1.X.0 → 1.Y.0): New features, backward compatible
- **PATCH** (1.2.X → 1.2.Y): Bug fixes, backward compatible

**Examples**:
- Mailserver 14.0.0 → 15.1.0: **MAJOR** (first number changed)
- CrowdSec v1.7.0 → v1.7.3: **PATCH** (last number changed)
- Traefik v3.5.1 → v3.5.4: **PATCH** (last number changed)

### When to Be Cautious

**Apply this skill for**:
- Any change in the first version number (14.x → 15.x)
- Upgrades spanning multiple major versions (2.x → 5.x)
- Services labeled as "major release" in release notes
- Changes with "breaking changes" in changelog

**Skip this skill for**:
- Minor version bumps (1.2.x → 1.3.x) - usually safe
- Patch updates (1.2.3 → 1.2.4) - very safe
- Services you control (local builds) - test in dev first

## Real Example from 2025-10-28

### Scenario: Mailserver 14.0.0 → 15.1.0

**Detection**:
```bash
# Current version in docker-compose.yml
grep "docker-mailserver" docker-compose.yml
# image: ghcr.io/docker-mailserver/docker-mailserver:14.0.0

# Latest version from GitHub API
curl -s https://api.github.com/repos/docker-mailserver/docker-mailserver/releases/latest | jq -r '.tag_name'
# Output: 15.1.0

# Analysis:
# Current: 14.0.0 (MAJOR version 14)
# Latest: 15.1.0 (MAJOR version 15)
# Change: MAJOR BUMP (14 → 15)
```

**Risk Assessment**:
- Type: MAJOR version change
- Release date: 2025-08-12 (2.5 months old)
- Stability: HIGH (well-tested, no hotfix releases)
- Breaking changes: YES (documented in changelog)

**Decision**: Proceed with caution using systematic upgrade workflow

### Workflow Applied

**Step 1: Research Breaking Changes**
```bash
# WebSearch for changelog
WebSearch query: "docker-mailserver 15.0.0 changelog breaking changes"
```

**Findings**:
```
Breaking changes in v15.x:
- Removed saslauthd mechanism support for pam, shadow, mysql
- Refactored getmail6
- Deprecated Rspamd config file path check removed
```

**Impact assessment**: None of these affect our configuration (we don't use saslauthd or getmail6)

**Step 2: Create Backup**
```bash
# Backup docker-compose.yml
cp docker-compose.yml docker-compose.yml.backup-20251028-212402

# Optional: Backup volumes if critical data
# (Skipped - our volumes are persistent and not affected by image updates)
```

**Step 3: Update Configuration**
```yaml
# docker-compose.yml
services:
  mailserver:
    image: ghcr.io/docker-mailserver/docker-mailserver:15.1.0  # Changed from 14.0.0
```

**Step 4: Pull New Image**
```bash
docker compose pull mailserver
# Downloading new image (~150MB)
```

**Step 5: Restart Service**
```bash
docker compose up -d mailserver
# or for all services:
docker compose down && docker compose up -d
```

**Step 6: Health Verification**
```bash
# Check container is running
docker ps | grep mailserver

# Check logs for errors
docker logs mailserver --tail 50

# Look for startup errors or warnings
docker logs mailserver 2>&1 | grep -i error
docker logs mailserver 2>&1 | grep -i warn
```

**Result**: Service started successfully, no errors in logs, all subsystems operational

**Step 7: Extended Monitoring**
```bash
# Check service internals
docker exec mailserver supervisorctl status
# Expected: All services (rspamd, clamav, fail2ban, etc.) running

# Test mail functionality (if applicable)
# docker exec mailserver setup email test ...
```

**Outcome**: SUCCESSFUL - All checks passed, major upgrade completed without issues

## Systematic Upgrade Workflow

### Pre-Upgrade Phase

#### 1. Research and Assessment

```bash
# Find latest version
curl -s https://api.github.com/repos/OWNER/REPO/releases/latest | jq -r '.tag_name'

# Check release date
curl -s https://api.github.com/repos/OWNER/REPO/releases/latest | jq -r '.published_at'

# WebSearch for changelog
WebSearch query: "SERVICE_NAME VERSION changelog breaking changes"
```

**Document findings**:
- Major version number change: YES/NO
- Release date: [date]
- Age: [weeks/months]
- Breaking changes: [list]
- Configuration changes required: [list]
- Our services affected: YES/NO

#### 2. Risk Assessment

**Release Age Guidelines**:
- < 1 week: WAIT (hotfixes likely)
- 1-4 weeks: CAUTIOUS (early adopter phase)
- 1-3 months: SAFE (production tested)
- > 6 months: VERY SAFE (mature release)

**Breaking Changes Impact**:
- No breaking changes affecting us: LOW RISK
- Minor config changes needed: MODERATE RISK
- Major refactoring of features we use: HIGH RISK
- Data migration required: CRITICAL RISK

**Service Criticality**:
- Monitoring/logging services: LOW (can be down briefly)
- Web services with users: MODERATE (minimize downtime)
- Email/database services: HIGH (zero data loss tolerance)

#### 3. Backup Strategy

**Always backup**:
```bash
# Configuration files
cp docker-compose.yml docker-compose.yml.backup-$(date +%Y%m%d-%H%M%S)

# Environment files
cp .env .env.backup-$(date +%Y%m%d-%H%M%S)
```

**Backup volumes if**:
- Critical data (databases, mail)
- Breaking changes mention data migration
- Major version jump (e.g., 2.x → 4.x)

**Volume backup example**:
```bash
# List volumes for service
docker volume ls | grep SERVICE_NAME

# Backup a volume
docker run --rm \
  -v VOLUME_NAME:/data \
  -v $(pwd):/backup \
  ubuntu tar czf /backup/volume-backup-$(date +%Y%m%d).tar.gz /data
```

### Upgrade Phase

#### 4. Update Configuration

```bash
# Edit docker-compose.yml
# Change: image: service:14.0.0
# To: image: service:15.1.0

# If breaking changes require config updates, apply them now
# Example: Update environment variables, volume paths, etc.
```

#### 5. Pull New Image

```bash
# For single service
docker compose pull SERVICE_NAME

# For all services
docker compose pull

# Check image size
docker images | grep SERVICE_NAME
```

**Expected**: Download size varies (50MB-500MB typical)

#### 6. Service Restart Strategy

**Option A: Single Service Update (Minimal Downtime)**
```bash
# Update one service at a time
docker compose up -d SERVICE_NAME --force-recreate

# Verify it's healthy
docker ps | grep SERVICE_NAME
docker logs SERVICE_NAME --tail 50

# If good, continue to next service
```

**Option B: Full Stack Restart (Clean State)**
```bash
# Stop all services
docker compose down

# Start all services with new versions
docker compose up -d

# Verify all are healthy
docker ps
```

**Used on 2025-10-28**: Option B (full restart) because:
- Multiple services being updated
- Disk cleanup required downtime anyway
- Clean state preferred after major changes

### Post-Upgrade Phase

#### 7. Health Verification Checklist

**Immediate checks (0-5 minutes)**:
```bash
# Container is running
docker ps | grep SERVICE_NAME
# Status should be "Up" not "Restarting"

# No errors in logs
docker logs SERVICE_NAME --tail 100 | grep -i error
docker logs SERVICE_NAME --tail 100 | grep -i fatal

# Service responds to health checks (if defined)
docker inspect SERVICE_NAME | jq '.[0].State.Health.Status'
# Expected: "healthy"

# Ports are bound correctly
docker port SERVICE_NAME
```

**Service-specific checks**:
```bash
# For web services: Test HTTP endpoint
curl -I http://localhost:PORT

# For databases: Test connection
docker exec SERVICE_NAME psql -U user -c "SELECT 1"

# For mail servers: Check subsystems
docker exec mailserver supervisorctl status

# For reverse proxies: Check routing
curl -H "Host: domain.com" http://localhost
```

**Configuration verification**:
```bash
# Environment variables loaded correctly
docker exec SERVICE_NAME env | grep KEY

# Volumes mounted correctly
docker inspect SERVICE_NAME | jq '.[0].Mounts'

# Network connectivity
docker exec SERVICE_NAME ping other_service
```

#### 8. Extended Monitoring

**24-hour monitoring period**:
- Check logs every 4-6 hours
- Monitor error rates
- Watch for memory leaks (increasing RAM usage)
- Verify cron jobs/scheduled tasks still work
- Test edge cases and less-used features

**Monitoring commands**:
```bash
# Resource usage over time
docker stats SERVICE_NAME --no-stream

# Error count trend
docker logs SERVICE_NAME --since 24h 2>&1 | grep -c ERROR

# Restart count (should be 0)
docker inspect SERVICE_NAME | jq '.[0].RestartCount'
```

#### 9. Documentation

**Update MEMORY.md**:
```markdown
## Update History
- 2025-10-28: Mailserver 14.0.0 → 15.1.0 (MAJOR)
  - Breaking changes: [list]
  - Impact: None (features not used)
  - Status: Successful, monitoring extended 48h
```

**Create maintenance report**: Include:
- What was updated
- Why (version gap detected)
- How (backup → update → verify)
- Breaking changes and impact
- Health check results
- Any issues encountered

### Rollback Phase (If Needed)

#### 10. When to Rollback

**Trigger rollback if**:
- Container won't start (exits immediately)
- Critical errors in logs (data corruption warnings)
- Service functionality broken (can't send mail, etc.)
- Performance degradation (10x slower)
- After 3 troubleshooting attempts without resolution

**Do NOT rollback for**:
- Expected warnings (deprecated features not used)
- Cosmetic log changes
- Minor performance differences
- Non-critical feature issues that can wait

#### 11. Rollback Procedure

```bash
# Step 1: Stop current containers
docker compose down

# Step 2: Restore old configuration
cp docker-compose.yml.backup-20251028-212402 docker-compose.yml

# Step 3: Pull old image (if pruned)
docker compose pull SERVICE_NAME

# Step 4: Start services with old version
docker compose up -d

# Step 5: Verify rollback successful
docker ps | grep SERVICE_NAME
docker logs SERVICE_NAME --tail 50
```

**Restore volumes (if backed up)**:
```bash
# Stop service
docker compose stop SERVICE_NAME

# Restore volume
docker run --rm \
  -v VOLUME_NAME:/data \
  -v $(pwd):/backup \
  ubuntu bash -c "cd /data && rm -rf * && tar xzf /backup/volume-backup-20251028.tar.gz --strip-components=1"

# Restart service
docker compose start SERVICE_NAME
```

#### 12. Document Rollback

**In maintenance report**:
```markdown
## Rollback Performed - SERVICE_NAME

**Original version**: 14.0.0
**Attempted upgrade**: 15.1.0
**Rollback reason**: [specific error/issue]

**Issue details**:
- Error message: [exact error]
- Troubleshooting attempted: [list attempts]
- Impact: [what was broken]

**Rollback actions**:
- Restored docker-compose.yml.backup-[timestamp]
- Reverted to image 14.0.0
- [Restored volumes: YES/NO]

**Current status**: Service operational on old version
**Recommendation**: Research issue, attempt upgrade again after fix available
```

## Troubleshooting Common Issues

### Issue: Container Exits Immediately After Upgrade

**Symptom**:
```bash
docker ps | grep SERVICE_NAME
# Not listed (exited)

docker ps -a | grep SERVICE_NAME
# Exited (1) 2 seconds ago
```

**Diagnosis**:
```bash
# Check exit reason
docker logs SERVICE_NAME

# Common causes:
# - Missing environment variable
# - Incompatible configuration file format
# - Permission issues with volumes
# - Port already in use
```

**Solution path**:
1. Read error message carefully
2. WebSearch: "SERVICE v15 [error message]"
3. Check migration guide for breaking changes
4. Verify environment variables
5. If no solution after 3 attempts: ROLLBACK

### Issue: Service Starts But Features Broken

**Symptom**:
- Container running (Up status)
- No errors in startup logs
- But functionality doesn't work (can't login, can't send mail, etc.)

**Diagnosis**:
```bash
# Check detailed logs
docker logs SERVICE_NAME --tail 200

# Test specific features
# Example: Test mail send
echo "Test" | docker exec -i mailserver mail -s "Test" test@example.com

# Check internal service status
docker exec SERVICE_NAME [service-specific health command]
```

**Solution path**:
1. Identify which feature is broken
2. Check if feature was removed (breaking changes)
3. Look for deprecation warnings in logs
4. WebSearch: "SERVICE v15 [feature] not working"
5. Check if configuration needs update for feature
6. If critical feature removed: ROLLBACK

### Issue: Performance Degradation After Upgrade

**Symptom**:
```bash
# High CPU usage
docker stats SERVICE_NAME
# 90%+ CPU on service that was previously 5%

# Or slow response times
curl -w "%{time_total}\n" http://SERVICE
# 5s response time (was 0.5s before)
```

**Diagnosis**:
```bash
# Check for resource leaks
docker stats SERVICE_NAME --no-stream
# Memory growing over time = memory leak

# Check logs for warnings
docker logs SERVICE_NAME | grep -i warn
```

**Solution path**:
1. Check if performance issue is known (search GitHub issues)
2. Review changelog for performance-related changes
3. Check if new default settings are suboptimal
4. Monitor for 1 hour - some services need warm-up
5. If persistent degradation: ROLLBACK

### Issue: Data Loss or Corruption Warnings

**Symptom**:
```
ERROR: Database schema incompatible
WARNING: Data migration required
FATAL: Cannot read data format from v14
```

**ACTION**: IMMEDIATE ROLLBACK

**Critical response**:
```bash
# DO NOT ATTEMPT TO FIX
# Stop container immediately
docker compose stop SERVICE_NAME

# Rollback immediately
cp docker-compose.yml.backup-[timestamp] docker-compose.yml
docker compose up -d SERVICE_NAME

# Restore volume backup if data was modified
[restore volume procedure]

# Document incident
```

**Why rollback immediately**:
- Data loss is unrecoverable
- Attempting fixes may corrupt data further
- Need to research proper migration procedure
- May need manual migration steps before upgrade

## Best Practices

### Pre-Upgrade

1. Always create timestamped backups
2. Read full changelog, not just summary
3. Check GitHub issues for "v15" problems
4. Assess risk based on service criticality
5. Plan upgrade during low-traffic period

### During Upgrade

6. Update one major service at a time (unless dependencies require batch)
7. Pull images before stopping services (minimize downtime)
8. Monitor logs in real-time during first 60 seconds
9. Have rollback commands ready in terminal
10. Take notes on any unexpected behavior

### Post-Upgrade

11. Don't prune old images immediately (keep for 24h)
12. Extended monitoring for critical services (24-48h)
13. Test edge cases and less-used features
14. Document everything in maintenance report
15. Update MEMORY.md with new version

## Lessons Learned (2025-10-28)

### What Worked Well:
1. GitHub API quickly identified major version gap (14 → 15)
2. Backup strategy was simple but effective
3. Release age (2.5 months) gave confidence in stability
4. Breaking changes review prevented surprises
5. Service started cleanly without issues

### What Was Tricky:
1. Watchtower didn't detect the major version jump
2. Had to manually research breaking changes
3. Assessing impact of breaking changes required understanding our config
4. Deciding whether to proceed or wait required judgment

### Best Practices Validated:
1. Always check release age before major upgrades
2. Breaking changes that don't affect your setup are fine
3. Full service restart after major versions is safer
4. Extended monitoring catches edge case issues
5. Document the upgrade process for future reference

### Would Do Differently:
1. Create automated script to check for major version bumps
2. Set up pre-upgrade volume snapshots for critical services
3. Keep a "known working versions" document
4. Test major upgrades in staging environment first (if available)

## Automation Potential

**Version comparison script**:
```bash
#!/bin/bash
# check-major-bump.sh

CURRENT="14.0.0"
LATEST="15.1.0"

CURRENT_MAJOR=$(echo $CURRENT | cut -d. -f1)
LATEST_MAJOR=$(echo $LATEST | cut -d. -f1)

if [ "$CURRENT_MAJOR" != "$LATEST_MAJOR" ]; then
  echo "MAJOR BUMP DETECTED: $CURRENT → $LATEST"
  echo "Review required before upgrade"
  exit 1
fi
```

**Backup automation**:
```bash
#!/bin/bash
# backup-before-upgrade.sh

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/srv/backups"

# Backup configurations
cp docker-compose.yml "$BACKUP_DIR/docker-compose.yml.backup-$TIMESTAMP"
cp .env "$BACKUP_DIR/.env.backup-$TIMESTAMP"

echo "Backup created: $TIMESTAMP"
echo "Restore with: cp $BACKUP_DIR/docker-compose.yml.backup-$TIMESTAMP docker-compose.yml"
```

## Related Skills

- `version-detection` - How to detect major version bumps
- `disk-cleanup` - Often needed to free space for large image updates

## Quick Reference

```bash
# Detect major version change
CURRENT_MAJOR=$(echo "14.0.0" | cut -d. -f1)
LATEST_MAJOR=$(echo "15.1.0" | cut -d. -f1)
[ "$CURRENT_MAJOR" != "$LATEST_MAJOR" ] && echo "MAJOR BUMP"

# Backup
cp docker-compose.yml docker-compose.yml.backup-$(date +%Y%m%d-%H%M%S)

# Update and restart
# [Edit docker-compose.yml]
docker compose pull SERVICE_NAME
docker compose up -d SERVICE_NAME --force-recreate

# Health check
docker ps | grep SERVICE_NAME
docker logs SERVICE_NAME --tail 50 | grep -i error

# Rollback if needed
cp docker-compose.yml.backup-[timestamp] docker-compose.yml
docker compose up -d SERVICE_NAME --force-recreate
```
