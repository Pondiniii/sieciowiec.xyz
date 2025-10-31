+++
title = "BOOTC w Praktyce: Od Kodu do Urządzenia w 15 Minut"
date = 2025-10-31
description = "Praktyczny przewodnik po BOOTC: pipeline do budowania RPM i obrazów, deployment na urządzenia, OTA updates. Uniwersalna infrastruktura, którą dostosujesz do siebie."
slug = "bootc-w-praktyce"

[taxonomies]
tags = ["bootc", "rhel", "containers", "devops", "cicd", "linux"]

[extra]
mermaid = true
comment = true
+++

Zapomnimy o teorii. Otwierasz terminal i robisz.

Ten post pokazuje jak faktycznie używać BOOTC w produkcji: jak budować RPM-y, obrazy kontenerowe, deployować na urządzenia i robić OTA updates. Prawdziwy kod, który dostosujesz do swojej infrastruktury.

## Jak To Wszystko Działa w Praktyce

Masz dwa repo:
1. **sources/** - kod źródłowy, SPECy RPM, pipeline budujący pakiety
2. **devices/** - Containerfiles, konfiguracja, pipeline budujący obrazy BOOTC

Workflow:
```
Git commit → CI/CD → RPM build (2 min) → BOOTC build (30 sec) → Registry → Devices (5 min)
```

Total: **15-20 minut od kodu do działającego urządzenia.**

vs tradycyjnie: 60+ minut (ISO build, manual install, konfiguracja)

## Pipeline 1: Budowanie Pakietów RPM

### Struktura Repo (sources/)

```
sources/
├── .gitlab-ci.yml              # Pipeline definition (GitLab/GitHub Actions/Jenkins)
└── my-app/                     # Package folder
    ├── src/                    # Source code
    │   ├── main.c
    │   └── Makefile
    └── my-app.spec             # RPM specification
```

### SPEC File (Przykład)

```ini
Name:           my-app
Version:        0.0.6
Release:        1%{?dist}%{?CI_BUILD_SUFFIX}
Summary:        Custom application for my devices

License:        MIT
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  gcc, make, kernel-devel
Requires:       bash

%description
Custom application for my edge devices.

%prep
%autosetup

%build
%{__make} -C src/

%install
%{__make} install DESTDIR=%{buildroot}

%files
/opt/myapp/
/usr/lib/systemd/system/myapp.service

%post
systemctl daemon-reload

%changelog
* Thu Oct 31 2025 Developer <dev@example.com> - 0.0.6-1
- Update application with new features
```

**Kluczowa linia:**
```ini
Release:        1%{?dist}%{?CI_BUILD_SUFFIX}
```

- **DEV build**: `Release` = `1.el9.master.1730376000.a8c12e3f`
- **PROD build**: `Release` = `1.el9` (CI_BUILD_SUFFIX removed)

### CI/CD Pipeline Concept (sources/)

**Uwaga:** Poniżej pokazuję **koncept** - dostosuj do swojego CI/CD (GitLab CI, GitHub Actions, Jenkins, etc.)

```yaml
# Pseudokod - dostosuj do swojego systemu
stages:
  - build-rpm
  - upload-rpm

variables:
  DEV_REPO: "dev-registry.example.com"
  PROD_REPO: "prod-registry.example.com"

build-rpm:
  stage: build-rpm
  image: registry.fedoraproject.org/fedora:39
  script:
    # DEV: Add timestamp suffix to Release field
    - export CI_BUILD_SUFFIX=".${BRANCH}.$(date +%s).${COMMIT_HASH:0:8}"

    # PROD: Remove suffix if building from tag
    - |
      if [[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        unset CI_BUILD_SUFFIX

        # Validate tag matches SPEC Version
        SPEC_VERSION=$(grep "^Version:" *.spec | awk '{print $2}')
        if [[ "$TAG" != "v${SPEC_VERSION}"* ]]; then
          echo "ERROR: Tag $TAG doesn't match Version $SPEC_VERSION"
          exit 1
        fi
      fi

    # Install build dependencies
    - dnf install -y dnf-utils rpm-build

    # Create source tarball
    - tar czf ${PROJECT_NAME}-${VERSION}.tar.gz src/

    # Build RPM
    - rpmbuild -ba --define "_topdir /tmp/rpmbuild" --define "dist .el9" *.spec

    # Save artifacts
    - cp /tmp/rpmbuild/RPMS/*/*.rpm ./

  artifacts:
    paths:
      - "*.rpm"

