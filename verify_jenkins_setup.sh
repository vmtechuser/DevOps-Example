#!/bin/bash

# Jenkins GitHub Integration Verification Script
# Run this script on the Jenkins VM to verify setup

echo "=== Jenkins GitHub Integration Verification ==="
echo "Date: $(date)"
echo ""

# Check Jenkins service
echo "1. Jenkins Service Status:"
systemctl is-active jenkins
echo ""

# Check Jenkins logs for startup errors
echo "2. Recent Jenkins Logs (last 10 lines):"
sudo tail -n 10 /var/log/jenkins/jenkins.log
echo ""

# Check if Jenkins is listening on port 8080
echo "3. Jenkins Port Status:"
netstat -tlnp | grep :8080 || ss -tlnp | grep :8080
echo ""

# Check installed plugins directory
echo "4. Jenkins Plugins Directory:"
ls -la /var/lib/jenkins/plugins/ | grep -E "(git|github|pipeline|docker|maven)" | head -10
echo ""

# Check Jenkins user
echo "5. Jenkins User Information:"
id jenkins
echo ""

# Check if jenkins user is in docker group (for Docker integration)
echo "6. Jenkins User Group Membership:"
groups jenkins
echo ""

# Check Java version
echo "7. Java Version (Jenkins uses):"
sudo -u jenkins java -version
echo ""

# Check Maven installation
echo "8. Maven Installation:"
which mvn
mvn -version
echo ""

# Check Git installation  
echo "9. Git Installation:"
which git
git --version
echo ""

# Check Docker installation
echo "10. Docker Installation:"
which docker
docker --version
systemctl is-active docker
echo ""

# Test Jenkins API accessibility
echo "11. Jenkins API Test:"
curl -s -w "HTTP Status: %{http_code}\n" http://localhost:8080/api/json | head -1
echo ""

# Check Jenkins work directory
echo "12. Jenkins Work Directory:"
ls -la /var/lib/jenkins/workspace/ 2>/dev/null || echo "No workspace directory yet"
echo ""

# Check available disk space
echo "13. Disk Space:"
df -h /var/lib/jenkins
echo ""

# Check system resources
echo "14. System Resources:"
free -h
echo ""
nproc
echo ""

echo "=== Verification Complete ==="
echo ""
echo "Manual Steps Needed:"
echo "1. Access Jenkins web interface at http://10.31.33.95:8080"
echo "2. Install required plugins (Git, GitHub, Pipeline, Docker, Maven)"
echo "3. Configure GitHub credentials"
echo "4. Create pipeline job for felipemeriga/DevOps-Example"
echo "5. Configure webhook in GitHub repository"
echo ""
echo "See jenkins_github_integration_guide.md for detailed instructions"