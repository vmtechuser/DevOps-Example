#!/bin/bash

# Configure K8s nodes for insecure Docker registry access
# This enables the Jenkins pipeline to deploy images to Kubernetes
# Run this script from your LOCAL LAPTOP

set -e  # Exit on any error

echo "🔧 Configuring Kubernetes nodes for insecure Docker registry..."

# Server IPs
JENKINS_SERVER="10.31.33.95"
NODES=("10.31.33.201" "10.31.33.202" "10.31.33.203" "10.31.33.204")
USER="vijaym"
DAEMON_JSON_SOURCE="/tmp/daemon.json"

# Step 0: Copy daemon.json from Jenkins server to local machine
echo "📥 Step 0: Copying daemon.json from Jenkins server..."
echo "  → Copying from $USER@$JENKINS_SERVER:/tmp/daemon.json to local /tmp/daemon.json"
scp -o StrictHostKeyChecking=no "$USER@$JENKINS_SERVER:/tmp/daemon.json" "$DAEMON_JSON_SOURCE" || {
    echo "❌ Error: Failed to copy daemon.json from Jenkins server!"
    echo "Please ensure:"
    echo "  1. Jenkins pipeline has run (build #21 or later)"
    echo "  2. You can SSH to Jenkins server: ssh $USER@$JENKINS_SERVER"
    echo "  3. File exists on Jenkins server: /tmp/daemon.json"
    exit 1
}
echo "  ✅ Successfully copied daemon.json from Jenkins server"

# Check if daemon.json exists locally now
if [ ! -f "$DAEMON_JSON_SOURCE" ]; then
    echo "❌ Error: $DAEMON_JSON_SOURCE not found locally after copy!"
    exit 1
fi

echo "📄 Using daemon.json configuration:"
cat "$DAEMON_JSON_SOURCE"
echo ""

# Step 1: Copy daemon.json to all K8s nodes
echo "📤 Step 1: Copying daemon.json to all K8s nodes..."
for node in "${NODES[@]}"; do
    echo "  → Copying to $node..."
    scp -o StrictHostKeyChecking=no "$DAEMON_JSON_SOURCE" "$USER@$node:/tmp/" || {
        echo "⚠️  Failed to copy to $node - skipping this node"
        continue
    }
    echo "    ✅ Copied to $node"
done

echo ""

# Step 2: Configure Docker on each node
echo "🔧 Step 2: Configuring Docker daemon on each K8s node..."
for node in "${NODES[@]}"; do
    echo "  → Configuring Docker on $node..."
    ssh -o StrictHostKeyChecking=no "$USER@$node" "
        # Backup existing daemon.json if it exists
        if [ -f /etc/docker/daemon.json ]; then
            sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.backup.\$(date +%Y%m%d-%H%M%S)
            echo '    📋 Backed up existing daemon.json'
        fi
        
        # Copy new daemon.json
        sudo cp /tmp/daemon.json /etc/docker/daemon.json
        echo '    📄 Installed new daemon.json'
        
        # Restart Docker service
        echo '    🔄 Restarting Docker service...'
        sudo systemctl restart docker
        
        # Verify Docker is running
        sleep 3
        if sudo systemctl is-active --quiet docker; then
            echo '    ✅ Docker service is running'
        else
            echo '    ❌ Docker service failed to start'
            exit 1
        fi
        
        # Clean up temp file
        rm -f /tmp/daemon.json
    " || {
        echo "    ⚠️  Failed to configure $node - manual intervention may be required"
        continue
    }
    echo "    ✅ Successfully configured $node"
done

echo ""
echo "🎉 Configuration complete!"
echo ""
echo "📋 Summary:"
echo "   • Configured Docker daemon on all K8s nodes for insecure registry access"
echo "   • Registry URL: 10.31.33.95:5000"
echo "   • Backed up existing configurations"
echo ""
echo "🚀 Next steps:"
echo "   1. Run Jenkins pipeline build #22"
echo "   2. The pipeline should now complete successfully"
echo "   3. Access the application at: http://10.31.33.202:30222"
echo ""
echo "🔍 If issues persist, check:"
echo "   • Jenkins registry is accessible: curl http://10.31.33.95:5000/v2/"
echo "   • Docker daemon status on nodes: sudo systemctl status docker"
echo "   • K8s pod logs: kubectl logs -n devops-example -l app=devopsexample"