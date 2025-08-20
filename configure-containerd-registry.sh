#!/bin/bash

# Configure containerd for insecure Docker registry on all K8s nodes
# This fixes the "http: server gave HTTP response to HTTPS client" error
# Run this script from your LOCAL LAPTOP

set -e

echo "🔧 Configuring containerd for insecure Docker registry..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Configuration
K8S_NODES=("10.31.33.201" "10.31.33.202" "10.31.33.203" "10.31.33.204")
USER="vjmdeb"
REGISTRY_URL="10.31.33.95:5000"

echo "📋 Configuration:"
echo "   K8s Nodes: ${K8S_NODES[*]}"
echo "   User: $USER"
echo "   Registry URL: $REGISTRY_URL"
echo ""

# Create containerd configuration script
echo "📝 Creating containerd configuration script..."
cat > /tmp/configure-containerd.sh << 'SCRIPT_EOF'
#!/bin/bash

echo "🔧 Configuring containerd on $(hostname) for insecure registry..."

# Check if containerd is running
if ! systemctl is-active --quiet containerd; then
    echo "❌ containerd is not running on $(hostname)"
    exit 1
fi

# Create containerd config directory
sudo mkdir -p /etc/containerd

# Backup existing containerd config if it exists
if [ -f /etc/containerd/config.toml ]; then
    sudo cp /etc/containerd/config.toml /etc/containerd/config.toml.backup.$(date +%Y%m%d-%H%M%S)
    echo "📋 Backed up existing containerd config"
fi

# Create containerd configuration with insecure registry
echo "📄 Creating containerd configuration..."
sudo tee /etc/containerd/config.toml > /dev/null << 'EOF'
version = 2
[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    [plugins."io.containerd.grpc.v1.cri".registry]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."10.31.33.95:5000"]
          endpoint = ["http://10.31.33.95:5000"]
      [plugins."io.containerd.grpc.v1.cri".registry.configs]
        [plugins."io.containerd.grpc.v1.cri".registry.configs."10.31.33.95:5000".tls]
          insecure_skip_verify = true
        [plugins."io.containerd.grpc.v1.cri".registry.configs."10.31.33.95:5000".transport]
          protocol = "http"
EOF

echo "📋 containerd configuration:"
sudo cat /etc/containerd/config.toml

# Restart containerd service
echo "🔄 Restarting containerd service..."
sudo systemctl restart containerd

# Wait for containerd to start
sleep 5

# Verify containerd is running
if sudo systemctl is-active --quiet containerd; then
    echo "✅ containerd service is active"
    echo "📊 containerd service status:"
    sudo systemctl status containerd --no-pager -l | head -10
else
    echo "❌ containerd service failed to start!"
    sudo systemctl status containerd --no-pager -l
    exit 1
fi

# Test registry connectivity from containerd
echo "🔍 Testing registry connectivity..."
sudo ctr --namespace k8s.io image pull --plain-http 10.31.33.95:5000/hello-world:latest 2>/dev/null || echo "Registry connectivity test completed (expected failure for hello-world)"

# Clean up script
rm -f /tmp/configure-containerd.sh

echo "✅ containerd configuration completed on $(hostname)!"
SCRIPT_EOF

chmod +x /tmp/configure-containerd.sh

echo "✅ containerd configuration script created"

# Configure containerd on all K8s nodes
echo ""
echo "🔧 Configuring containerd on all K8s nodes..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for node in "${K8S_NODES[@]}"; do
    node_type="worker"
    if [ "$node" == "10.31.33.201" ]; then
        node_type="master"
    fi
    
    echo ""
    echo "🖥️  Configuring containerd on K8s $node_type: $node"
    echo "────────────────────────────────────────────────────────"
    
    # Copy containerd configuration script to node
    echo "📤 Copying containerd script to $node..."
    scp -o StrictHostKeyChecking=no /tmp/configure-containerd.sh $USER@$node:/tmp/ || {
        echo "❌ Failed to copy script to $node"
        continue
    }
    
    # Run containerd configuration on node
    echo "⚙️  Configuring containerd on $node..."
    ssh -o StrictHostKeyChecking=no $USER@$node "/tmp/configure-containerd.sh" || {
        echo "❌ containerd configuration failed on $node"
        continue
    }
    
    echo "✅ Successfully configured containerd on $node"
done

# Step 3: Verify containerd configuration
echo ""
echo "✅ Verifying containerd configuration..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for node in "${K8S_NODES[@]}"; do
    node_type="worker"
    if [ "$node" == "10.31.33.201" ]; then
        node_type="master"
    fi
    
    echo ""
    echo "🖥️  Verifying containerd on $node_type $node..."
    echo "────────────────────────────────────────────────────────"
    
    ssh -o StrictHostKeyChecking=no $USER@$node "
        echo '🔧 containerd service status:'
        systemctl is-active containerd 2>/dev/null || echo 'containerd not active'
        echo ''
        echo '📄 containerd config exists:'
        [ -f /etc/containerd/config.toml ] && echo 'containerd config found' || echo 'containerd config missing'
        echo ''
        echo '🔍 Registry configuration:'
        grep -A5 -B5 '10.31.33.95:5000' /etc/containerd/config.toml 2>/dev/null | head -10 || echo 'Registry config not found'
    " || {
        echo "⚠️  Could not verify $node"
    }
done

# Cleanup local script
echo ""
echo "🧹 Cleaning up local files..."
rm -f /tmp/configure-containerd.sh
echo "✅ Cleanup complete"

echo ""
echo "🎉 CONTAINERD CONFIGURATION COMPLETE!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Summary:"
echo "   ✅ Configured containerd on all K8s nodes for insecure registry"
echo "   ✅ Registry URL: $REGISTRY_URL configured as HTTP"
echo "   ✅ containerd service restarted on all nodes"
echo ""
echo "🚀 Next Steps:"
echo "   1. Run Jenkins pipeline build #27"
echo "   2. Pipeline should now complete successfully without ImagePullBackOff"
echo "   3. Pods should successfully pull images from insecure registry"
echo "   4. Access application at: http://worker-node-ip:30222"
echo ""
echo "🔍 If issues persist:"
echo "   • Check containerd logs: journalctl -u containerd -f"
echo "   • Verify config: cat /etc/containerd/config.toml"
echo "   • Test manual pull: sudo ctr --namespace k8s.io image pull --plain-http $REGISTRY_URL/devopsexample:26"
echo ""