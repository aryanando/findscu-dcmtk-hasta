# Ubuntu Server Deployment Guide

## Prerequisites

### 1. Install Docker and Docker Compose
```bash
# Update package index
sudo apt update

# Install Docker
sudo apt install -y docker.io

# Install Docker Compose
sudo apt install -y docker-compose

# Add your user to docker group (to run docker without sudo)
sudo usermod -aG docker $USER

# Log out and back in, or run:
newgrp docker

# Verify installation
docker --version
docker-compose --version
```

### 2. Clone the Project
```bash
git clone <your-repository-url>
cd findscu-dcmtk
```

## Environment Configuration

### 3. Setup Environment File
```bash
# Copy example environment file
cp .env.example .env

# Edit the environment file
nano .env
```

### 4. Configure for Ubuntu Server

Edit `.env` with these Ubuntu-specific settings:

```bash
# PACS Server Configuration
# Option 1: If Orthanc runs on the same Ubuntu server
PACS_HOST=localhost

# Option 2: If Orthanc runs on a different server
# PACS_HOST=192.168.1.100  # Replace with actual Orthanc server IP

# Option 3: If using Docker network
# PACS_HOST=orthanc  # Use container name if in same docker network

PACS_PORT=4242
REMOTE_AET=ORTHANC

# Local Configuration
LOCAL_AET=FINDSCU
LOCAL_PORT=11112

# Paths (Linux style)
LOG_DIR=/var/log/findscu
RESULT_DIR=/opt/findscu/results
```

## Deployment Options

### Option 1: Standalone DCMTK Container

If Orthanc is running separately on the server:

```bash
# Start the DCMTK container
docker-compose up -d

# Test connection
docker-compose exec dcmtk-findscu ./query-worklist.sh
```

### Option 2: Full Stack with Orthanc

If you want to run Orthanc and DCMTK together:

```bash
# Create a combined docker-compose.yml
# (We can create this if needed)

# Start all services
docker-compose up -d orthanc dcmtk-findscu

# Check services
docker-compose ps
```

### Option 3: System-wide DCMTK Installation

Install DCMTK directly on Ubuntu:

```bash
# Install DCMTK
sudo apt install -y dcmtk

# Test installation
findscu --version

# Query directly (no Docker)
findscu -v -aet "FINDSCU" -aec "ORTHANC" -W \
  -k "PatientName" -k "PatientID" -k "AccessionNumber" \
  localhost 4242
```

## Network Configuration

### Firewall Settings
```bash
# Allow DICOM port (if needed)
sudo ufw allow 4242/tcp
sudo ufw allow 11112/tcp

# Check firewall status
sudo ufw status
```

### Docker Network Setup
```bash
# Create custom network (if needed)
docker network create findscu-network

# List networks
docker network ls

# Inspect network
docker network inspect findscu-network
```

## Service Management

### Systemd Service (Optional)
Create a systemd service to auto-start:

```bash
# Create service file
sudo nano /etc/systemd/system/findscu-dcmtk.service
```

Service content:
```ini
[Unit]
Description=DCMTK FindSCU Docker Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/path/to/findscu-dcmtk
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

Enable service:
```bash
sudo systemctl enable findscu-dcmtk.service
sudo systemctl start findscu-dcmtk.service
```

## Troubleshooting

### 1. Connection Issues
```bash
# Test network connectivity
ping <pacs-server-ip>
telnet <pacs-server-ip> 4242

# Check if Orthanc is running
curl http://localhost:8042/app/explorer.html

# Test DICOM connectivity
findscu -v -aet "FINDSCU" -aec "ORTHANC" localhost 4242
```

### 2. Docker Issues
```bash
# Check container logs
docker-compose logs dcmtk-findscu

# Interactive shell
docker-compose exec dcmtk-findscu /bin/bash

# Rebuild containers
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### 3. Permission Issues
```bash
# Fix Docker permissions
sudo chown -R $USER:$USER .
sudo chmod +x scripts/*.sh

# Fix log directory
sudo mkdir -p /var/log/findscu
sudo chown -R $USER:$USER /var/log/findscu
```

## Production Deployment

### 1. Resource Limits
Add to docker-compose.yml:
```yaml
services:
  dcmtk-findscu:
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'
```

### 2. Logging
```bash
# Configure log rotation
sudo nano /etc/logrotate.d/findscu-dcmtk
```

### 3. Monitoring
```bash
# Check container health
docker-compose ps
docker stats

# Monitor logs
tail -f /var/log/findscu/findscu.log
```

## Integration with Hasta Radiologi API

If integrating with your Node.js API:

```bash
# Ensure both services can communicate
# Update API server's .env:
FINDSCU_CONTAINER=dcmtk-findscu
PACS_HOST=localhost
PACS_PORT=4242

# Test API integration
curl http://localhost:3000/api/pacs/worklists
```
