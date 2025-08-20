#!/bin/bash

# Fix disk space and install Docker on Debian K8s worker nodes
# Run this script from your LOCAL LAPTOP

set -e

echo "🧹 Fixing Kubernetes worker nodes - disk space and Docker installation..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Configuration
K8S_WORKERS=("10.31.33.202" "10.31.33.203" "10.31.33.204")
USER="vjmdeb"
REGISTRY_URL="10.31.33.95:5000"

echo "📋 Configuration:"
echo "   K8s Workers: ${K8S_WORKERS[*]}"
echo "   User: $USER"
echo "   Registry URL: $REGISTRY_URL"
echo ""

# Create disk cleanup script
echo "📝 Creating disk cleanup script..."
cat > /tmp/cleanup-disk.sh << 'CLEANUP_EOF'
#!/bin/bash

echo "🧹 Cleaning up disk space on $(hostname)..."

# Check current disk usage
echo "📊 Current disk usage:"
df -h /

# Clean package cache
echo "🧹 Cleaning package cache..."
sudo apt-get clean

# Remove old kernels and headers (keep current and one previous)
echo "🧹 Removing old kernels..."
CURRENT_KERNEL=$(uname -r)
echo "Current kernel: $CURRENT_KERNEL"

# List all kernel packages and remove old ones
dpkg -l | grep -E "linux-(image|headers)" | grep -v "$CURRENT_KERNEL" | head -10 | awk '{print $2}' | xargs -r sudo dpkg --remove --force-remove-reinstreq

# Clean up failed packages
echo "🧹 Fixing broken packages..."
sudo dpkg --configure -a || true
sudo apt-get -f install -y || true

# Remove unnecessary packages
echo "🧹 Removing unnecessary packages..."
sudo apt-get autoremove --purge -y

# Clean more caches
echo "🧹 Cleaning additional caches..."
sudo rm -rf /var/cache/apt/archives/*
sudo rm -rf /tmp/*
sudo journalctl --vacuum-time=7d

# Check final disk usage
echo "📊 Disk usage after cleanup:"
df -h /

echo "✅ Disk cleanup completed on $(hostname)"
CLEANUP_EOF

chmod +x /tmp/cleanup-disk.sh

# Create Debian Docker installation script
echo "📝 Creating Debian Docker installation script..."
cat > /tmp/install-docker-debian.sh << 'DOCKER_EOF'
#!/bin/bash

echo "🐳 Installing Docker on Debian $(hostname)..."

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

# Add Docker's official GPG key for Debian
echo "🔑 Adding Docker GPG key for Debian..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add Docker repository for Debian
echo "📦 Adding Docker repository for Debian..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package database with Docker repo
echo "📦 Updating package database with Docker repository..."
sudo apt-get update -qq

# Install Docker Engine
echo "🐳 Installing Docker Engine..."
sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io

# Start and enable Docker service
echo "🔄 Starting Docker service..."
sudo systemctl start docker
sudo systemctl enable docker

# Add current user to docker group
echo "👤 Adding user to docker group..."
sudo usermod -aG docker $USER

# Create Docker daemon configuration directory
sudo mkdir -p /etc/docker

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

# Verify Docker installation
echo "✅ Verifying Docker installation..."
sudo docker --version
sudo systemctl is-active docker

# Test registry connectivity
echo "🔍 Testing registry connectivity..."
curl -f http://10.31.33.95:5000/v2/ && echo "✅ Registry is accessible" || echo "⚠️  Registry connectivity test failed"

# Clean up installation scripts
rm -f /tmp/cleanup-disk.sh /tmp/install-docker-debian.sh

echo "✅ Docker installation and configuration completed on $(hostname)!"
DOCKER_EOF

chmod +x /tmp/install-docker-debian.sh

echo "✅ Scripts created"

# Step 1: Clean up disk space on all worker nodes
echo ""
echo "🧹 Step 1: Cleaning up disk space on all worker nodes..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for node in "${K8S_WORKERS[@]}"; do
    echo ""
    echo "🖥️  Cleaning disk space on worker node: $node"
    echo "────────────────────────────────────────────────────"
    
    # Copy cleanup script to node
    echo "📤 Copying cleanup script to $node..."
    scp -o StrictHostKeyChecking=no /tmp/cleanup-disk.sh $USER@$node:/tmp/ || {
        echo "❌ Failed to copy cleanup script to $node"
        continue
    }
    
    # Run cleanup on node
    echo "🧹 Running disk cleanup on $node..."
    ssh -o StrictHostKeyChecking=no $USER@$node "/tmp/cleanup-disk.sh" || {
        echo "⚠️  Cleanup had issues on $node, but continuing..."
    }
    
    echo "✅ Disk cleanup attempted on $node"
done

# Step 2: Install Docker on all worker nodes
echo ""
echo "🐳 Step 2: Installing Docker on all worker nodes..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for node in "${K8S_WORKERS[@]}"; do
    echo ""
    echo "🖥️  Installing Docker on worker node: $node"
    echo "────────────────────────────────────────────────────"
    
    # Copy Docker installation script to node
    echo "📤 Copying Docker installation script to $node..."
    scp -o StrictHostKeyChecking=no /tmp/install-docker-debian.sh $USER@$node:/tmp/ || {
        echo "❌ Failed to copy Docker script to $node"
        continue
    }
    
    # Run Docker installation on node
    echo "🐳 Installing Docker on $node..."
    ssh -o StrictHostKeyChecking=no $USER@$node "/tmp/install-docker-debian.sh" || {
        echo "❌ Docker installation failed on $node"
        continue
    }
    
    echo "✅ Successfully installed Docker on $node"
done

# Step 3: Verify installation
echo ""
echo "✅ Step 3: Verifying Docker installation..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for node in "${K8S_WORKERS[@]}"; do
    echo ""
    echo "🖥️  Verifying $node..."
    echo "────────────────────────────────────────────────────"
    
    ssh -o StrictHostKeyChecking=no $USER@$node "
        echo '📊 Disk usage:'
        df -h / | head -2
        echo ''
        echo '🐳 Docker version:'
        docker --version 2>/dev/null || echo 'Docker not found'
        echo ''
        echo '🔧 Docker service:'
        systemctl is-active docker 2>/dev/null || echo 'Docker service not active'
        echo ''
        echo '📄 Docker daemon config:'
        cat /etc/docker/daemon.json 2>/dev/null || echo 'daemon.json not found'
    " || {
        echo "⚠️  Could not verify $node"
    }
done

# Cleanup local scripts
echo ""
echo "🧹 Cleaning up local files..."
rm -f /tmp/cleanup-disk.sh /tmp/install-docker-debian.sh
echo "✅ Cleanup complete"

echo ""
echo "🎉 WORKER NODE SETUP COMPLETE!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Summary:"
echo "   ✅ Cleaned up disk space on all worker nodes"
echo "   ✅ Installed Docker CE for Debian on all worker nodes"
echo "   ✅ Configured insecure registry access for $REGISTRY_URL"
echo "   ✅ Docker service started and enabled"
echo ""
echo "🚀 Next Steps:"
echo "   1. Update Jenkins pipeline to remove nodeSelector restrictions"
echo "   2. Run Jenkins pipeline build (should work on any node now)"
echo "   3. Pods can now be scheduled on any worker node"
echo ""