upload-rpm:
  stage: upload-rpm
  needs:
    - build-rpm
  script:
    # Detect DEV vs PROD from tag
    - |
      if [[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        REPO_URL="${PROD_REPO}"
      else
        REPO_URL="${DEV_REPO}"
      fi

    # Upload RPMs to your repository
    # Przykład: scp, rsync, curl, Nexus API, Artifactory, etc.
    - |
      for rpm in *.rpm; do
        # Dostosuj do swojego repo (curl/scp/API)
        curl -u "${REPO_USER}:${REPO_PASS}" \
          -F "file=@${rpm}" \
          "${REPO_URL}/upload"
      done

    # Regenerate repository metadata (createrepo_c)
    - ssh repo-server "createrepo_c /path/to/rpm-repo"
```

**Dostosuj do swojego CI/CD:**

- **GitLab CI**: użyj `$CI_COMMIT_TAG`, `$CI_COMMIT_BRANCH`, `$CI_COMMIT_SHA`
- **GitHub Actions**: użyj `${{ github.ref }}`, `${{ github.sha }}`
- **Jenkins**: użyj `$GIT_BRANCH`, `$GIT_COMMIT`

### Co Się Dzieje

**DEV build (każdy commit):**
```bash
$ git push origin feature/new-feature
# CI/CD trigger
# → build-rpm (2 min)
# → upload-rpm (10 sec)
# Result: my-app-0.0.6-1.el9.feature.1730376000.a8c12e3f.rpm
```

**PROD build (protected tag):**
```bash
$ git tag -a v0.0.6 -m "Release 0.0.6"
$ git push origin v0.0.6
# CI/CD detects tag
# → validate SPEC matches tag
# → build without CI_BUILD_SUFFIX
# → upload to prod repo
# Result: my-app-0.0.6-1.el9.rpm
```

## Pipeline 2: Budowanie Obrazów BOOTC

### Struktura Repo (devices/)

```
devices/
├── .gitlab-ci.yml              # BOOTC build pipeline
└── my-os/
    ├── Containerfile           # BOOTC recipe
    ├── files/
    │   ├── kargs.d/
    │   │   └── 50-custom.toml  # Kernel arguments
    │   └── etc/
    │       └── myapp.yaml      # Configuration files
    └── README.md
```

### Containerfile (Praktyczny Przykład)

```dockerfile
# Base: CentOS Stream 9 BOOTC
FROM quay.io/centos-bootc/centos-bootc:stream9

# Labels - opisz swój obraz
LABEL org.opencontainers.image.title="My OS"
LABEL org.opencontainers.image.version="0.0.6"

# ===== Layer 1: System Packages =====
# Cached, changes rarely
RUN dnf install -y \
    kernel-modules-extra \
    systemd-container \
    podman \
    vim \
    htop \
    && dnf clean all

# ===== Layer 2: Custom RPMs =====
# Install from YOUR RPM repository
# UWAGA: Dostosuj do swojego repo!
COPY files/custom.repo /etc/yum.repos.d/
RUN dnf install -y \
    --enablerepo=my-custom-repo \
    my-app \
    my-driver \
    && dnf clean all

# ===== Layer 3: System Services =====
# Enable/disable services
RUN systemctl enable myapp.service && \
    systemctl enable podman.socket && \
    systemctl mask kdump.service debug-shell.service

# ===== Layer 4: SSH Hardening =====
RUN sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# ===== Layer 5: Kernel Arguments =====
# CPU isolation, performance tuning, etc.
COPY files/kargs.d/50-custom.toml /usr/lib/bootc/kargs.d/

# ===== Layer 6: Configuration Files =====
# Application config
COPY files/etc/ /etc/

# ===== Layer 7: Sysctl Tweaks =====
RUN echo "kernel.unprivileged_userns_clone=0" > /etc/sysctl.d/99-security.conf && \
    echo "net.ipv4.conf.all.rp_filter=1" >> /etc/sysctl.d/99-security.conf

# ===== Layer 8: Cleanup =====
RUN rm -rf /tmp/* /var/tmp/* && \
    dnf clean all
```

**Kernel Arguments (files/kargs.d/50-custom.toml):**
```toml
# CPU isolation for real-time workloads
# Dostosuj do swojego hardware!
kargs = ["isolcpus=2-7", "nohz_full=2-7", "rcu_nocbs=2-7"]
```

**Custom Repository (files/custom.repo):**
```ini
[my-custom-repo]
name=My Custom RPM Repository
baseurl=https://rpm-repo.example.com/el9/$basearch
enabled=1
gpgcheck=1
gpgkey=https://rpm-repo.example.com/RPM-GPG-KEY
```

{% admonition(type="tip", title="Dostosuj do swojego repo") %}
- Jeśli używasz Nexus/Artifactory: zmień `baseurl` na ich URL
- Jeśli masz lokalny repo: użyj `file:///path/to/repo`
- Jeśli nie masz GPG: ustaw `gpgcheck=0` (tylko DEV!)
{% end %}

### CI/CD Pipeline Concept (devices/)

```yaml
# Pseudokod - dostosuj do swojego CI/CD
stages:
  - build-bootc

variables:
  REGISTRY_DEV: "dev-registry.example.com"
  REGISTRY_PROD: "registry.example.com"

build-bootc:
  stage: build-bootc
  image: quay.io/podman/podman:v5.0
  script:
    # Determine registry and tag based on branch/tag
    - |
      if [[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        REGISTRY="${REGISTRY_PROD}"
        IMAGE_TAG="${TAG:1}"  # Remove 'v' prefix
      else
        REGISTRY="${REGISTRY_DEV}"
        IMAGE_TAG="dev.${BRANCH}.$(date +%s).${COMMIT_HASH:0:8}"
      fi

    # Build BOOTC image
    - |
      podman build \
        --file Containerfile \
        --tag ${REGISTRY}/my-os:${IMAGE_TAG} \
        .

    # Login to your registry
    # Dostosuj: Docker Hub, Quay.io, Harbor, własny registry
    - echo "${REGISTRY_PASSWORD}" | podman login -u "${REGISTRY_USER}" --password-stdin ${REGISTRY}

    # Push image
    - podman push ${REGISTRY}/my-os:${IMAGE_TAG}

    # Tag as latest (DEV only)
    - |
      if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
        podman tag ${REGISTRY}/my-os:${IMAGE_TAG} ${REGISTRY}/my-os:latest
        podman push ${REGISTRY}/my-os:latest
      fi

    # Output digest for verification
    - podman inspect ${REGISTRY}/my-os:${IMAGE_TAG} --format '{{.Digest}}'
```

**Dostosuj do swojego registry:**

- **Docker Hub**: `docker.io/username/my-os:tag`
- **Quay.io**: `quay.io/username/my-os:tag`
- **Harbor**: `harbor.example.com/project/my-os:tag`
- **Własny registry**: `registry.local/my-os:tag`

### Co Się Dzieje

**DEV build:**
```bash
$ git push origin feature/new-config
# CI/CD trigger
# → build-bootc (30 sec with cache)
# → push to dev-registry.example.com
# Image: dev-registry.example.com/my-os:dev.feature.1730376000.a8c12e3f
# Also tagged: latest
```

**PROD build:**
```bash
$ git tag -a v0.0.6 -m "Release 0.0.6"
$ git push origin v0.0.6
# CI/CD trigger
# → build-bootc (30 sec with cache)
# → push to registry.example.com
# Image: registry.example.com/my-os:0.0.6
```

{% admonition(type="tip", title="Layer Caching") %}
Podman cache'uje layers. First build: 5-10 min. Subsequent builds with same layers: 10-30 sec.

Kolejność ma znaczenie: umieszczaj zmieniające się rzeczy (config) na końcu, a stabilne (packages) na początku.
{% end %}

## Deployment na Urządzenia

### Scenariusz A: DEV - Instalacja na Dysk (USB/M.2 Adapter)

Szybkie testowanie: wyciągasz dysk z urządzenia, podłączasz przez adapter USB/M.2, instalujesz obraz.

```bash
# Na twoim laptopie
lsblk
# sda       8:0    0  238.5G  0 disk  (USB adapter)
# ├─sda1    8:1    0    500M  0 part
# └─sda2    8:2    0    238G  0 part

# Pull DEV image
# UWAGA: Zmień na SWÓJ registry!
podman pull dev-registry.example.com/my-os:latest

# Install to disk
# UWAGA: Zmień /dev/sda na SWÓJ dysk! (sprawdź lsblk)
sudo podman run --rm --privileged --pid=host \
  -v /var/lib/containers:/var/lib/containers \
  -v /dev:/dev \
  dev-registry.example.com/my-os:latest \
  bootc install to-disk --wipe /dev/sda
```

**Co się stanie:**
1. Weryfikacja image integrity
2. Partycjonowanie dysku:
   - EFI (500MB)
   - /boot (1GB)
   - / (reszta, **niezaszyfrowane** dla DEV)
3. Instalacja GRUB
4. Konfiguracja kernel arguments z `kargs.d/`
5. Gotowe

**Czas: ~5 minut**

```bash
# Eject disk
sudo eject /dev/sda

# Wkładasz do urządzenia, startujesz
# System bootuje z nowego obrazu
```

{% admonition(type="warning", title="UWAGA: Disk Device") %}
**ZAWSZE** sprawdź `lsblk` przed użyciem `bootc install`!

- Laptop disk: `/dev/nvme0n1` lub `/dev/sda`
- USB adapter: `/dev/sdb`, `/dev/sdc`, etc.
- **Nie pomyl dysków!** `--wipe` wymazuje wszystko!
{% end %}

### Scenariusz B: PROD - Provisioning z Base Image

Urządzenia produkcyjne wymagają szyfrowania. Nie możesz "wlać" zaszyfrowanego dysku offline - TPM2 sealing wymaga działającego systemu.

**Flow:**
1. Instalujesz **base image** (minimalne BOOTC bez aplikacji)
2. Base image bootuje
3. Kopiujesz **final image** na `/var/tmp/`
4. Device wykrywa nowy obraz i robi self-upgrade

**Provision script (provision.sh):**

```bash
#!/bin/bash
set -e

# UWAGA: Dostosuj do swoich wartości!
DEVICE="/dev/sda"                                  # Zmień na swój dysk
BASE_IMAGE="registry.example.com/base-os:latest"   # Minimalna base image
FINAL_IMAGE="registry.example.com/my-os:0.0.6"     # Twój final image

echo "Step 1: Install base image with LUKS+TPM2"
podman pull ${BASE_IMAGE}
sudo podman run --rm --privileged --pid=host \
  -v /var/lib/containers:/var/lib/containers \
  -v /dev:/dev \
  ${BASE_IMAGE} \
  bootc install to-disk \
    --target-transport=containers-storage \
    --wipe ${DEVICE}

echo "Step 2: Copy final image to device"
# Mount new root partition
mkdir -p /mnt/device-root
sudo mount ${DEVICE}3 /mnt/device-root  # Partition 3 = rootfs

# Pull and save final image
podman pull ${FINAL_IMAGE}
sudo podman save -o /mnt/device-root/var/tmp/my-os.tar ${FINAL_IMAGE}

# Unmount
sudo umount /mnt/device-root

echo "Step 3: First boot"
echo "Device will boot base image, detect new image in /var/tmp, and self-upgrade"
```

**Uruchomienie:**
```bash
$ ./provision.sh
# Step 1: Install base image with LUKS+TPM2 (~3 min)
# Step 2: Copy final image to device (~2 min)
# Device ready for first boot

# Wkładasz dysk do urządzenia
# Device bootuje, wykrywa /var/tmp/my-os.tar
# Automatyczny upgrade do final image
# Reboot → final system up
```

**LUKS2 + TPM2 Sealing:**
- Klucz LUKS2 sealed do TPM2 PCR 0, 2, 3 (BIOS, firmware, boot config)
- Jeśli PCRs się zgadzają: TPM2 unlocks automatycznie
- Jeśli PCRs nie pasują (tampered): manual passphrase required

{% admonition(type="info", title="Brak TPM2?") %}
Jeśli Twoje urządzenia nie mają TPM2:
- Użyj `--karg rd.luks.key=/path/to/keyfile` (keyfile on USB)
- Lub pomiń szyfrowanie dla non-critical deployments
- Lub użyj network-based unlock (Clevis + Tang server)
{% end %}

### Scenariusz C: Live Image (Live USB/PXE)

Testowanie przed wdrożeniem: bootable USB bez instalacji na dysk.

**Create live image (create-live-image.sh):**

```bash
#!/bin/bash
set -e

# UWAGA: Dostosuj do swoich wartości!
IMAGE="registry.example.com/my-os:0.0.6"
OUTPUT_DIR="/tmp/live-image"

echo "Creating live image from ${IMAGE}"

# Pull image
podman pull ${IMAGE}

# Extract kernel and initramfs
mkdir -p ${OUTPUT_DIR}
podman run --rm ${IMAGE} cat /boot/vmlinuz-* > ${OUTPUT_DIR}/vmlinuz
podman run --rm ${IMAGE} cat /boot/initramfs-*.img > ${OUTPUT_DIR}/initramfs.img

# Create squashfs rootfs
mkdir -p ${OUTPUT_DIR}/rootfs
podman export $(podman create ${IMAGE}) | tar -xC ${OUTPUT_DIR}/rootfs
mksquashfs ${OUTPUT_DIR}/rootfs ${OUTPUT_DIR}/rootfs.squashfs -comp xz

echo "Live image ready:"
echo "  Kernel: ${OUTPUT_DIR}/vmlinuz"
echo "  Initramfs: ${OUTPUT_DIR}/initramfs.img"
echo "  Rootfs: ${OUTPUT_DIR}/rootfs.squashfs"
echo ""
echo "Copy to USB:"
echo "  sudo dd if=${OUTPUT_DIR}/rootfs.squashfs of=/dev/sdX bs=4M"
```

**Użycie:**
```bash
$ ./create-live-image.sh
# Kernel, initramfs, squashfs generated

# Copy to USB (UWAGA: sprawdź lsblk, zmień /dev/sdX!)
$ sudo dd if=/tmp/live-image/rootfs.squashfs of=/dev/sdX bs=4M status=progress

# Boot device from USB
# System bootuje bez instalacji na dysk
# Możesz testować bez modyfikowania storage
```

### Scenariusz D: OTA Updates (Automatic)

Urządzenia już działają w produkcji. Nowa wersja gotowa. Deployment: automatyczny.

**Setup systemd timer (na urządzeniu):**

```bash
# /etc/systemd/system/bootc-auto-update.service
[Unit]
Description=BOOTC Automatic Update
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/bootc upgrade --check
ExecStartPost=/usr/bin/systemctl reboot

[Install]
WantedBy=multi-user.target
```

```bash
# /etc/systemd/system/bootc-auto-update.timer
[Unit]
Description=BOOTC Automatic Update Timer

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

**Enable:**
```bash
sudo systemctl enable --now bootc-auto-update.timer
```

**Co się dzieje:**
```
Daily at 00:00:
1. bootc upgrade --check
2. Query registry for new image
3. If new version: download and apply
4. Reboot device
5. System boots new version
6. If boot fails: automatic rollback to previous version
```

**Manual trigger:**
```bash
# SSH to device
ssh my-device-01

# Check status
sudo bootc status
# Booted: my-os:0.0.5
# Available: my-os:0.0.6

# Upgrade
sudo bootc upgrade
# Downloading 0.0.6... [######################] 100%
# Staging update...
# Rebooting...

# Device reboots → new version active
```

**Rollback:**
```bash
# If something breaks after update
sudo bootc rollback
sudo systemctl reboot

# Device boots previous version
```

{% admonition(type="success", title="Zero Downtime Updates") %}
BOOTC uses A/B partitioning:
- Current system runs from partition A
- Update downloads to partition B
- Reboot switches to B
- If B fails: automatic fallback to A

Rollback zawsze dostępny.
{% end %}

## Real-World Flow: Developer Perspective

### Morning: Feature Development

```bash
# 9:00 - Clone repo
git clone https://git.example.com/sources/my-app.git
cd my-app

# Check current version
grep "^Version:" *.spec
# Version:        0.0.5

# Create feature branch
git checkout -b feature/new-feature-0.0.6

# Make changes
vim src/main.c
# ... code changes ...

# Update SPEC
vim my-app.spec
# Version:        0.0.6

# Commit
git commit -am "feat: add new feature to version 0.0.6"
git push origin feature/new-feature-0.0.6
```

### CI/CD Reaction

```
10:00 - CI/CD triggered
  ├─ build-rpm (2 min)
  └─ upload-rpm (10 sec)

10:02 - DEV build ready
  Result: my-app-0.0.6-1.el9.feature.1730376000.a8c12e3f.rpm
```

### Testing DEV Build

```bash
# 10:05 - Pull DEV image
podman pull dev-registry.example.com/my-os:latest

# Quick container test
podman run -it --rm dev-registry.example.com/my-os:latest /bin/bash
# Check if your app is installed
rpm -qa | grep my-app
systemctl status myapp.service
exit

# Install to test device (USB adapter)
sudo podman run --rm --privileged --pid=host \
  -v /var/lib/containers:/var/lib/containers \
  -v /dev:/dev \
  dev-registry.example.com/my-os:latest \
  bootc install to-disk --wipe /dev/sdb  # USB disk!

# Boot test device
# Tests pass ✅
```

### Merge to Main

```bash
# 11:00 - Tests passed, merge to main
git checkout main
git merge feature/new-feature-0.0.6
git push origin main

# CI/CD triggers another DEV build for main branch
```

### Production Release

```bash
# 14:00 - Ready for production
git tag -a v0.0.6 -m "Release: version 0.0.6"
git push origin v0.0.6

# CI/CD detects protected tag
# Triggers PROD pipeline
```

### PROD Pipeline

```
14:02 - PROD build triggered
  ├─ Validate: tag v0.0.6 matches SPEC Version 0.0.6 ✅
  ├─ build-rpm (no CI_BUILD_SUFFIX) (2 min)
  ├─ upload-rpm to prod repo (10 sec)
  ├─ build-bootc (30 sec)
  └─ push to prod registry (10 sec)

14:05 - PROD build complete
  RPM: my-app-0.0.6-1.el9.rpm
  Image: registry.example.com/my-os:0.0.6
```

### Deployment to Devices

```bash
# 15:00 - Deploy to devices
# Option 1: Ansible playbook
ansible-playbook -i production deploy-update.yml -e "version=0.0.6"

# Option 2: Manual SSH
ssh my-device-01 "sudo bootc upgrade"
ssh my-device-02 "sudo bootc upgrade"
ssh my-device-03 "sudo bootc upgrade"

# Option 3: Salt, Puppet, Chef - cokolwiek używasz

# Devices reboot one by one
# New version active in 5 minutes
```

### Timeline Summary

```
09:00 - Feature development starts
10:00 - Git push → CI trigger
10:02 - DEV build complete (2 min)
10:05 - Testing starts
11:00 - Tests pass, merge to main
14:00 - Production tag created
14:05 - PROD build complete (5 min)
15:00 - Deployment to devices
15:05 - Devices running new version

Total: ~15-20 minutes from code to production devices
```

vs **Traditional approach:** 60+ minutes (ISO build, manual install, configuration)

## Praktyczne Obserwacje

### Layer Caching: Co Umieszczać Gdzie

**Bad (wszystko razem):**
```dockerfile
FROM base
RUN dnf install -y packages && \
    dnf install -y custom-rpms && \
    systemctl enable services
COPY files/ /
```

Result: każda zmiana w `files/` invaliduje cache i rebuildujesz wszystko.

**Good (warstwy logiczne):**
```dockerfile
FROM base

# Layer 1: System packages (cached for days)
RUN dnf install -y systemd podman vim

# Layer 2: Custom RPMs (cached by version)
RUN dnf install -y my-app-0.0.6

# Layer 3: Services (cached until changed)
RUN systemctl enable myapp.service

# Layer 4: Config (changes often, last layer)
COPY files/ /
```

Result: zmiana w config = rebuild tylko Layer 4 (~5 sec)

### Versioning: Tag Format

**Consistent tagging:**
```bash
# Git tag format
v0.0.6

# SPEC Version
Version:        0.0.6

# RPM filename (PROD)
my-app-0.0.6-1.el9.rpm

# Container image (PROD)
registry.example.com/my-os:0.0.6
```

Pipeline validates: git tag MUST match SPEC Version.

### Testing: Weryfikacja Obrazu

```bash
# Test 1: Run as container
podman run -it --rm registry.example.com/my-os:0.0.6 /bin/bash
rpm -qa | grep my-app
systemctl status myapp.service
exit

# Test 2: Install to test disk
sudo podman run --rm --privileged --pid=host \
  -v /var/lib/containers:/var/lib/containers \
  -v /dev:/dev \
  registry.example.com/my-os:0.0.6 \
  bootc install to-disk --wipe /dev/sdX  # Test disk!

# Boot device, verify:
# - Services running
# - Network configured
# - Applications functional

# Test 3: OTA upgrade test
# Install v0.0.5 on device
# Trigger upgrade to v0.0.6
sudo bootc upgrade
# Verify rollback works
sudo bootc rollback && sudo reboot
```

### Monitoring: Co Obserwować

**Na build server:**
```bash
# Registry disk usage
df -h /var/lib/registry

# Build logs (dostosuj do swojego CI/CD)
journalctl -u gitlab-runner -f    # GitLab
journalctl -u jenkins -f          # Jenkins
docker logs github-runner         # GitHub Actions self-hosted

# RPM repository size
du -sh /var/www/html/rpm-repo/dev/
du -sh /var/www/html/rpm-repo/prod/
```

**Na urządzeniach:**
```bash
# BOOTC status
sudo bootc status
# Shows: booted version, available updates

# Update logs
sudo journalctl -u bootc-fetch-apply-update

# System health
systemctl status
systemctl --failed
```

**Alerts to configure:**
- Pipeline build failure (email/Slack/Discord)
- Registry disk >80% (automated cleanup)
- Device failed to upgrade (rollback automatic, but notify)

### Troubleshooting: Rollback

**Scenariusz: Update wprowadza bug**

```bash
# Device updated to v0.0.6
# Application crashes

# Option 1: Automatic rollback (if boot fails)
# BOOTC detects failed boot → reverts to v0.0.5 automatically

# Option 2: Manual rollback
ssh my-device-01
sudo bootc rollback
sudo systemctl reboot

# Device boots v0.0.5 (previous working version)
```

**Scenariusz: Factory reset**

```bash
# Device corrupted, needs full reset
# Boot from live USB
# Re-install fresh image

sudo podman run --rm --privileged --pid=host \
  -v /var/lib/containers:/var/lib/containers \
  -v /dev:/dev \
  registry.example.com/my-os:0.0.6 \
  bootc install to-disk --wipe /dev/sda

# Device back to known state
```

## Dostosowanie do Różnych CI/CD

### GitLab CI

```yaml
variables:
  CI_BUILD_SUFFIX: ".${CI_COMMIT_BRANCH}.$(date +%s).${CI_COMMIT_SHA:0:8}"

script:
  - |
    if [[ "$CI_COMMIT_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      unset CI_BUILD_SUFFIX
    fi
```

### GitHub Actions

```yaml
env:
  CI_BUILD_SUFFIX: ".${{ github.ref_name }}.$(date +%s).${{ github.sha:0:8 }}"

steps:
  - name: Detect PROD build
    run: |
      if [[ "${{ github.ref }}" =~ ^refs/tags/v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        unset CI_BUILD_SUFFIX
      fi
```

### Jenkins

```groovy
environment {
    CI_BUILD_SUFFIX = ".${env.BRANCH_NAME}.${currentBuild.startTimeInMillis}.${env.GIT_COMMIT.take(8)}"
}

stages {
    stage('Detect PROD') {
        when {
            tag pattern: "v\\d+\\.\\d+\\.\\d+", comparator: "REGEXP"
        }
        steps {
            script {
                env.CI_BUILD_SUFFIX = ""
            }
        }
    }
}
```

## Podsumowanie

BOOTC workflow:

1. **RPM Build**: Git commit → pipeline builds RPM (~2 min) → upload to repo
2. **BOOTC Build**: RPM ready → pipeline builds container image (~30 sec) → push to registry
3. **Deployment DEV**: Pull image → install to disk via USB → boot device (~5 min)
4. **Deployment PROD**: Provision with base image → copy final image → self-upgrade → encrypted with TPM2
5. **OTA Updates**: `bootc upgrade` → download new version → reboot → automatic rollback if fails

**Total time from code to device: 15-20 minutes.**

**Kluczowe punkty dostosowania:**

{% admonition(type="info", title="Dostosuj do siebie") %}
1. **Registry**: Docker Hub, Quay.io, Harbor, własny registry
2. **CI/CD**: GitLab CI, GitHub Actions, Jenkins, Drone, etc.
3. **RPM repo**: Nexus, Artifactory, prosty HTTP server + createrepo_c
4. **Disk device**: `/dev/sda`, `/dev/nvme0n1`, sprawdź `lsblk`
5. **Network config**: Static IP, DHCP, WiFi - dostosuj w `files/etc/`
6. **TPM2**: Jeśli brak, użyj keyfile lub pomiń encryption dla non-critical
{% end %}

Praktycznie, konkretnie, działa. Dla Twojej infrastruktury.

## Dodatkowe Zasoby

- [BOOTC Documentation](https://containers.github.io/bootc/)
- [Podman Documentation](https://docs.podman.io/)
- [RPM Packaging Guide](https://rpm-packaging-guide.github.io/)
- [Fedora SPEC File Guide](https://docs.fedoraproject.org/en-US/packaging-guidelines/)
- [GitLab CI/CD](https://docs.gitlab.com/ee/ci/)
- [GitHub Actions](https://docs.github.com/en/actions)
- [Jenkins Pipeline](https://www.jenkins.io/doc/book/pipeline/)
