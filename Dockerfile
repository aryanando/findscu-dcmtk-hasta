# DCMTK FindSCU Dockerfile
FROM ubuntu:22.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Update package list and install DCMTK tools
RUN apt-get update && apt-get install -y \
    dcmtk \
    curl \
    wget \
    net-tools \
    iputils-ping \
    telnet \
    vim \
    && rm -rf /var/lib/apt/lists/*

# Create directories for scripts and logs
RUN mkdir -p /usr/local/bin /var/log/findscu /opt/findscu/results

# Copy scripts into the container
COPY scripts/ /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh

# Create a non-root user for security
RUN useradd -m -s /bin/bash findscu && \
    chown -R findscu:findscu /var/log/findscu /opt/findscu

# Switch to non-root user
USER findscu

# Set working directory
WORKDIR /home/findscu

# Health check to ensure DCMTK tools are working
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD findscu --version || exit 1

# Keep container running
CMD ["tail", "-f", "/dev/null"]
