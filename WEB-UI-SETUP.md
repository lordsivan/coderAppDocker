# Using Coder Static IP Workspace via Web UI

This guide walks you through using your custom Docker image with static IP assignment through the Coder web interface.

## Quick Start

### 1. Build and Push Your Image

```bash
# Build the image
docker build -t coder-static-ip:latest .

# Tag for your registry (replace with your registry)
docker tag coder-static-ip:latest your-registry/coder-static-ip:latest

# Push to registry
docker push your-registry/coder-static-ip:latest
```

### 2. Deploy the Template

```bash
# Deploy using the script
./deploy-template.sh

# Or deploy with custom registry
DOCKER_REGISTRY=your-registry.com IMAGE_NAME=coder-static-ip ./deploy-template.sh
```

### 3. Create Workspace via Web UI

1. **Open Coder Web UI**: Navigate to your Coder instance (e.g., `https://coder.your-domain.com`)

2. **Login**: Use your credentials to access the dashboard

3. **Create Workspace**:
   - Click the **"Create Workspace"** button
   - Select the **"Static IP Workspace"** template
   - Enter a workspace name (e.g., `dev-workspace`)

4. **Configure Resources**:
   - **CPU Cores**: Choose 1-8 cores (default: 2)
   - **Memory (GB)**: Choose 1-16 GB (default: 4)  
   - **Storage (GB)**: Choose 1-100 GB (default: 20)

5. **Create**: Click **"Create workspace"**

### 4. Access Your Workspace

Once created, your workspace will show:

- **🟢 Status**: Running (with your static IP)
- **💻 VS Code**: Click to open web-based VS Code
- **🖥️ Terminal**: Click for browser terminal access
- **📁 File Browser**: Click for web file manager

## What Happens Behind the Scenes

1. **Container Creation**: Docker creates container with your custom image
2. **Network Setup**: Container joins `coder_net` bridge network
3. **IP Assignment**: Entrypoint script assigns static IP from `ip-map.txt`
4. **Agent Connection**: Coder agent connects to provide web access
5. **Apps Launch**: VS Code, terminal, and file browser become available

## Viewing Your Static IP

### Method 1: Via Web Terminal
1. Click **Terminal** in workspace
2. Run: `ip addr show | grep "inet 172.20"`
3. Your static IP will be displayed

### Method 2: Via Workspace Metadata
- Look at the **"Container IP"** metadata in the workspace dashboard
- This updates every 60 seconds automatically

### Method 3: Via Docker (on Coder host)
```bash
# Check container network
docker network inspect coder_net

# Show container details
docker inspect coder-username-workspacename
```

## User-to-IP Mapping

Your IP is determined by your Coder username and the `ip-map.txt` file:

```
# Example mappings
john:172.20.0.11
jane:172.20.0.12
admin:172.20.0.10
```

If your username is `john`, you'll automatically get IP `172.20.0.11`.

## Customizing Your Workspace

### Installing Additional Tools

Use the VS Code terminal or SSH to install tools:

```bash
# Python development
apk add python3 python3-dev py3-pip

# Node.js development  
apk add nodejs npm

# Go development
apk add go

# Database clients
apk add postgresql-client mysql-client
```

### Adding Custom Applications

Modify `template/main.tf` and add new `coder_app` resources:

```hcl
resource "coder_app" "jupyter" {
  agent_id     = coder_agent.main.id
  slug         = "jupyter"
  display_name = "Jupyter Lab"
  url          = "http://localhost:8888"
  icon         = "/icon/jupyter.svg"
}
```

Then redeploy: `./deploy-template.sh`

## Troubleshooting

### Workspace Won't Start

1. **Check Template**: `coder templates show static-ip-workspace`
2. **View Logs**: In web UI, go to workspace → **Logs** tab
3. **Check Image**: Verify image exists in registry

### No Static IP Assigned

1. **Check Username**: Your Coder username must be in `ip-map.txt`
2. **View Network Logs**: In terminal: `cat /var/log/coder/network-setup.log`
3. **Check Docker Socket**: Ensure `/var/run/docker.sock` is mounted

### Applications Won't Load

1. **Wait for Startup**: Applications take 30-60 seconds to initialize
2. **Check Agent**: Workspace must show "Connected" status  
3. **Port Conflicts**: Ensure ports 8080, 8081 aren't in use

### IP Address Conflict

1. **Check Duplicates**: Look for duplicate IPs in `ip-map.txt`
2. **Stop Conflicting Containers**: `docker ps | grep 172.20.0.11`
3. **Update Mapping**: Assign different IP and restart workspace

## Advanced Usage

### SSH Access

```bash
# Get SSH command from workspace
coder ssh workspace-name

# Or configure SSH client
coder config-ssh
ssh coder.workspace-name
```

### Port Forwarding

```bash
# Forward local port to workspace
coder port-forward workspace-name --tcp 3000:3000

# Access via http://localhost:3000
```

### File Synchronization

```bash
# Upload files
coder push workspace-name local-file.txt remote-path/

# Download files  
coder pull workspace-name remote-path/file.txt ./
```

## Production Considerations

### High Availability

- Use multiple Coder replicas
- Implement load balancing
- Use persistent storage for workspaces

### Security

- Regular image updates
- Network security policies
- User access controls
- Resource quotas

### Monitoring

- Track resource usage via Coder metrics
- Monitor network connectivity
- Set up alerts for failures

## Support

### Getting Help

1. **Template Issues**: Check `terraform validate` in template directory
2. **Network Issues**: Review Docker network configuration  
3. **Coder Issues**: Check Coder server logs
4. **Image Issues**: Test image locally with `docker run`

### Useful Commands

```bash
# Template management
coder templates list
coder templates show static-ip-workspace
coder templates delete static-ip-workspace

# Workspace management
coder list
coder show workspace-name
coder restart workspace-name
coder delete workspace-name

# Debugging
coder ping workspace-name
coder speedtest workspace-name
```

---

**Need more help?** Check the main [README.md](README.md) for detailed configuration and troubleshooting information.