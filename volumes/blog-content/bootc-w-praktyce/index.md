+++
title = "BOOTC w Praktyce: Od Kodu do Urządzenia w 15 Minut"
date = 2025-10-31
description = "Praktyczny przewodnik po BOOTC: pipeline do budowania RPM i obrazów, deployment na urządzenia, OTA updates. Prawdziwy kod, które działa."
slug = "bootc-w-praktyce"

[taxonomies]
tags = ["bootc", "rhel", "containers", "devops", "cicd", "linux"]

[extra]
mermaid = true
comment = true
+++

Zapomnimy o teorii. Otwierasz terminal i robisz.

Ten post pokazuje jak faktycznie używać BOOTC w produkcji: jak budować RPM-y, obrazy kontenerowe, deployować na urządzenia i robić OTA updates. Prawdziwy kod z działającego systemu.

## Jak To Wszystko Działa w Praktyce

Masz dwa repo:
1. **sources/** - kod źródłowy, SPECy RPM, pipeline budujący pakiety
2. **devices/** - Containerfiles, konfiguracja, pipeline budujący obrazy BOOTC

Workflow:
```
Git commit → GitLab CI/CD → RPM build (2 min) → BOOTC build (30 sec) → Registry → Devices (5 min)
```

Total: **15-20 minut od kodu do działającego urządzenia.**

vs tradycyjnie: 60+ minut (ISO build, manual install, konfiguracja)

## Pipeline 1: Budowanie Pakietów RPM

### Struktura Repo (sources/)

```
sources/
├── .gitlab-ci.yml              # Pipeline definition
└── rp201-02-dpdk/              # Package folder
    ├── src/                    # Source code
    │   ├── main.c
    │   └── Makefile
    └── rp201-02-dpdk.spec      # RPM specification
```

### SPEC File (Przykład)

```ini
Name:           rp201-02-dpdk
Version:        0.0.6
Release:        1%{?dist}%{?CI_BUILD_SUFFIX}
Summary:        DPDK custom build for RP201-02
License:        MIT

Source0:        %{name}-%{version}.tar.gz

BuildRequires:  gcc, make, kernel-devel
Requires:       bash

%description
Custom DPDK build for RP201-02 device.

%prep
%autosetup

%build
%{__make} -C src/
dpdk_build="%{_builddir}/dpdk" ./build.sh

%install
%{__make} install DESTDIR=%{buildroot}

%files
/opt/dpdk/
/lib/modules/*/extra/dpdk.ko

%post
depmod -a

%changelog
* Thu Oct 31 2025 Developer <dev@example.com> - 0.0.6-1
- Update DPDK with memory pooling
```

**Kluczowa linia:**
```ini
Release:        1%{?dist}%{?CI_BUILD_SUFFIX}
```

- **DEV build**: `Release` = `1.el9.master.1730376000.a8c12e3f`
- **PROD build**: `Release` = `1.el9` (CI_BUILD_SUFFIX removed)

### GitLab CI Pipeline (sources/.gitlab-ci.yml)

```yaml
stages:
  - build-rpm
  - upload-rpm
  - regenerate-repo

variables:
  DEV_REG_URL: "dev-reg.budowaczka.transbit.com.pl"
  PROD_REG_URL: "prod-reg.budowaczka.transbit.com.pl"
  OFFLINE_REPO_FILE: "file:///builds/data/offline.repo"

