# 🏠 Sieciowiec Server

Personal VPS infrastructure as code. All services in one place.

## 📦 Services

| Service | Domain | Description |
|---------|--------|-------------|
| **Traefik** | - | Reverse proxy + SSL (Let's Encrypt) |
| **CrowdSec** | - | Security / IPS - blocks attacks |
| **RapidMaker** | rapidmaker.pl | 3D printing calculator |
| **Blog** | sieciowiec.xyz | Static blog (Zola) |
| **Mail Server** | mail.rapidmaker.pl | SMTP/IMAP with Rspamd + ClamAV |
| **Obsidian LiveSync** | obsidian-livesync.sieciowiec.xyz | Note sync (CouchDB) |

## 🚀 Quick Start

### First Time Setup

```bash
# 1. Clone or copy to /srv/sieciowiec/
cd /srv/sieciowiec

# 2. Create .env file with secrets
cp .env.example .env
nano .env  # Fill in passwords

# 3. Start services
make up

# 4. Check logs
make logs
```

### Daily Operations

```bash
make up        # Start all
make down      # Stop all
make restart   # Restart all
make logs      # Watch logs
make status    # Container status
```

## 📂 Directory Structure

```
/srv/sieciowiec/
├── docker-compose.yml      # Main orchestration
├── .env                    # Secrets (gitignored)
├── Makefile                # Convenience commands
│
├── volumes/                # Data (gitignored, bind mounts)
│   ├── traefik/
│   │   ├── letsencrypt/    # SSL certificates
│   │   └── logs/           # HTTP access logs
│   ├── crowdsec/           # Security data
│   ├── mailserver/         # Email data (IMPORTANT!)
│   └── couchdb/            # Obsidian notes
│
├── config/                 # Configs (in git)
│   └── crowdsec/
│       └── acquis.yaml     # Log sources
│
└── apps/                   # Application code (in git)
    ├── RapidMaker/
    └── blog/
```

## 🔄 Migration from Old Setup

If migrating from old `/opt/` + named volumes setup:

```bash
# 1. Stop old containers
cd /home/rapidmaker
docker-compose down

# 2. Copy data
sudo rsync -av /opt/traefik/letsencrypt/ /srv/sieciowiec/volumes/traefik/letsencrypt/
sudo rsync -av /opt/mailserver/ /srv/sieciowiec/volumes/mailserver/
sudo rsync -av /opt/crowdsec/ /srv/sieciowiec/volumes/crowdsec/config/
sudo rsync -av /opt/crowdsec-db/ /srv/sieciowiec/volumes/crowdsec/data/

# Copy CouchDB named volumes
docker run --rm -v couchdb-data:/from -v /srv/sieciowiec/volumes/couchdb/data:/to alpine cp -av /from/. /to/
docker run --rm -v couchdb-config:/from -v /srv/sieciowiec/volumes/couchdb/config:/to alpine cp -av /from/. /to/

# 3. Fix permissions
sudo chown -R 1000:1000 /srv/sieciowiec/volumes/

# 4. Start new setup
cd /srv/sieciowiec
make up
```

## 🔐 Security

### CrowdSec Protection
- Monitors Traefik access logs (HTTP attacks)
- Monitors mail server logs (SMTP attacks)
- Monitors SSH logs (brute force)
- Auto-bans IPs via Traefik bouncer

### Rate Limiting
- RapidMaker: 60 req/min
- All services protected

### SSL/TLS
- Automatic Let's Encrypt certificates
- Auto-renewal via Traefik

## 🛠️ Maintenance

### Update Images

```bash
# Edit docker-compose.yml with new versions
nano docker-compose.yml

# Rebuild
make rebuild
```

### Check CrowdSec Decisions

```bash
docker exec crowdsec cscli decisions list
```

### View Traefik Access Logs

```bash
tail -f volumes/traefik/logs/access.log
```

### Rebuild Blog

```bash
docker-compose up zola
docker-compose restart blog
```

## 📋 Backups

**Important directories to backup:**
- `volumes/mailserver/data/` - Email data
- `volumes/traefik/letsencrypt/` - SSL certificates
- `volumes/couchdb/data/` - Obsidian notes
- `docker-compose.yml` + `.env` - Configuration

**With Hetzner:**
Backup entire `/srv/sieciowiec/` directory.

## 🐛 Troubleshooting

### Container won't start
```bash
docker-compose logs <service_name>
```

### CrowdSec not blocking
```bash
# Check if logs are being read
docker exec crowdsec cscli metrics

# Check parsers
docker exec crowdsec cscli hub list
```

### SSL certificate issues
```bash
# Check Traefik logs
docker logs traefik

# Verify acme.json
ls -lh volumes/traefik/letsencrypt/acme.json
```

### Permissions issues
```bash
# Fix all permissions
sudo chown -R 1000:1000 /srv/sieciowiec/volumes/
```

## 📝 Changes from Old Setup

### ✅ Improvements
- **Bind mounts** instead of named volumes (easier backup)
- **Traefik access logs enabled** (CrowdSec now works!)
- **Pinned image versions** (no more `latest` surprises)
- **Clean acquis.yaml** (removed nginx/apache noise)
- **All-in-one directory** (easy backup/restore)
- **Git-ready** (IaC approach)

### 🗑️ Removed
- PZZ Quiz (and postgres database)
- Unused volumes (synapse, orphaned hashes)

## 🔗 Links

- Traefik Dashboard: Enable in docker-compose.yml if needed
- CrowdSec API: `http://localhost:8080`

---

**Last updated:** 2025-10-28
