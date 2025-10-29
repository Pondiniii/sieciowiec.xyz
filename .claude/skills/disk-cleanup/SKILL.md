---
name: disk-cleanup
description: Recover disk space from Docker when usage is critical (80%+)
---

## Purpose

Docker accumulates unused images, containers, volumes, and build cache over time. Without periodic cleanup, disk space can reach critical levels, preventing updates and potentially causing service failures. This skill provides safe, effective cleanup strategies.

## When to Use

### Disk Usage Thresholds:

**HEALTHY (< 70%)**:
- No action needed
- Continue monitoring

**WARNING (70-79%)**:
- Schedule cleanup during next maintenance
- Monitor growth rate
- Light cleanup: `docker image prune -a`

**CRITICAL (80-89%)**:
- Immediate cleanup required
- Use `docker system prune -af`
- May need to stop containers first

**EMERGENCY (90%+)**:
- URGENT ACTION REQUIRED
- Stop all containers
- Aggressive cleanup with volumes
- Investigate what's consuming space

### Situations:

1. Before pulling large image updates (e.g., major version bumps)
2. After multiple failed update attempts (orphaned layers)
3. When Docker build cache grows large
4. After removing services from docker-compose.yml
5. Scheduled monthly/quarterly maintenance

## Real Example from 2025-10-28

### Initial State:
```bash
df -h /
# Filesystem      Size  Used Avail Use% Mounted on
# /dev/sda1        38G   32G  4.1G  89%  /
```

**Status**: CRITICAL (89% usage, only 4.1GB free)
**Risk**: Can't pull large images, potential service failures
**Action**: Aggressive cleanup required

### Cleanup Executed:
```bash
# Step 1: Stop all containers to release resources
docker compose down

# Step 2: Aggressive prune with volumes
docker system prune -af --volumes
```

### Output Analysis:
```
Deleted Containers: 0
Deleted Networks: 1 (web)
Deleted Volumes: 12 (unused volumes from old services)
Deleted Images: 90+ images including:
  - Old Traefik: v2.10.x, v3.5.1
  - Old CrowdSec: v1.6.4
  - Old Mailserver: 14.0.0 and legacy versions
  - Old CouchDB: 3.4.2
  - Obsolete projects: fireflyiii, xometry-scrapper
  - Orphaned base images: python, postgres, nginx
  - Build cache and intermediate layers

Total space reclaimed: 11GB
```

### Result:
```bash
df -h /
# Filesystem      Size  Used Avail Use% Mounted on
# /dev/sda1        38G   24G   13G  65%  /
```

**Status**: HEALTHY (65% usage, 13GB free)
**Improvement**: 89% → 65% (24% reduction, 11GB recovered)
**Target exceeded**: Target was 9GB, achieved 11GB

## Commands/Workflow

### Step 1: Assess Current Disk Usage

```bash
# Overall disk usage
df -h /

# Docker-specific disk usage
docker system df

# Detailed breakdown
docker system df -v
```

**Expected output**:
```
TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
Images          45        6         15GB      12GB (80%)
Containers      6         6         2MB       0B (0%)
Local Volumes   8         8         905MB     0B (0%)
Build Cache     0         0         0B        0B
```

### Step 2: Identify What Can Be Cleaned

**Safe to remove**:
- Images not used by any container (untagged/dangling)
- Stopped containers
- Volumes not attached to any container
- Build cache
- Networks not used by any container

**Do NOT remove**:
- Volumes currently in use (data loss risk)
- Images tagged in docker-compose.yml (will need to re-download)
- Currently running containers

### Step 3: Choose Cleanup Strategy

#### Strategy A: Conservative (Service Running)

Use when services must stay up:

```bash
# Remove dangling images only
docker image prune -f

# Remove stopped containers
docker container prune -f

# Remove unused networks
docker network prune -f

# Remove build cache
docker builder prune -f
```

**Expected recovery**: 1-3GB (depends on accumulation)

#### Strategy B: Moderate (Planned Downtime)

