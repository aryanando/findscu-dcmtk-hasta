# Ubuntu Server Docker Deployment Guide

## Complete Docker Stack for PACS System

This guide shows how to deploy the entire PACS system using Docker on Ubuntu server.

## Prerequisites

### 1. Install Docker and Docker Compose on Ubuntu
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo apt install -y docker-compose

# Add user to docker group
sudo usermod -aG docker $USER

# Reboot or logout/login to apply group changes
sudo reboot
```

### 2. Verify Installation
```bash
docker --version
docker-compose --version
docker run hello-world
```

## Deployment Options

### Option 1: Full Stack Deployment (Recommended)

Deploy Orthanc, DCMTK, and API together:

```bash
# Clone the project
git clone <your-repo-url>
cd findscu-dcmtk

# Copy and configure environment
cp .env.example .env
nano .env

# Start the full stack
docker-compose -f docker-compose.full-stack.yml up -d

# Check status
docker-compose -f docker-compose.full-stack.yml ps
```

### Option 2: Individual Services

Deploy services separately for more control:

```bash
# Start Orthanc first
cd ../orthanc-mwl
docker-compose up -d orthanc

# Start DCMTK
cd ../findscu-dcmtk
docker-compose up -d

# Start API
cd ../hasta_radiologi
docker build -t hasta-radiologi-api .
docker run -d -p 3000:3000 --name api \
  --network findscu-dcmtk_pacs-network \
  -e PACS_HOST=orthanc \
  -e PACS_PORT=4242 \
  hasta-radiologi-api
```

## Configuration for Ubuntu Server

### Environment Variables (.env)
```bash
# Docker-to-Docker communication
PACS_HOST=orthanc              # Container name
PACS_PORT=4242
REMOTE_AET=ORTHANC

# Local settings
LOCAL_AET=FINDSCU
LOCAL_PORT=11112

# API settings
WEB_PORT=8080
LOG_LEVEL=INFO

# Paths (inside containers)
LOG_DIR=/var/log/findscu
RESULT_DIR=/opt/findscu/results
```

### Network Configuration
```bash
# The services communicate via Docker network
# No need to expose all ports to host
# Only expose what you need external access to:

# Orthanc Web UI: http://server-ip:8042
# API Server: http://server-ip:3000
# DICOM port 4242 is internal only
```

## Service Management

### Start Services
```bash
# Full stack
docker-compose -f docker-compose.full-stack.yml up -d

# Individual services
docker-compose up -d orthanc
docker-compose up -d dcmtk-findscu
```

### Stop Services
```bash
# Full stack
docker-compose -f docker-compose.full-stack.yml down

# Individual
docker-compose down
```

### Check Status
```bash
# View running containers
docker ps

# Check logs
docker-compose logs orthanc
docker-compose logs dcmtk-findscu
docker-compose logs hasta-radiologi-api

# Follow logs
docker-compose logs -f orthanc
```

### Update Services
```bash
# Pull latest images
docker-compose pull

# Rebuild custom images
docker-compose build --no-cache

# Restart with updates
docker-compose down
docker-compose up -d
```

## Testing the Deployment

### 1. Test Orthanc
```bash
# Check Orthanc web interface
curl http://localhost:8042/app/explorer.html

# Check DICOM connectivity
docker exec dcmtk-findscu-client findscu -v -aet "FINDSCU" -aec "ORTHANC" orthanc 4242
```

### 2. Test DCMTK Queries
```bash
# Query worklists
docker exec dcmtk-findscu-client ./query-worklist.sh

# Interactive shell
docker exec -it dcmtk-findscu-client /bin/bash
```

### 3. Test API
```bash
# Health check
curl http://localhost:3000/health

# Test PACS integration
curl http://localhost:3000/api/pacs/worklists
```

## Persistence and Backups

### Data Volumes
```bash
# List volumes
docker volume ls

# Backup Orthanc database
docker run --rm -v findscu-dcmtk_orthanc-db:/data -v $(pwd):/backup \
  ubuntu tar czf /backup/orthanc-backup.tar.gz /data

# Restore database
docker run --rm -v findscu-dcmtk_orthanc-db:/data -v $(pwd):/backup \
  ubuntu tar xzf /backup/orthanc-backup.tar.gz -C /
```

### Configuration Backups
```bash
# Backup configurations
tar czf pacs-config-backup.tar.gz \
  orthanc-mwl/config/ \
  findscu-dcmtk/.env \
  hasta_radiologi/.env
```

## Production Optimization

### Resource Limits
Add to docker-compose files:
```yaml
services:
  orthanc:
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1.0'
        reservations:
          memory: 512M
          cpus: '0.5'
```

### Security
```bash
# Firewall (UFW)
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 8042/tcp  # Orthanc UI
sudo ufw allow 3000/tcp  # API
# Don't expose 4242 externally for security

# Docker security
sudo usermod -aG docker $USER
sudo systemctl enable docker
```

### Auto-start on Boot
```bash
# Create systemd service
sudo nano /etc/systemd/system/pacs-stack.service
```

Service file content:
```ini
[Unit]
Description=PACS Docker Stack
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/path/to/findscu-dcmtk
ExecStart=/usr/bin/docker-compose -f docker-compose.full-stack.yml up -d
ExecStop=/usr/bin/docker-compose -f docker-compose.full-stack.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

Enable service:
```bash
sudo systemctl enable pacs-stack.service
sudo systemctl start pacs-stack.service
```

## Monitoring

### Container Health
```bash
# Check container status
docker ps
docker stats

# Health checks
docker inspect orthanc-server | grep Health
```

### Log Management
```bash
# Configure log rotation
sudo nano /etc/docker/daemon.json
```

Content:
```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "5"
  }
}
```

### Alerts (Optional)
```bash
# Install monitoring tools
docker run -d --name=cadvisor \
  -p 8080:8080 \
  -v /:/rootfs:ro \
  -v /var/run:/var/run:rw \
  -v /sys:/sys:ro \
  -v /var/lib/docker/:/var/lib/docker:ro \
  gcr.io/cadvisor/cadvisor:latest
```

## Troubleshooting

### Common Issues
1. **Containers can't communicate**: Check network configuration
2. **Port conflicts**: Change port mappings in docker-compose
3. **Permission issues**: Check volume mounts and file permissions
4. **Out of space**: Clean up with `docker system prune`

### Debug Commands
```bash
# Container networking
docker network ls
docker network inspect pacs-network

# Container logs
docker logs orthanc-server
docker logs dcmtk-findscu-client

# Interactive debugging
docker exec -it orthanc-server /bin/bash
docker exec -it dcmtk-findscu-client /bin/bash
```
