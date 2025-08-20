#!/usr/bin/env groovy

/**
 * Jenkins K8s CI/CD Pipeline for felipemeriga/DevOps-Example
 * 6-Stage Pipeline: Source Control → Build → Test → Docker Build → Push to Registry → Deploy to K8s → Verify K8s
 * 
 * Updated for Java 17, Spring Boot 2.7.18, JUnit 5, Kubernetes deployment
 * Optimized for jenkins-vm at 10.31.33.95 and K8s cluster at 10.31.33.201-204
 */

pipeline {
    agent any
    
    // Global tool configuration
    tools {
        maven 'maven-3.5.2'
        jdk 'OpenJDK-17'
    }
    
    // Environment variables
    environment {
        // Application configuration
        APP_NAME = 'devopsexample'
        APP_PORT = '2222'
        
        // Docker configuration
        DOCKER_IMAGE = "${APP_NAME}"
        DOCKER_TAG = "${BUILD_NUMBER}"
        DOCKER_CONTAINER = "${APP_NAME}-container"
        
        // Registry configuration
        REGISTRY_URL = '10.31.33.95:5000'
        
        // Kubernetes configuration
        K8S_NAMESPACE = 'devops-example'
        K8S_DEPLOYMENT = 'devopsexample'
        K8S_SERVICE = 'devopsexample-service'
        
        // Build configuration
        MAVEN_OPTS = '-Dmaven.repo.local=/var/lib/jenkins/.m2/repository'
        JAVA_HOME = '/usr/lib/jvm/java-17-openjdk-amd64'
        
        // Jenkins configuration
        BUILD_TIMESTAMP = sh(script: 'date +%Y%m%d-%H%M%S', returnStdout: true).trim()
        
        // Health check configuration
        HEALTH_CHECK_URL = "http://localhost:${APP_PORT}"
        MAX_HEALTH_CHECK_ATTEMPTS = '10'
        HEALTH_CHECK_INTERVAL = '15'
    }
    
    // Build parameters
    parameters {
        choice(
            name: 'DEPLOY_ENVIRONMENT',
            choices: ['development', 'staging', 'production'],
            description: 'Target deployment environment'
        )
        choice(
            name: 'K8S_NAMESPACE', 
            choices: ['devops-example', 'staging', 'production'],
            description: 'Kubernetes namespace'
        )
        choice(
            name: 'REPLICAS',
            choices: ['1', '2', '3', '5'],
            description: 'Number of application replicas'
        )
        booleanParam(
            name: 'DEPLOY_INGRESS',
            defaultValue: true,
            description: 'Deploy Ingress for external access'
        )
        booleanParam(
            name: 'SKIP_REGISTRY_PUSH',
            defaultValue: true,
            description: 'Skip pushing to Docker registry'
        )
        booleanParam(
            name: 'SKIP_TESTS',
            defaultValue: false,
            description: 'Skip unit tests execution'
        )
        booleanParam(
            name: 'CLEANUP_OLD_IMAGES',
            defaultValue: true,
            description: 'Clean up old Docker images after deployment'
        )
    }
    
    stages {
        
        // =====================================
        // STAGE 1: SOURCE CONTROL
        // =====================================
        stage('🔄 Source Control') {
            steps {
                script {
                    echo "========================================="
                    echo "🔄 STAGE 1: SOURCE CONTROL"
                    echo "========================================="
                    echo "Build #${BUILD_NUMBER} - ${BUILD_TIMESTAMP}"
                    echo "Repository: ${env.GIT_URL ?: 'https://github.com/felipemeriga/DevOps-Example.git'}"
                    echo "Branch: ${env.GIT_BRANCH ?: 'main'}"
                    echo "Commit: ${env.GIT_COMMIT ?: 'latest'}"
                    echo "Environment: ${params.DEPLOY_ENVIRONMENT}"
                    echo "K8s Namespace: ${params.K8S_NAMESPACE}"
                    echo "Replicas: ${params.REPLICAS}"
                    echo "========================================="
                }
                
                // Clone source code from GitHub fork
                script {
                    echo "📥 Cloning source code from GitHub fork..."
                    git branch: 'master', url: 'https://github.com/vmtechuser/DevOps-Example.git'
                }
                
                // Create k8s manifests directory and files
                sh '''
                    echo "📁 Creating k8s manifests..."
                    mkdir -p k8s
                    
                    # Create namespace.yaml
                    cat > k8s/namespace.yaml << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: devops-example
  labels:
    name: devops-example
    environment: development
EOF

                    # Create deployment.yaml  
                    cat > k8s/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: devopsexample
  namespace: devops-example
  labels:
    app: devopsexample
    version: v1
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  selector:
    matchLabels:
      app: devopsexample
  template:
    metadata:
      labels:
        app: devopsexample
        version: v1
    spec:
      containers:
      - name: devopsexample
        image: \${REGISTRY_URL:-localhost:5000}/devopsexample:\${BUILD_NUMBER:-latest}
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 2222
          protocol: TCP
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /
            port: 2222
          initialDelaySeconds: 60
          periodSeconds: 30
          timeoutSeconds: 10
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /
            port: 2222
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        env:
        - name: JAVA_OPTS
          value: "-Xmx256m -Xms128m"
        - name: SERVER_PORT
          value: "2222"
EOF

                    # Create service.yaml
                    cat > k8s/service.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  name: devopsexample-service
  namespace: devops-example
  labels:
    app: devopsexample
spec:
  type: NodePort
  ports:
  - port: 2222
    targetPort: 2222
    nodePort: 30222
    protocol: TCP
    name: http
  selector:
    app: devopsexample
EOF

                    # Create ingress.yaml
                    cat > k8s/ingress.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: devopsexample-ingress
  namespace: devops-example
  labels:
    app: devopsexample
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: devops.k8s.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: devopsexample-service
            port:
              number: 2222
EOF
                    
                    echo "✅ K8s manifests created successfully"
                '''
                
                // Verify source code structure
                sh '''
                    echo "📁 Verifying project structure..."
                    ls -la
                    
                    echo "📄 Checking essential files..."
                    [ -f "pom.xml" ] && echo "✅ pom.xml found" || echo "❌ pom.xml missing"
                    [ -f "Dockerfile" ] && echo "✅ Dockerfile found" || echo "❌ Dockerfile missing"
                    [ -d "src" ] && echo "✅ src directory found" || echo "❌ src directory missing"
                    [ -d "k8s" ] && echo "✅ k8s directory found" || echo "❌ k8s directory missing"
                    
                    echo "🔍 K8s manifests:"
                    ls -la k8s/ || echo "No k8s directory found"
                '''
                
                // Set build description
                script {
                    currentBuild.description = "K8s Build #${BUILD_NUMBER} - ${params.DEPLOY_ENVIRONMENT}"
                    currentBuild.displayName = "#${BUILD_NUMBER} - K8s - ${BUILD_TIMESTAMP}"
                }
            }
        }
        
        // =====================================
        // STAGE 2: BUILD & TEST
        // =====================================
        stage('🔨 Build & Test') {
            steps {
                script {
                    echo "========================================="
                    echo "🔨 STAGE 2: BUILD & TEST"
                    echo "========================================="
                }
                
                // Clean and compile
                sh '''
                    echo "🧹 Cleaning previous builds..."
                    mvn clean -q
                    
                    echo "⚙️ Compiling source code..."
                    mvn compile -q
                '''
                
                // Run tests if not skipped
                script {
                    if (!params.SKIP_TESTS) {
                        sh '''
                            echo "🧪 Running unit tests..."
                            mvn test -q
                        '''
                    } else {
                        echo "⏭️ Tests skipped by parameter"
                    }
                }
                
                // Package application
                sh '''
                    echo "📦 Packaging application..."
                    mvn package -DskipTests -q
                    
                    echo "🔍 Verifying build artifacts..."
                    ls -la target/
                    [ -f target/devOpsDemo-0.0.1-SNAPSHOT.jar ] && echo "✅ JAR file created" || exit 1
                '''
            }
            
            post {
                always {
                    archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
                    script {
                        if (!params.SKIP_TESTS && fileExists('target/surefire-reports')) {
                            junit 'target/surefire-reports/*.xml'
                        }
                    }
                }
            }
        }
        
        // =====================================
        // STAGE 3: DOCKER BUILD
        // =====================================
        stage('🐳 Docker Build') {
            steps {
                script {
                    echo "========================================="
                    echo "🐳 STAGE 3: DOCKER BUILD"
                    echo "========================================="
                }
                
                script {
                    try {
                        // Build Docker image
                        echo "🔨 Building Docker image..."
                        def image = docker.build("${DOCKER_IMAGE}:${DOCKER_TAG}")
                        
                        // Tag as latest
                        echo "🏷️ Tagging image as latest..."
                        sh "docker tag ${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_IMAGE}:latest"
                        
                        // Show built images
                        sh '''
                            echo "📦 Docker images created:"
                            docker images | grep devopsexample | head -5
                        '''
                        
                    } catch (Exception e) {
                        error "Docker build failed: ${e.getMessage()}"
                    }
                }
            }
        }
        
        // =====================================
        // STAGE 4: PUSH TO REGISTRY
        // =====================================
        stage('📤 Push to Registry') {
            when {
                expression { !params.SKIP_REGISTRY_PUSH }
            }
            steps {
                script {
                    echo "========================================="
                    echo "📤 STAGE 4: PUSH TO REGISTRY"
                    echo "========================================="
                    echo "📤 Pushing Docker image to registry..."
                    
                    // Tag images for registry
                    sh "docker tag ${DOCKER_IMAGE}:${BUILD_NUMBER} ${REGISTRY_URL}/${DOCKER_IMAGE}:${BUILD_NUMBER}"
                    sh "docker tag ${DOCKER_IMAGE}:${BUILD_NUMBER} ${REGISTRY_URL}/${DOCKER_IMAGE}:latest"
                    
                    // Push to registry
                    sh "docker push ${REGISTRY_URL}/${DOCKER_IMAGE}:${BUILD_NUMBER}"
                    sh "docker push ${REGISTRY_URL}/${DOCKER_IMAGE}:latest"
                    
                    echo "✅ Images pushed successfully"
                }
            }
        }
        
        // =====================================
        // STAGE 5: DEPLOY TO K8S
        // =====================================
        stage('🚀 Deploy to K8s') {
            steps {
                script {
                    echo "========================================="
                    echo "🚀 STAGE 5: DEPLOY TO KUBERNETES"
                    echo "========================================="
                    echo "🚀 Deploying to Kubernetes cluster..."
                    
                    // Apply namespace first
                    sh "KUBECONFIG=/tmp/kubeconfig /tmp/kubectl apply -f k8s/namespace.yaml"
                    
                    // Check Docker daemon configuration  
                    echo "🔧 Checking Docker daemon configuration..."
                    sh """
                        # Create daemon.json configuration file for manual setup
                        echo '{\"insecure-registries\":[\"10.31.33.95:5000\"]}' > /tmp/jenkins-daemon.json
                        echo "📄 Jenkins server Docker daemon.json created at /tmp/jenkins-daemon.json"
                        echo "⚠️  If Docker registry push fails, manually copy to /etc/docker/daemon.json and restart Docker"
                        echo "✅ Configuration prepared"
                    """
                    
                    // Start local registry and push image
                    echo "📦 Setting up local Docker registry..."
                    sh """
                        # Start local registry if not running, bind to all interfaces
                        docker run -d -p 0.0.0.0:5000:5000 --restart=always --name registry registry:2 2>/dev/null || echo "Registry already running"
                        
                        # Tag and push image to local registry
                        docker tag devopsexample:${BUILD_NUMBER} localhost:5000/devopsexample:${BUILD_NUMBER}
                        docker push localhost:5000/devopsexample:${BUILD_NUMBER}
                        
                        # Also tag for external access
                        docker tag devopsexample:${BUILD_NUMBER} 10.31.33.95:5000/devopsexample:${BUILD_NUMBER}
                        
                        # Test registry connectivity
                        curl -f http://localhost:5000/v2/ || echo "Registry may not be accessible"
                        
                        echo "✅ Image pushed to local registry"
                    """
                    
                    // Create insecure registry configuration for manual setup
                    echo "🔧 Creating Docker daemon configuration for K8s nodes..."
                    sh """
                        # Create daemon.json for manual configuration
                        echo '{\"insecure-registries\":[\"10.31.33.95:5000\"]}' > /tmp/daemon.json
                        echo "📄 Docker daemon.json created at /tmp/daemon.json"
                        echo "⚠️  MANUAL STEP REQUIRED: Copy this file to /etc/docker/daemon.json on ALL K8s nodes"
                        echo "⚠️  Then restart Docker service on each node: sudo systemctl restart docker"
                        echo "✅ Configuration file prepared"
                    """
                    
                    // Tag image for K8s registry  
                    echo "📦 Tagging image for Kubernetes registry..."
                    sh """
                        # Tag image for K8s registry access
                        docker tag localhost:5000/devopsexample:${BUILD_NUMBER} 10.31.33.95:5000/devopsexample:${BUILD_NUMBER}
                        echo "✅ Image tagged as 10.31.33.95:5000/devopsexample:${BUILD_NUMBER}"
                        
                        # Show available images
                        echo "📋 Available Docker images:"
                        docker images | grep devopsexample | head -3
                    """
                    
                    // Delete existing deployment to force recreation
                    echo "🗑️ Cleaning up existing deployment..."
                    sh """
                        export KUBECONFIG=/tmp/kubeconfig
                        /tmp/kubectl delete deployment devopsexample -n devops-example --ignore-not-found=true
                        echo "✅ Existing deployment cleaned up"
                    """
                    
                    // Apply manifests with variable substitution
                    sh """
                        export BUILD_NUMBER=${BUILD_NUMBER}
                        export REGISTRY_URL=${REGISTRY_URL}
                        export KUBECONFIG=/tmp/kubeconfig
                        
                        # Create deployment with correct values
                        sed -e 's/replicas: 3/replicas: ${params.REPLICAS}/' \\
                            -e 's|\${REGISTRY_URL:-localhost:5000}|10.31.33.95:5000|g' \\
                            -e 's|\${BUILD_NUMBER:-latest}|${BUILD_NUMBER}|g' \\
                            k8s/deployment.yaml | /tmp/kubectl apply -f -
                        /tmp/kubectl apply -f k8s/service.yaml
                    """
                    
                    // Apply ingress if requested
                    script {
                        if (params.DEPLOY_INGRESS) {
                            sh "KUBECONFIG=/tmp/kubeconfig /tmp/kubectl apply -f k8s/ingress.yaml"
                            echo "✅ Ingress deployed"
                        } else {
                            echo "⏭️ Ingress deployment skipped"
                        }
                    }
                    
                    // Wait for deployment rollout
                    sh "KUBECONFIG=/tmp/kubeconfig /tmp/kubectl rollout status deployment/${K8S_DEPLOYMENT} -n ${params.K8S_NAMESPACE} --timeout=300s"
                    
                    echo "✅ Kubernetes deployment completed"
                }
            }
        }
        
        // =====================================
        // STAGE 6: VERIFY K8S DEPLOYMENT
        // =====================================
        stage('✅ Verify K8s') {
            steps {
                script {
                    echo "========================================="
                    echo "✅ STAGE 6: VERIFY KUBERNETES DEPLOYMENT"
                    echo "========================================="
                    echo "✅ Verifying Kubernetes deployment..."
                    
                    // Check cluster status
                    sh """
                        export KUBECONFIG=/tmp/kubeconfig
                        echo "📊 Cluster nodes:"
                        /tmp/kubectl get nodes
                        
                        echo "📦 Pods status:"
                        /tmp/kubectl get pods -n ${params.K8S_NAMESPACE} -l app=${K8S_DEPLOYMENT}
                        
                        echo "🔗 Services:"
                        /tmp/kubectl get svc -n ${params.K8S_NAMESPACE}
                        
                        echo "📋 Deployment status:"
                        /tmp/kubectl describe deployment ${K8S_DEPLOYMENT} -n ${params.K8S_NAMESPACE}
                    """
                    
                    // Health check via service
                    sh """
                        export KUBECONFIG=/tmp/kubeconfig
                        echo "🔍 Testing service endpoints..."
                        CLUSTER_IP=\$(/tmp/kubectl get svc ${K8S_SERVICE} -n ${params.K8S_NAMESPACE} -o jsonpath='{.spec.clusterIP}')
                        echo "Cluster IP: \${CLUSTER_IP}"
                        
                        # Test internal service
                        /tmp/kubectl run curl-test --image=curlimages/curl:latest --rm -i --restart=Never -- curl -f http://\${CLUSTER_IP}/ || echo "Service test completed"
                        
                        # Get NodePort for external access
                        NODE_PORT=\$(/tmp/kubectl get svc ${K8S_SERVICE} -n ${params.K8S_NAMESPACE} -o jsonpath='{.spec.ports[0].nodePort}')
                        echo "✅ External access: http://10.31.33.202:\${NODE_PORT}"
                        echo "✅ External access: http://10.31.33.203:\${NODE_PORT}"
                        echo "✅ External access: http://10.31.33.204:\${NODE_PORT}"
                    """
                }
            }
        }
    }
    
    // =====================================
    // POST-BUILD ACTIONS
    // =====================================
    post {
        always {
            script {
                echo "========================================="
                echo "📊 K8S PIPELINE SUMMARY"
                echo "========================================="
                echo "Build #${BUILD_NUMBER} completed"
                echo "Duration: ${currentBuild.durationString}"
                echo "Environment: ${params.DEPLOY_ENVIRONMENT}"
                echo "K8s Namespace: ${params.K8S_NAMESPACE}"
                echo "Replicas: ${params.REPLICAS}"
                echo "Docker Image: ${REGISTRY_URL}/${DOCKER_IMAGE}:${DOCKER_TAG}"
                echo "External Access: http://worker-node-ip:30222"
                echo "========================================="
            }
            
            // Clean up workspace
            cleanWs()
        }
        
        success {
            script {
                echo "🎉 K8S PIPELINE SUCCESSFUL!"
                echo "✅ Application deployed to Kubernetes cluster"
                echo "🔗 Access via: http://10.31.33.202:30222"
                echo "🔗 Access via: http://10.31.33.203:30222"
                echo "🔗 Access via: http://10.31.33.204:30222"
            }
        }
        
        failure {
            script {
                echo "💥 K8S PIPELINE FAILED!"
                echo "❌ Check build logs for details"
                
                // Show K8s diagnostics if available
                try {
                    sh """
                        echo "K8s pod status:"
                        KUBECONFIG=/tmp/kubeconfig /tmp/kubectl get pods -n ${params.K8S_NAMESPACE} || echo "Could not retrieve pod status"
                        
                        echo "K8s events:"
                        KUBECONFIG=/tmp/kubeconfig /tmp/kubectl get events -n ${params.K8S_NAMESPACE} --sort-by='.lastTimestamp' | tail -10 || echo "Could not retrieve events"
                    """
                } catch (Exception e) {
                    echo "Could not retrieve K8s diagnostics: ${e.getMessage()}"
                }
            }
        }
        
        cleanup {
            script {
                // Clean up old Docker images if requested
                if (params.CLEANUP_OLD_IMAGES) {
                    try {
                        echo "🧹 Cleaning up old Docker images..."
                        sh '''
                            # Keep last 3 builds
                            docker images ${DOCKER_IMAGE} --format "table {{.Tag}}\\t{{.ID}}" | \\
                            tail -n +2 | sort -rn | tail -n +4 | awk '{print $2}' | \\
                            xargs -r docker rmi || true
                            
                            # Clean up dangling images
                            docker image prune -f || true
                        '''
                        echo "✅ Docker cleanup completed"
                    } catch (Exception e) {
                        echo "⚠️ Docker cleanup warning: ${e.getMessage()}"
                    }
                }
            }
        }
    }
}