Use during maintenance windows:

```bash
# Remove all unused images (not just dangling)
docker image prune -af

# This is safe while services are running
# Only removes images not currently used by containers
```

**Expected recovery**: 5-10GB

#### Strategy C: Aggressive (Critical Cleanup)

Use when disk is critical (80%+) - **USED ON 2025-10-28**:

```bash
# Stop all services first
docker compose down

# Remove EVERYTHING unused (including volumes)
docker system prune -af --volumes

# WARNING: This removes:
# - All stopped containers
# - All networks not used by at least one container
# - All dangling images
# - All build cache
# - All volumes not used by at least one container
```

**Expected recovery**: 10-20GB (depending on accumulation)
**Risk**: Unused volumes are deleted (ensure backups exist)

### Step 4: Restart Services

```bash
# After cleanup, restart services
docker compose up -d

# Verify all services started
docker ps
```

### Step 5: Verify Results

```bash
# Check new disk usage
df -h /

# Check Docker disk usage
docker system df

# Ensure all services are running
docker ps --format "table {{.Names}}\t{{.Status}}"
```

## Safety Considerations

### Before Running Prune Commands

1. **Check for important volumes**:
```bash
docker volume ls
# Review list - ensure no critical data in unused volumes
```

2. **Backup if unsure**:
```bash
# Backup a specific volume
docker run --rm -v VOLUME_NAME:/data -v $(pwd):/backup ubuntu tar czf /backup/volume-backup.tar.gz /data
```

3. **Understand what will be deleted**:
```bash
# DRY RUN - see what would be deleted (without --volumes)
docker system prune -a --dry-run

# Note: --dry-run doesn't support --volumes flag
# To check volumes that would be removed:
docker volume ls -f dangling=true
```

### When NOT to Use --volumes Flag

**Skip --volumes if**:
- Unsure about volume contents
- Any volumes contain irreplaceable data
- Services are temporarily stopped but will restart
- Database volumes exist (postgres, mysql, couchdb)

**Safe to use --volumes if**:
- All important data is in persistent volumes defined in docker-compose.yml
- You've verified `docker volume ls` shows only test/temp volumes as unused
- You have backups of critical data

### Volumes Currently Protected (2025-10-28)

These volumes are defined in docker-compose.yml and won't be deleted even with --volumes:
```yaml
volumes:
  traefik-letsencrypt
  traefik-logs
  crowdsec-db
  crowdsec-config
  mailserver-data
  mailserver-state
  mailserver-logs
  mailserver-config
  couchdb-data
```

They're mounted to running containers, so they're considered "in use".

## Troubleshooting

### Issue: "Volume in Use" Error

**Symptom**:
```
Error response from daemon: remove volume_name: volume is in use
```

**Cause**: Container still referencing the volume (even if stopped)

**Solution**:
```bash
# Find which container is using it
docker ps -a --filter volume=volume_name

# Remove the container first
docker rm container_name

# Then remove volume
docker volume rm volume_name
```

### Issue: Not Enough Space Freed

**Symptom**: Cleanup only freed 1-2GB, still at 80%+ usage

**Investigation**:
```bash
# Check what's using space outside Docker
du -sh /* | sort -hr | head -10

# Check Docker data directory specifically
du -sh /var/lib/docker/*

# Check for large log files
find /var/log -type f -size +100M -exec ls -lh {} \;
```

**Solutions**:
- Large logs: Truncate or rotate log files
- Non-Docker data: Identify and remove large files
- Docker images still present: Verify images were actually removed with `docker images`

### Issue: Services Won't Start After Cleanup

**Symptom**: Containers fail to start after `docker compose up -d`

**Cause**: Required images were removed

**Solution**:
```bash
# Pull missing images
docker compose pull

# Rebuild local images
docker compose build

# Start services
docker compose up -d
```

### Issue: Data Loss from Volume Deletion

**Symptom**: Service starts but data is missing (empty database, etc.)

**Cause**: Critical volume was removed by --volumes flag

