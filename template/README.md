# Coder Template: Static IP Workspace

A Coder workspace template that automatically assigns static IP addresses to containers using a custom Docker image.

## Features

- **Static IP Assignment**: Each user gets a predefined IP address from `ip-map.txt`
- **Automatic Network Setup**: Creates and connects to `coder_net` bridge network
- **VS Code Integration**: Built-in code-server with web access
- **Resource Configuration**: Customizable CPU, memory, and storage
- **Development Ready**: Pre-installed tools and development environment

## Template Parameters

| Parameter | Description | Default | Range |
|-----------|-------------|---------|-------|
| CPU Cores | Number of CPU cores | 2 | 1-8 |
| Memory (GB) | RAM allocation | 4 | 1-16 |
| Storage (GB) | Home directory size | 20 | 1-100 |

## Network Configuration

- **Network Name**: `coder_net`
- **Subnet**: `172.20.0.0/16`
- **Gateway**: `172.20.0.1`
- **IP Mapping**: Configured in `ip-map.txt`

## Prerequisites

1. **Docker Image**: Build and push the custom image
   ```bash
   docker build -t your-registry/coder-static-ip:latest .
   docker push your-registry/coder-static-ip:latest
   ```

2. **IP Mapping File**: Ensure `ip-map.txt` exists in the template directory
   ```
   user1:172.20.0.11
   user2:172.20.0.12
   admin:172.20.0.10
   ```

3. **Docker Socket Access**: Coder server needs access to Docker socket

## Deployment Steps

### 1. Prepare the Template

```bash
# Copy ip-map.txt to template directory
cp ip-map.txt template/

# Update image reference in main.tf if needed
# Edit the default values for image_registry, image_name, image_tag
```

### 2. Create the Template in Coder

```bash
# Create template from current directory
coder templates create static-ip-workspace

# Or create from specific directory
coder templates create static-ip-workspace --directory ./template
```

### 3. Update Template Variables (Optional)

```bash
# Push template with custom image registry
coder templates push static-ip-workspace \
  --var image_registry=your-registry.com \
  --var image_name=coder-static-ip \
  --var image_tag=v1.0
```

## Using the Template

1. **Access Coder Web UI**: Navigate to your Coder instance
2. **Create Workspace**: Click "Create Workspace"
3. **Select Template**: Choose "Static IP Workspace"
4. **Configure Resources**: Set CPU, memory, and storage as needed
5. **Create**: Click "Create workspace"

The workspace will:
- Start with your custom Docker image
- Automatically connect to the `coder_net` network
- Get assigned a static IP based on your username
- Launch VS Code, terminal, and file browser

## Applications Available

| Application | Description | Access |
|-------------|-------------|--------|
| VS Code | Web-based code editor | Browser |
| Terminal | Command-line access | Browser or SSH |
| File Browser | Web file manager | Browser |

## Troubleshooting

### Check Network Assignment

```bash
# Inside workspace terminal
ip addr show
docker network inspect coder_net
```

### View Logs

```bash
# Container logs
docker logs coder-username-workspace

# Network setup logs
cat /var/log/coder/network-setup.log
```

### Common Issues

1. **IP Already in Use**
   - Check for duplicate entries in `ip-map.txt`
   - Verify no other containers use the same IP

2. **Network Connection Failed**
   - Ensure Docker socket is accessible
   - Check if `coder_net` network exists

3. **Template Creation Failed**
   - Verify Terraform syntax: `terraform validate`
   - Check image availability: `docker pull your-image`

## Customization

### Adding New Applications

Add to `main.tf`:

```hcl
resource "coder_app" "my_app" {
  agent_id     = coder_agent.main.id
  slug         = "my-app"
  display_name = "My Application"
  url          = "http://localhost:3000"
  icon         = "/icon/app.svg"
}
```

### Custom Environment Variables

Add to container `env` block:

```hcl
env = [
  "CODER_AGENT_TOKEN=${coder_agent.main.token}",
  "CUSTOM_VAR=value",
  # ... other vars
]
```

### Additional Volumes

Add to `volumes` blocks:

```hcl
volumes {
  container_path = "/workspace/data"
  host_path      = "/host/data"
  read_only      = false
}
```

## Security Considerations

- **Docker Socket**: Grants container management privileges
- **Network Isolation**: Consider additional network policies
- **User Validation**: Ensure proper authentication
- **Image Security**: Regularly update base images

## Support

For issues with:
- **Template**: Check Terraform configuration
- **Network**: Verify Docker network setup  
- **Image**: Rebuild and test locally
- **Coder**: Check Coder server logs