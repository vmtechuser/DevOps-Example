#!/bin/bash

# Setup script to configure all K8s nodes for insecure Docker registry access
# Run this from your LOCAL LAPTOP

set -e

echo "🚀 Setting up K8s cluster for insecure Docker registry access..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Configuration
JENKINS_SERVER="10.31.33.95"
K8S_MASTER="10.31.33.201"
K8S_WORKERS=("10.31.33.202" "10.31.33.203" "10.31.33.204")
ALL_NODES=("10.31.33.201" "10.31.33.202" "10.31.33.203" "10.31.33.204")
USER="vjmdeb"

echo "📋 Configuration:"
echo "   Jenkins Server: $JENKINS_SERVER"
echo "   K8s Master: $K8S_MASTER"
echo "   K8s Workers: ${K8S_WORKERS[*]}"
echo "   User: $USER"
echo ""

# Step 1: Get daemon.json from Jenkins server
echo "📥 Step 1: Getting Docker daemon configuration from Jenkins server..."
scp -o StrictHostKeyChecking=no $USER@$JENKINS_SERVER:/tmp/daemon.json /tmp/daemon.json || {
    echo "❌ Failed to get daemon.json from Jenkins server!"
    echo "Make sure Jenkins pipeline has run and created /tmp/daemon.json"
    exit 1
}
echo "✅ Retrieved daemon.json from Jenkins server"

# Show the configuration
echo ""
echo "📄 Docker daemon configuration:"
cat /tmp/daemon.json
echo ""

# Step 2: Create the configuration script
echo "📝 Step 2: Creating configuration script for K8s nodes..."
cat > /tmp/configure-node-docker.sh << 'SCRIPT_EOF'
#!/bin/bash
echo "🔧 Configuring Docker daemon on $(hostname)..."

# Backup existing daemon.json if it exists
if [ -f /etc/docker/daemon.json ]; then
    sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.backup.$(date +%Y%m%d-%H%M%S)
    echo "📋 Backed up existing daemon.json"
fi

# Install new daemon.json
sudo cp /tmp/daemon.json /etc/docker/daemon.json
echo "📄 Installed new daemon.json"

# Show the configuration
echo "📋 Docker daemon configuration:"
sudo cat /etc/docker/daemon.json

# Restart Docker service
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

# Clean up
rm -f /tmp/daemon.json /tmp/configure-node-docker.sh

echo "✅ Node $(hostname) configuration complete!"
SCRIPT_EOF

chmod +x /tmp/configure-node-docker.sh
echo "✅ Configuration script created"

# Step 3: Configure all K8s nodes
echo ""
echo "🔧 Step 3: Configuring all K8s nodes..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for node in "${ALL_NODES[@]}"; do
    node_type="worker"
    if [ "$node" == "$K8S_MASTER" ]; then
        node_type="master"
    fi
    
    echo ""
    echo "🖥️  Configuring K8s $node_type: $node"
    echo "────────────────────────────────────────"
    
    # Copy files to node
    echo "📤 Copying files to $node..."
    scp -o StrictHostKeyChecking=no /tmp/daemon.json $USER@$node:/tmp/ || {
        echo "❌ Failed to copy daemon.json to $node"
        continue
    }
    scp -o StrictHostKeyChecking=no /tmp/configure-node-docker.sh $USER@$node:/tmp/ || {
        echo "❌ Failed to copy script to $node" 
        continue
    }
    
    # Run configuration on node
    echo "⚙️  Running configuration on $node..."
    ssh -o StrictHostKeyChecking=no $USER@$node "/tmp/configure-node-docker.sh" || {
        echo "❌ Configuration failed on $node"
        continue
    }
    
    echo "✅ Successfully configured $node"
done

# Step 4: Cleanup and summary
echo ""
echo "🧹 Step 4: Cleaning up local files..."
rm -f /tmp/daemon.json /tmp/configure-node-docker.sh
echo "✅ Cleanup complete"

echo ""
echo "🎉 K8s CLUSTER CONFIGURATION COMPLETE!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Summary:"
echo "   ✅ Retrieved Docker daemon configuration from Jenkins server"
echo "   ✅ Configured Docker daemon on K8s master node"
echo "   ✅ Configured Docker daemon on all K8s worker nodes"
echo "   ✅ All nodes can now access insecure registry at 10.31.33.95:5000"
echo ""
echo "🚀 Next Steps:"
echo "   1. Run Jenkins pipeline build #22"
echo "   2. Pipeline should complete successfully without ImagePullBackOff errors"
echo "   3. Access your application at: http://10.31.33.202:30222"
echo ""
echo "🔍 If issues persist:"
echo "   • Check registry: curl http://10.31.33.95:5000/v2/"
echo "   • Check Docker on nodes: ssh vjmdeb@NODE_IP 'sudo systemctl status docker'"
echo "   • Check K8s pods: kubectl get pods -n devops-example"
echo ""