FROM ghcr.io/coder/coder:latest

# Install Docker CLI and necessary tools
USER root
RUN apt-get update && \
    apt-get install -y \
    docker.io \
    curl \
    jq \
    iproute2 \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

# Copy configuration files
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY ip-map.txt /etc/ip-map.txt

# Make entrypoint script executable
RUN chmod +x /usr/local/bin/entrypoint.sh

# Create necessary directories and set permissions
RUN mkdir -p /var/log/coder && \
    chown -R coder:coder /var/log/coder

# Switch back to coder user
USER coder

# Set the custom entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Default command (will be passed to the original coder entrypoint)
CMD ["server"]