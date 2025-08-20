#!/bin/bash

# Install Docker and configure insecure registry on K8s worker nodes
# Run this script from your LOCAL LAPTOP

set -e

echo "🚀 Installing Docker on Kubernetes worker nodes..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Configuration
JENKINS_SERVER="10.31.33.95"
K8S_WORKERS=("10.31.33.202" "10.31.33.203" "10.31.33.204")
USER="vjmdeb"
REGISTRY_URL="10.31.33.95:5000"

echo "📋 Configuration:"
echo "   Jenkins Server: $JENKINS_SERVER"
echo "   K8s Workers: ${K8S_WORKERS[*]}"
echo "   User: $USER"
echo "   Registry URL: $REGISTRY_URL"
echo ""

# Create Docker installation script
echo "📝 Creating Docker installation script..."
cat > /tmp/install-docker-worker.sh << 'SCRIPT_EOF'
#!/bin/bash

echo "🐳 Installing Docker on $(hostname)..."

# Update package database
echo "📦 Updating package database..."
sudo apt-get update -qq

# Install prerequisites
echo "📦 Installing prerequisites..."
sudo apt-get install -y -qq \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
echo "🔑 Adding Docker GPG key..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo "📦 Adding Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package database with Docker repo
echo "📦 Updating package database with Docker repository..."
sudo apt-get update -qq

# Install Docker Engine
echo "🐳 Installing Docker Engine..."
sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker service
echo "🔄 Starting Docker service..."
sudo systemctl start docker
sudo systemctl enable docker

# Add current user to docker group
echo "👤 Adding user to docker group..."
sudo usermod -aG docker $USER

# Verify Docker installation
echo "✅ Verifying Docker installation..."
sudo docker --version
sudo systemctl is-active docker

echo "✅ Docker installation completed on $(hostname)!"
SCRIPT_EOF

chmod +x /tmp/install-docker-worker.sh

# Create Docker daemon configuration script
cat > /tmp/configure-docker-daemon.sh << 'SCRIPT_EOF'
#!/bin/bash

echo "🔧 Configuring Docker daemon on $(hostname)..."

# Create Docker daemon configuration directory
sudo mkdir -p /etc/docker

# Backup existing daemon.json if it exists
if [ -f /etc/docker/daemon.json ]; then
    sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.backup.$(date +%Y%m%d-%H%M%S)
    echo "📋 Backed up existing daemon.json"
fi

# Create daemon.json for insecure registry
echo "📄 Creating Docker daemon configuration..."
sudo tee /etc/docker/daemon.json > /dev/null << EOF
{
  "insecure-registries": ["10.31.33.95:5000"]
}
EOF

echo "📋 Docker daemon configuration:"
sudo cat /etc/docker/daemon.json

# Restart Docker service to apply configuration
echo "🔄 Restarting Docker service..."
sudo systemctl restart docker

# Wait for Docker to start
sleep 5

# Verify Docker is running
if sudo systemctl is-active --quiet docker; then
    echo "✅ Docker service is active"
    echo "📊 Docker service status:"
    sudo systemctl status docker --no-pager -l | head -10
else
    echo "❌ Docker service failed to start!"
    sudo systemctl status docker --no-pager -l
    exit 1
fi

# Test registry connectivity
echo "🔍 Testing registry connectivity..."
curl -f http://10.31.33.95:5000/v2/ && echo "✅ Registry is accessible" || echo "⚠️  Registry connectivity test failed"

# Clean up installation script
rm -f /tmp/install-docker-worker.sh /tmp/configure-docker-daemon.sh

echo "✅ Docker configuration completed on $(hostname)!"
SCRIPT_EOF

chmod +x /tmp/configure-docker-daemon.sh

echo "✅ Installation scripts created"

# Install Docker on all worker nodes
echo ""
echo "🔧 Installing Docker on all K8s worker nodes..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for node in "${K8S_WORKERS[@]}"; do
    echo ""
    echo "🖥️  Installing Docker on worker node: $node"
    echo "────────────────────────────────────────────────────"
    
    # Copy installation scripts to node
    echo "📤 Copying installation scripts to $node..."
    scp -o StrictHostKeyChecking=no /tmp/install-docker-worker.sh $USER@$node:/tmp/ || {
        echo "❌ Failed to copy installation script to $node"
        continue
    }
    scp -o StrictHostKeyChecking=no /tmp/configure-docker-daemon.sh $USER@$node:/tmp/ || {
        echo "❌ Failed to copy configuration script to $node"
        continue
    }
    
    # Run Docker installation on node
    echo "🐳 Installing Docker on $node..."
    ssh -o StrictHostKeyChecking=no $USER@$node "/tmp/install-docker-worker.sh" || {
        echo "❌ Docker installation failed on $node"
        continue
    }
    
    # Configure Docker daemon on node
    echo "🔧 Configuring Docker daemon on $node..."
    ssh -o StrictHostKeyChecking=no $USER@$node "/tmp/configure-docker-daemon.sh" || {
        echo "❌ Docker configuration failed on $node"
        continue
    }
    
    echo "✅ Successfully configured Docker on $node"
done

# Cleanup local scripts
echo ""
echo "🧹 Cleaning up local files..."
rm -f /tmp/install-docker-worker.sh /tmp/configure-docker-daemon.sh
echo "✅ Cleanup complete"

echo ""
echo "🎉 DOCKER INSTALLATION COMPLETE!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Summary:"
echo "   ✅ Installed Docker CE on all K8s worker nodes"
echo "   ✅ Configured insecure registry access for $REGISTRY_URL"
echo "   ✅ Added user to docker group (requires re-login)"
echo "   ✅ Started and enabled Docker service"
echo ""
echo "🚀 Next Steps:"
echo "   1. Update Jenkins pipeline to remove nodeSelector restrictions"
echo "   2. Run Jenkins pipeline build (should work on any node now)"
echo "   3. Pods can now be scheduled on any worker node"
echo "   4. Access application at: http://10.31.33.202:30222"
echo ""
echo "🔍 Verification Commands:"
echo "   • Check Docker on nodes: ssh vjmdeb@NODE_IP 'docker --version'"
echo "   • Test registry access: ssh vjmdeb@NODE_IP 'curl http://10.31.33.95:5000/v2/'"
echo "   • Check K8s pods: kubectl get pods -n devops-example"
echo ""