build-rpm:
  stage: build-rpm
  image: registry.fedoraproject.org/fedora:39
  script:
    # DEV: Add timestamp suffix
    - export CI_BUILD_SUFFIX=".${CI_COMMIT_BRANCH}.$(date +%s).${CI_COMMIT_SHA:0:8}"

    # PROD: Remove suffix and validate tag
    - |
      if [[ "$CI_COMMIT_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        unset CI_BUILD_SUFFIX

        # Tag must match SPEC Version
        SPEC_VERSION=$(grep "^Version:" *.spec | awk '{print $2}')
        if [[ "$CI_COMMIT_TAG" != "v${SPEC_VERSION}"* ]]; then
          echo "ERROR: Tag $CI_COMMIT_TAG doesn't match Version $SPEC_VERSION"
          exit 1
        fi
      fi

    # Install build dependencies
    - mkdir -p /etc/yum.repos.d/
    - cp /builds/data/offline.repo /etc/yum.repos.d/offline.repo
    - dnf install -y dnf-utils rpm-build

    # Create source tarball
    - git archive --prefix="${CI_PROJECT_NAME}-${CI_COMMIT_SHA:0:8}/" HEAD | tar -xz
    - tar czf ${CI_PROJECT_NAME}-0.0.6.tar.gz ${CI_PROJECT_NAME}-*

    # Build RPM
    - rpmbuild -ba --define "_topdir /tmp/rpmbuild" --define "dist .el9" *.spec

    # Copy artifacts
    - cp /tmp/rpmbuild/RPMS/*/*.rpm ./
  artifacts:
    paths:
      - "*.rpm"
    expire_in: 30 days
  tags:
    - bootc

upload-rpm:
  stage: upload-rpm
  image: curlimages/curl:latest
  needs:
    - job: build-rpm
      artifacts: true
  script:
    # Detect DEV vs PROD
    - |
      if [[ "$CI_COMMIT_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        REPO_TYPE="prod"
      else
        REPO_TYPE="dev"
      fi

    # Upload RPMs to repository
    - |
      for rpm in *.rpm; do
        curl -u "${RPM_PIPELINE_USER}:${RPM_PIPELINE_PASS}" \
          -H "X-Repo-Type: ${REPO_TYPE}" \
          -F "file=@${rpm}" \
          "https://rpm-pipeline-api.budowaczka.transbit.com.pl/upload-rpm"
      done
  tags:
    - bootc

regenerate-repo:
  stage: regenerate-repo
  image: curlimages/curl:latest
  script:
    - |
      if [[ "$CI_COMMIT_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        REPO_TYPE="prod"
      else
        REPO_TYPE="dev"
      fi

    # Regenerate repository metadata
    - curl -u "${RPM_PIPELINE_USER}:${RPM_PIPELINE_PASS}" \
      -X POST \
      -H "X-Repo-Type: ${REPO_TYPE}" \
      "https://rpm-pipeline-api.budowaczka.transbit.com.pl/regenerate-repo"
  tags:
    - bootc
```

### Co Się Dzieje

**DEV build (każdy commit):**
```bash
$ git push origin feature/dpdk-update
# GitLab trigger
# → build-rpm (2 min)
# → upload-rpm (10 sec)
# → regenerate-repo (2 sec)
# Result: rp201-02-dpdk-0.0.6-1.el9.feature.1730376000.a8c12e3f.rpm
```

**PROD build (protected tag):**
```bash
$ git tag -a v0.0.6 -m "Release 0.0.6"
$ git push origin v0.0.6
# GitLab detects tag
# → validate SPEC matches tag
# → build without CI_BUILD_SUFFIX
# → upload to prod repo
# Result: rp201-02-dpdk-0.0.6-1.el9.rpm
```

## Pipeline 2: Budowanie Obrazów BOOTC

### Struktura Repo (devices/)

```
devices/
├── .gitlab-ci.yml              # BOOTC build pipeline
└── rp201-device/
    ├── Containerfile           # BOOTC recipe
    ├── files/
    │   ├── kargs.d/
    │   │   └── 50-rp.toml      # Kernel arguments
    │   └── etc/
    │       └── my-config.yaml  # Configuration files
    └── README.md
```

### Containerfile (Praktyczny Przykład)

```dockerfile
# Base: CentOS Stream 9 BOOTC
FROM quay.io/centos-bootc/centos-bootc:stream9

# Labels
LABEL com.example.device="rp201"
LABEL com.example.version="0.0.6"

# ===== Layer 1: System Packages =====
# Cached, changes rarely
RUN dnf install -y \
    kernel-modules-extra \
    systemd-container \
    podman \
    vim \
    && dnf clean all

# ===== Layer 2: Custom RPMs =====
# Install from your RPM repository
COPY files/transbit.repo /etc/yum.repos.d/
RUN dnf install -y \
    --enablerepo=rhel-9-for-x86_64-transbit-rpms \
    rp201-02-dpdk \
    rp201-01-fw \
    && dnf clean all

# ===== Layer 3: System Services =====
# Enable/disable services
RUN systemctl enable rp201-service.service && \
    systemctl enable podman.socket && \
    systemctl mask kdump.service debug-shell.service

# ===== Layer 4: SSH Hardening =====
RUN sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# ===== Layer 5: Kernel Arguments =====
# CPU isolation for real-time
COPY files/kargs.d/50-rp.toml /usr/lib/bootc/kargs.d/

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

**Kernel Arguments (files/kargs.d/50-rp.toml):**
```toml
# CPU isolation for real-time workloads
kargs = ["isolcpus=2-7", "nohz_full=2-7", "rcu_nocbs=2-7"]
```

### GitLab CI Pipeline (devices/.gitlab-ci.yml)

```yaml
stages:
  - build-bootc

variables:
  REGISTRY_DEV: "dev-reg.budowaczka.transbit.com.pl"
  REGISTRY_PROD: "prod-push-reg.budowaczka.transbit.com.pl"

build-bootc:
  stage: build-bootc
  image: quay.io/podman/podman:v5.0
  script:
    # Determine registry and tag
    - |
      if [[ "$CI_COMMIT_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        REGISTRY="${REGISTRY_PROD}"
        IMAGE_TAG="${CI_COMMIT_TAG:1}"  # Remove 'v' prefix
        REPO_TYPE="prod"
      else
        REGISTRY="${REGISTRY_DEV}"
        IMAGE_TAG="dev.${CI_COMMIT_BRANCH}.$(date +%s).${CI_COMMIT_SHA:0:8}"
        REPO_TYPE="dev"
      fi

    # Install CA certificate for registry
    - mkdir -p /etc/containers/certs.d/${REGISTRY}/
    - cp /builds/data/ca.crt /etc/containers/certs.d/${REGISTRY}/ca.crt

    # Build BOOTC image
    - |
      podman build \
        --file Containerfile \
        --tag ${REGISTRY}/rhel9/rp201-device:${IMAGE_TAG} \
        .

    # Login to registry
    - echo "${REGISTRY_PASSWORD}" | podman login -u "${REGISTRY_USER}" --password-stdin ${REGISTRY}

    # Push image
    - podman push ${REGISTRY}/rhel9/rp201-device:${IMAGE_TAG}

    # Tag as latest (DEV only)
    - |
      if [[ "$REPO_TYPE" == "dev" ]]; then
        podman tag ${REGISTRY}/rhel9/rp201-device:${IMAGE_TAG} \
                   ${REGISTRY}/rhel9/rp201-device:latest
        podman push ${REGISTRY}/rhel9/rp201-device:latest
      fi

    # Output digest
    - podman inspect ${REGISTRY}/rhel9/rp201-device:${IMAGE_TAG} --format '{{.Digest}}'
  tags:
    - bootc
```

### Co Się Dzieje

**DEV build:**
```bash
$ git push origin feature/new-config
# GitLab trigger
# → build-bootc (30 sec with cache)
# → push to dev-reg
# Image: dev-reg/rhel9/rp201-device:dev.feature.1730376000.a8c12e3f
# Also tagged: latest
```

**PROD build:**
```bash
$ git tag -a v0.0.6 -m "Release 0.0.6"
$ git push origin v0.0.6
# GitLab trigger
# → build-bootc (30 sec with cache)
# → push to prod-reg
# Image: prod-reg/rhel9/rp201-device:0.0.6
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
# nvme0n1  (adapter)

# Pull DEV image
podman pull dev-reg.budowaczka.transbit.com.pl/rhel9/rp201-device:latest

# Install to disk
sudo podman run --rm --privileged --pid=host \
  -v /var/lib/containers:/var/lib/containers \
  -v /dev:/dev \
  dev-reg.budowaczka.transbit.com.pl/rhel9/rp201-device:latest \
  bootc install to-disk --wipe /dev/nvme0n1
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
sudo eject /dev/nvme0n1

# Wkładasz do urządzenia, startujesz
# System bootuje z nowego obrazu
```

{% admonition(type="warning", title="DEV vs PROD") %}
DEV deployment: bez szyfrowania (szybkie testowanie).
PROD deployment: LUKS2 + TPM2 (bezpieczeństwo).
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

DEVICE="/dev/nvme0n1"
BASE_IMAGE="prod-reg/rhel9/rhel-bootc-base:9.6"
FINAL_IMAGE="prod-reg/rhel9/rp201-device:0.0.6"

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
sudo mount /dev/nvme0n1p3 /mnt/device-root

# Pull and save final image
podman pull ${FINAL_IMAGE}
sudo podman save -o /mnt/device-root/var/tmp/rp201-device.tar ${FINAL_IMAGE}

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
# Device bootuje, wykrywa /var/tmp/rp201-device.tar
# Automatyczny upgrade do final image
# Reboot → final system up
```

**LUKS2 + TPM2 Sealing:**
- Klucz LUKS2 sealed do TPM2 PCR 0, 2, 3 (BIOS, firmware, boot config)
- Jeśli PCRs się zgadzają: TPM2 unlocks automatycznie
- Jeśli PCRs nie pasują (tampered): manual passphrase required

### Scenariusz C: Live Image (Live USB/PXE)

Testowanie przed wdrożeniem: bootable USB bez instalacji na dysk.

**Create live image (create-live-image.sh):**

```bash
#!/bin/bash
set -e

IMAGE="prod-reg/rhel9/rp201-device:0.0.6"
OUTPUT_DIR="/tmp/live-image"

echo "Creating live image from ${IMAGE}"

# Pull image
podman pull ${IMAGE}

# Extract kernel and initramfs
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

# Copy to USB
$ sudo dd if=/tmp/live-image/rootfs.squashfs of=/dev/sdX bs=4M

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
ssh rp201-device-01

# Check status
sudo bootc status
# Booted: rp201-device:0.0.5
# Available: rp201-device:0.0.6

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
git clone https://git.example.com/bootc/sources/rp201-02-dpdk.git
cd rp201-02-dpdk

# Check current version
grep "^Version:" *.spec
# Version:        0.0.5

# Create feature branch
git checkout -b feature/dpdk-update-0.0.6

# Make changes
vim src/dpdk-init.c
# ... code changes ...

# Update SPEC
vim rp201-02-dpdk.spec
# Version:        0.0.6

# Commit
git commit -am "feat: update DPDK to 0.0.6 with memory pooling"
git push origin feature/dpdk-update-0.0.6
```

### GitLab Reaction

```
10:00 - GitLab CI/CD triggered
  ├─ build-rpm (2 min)
  ├─ upload-rpm (10 sec)
  └─ regenerate-repo (2 sec)

10:02 - DEV build ready
  Result: rp201-02-dpdk-0.0.6-1.el9.feature.1730376000.a8c12e3f.rpm
```

### Testing DEV Build

```bash
# 10:05 - Pull DEV image
podman pull dev-reg/rhel9/rp201-device:latest

# Quick container test
podman run -it --rm dev-reg/rhel9/rp201-device:latest /bin/bash
# Check if dpdk module loads
lsmod | grep dpdk

# Install to test device (USB adapter)
sudo podman run --rm --privileged --pid=host \
  -v /var/lib/containers:/var/lib/containers \
  -v /dev:/dev \
  dev-reg/rhel9/rp201-device:latest \
  bootc install to-disk --wipe /dev/nvme0n1

# Boot test device
# Tests pass ✅
```

### Merge to Main

```bash
# 11:00 - Tests passed, merge to main
git checkout main
git merge feature/dpdk-update-0.0.6
git push origin main

# GitLab triggers another DEV build for main branch
```

### Production Release

```bash
# 14:00 - Ready for production
git tag -a v0.0.6 -m "Release: DPDK 0.0.6"
git push origin v0.0.6

# GitLab detects protected tag
# Triggers PROD pipeline
```

### PROD Pipeline

```
14:02 - PROD build triggered
  ├─ Validate: tag v0.0.6 matches SPEC Version 0.0.6 ✅
  ├─ build-rpm (no CI_BUILD_SUFFIX) (2 min)
  ├─ upload-rpm to prod repo (10 sec)
  ├─ build-bootc (30 sec)
  └─ push to prod-reg (10 sec)

14:05 - PROD build complete
  RPM: rp201-02-dpdk-0.0.6-1.el9.rpm
  Image: prod-reg/rhel9/rp201-device:0.0.6
```

### Deployment to Devices

```bash
# 15:00 - Deploy to devices (Ansible playbook or manual SSH)
ansible-playbook -i production deploy-update.yml -e "version=0.0.6"

# Or manual:
ssh rp201-device-01 "sudo bootc upgrade"
ssh rp201-device-02 "sudo bootc upgrade"
ssh rp201-device-03 "sudo bootc upgrade"

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
RUN dnf install -y rp201-02-dpdk-0.0.6

# Layer 3: Services (cached until changed)
RUN systemctl enable rp201-service

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
rp201-02-dpdk-0.0.6-1.el9.rpm

# Container image (PROD)
prod-reg/rhel9/rp201-device:0.0.6
```

Pipeline validates: git tag MUST match SPEC Version.

### Testing: Weryfikacja Obrazu

```bash
# Test 1: Run as container
podman run -it --rm registry/image:tag /bin/bash
rpm -qa | grep rp201
systemctl status rp201-service
exit

# Test 2: Install to test disk
sudo podman run --rm --privileged --pid=host \
  -v /var/lib/containers:/var/lib/containers \
  -v /dev:/dev \
  registry/image:tag \
  bootc install to-disk --wipe /dev/sdX

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

**Na pipeline server:**
```bash
# Registry disk usage
df -h /var/lib/registry

# Build logs
journalctl -u gitlab-runner -f

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
- Pipeline build failure (email/Slack)
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
ssh rp201-device-01
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
  prod-reg/rhel9/rp201-device:0.0.6 \
  bootc install to-disk --wipe /dev/nvme0n1

# Device back to known state
```

## Podsumowanie

BOOTC workflow:

1. **RPM Build**: Git commit → pipeline builds RPM (~2 min) → upload to repo
2. **BOOTC Build**: RPM ready → pipeline builds container image (~30 sec) → push to registry
3. **Deployment DEV**: Pull image → install to disk via USB → boot device (~5 min)
4. **Deployment PROD**: Provision with base image → copy final image → self-upgrade → encrypted with TPM2
5. **OTA Updates**: `bootc upgrade` → download new version → reboot → automatic rollback if fails

**Total time from code to device: 15-20 minutes.**

Praktycznie, konkretnie, działa.

## Dodatkowe Zasoby

- [BOOTC Documentation](https://containers.github.io/bootc/)
- [Podman Rootless](https://docs.podman.io/en/latest/markdown/podman.1.html)
- [RPM Packaging Guide](https://rpm-packaging-guide.github.io/)
- [GitLab CI/CD](https://docs.gitlab.com/ee/ci/)
