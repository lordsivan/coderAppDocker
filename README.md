# Coder Multi-User Environment with Static IP Assignment

A custom Docker image for [Coder](https://github.com/coder/coder) workspaces that automatically assigns static IP addresses to containers in a multi-user environment.

## Features

- **Static IP Assignment**: Each user gets a predefined static IP address
- **Automatic Network Connection**: Containers automatically join the `coder_net` bridge network
- **Production Ready**: Error handling, logging, and graceful failure modes
- **User Mapping**: Simple text file configuration for user-to-IP mappings
- **Docker Socket Integration**: Uses Docker-in-Docker for network management

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Workspace 1   │    │   Workspace 2   │    │   Workspace N   │
│   (user1)       │    │   (user2)       │    │   (userN)       │
│   172.20.0.11   │    │   172.20.0.12   │    │   172.20.0.XX   │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                    ┌─────────────┴───────────┐
                    │    coder_net bridge     │
                    │    172.20.0.0/16       │
                    │    Gateway: 172.20.0.1  │
                    └─────────────────────────┘
```

## Quick Start

### 1. Setup the Network

```bash
# Create the bridge network
./setup-network.sh
```

### 2. Configure User Mappings

Edit `ip-map.txt` to define your user-to-IP mappings:

```
user1:172.20.0.11
user2:172.20.0.12
admin:172.20.0.10
```

### 3. Build the Image

```bash
docker build -t coder-static-ip .
```

### 4. Run a Workspace

```bash
# Method 1: Docker run
docker run -d \
  --name coder-workspace-user1 \
  -e CODER_USERNAME=user1 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  coder-static-ip

# Method 2: Docker Compose
USER=user1 docker-compose up -d
```

## Files Overview

### Core Files

- **`Dockerfile`**: Custom Coder image with Docker CLI and networking tools
- **`entrypoint.sh`**: Main script that handles IP assignment and network connection
- **`ip-map.txt`**: User-to-IP address mappings

### Supporting Files

- **`docker-compose.yml`**: Easy deployment configuration
- **`setup-network.sh`**: Network initialization script
- **`.dockerignore`**: Docker build optimization

## Configuration

### IP Address Mapping (`ip-map.txt`)

Format: `username:ip_address`

```
# Development Team
user1:172.20.0.11
user2:172.20.0.12

# QA Team
qa1:172.20.0.21
qa2:172.20.0.22

# Admin
admin:172.20.0.10
```

### Network Configuration

- **Network Name**: `coder_net`
- **Subnet**: `172.20.0.0/16`
- **Gateway**: `172.20.0.1`
- **Available IPs**: `172.20.0.10` - `172.20.0.254`

### Environment Variables

- **`CODER_USERNAME`**: Username for IP lookup (overrides `whoami`)
- **`CODER_ACCESS_TOKEN`**: Coder access token
- **`CODER_URL`**: Coder server URL

## Production Deployment

### 1. Network Setup

```bash
# Create the bridge network on the host
docker network create --driver bridge --subnet=172.20.0.0/16 coder_net
```

### 2. Build and Push Image

```bash
# Build
docker build -t your-registry/coder-static-ip:latest .

# Push to registry
docker push your-registry/coder-static-ip:latest
```

### 3. Deploy Workspaces

```bash
# Deploy workspace for user1
docker run -d \
  --name coder-workspace-user1 \
  --hostname coder-user1 \
  -e CODER_USERNAME=user1 \
  -e CODER_ACCESS_TOKEN=your-token \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v coder-data-user1:/home/coder \
  --restart unless-stopped \
  your-registry/coder-static-ip:latest
```

## Troubleshooting

### Check Logs

```bash
# Container logs
docker logs coder-workspace-user1

# Network setup logs (inside container)
docker exec coder-workspace-user1 cat /var/log/coder/network-setup.log
```

### Verify Network Connection

```bash
# Check if container is connected to network
docker network inspect coder_net

# Check IP assignment inside container
docker exec coder-workspace-user1 ip addr show
```

### Common Issues

1. **"Network 'coder_net' not found"**
   - Run `./setup-network.sh` to create the network

2. **"No IP mapping found for user"**
   - Add the user to `ip-map.txt`
   - Ensure the format is correct: `username:ip_address`

3. **"IP address already in use"**
   - Check for duplicate IPs in `ip-map.txt`
   - Verify no other containers are using the IP

4. **Docker socket permission denied**
   - Ensure the coder user has access to Docker socket
   - Add coder user to docker group if needed

## Security Considerations

- **Docker Socket Access**: Required for network management, ensure proper access controls
- **IP Range Isolation**: Use private IP ranges (172.20.0.0/16)
- **User Validation**: Implement proper user authentication in your Coder setup
- **Network Segmentation**: Consider additional network policies for production

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with multiple users
5. Submit a pull request

## License

This project is licensed under the MIT License.
