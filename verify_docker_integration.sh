#!/bin/bash

# Jenkins Docker Integration Verification Script
# Run this script on the Jenkins VM to verify Docker integration

echo "=== Jenkins Docker Integration Verification ==="
echo "Date: $(date)"
echo ""

# Check Docker service status
echo "1. Docker Service Status:"
systemctl is-active docker
systemctl status docker --no-pager -l | head -5
echo ""

# Check Docker version and info
echo "2. Docker Version Information:"
docker --version
echo ""

# Check Docker daemon info
echo "3. Docker System Information:"
docker info | grep -E "(Server Version|Storage Driver|Cgroup Driver|Kernel Version)"
echo ""

# Check Docker socket permissions
echo "4. Docker Socket Permissions:"
ls -la /var/run/docker.sock
echo ""

# Check jenkins user and groups
echo "5. Jenkins User Information:"
id jenkins
echo "Jenkins user groups:"
groups jenkins
echo ""

# Test Docker access as jenkins user
echo "6. Docker Access Test (as jenkins user):"
if sudo -u jenkins docker ps >/dev/null 2>&1; then
    echo "✅ Jenkins user can access Docker"
    sudo -u jenkins docker ps
else
    echo "❌ Jenkins user cannot access Docker"
    echo "Run: sudo usermod -aG docker jenkins && sudo systemctl restart jenkins"
fi
echo ""

# Test Docker image operations
echo "7. Docker Image Operations Test:"
echo "Available Docker images:"
docker images | head -5
echo ""

# Test Docker network
echo "8. Docker Network Configuration:"
docker network ls
echo ""

# Check Docker storage
echo "9. Docker Storage Information:"
docker system df
echo ""

# Check for running containers
echo "10. Currently Running Containers:"
docker ps
echo ""

# Test basic Docker functionality
echo "11. Docker Functionality Test:"
if docker run --rm hello-world >/dev/null 2>&1; then
    echo "✅ Docker basic functionality works"
else
    echo "❌ Docker basic functionality failed"
fi
echo ""

# Test Docker build capability
echo "12. Docker Build Test:"
cat > /tmp/test-dockerfile << 'EOF'
FROM alpine:latest
RUN echo "Docker build test" > /test.txt
CMD cat /test.txt
EOF

if docker build -t test-build /tmp -f /tmp/test-dockerfile >/dev/null 2>&1; then
    echo "✅ Docker build capability works"
    docker rmi test-build >/dev/null 2>&1
else
    echo "❌ Docker build capability failed"
fi
rm -f /tmp/test-dockerfile
echo ""

# Check Jenkins plugin directory for Docker plugins
echo "13. Jenkins Docker Plugins Check:"
if [ -d "/var/lib/jenkins/plugins" ]; then
    echo "Docker-related plugins installed:"
    ls /var/lib/jenkins/plugins/ | grep -i docker | head -5
    echo ""
    
    echo "Pipeline-related plugins:"
    ls /var/lib/jenkins/plugins/ | grep -i pipeline | head -5
else
    echo "Jenkins plugins directory not found"
fi
echo ""

# Test Jenkins Docker integration (if Jenkins is running)
echo "14. Jenkins Docker Integration Test:"
if curl -s http://localhost:8080 >/dev/null 2>&1; then
    echo "Jenkins is accessible on port 8080"
    
    # Test if jenkins user can run Docker commands
    if sudo -u jenkins docker version >/dev/null 2>&1; then
        echo "✅ Jenkins user can execute Docker commands"
    else
        echo "❌ Jenkins user cannot execute Docker commands"
    fi
else
    echo "Jenkins is not accessible on port 8080"
fi
echo ""

# Check system resources
echo "15. System Resources:"
echo "Memory usage:"
free -h
echo ""
echo "Disk usage:"
df -h | grep -E "(^/dev|Use%)"
echo ""
echo "CPU cores:"
nproc
echo ""

# Check for potential issues
echo "16. Potential Issues Check:"

# Check Docker daemon logs for errors
echo "Recent Docker daemon logs:"
journalctl -u docker --no-pager -l | tail -3
echo ""

# Check disk space
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    echo "⚠️  Warning: Disk usage is high (${DISK_USAGE}%)"
else
    echo "✅ Disk usage is acceptable (${DISK_USAGE}%)"
fi

# Check memory usage
MEMORY_USAGE=$(free | awk 'NR==2{printf "%.0f", $3/$2*100}')
if [ "$MEMORY_USAGE" -gt 80 ]; then
    echo "⚠️  Warning: Memory usage is high (${MEMORY_USAGE}%)"
else
    echo "✅ Memory usage is acceptable (${MEMORY_USAGE}%)"
fi
echo ""

echo "=== Docker Integration Verification Complete ==="
echo ""
echo "Summary:"
echo "1. Ensure Docker service is running"
echo "2. Verify jenkins user is in docker group"
echo "3. Install Docker Pipeline plugin in Jenkins"
echo "4. Test Docker commands in Jenkins pipeline"
echo "5. Configure Docker registry credentials if needed"
echo ""
echo "Next Steps:"
echo "- Create Jenkins pipeline with Docker integration"
echo "- Test Docker build and deployment stages"
echo "- Configure container monitoring and logging"