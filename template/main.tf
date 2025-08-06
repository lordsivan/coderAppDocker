terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

# Variables for template customization
variable "docker_host" {
  description = "Docker daemon host (e.g., unix:///var/run/docker.sock)"
  default     = "unix:///var/run/docker.sock"
  type        = string
}

variable "image_registry" {
  description = "Docker image registry URL"
  default     = "docker.io"
  type        = string
}

variable "image_name" {
  description = "Custom Coder image name"
  default     = "coder-static-ip"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag"
  default     = "latest"
  type        = string
}

# Configure Docker provider
provider "docker" {
  host = var.docker_host
}

# Data source for workspace owner info
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# Parameter for CPU allocation
data "coder_parameter" "cpu" {
  name         = "cpu"
  display_name = "CPU Cores"
  description  = "Number of CPU cores for the workspace"
  type         = "number"
  default      = "2"
  mutable      = true
  validation {
    min = 1
    max = 8
  }
}

# Parameter for memory allocation
data "coder_parameter" "memory" {
  name         = "memory"
  display_name = "Memory (GB)"
  description  = "Amount of memory in GB"
  type         = "number"
  default      = "4"
  mutable      = true
  validation {
    min = 1
    max = 16
  }
}

# Parameter for storage size
data "coder_parameter" "home_disk_size" {
  name         = "home_disk_size"
  display_name = "Home Volume Size (GB)"
  description  = "Size of the home directory volume"
  type         = "number"
  default      = "20"
  mutable      = true
  validation {
    min = 1
    max = 100
  }
}

# Ensure the coder_net network exists
resource "docker_network" "coder_net" {
  name = "coder_net"
  driver = "bridge"
  ipam_config {
    subnet  = "172.20.0.0/16"
    gateway = "172.20.0.1"
  }
  options = {
    "com.docker.network.bridge.name" = "coder-br0"
    "com.docker.network.driver.mtu"  = "1500"
  }
}

# Volume for persistent home directory
resource "docker_volume" "home_volume" {
  name = "coder-${data.coder_workspace.me.id}-home"
}

# Main workspace container
resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  name  = "coder-${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}"
  
  # Use custom image with static IP functionality
  image = "${var.image_registry}/${var.image_name}:${var.image_tag}"
  
  # Container configuration
  hostname = "coder-${data.coder_workspace.me.name}"
  restart  = "unless-stopped"
  
  # Resource limits
  memory    = data.coder_parameter.memory.value * 1024 # Convert GB to MB
  cpu_count = data.coder_parameter.cpu.value
  
  # Environment variables
  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    "CODER_USERNAME=${data.coder_workspace.me.owner}",
    "CODER_WORKSPACE_NAME=${data.coder_workspace.me.name}",
    "CODER_URL=${data.coder_workspace.me.access_url}",
  ]
  
  # Mount Docker socket for network management
  volumes {
    container_path = "/var/run/docker.sock"
    host_path      = "/var/run/docker.sock"
    read_only      = false
  }
  
  # Mount home directory volume
  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.home_volume.name
    read_only      = false
  }
  
  # Mount IP mapping configuration
  volumes {
    container_path = "/etc/ip-map.txt"
    host_path      = "${path.cwd}/ip-map.txt"
    read_only      = true
  }
  
  # Network configuration - will be managed by entrypoint script
  networks_advanced {
    name = docker_network.coder_net.name
  }
  
  # Labels for identification
  labels {
    label = "coder.workspace"
    value = "true"
  }
  
  labels {
    label = "coder.workspace.id"
    value = data.coder_workspace.me.id
  }
  
  labels {
    label = "coder.workspace.name"
    value = data.coder_workspace.me.name
  }
  
  labels {
    label = "coder.workspace.owner"
    value = data.coder_workspace.me.owner
  }
}

# Coder agent for workspace management
resource "coder_agent" "main" {
  arch           = "amd64"
  os             = "linux"
  startup_script = <<-EOT
    #!/bin/bash
    
    # Wait for container to be fully started
    sleep 5
    
    # Log network information
    echo "=== Network Configuration ==="
    ip addr show
    echo "=== Docker Networks ==="
    docker network ls
    echo "=== Container Network Details ==="
    docker network inspect coder_net --format '{{json .Containers}}' | jq .
    
    # Setup development environment
    if ! command -v code-server &> /dev/null; then
      echo "Installing code-server..."
      curl -fsSL https://code-server.dev/install.sh | sh
    fi
    
    # Install common development tools
    echo "Setting up development environment..."
    
    # Create common directories
    mkdir -p /home/coder/{projects,scripts,logs}
    
    echo "Workspace ready!"
  EOT
  
  # Metadata about the workspace
  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }
  
  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }
  
  metadata {
    display_name = "Home Disk"
    key          = "3_home_disk"
    script       = "coder stat disk --path /home/coder"
    interval     = 60
    timeout      = 1
  }
  
  metadata {
    display_name = "Container IP"
    key          = "2_container_ip"
    script       = "ip route get 8.8.8.8 | awk '{print $7}' | head -1"
    interval     = 60
    timeout      = 1
  }
}

# VS Code Web application
resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "VS Code"
  url          = "http://localhost:8080/?folder=/home/coder"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"
  
  healthcheck {
    url       = "http://localhost:8080/healthz"
    interval  = 5
    threshold = 6
  }
}

# Terminal application
resource "coder_app" "terminal" {
  agent_id     = coder_agent.main.id
  slug         = "terminal"
  display_name = "Terminal"
  command      = "bash"
  icon         = "/icon/terminal.svg"
}

# File browser application (optional)
resource "coder_app" "filebrowser" {
  agent_id     = coder_agent.main.id
  slug         = "filebrowser"
  display_name = "File Browser"
  url          = "http://localhost:8081"
  icon         = "/icon/folder.svg"
  subdomain    = false
  share        = "owner"
}

# Output workspace information
output "workspace_info" {
  value = {
    username    = data.coder_workspace.me.owner
    workspace   = data.coder_workspace.me.name
    image       = "${var.image_registry}/${var.image_name}:${var.image_tag}"
    cpu_cores   = data.coder_parameter.cpu.value
    memory_gb   = data.coder_parameter.memory.value
    storage_gb  = data.coder_parameter.home_disk_size.value
  }
  description = "Workspace configuration details"
}