**Prevention**:
```bash
# Before aggressive cleanup, list volumes
docker volume ls > volumes-before-cleanup.txt

# After cleanup, compare
docker volume ls > volumes-after-cleanup.txt
diff volumes-before-cleanup.txt volumes-after-cleanup.txt
```

**Recovery**:
- Restore from backup (if available)
- If no backup, data is lost - lesson learned

## Monitoring and Prevention

### Set Up Disk Space Alerts

**Manual check**:
```bash
df -h / | awk 'NR==2 {print $5}' | sed 's/%//'
# Returns just the percentage number
```

**Alert logic**:
```bash
USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $USAGE -gt 80 ]; then
  echo "WARNING: Disk usage at ${USAGE}%"
  echo "Run cleanup immediately"
fi
```

### Scheduled Maintenance

**Recommended cleanup schedule**:
- **Weekly**: Check disk usage (automated monitoring)
- **Monthly**: Light cleanup (`docker image prune -a`)
- **Quarterly**: Moderate cleanup during maintenance window
- **As needed**: Aggressive cleanup if critical

### Identify Space Hogs

**Find large images**:
```bash
docker images --format "{{.Repository}}:{{.Tag}}\t{{.Size}}" | sort -k2 -hr | head -10
```

**Find large volumes**:
```bash
docker system df -v | grep -A 100 "Local Volumes:" | tail -n +2 | sort -k3 -hr | head -10
```

## Lessons Learned (2025-10-28)

### What Worked Well:
1. Stopping containers before cleanup freed more space
2. `--volumes` flag was safe (our volumes are all defined in compose)
3. 11GB recovery exceeded expectations (target was 9GB)
4. Single prune command cleaned everything efficiently
5. All services restarted successfully without issues

### What Was Tricky:
1. Had to verify volumes before using --volumes flag
2. Network "web" was recreated automatically (no issue)
3. Downloaded new images took space back (expected)
4. Entire operation took ~4.5 minutes of downtime

### Best Practices:
1. Always check `df -h` before and after to measure impact
2. Create backup of docker-compose.yml before major operations
3. Document what was cleaned in maintenance reports
4. Verify services are healthy after cleanup
5. Set up recurring cleanup to prevent buildup

### Prevention:
1. Don't let disk usage reach 85%+
2. Clean up after removing services from compose files
3. Remove old images after successful updates
4. Monitor Docker disk usage separately from system usage
5. Consider using Docker's built-in cleanup policies:
   ```yaml
   # In docker-compose.yml
   x-logging: &default-logging
     driver: "json-file"
     options:
       max-size: "10m"
       max-file: "3"
   ```

## Related Skills

- `version-detection` - Often need cleanup before pulling new images
- `major-version-upgrade` - Cleanup helps ensure space for large updates

## Quick Reference

```bash
# Check disk usage
df -h /
docker system df

# Light cleanup (safe, services running)
docker image prune -af

# Moderate cleanup (safe, services running)
docker system prune -af

# Aggressive cleanup (requires downtime)
docker compose down
docker system prune -af --volumes
docker compose up -d

# Verify results
df -h /
docker ps
```

## Automation Potential

Create a cleanup script for scheduled maintenance:

```bash
#!/bin/bash
# cleanup-docker.sh

THRESHOLD=75  # Start cleanup at 75%

USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

if [ $USAGE -gt $THRESHOLD ]; then
  echo "Disk usage at ${USAGE}%, starting cleanup..."

  # Light cleanup (safe)
  docker image prune -af

  # Check again
  USAGE_AFTER=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
  echo "Disk usage after cleanup: ${USAGE_AFTER}%"

  if [ $USAGE_AFTER -gt 85 ]; then
    echo "WARNING: Still above 85%, aggressive cleanup needed"
    # Alert human operator
  fi
else
  echo "Disk usage at ${USAGE}%, no cleanup needed"
fi
```

Add to crontab for monthly execution:
```bash
0 2 1 * * /srv/sieciowiec.xyz/scripts/cleanup-docker.sh
```
