#!/usr/bin/env groovy

/**
 * Jenkins CI/CD Pipeline for vmtechuser/DevOps-Example
 * 6-Stage Pipeline: Source Control → Build → Test → Docker Build → Deploy → Verification
 * 
 * Updated for Java 17, Spring Boot 2.7.18, JUnit 5
 * Optimized for jenkins-vm at 10.31.33.95
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
    
    // Build parameters (optional)
    parameters {
        choice(
            name: 'DEPLOY_ENVIRONMENT',
            choices: ['development', 'staging', 'production'],
            description: 'Target deployment environment'
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
        stage('1️⃣ Source Control') {
            steps {
                script {
                    echo "========================================="
                    echo "🔄 STAGE 1: SOURCE CONTROL"
                    echo "========================================="
                    echo "Build #${BUILD_NUMBER} - ${BUILD_TIMESTAMP}"
                    echo "Repository: ${env.GIT_URL ?: 'https://github.com/vmtechuser/DevOps-Example.git'}"
                    echo "Branch: ${env.GIT_BRANCH ?: 'main'}"
                    echo "Commit: ${env.GIT_COMMIT ?: 'latest'}"
                    echo "Environment: ${params.DEPLOY_ENVIRONMENT}"
                    echo "========================================="
                }
                
                // Verify source code structure
                sh '''
                    echo "📁 Verifying project structure..."
                    ls -la
                    
                    echo "📄 Checking essential files..."
                    [ -f "pom.xml" ] && echo "✅ pom.xml found" || echo "❌ pom.xml missing"
                    [ -f "Dockerfile" ] && echo "✅ Dockerfile found" || echo "❌ Dockerfile missing"
                    [ -d "src" ] && echo "✅ src directory found" || echo "❌ src directory missing"
                    
                    echo "🔍 Project information from pom.xml:"
                    grep -E "(artifactId|groupId|version)" pom.xml | head -6
                '''
                
                // Set build description
                script {
                    currentBuild.description = "Build #${BUILD_NUMBER} - ${params.DEPLOY_ENVIRONMENT}"
                    currentBuild.displayName = "#${BUILD_NUMBER} - ${BUILD_TIMESTAMP}"
                }
            }
        }
        
        // =====================================
        // STAGE 2: BUILD
        // =====================================
        stage('2️⃣ Build') {
            steps {
                script {
                    echo "========================================="
                    echo "🔨 STAGE 2: BUILD"
                    echo "========================================="
                }
                
                // Clean previous builds
                sh '''
                    echo "🧹 Cleaning previous builds..."
                    mvn clean -q
                '''
                
                // Compile source code
                sh '''
                    echo "⚙️ Compiling source code..."
                    mvn compile -q
                    
                    echo "📦 Packaging application..."
                    mvn package -DskipTests -q
                '''
                
                // Verify build artifacts
                sh '''
                    echo "🔍 Verifying build artifacts..."
                    ls -la target/
                    
                    if [ -f target/devOpsDemo-0.0.1-SNAPSHOT.jar ]; then
                        JAR_SIZE=$(stat -c%s target/devOpsDemo-0.0.1-SNAPSHOT.jar)
                        echo "✅ JAR file created successfully (${JAR_SIZE} bytes)"
                        
                        # Check JAR contents
                        jar -tf target/devOpsDemo-0.0.1-SNAPSHOT.jar | head -10
                    else
                        echo "❌ JAR file not found!"
                        exit 1
                    fi
                '''
            }
            
            post {
                success {
                    // Archive build artifacts
                    archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
                    echo "✅ Build artifacts archived successfully"
                }
                failure {
                    echo "❌ Build stage failed!"
                }
            }
        }
        
        // =====================================
        // STAGE 3: TEST
        // =====================================
        stage('3️⃣ Test') {
            when {
                expression { !params.SKIP_TESTS }
            }
            steps {
                script {
                    echo "========================================="
                    echo "🧪 STAGE 3: TEST"
                    echo "========================================="
                }
                
                // Run unit tests
                sh '''
                    echo "🧪 Running unit tests..."
                    mvn test -q
                    
                    echo "📊 Test results summary:"
                    if [ -d "target/surefire-reports" ]; then
                        TOTAL_TESTS=$(find target/surefire-reports -name "*.xml" -exec grep -l "testsuite" {} \\; | wc -l)
                        echo "Total test suites: ${TOTAL_TESTS}"
                        
                        # Count test results
                        grep -r "tests=" target/surefire-reports/*.xml | head -5 | sed 's/.*tests="\\([0-9]*\\)".*/Tests: \\1/' || echo "No detailed test count available"
                    else
                        echo "⚠️ No surefire reports directory found"
                    fi
                '''
                
                // Generate test reports
                script {
                    if (fileExists('target/surefire-reports')) {
                        echo "📋 Publishing test results..."
                    }
                }
            }
            
            post {
                always {
                    // Publish test results
                    script {
                        try {
                            publishTestResults testResultsPattern: 'target/surefire-reports/*.xml'
                            echo "✅ Test results published"
                        } catch (Exception e) {
                            echo "⚠️ Could not publish test results: ${e.getMessage()}"
                        }
                    }
                    
                    // Archive test reports
                    archiveArtifacts artifacts: 'target/surefire-reports/**', allowEmptyArchive: true
                }
                success {
                    echo "✅ All tests passed successfully!"
                }
                failure {
                    echo "❌ Some tests failed!"
                }
            }
        }
        
        // =====================================
        // STAGE 4: DOCKER BUILD
        // =====================================
        stage('4️⃣ Docker Build') {
            steps {
                script {
                    echo "========================================="
                    echo "🐳 STAGE 4: DOCKER BUILD"
                    echo "========================================="
                }
                
                // Verify Dockerfile exists
                sh '''
                    echo "📄 Verifying Dockerfile..."
                    if [ -f "Dockerfile" ]; then
                        echo "✅ Dockerfile found"
                        echo "📋 Dockerfile contents:"
                        cat Dockerfile
                    else
                        echo "❌ Dockerfile not found!"
                        exit 1
                    fi
                '''
                
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
                            
                            echo "💾 Image details:"
                            docker inspect ${DOCKER_IMAGE}:${DOCKER_TAG} | grep -E "(Created|Size)" | head -2
                        '''
                        
                    } catch (Exception e) {
                        error "Docker build failed: ${e.getMessage()}"
                    }
                }
            }
            
            post {
                success {
                    echo "✅ Docker image built successfully!"
                }
                failure {
                    echo "❌ Docker build failed!"
                }
            }
        }
        
        // =====================================
        // STAGE 5: LOCAL DEPLOY
        // =====================================
        stage('5️⃣ Local Deploy') {
            steps {
                script {
                    echo "========================================="
                    echo "🚀 STAGE 5: LOCAL DEPLOY"
                    echo "========================================="
                }
                
                script {
                    try {
                        // Stop and remove existing container
                        echo "🛑 Stopping existing containers..."
                        sh '''
                            if docker ps -q -f name=${DOCKER_CONTAINER}; then
                                echo "Stopping existing container: ${DOCKER_CONTAINER}"
                                docker stop ${DOCKER_CONTAINER} || true
                            fi
                            
                            if docker ps -aq -f name=${DOCKER_CONTAINER}; then
                                echo "Removing existing container: ${DOCKER_CONTAINER}"
                                docker rm ${DOCKER_CONTAINER} || true
                            fi
                        '''
                        
                        // Deploy new container
                        echo "🚀 Deploying new container..."
                        sh """
                            docker run -d \\
                                --name ${DOCKER_CONTAINER} \\
                                --restart unless-stopped \\
                                -p ${APP_PORT}:${APP_PORT} \\
                                -e ENVIRONMENT=${params.DEPLOY_ENVIRONMENT} \\
                                -e BUILD_NUMBER=${BUILD_NUMBER} \\
                                ${DOCKER_IMAGE}:${DOCKER_TAG}
                        """
                        
                        // Wait for container to start
                        echo "⏳ Waiting for container to initialize..."
                        sleep(time: 30, unit: 'SECONDS')
                        
                        // Show container status
                        sh '''
                            echo "📊 Container status:"
                            docker ps | grep devopsexample || echo "Container not found in ps output"
                            
                            echo "🔍 Container details:"
                            docker inspect ${DOCKER_CONTAINER} | grep -E "(Status|IPAddress|PortBindings)" | head -3
                            
                            echo "📝 Initial container logs:"
                            docker logs ${DOCKER_CONTAINER} | head -20
                        '''
                        
                    } catch (Exception e) {
                        error "Deployment failed: ${e.getMessage()}"
                    }
                }
            }
            
            post {
                success {
                    echo "✅ Application deployed successfully!"
                }
                failure {
                    echo "❌ Deployment failed!"
                    script {
                        // Show container logs for debugging
                        try {
                            sh "docker logs ${DOCKER_CONTAINER} | tail -50"
                        } catch (Exception e) {
                            echo "Could not retrieve container logs: ${e.getMessage()}"
                        }
                    }
                }
            }
        }
        
        // =====================================
        // STAGE 6: VERIFICATION
        // =====================================
        stage('6️⃣ Verification') {
            steps {
                script {
                    echo "========================================="
                    echo "✅ STAGE 6: VERIFICATION"
                    echo "========================================="
                }
                
                script {
                    def healthCheckPassed = false
                    def retryCount = 0
                    def maxRetries = Integer.parseInt(MAX_HEALTH_CHECK_ATTEMPTS)
                    def checkInterval = Integer.parseInt(HEALTH_CHECK_INTERVAL)
                    
                    // Health check loop
                    while (retryCount < maxRetries && !healthCheckPassed) {
                        try {
                            echo "🔍 Health check attempt ${retryCount + 1}/${maxRetries}..."
                            
                            // Check container status
                            def containerStatus = sh(
                                script: "docker inspect --format='{{.State.Status}}' ${DOCKER_CONTAINER}",
                                returnStdout: true
                            ).trim()
                            
                            echo "Container status: ${containerStatus}"
                            
                            if (containerStatus == 'running') {
                                // HTTP health check
                                def httpResult = sh(
                                    script: "curl -f -s -o /dev/null -w '%{http_code}' --connect-timeout 10 ${HEALTH_CHECK_URL}",
                                    returnStdout: true
                                ).trim()
                                
                                echo "HTTP response: ${httpResult}"
                                
                                if (httpResult == '200') {
                                    healthCheckPassed = true
                                    echo "✅ Health check passed! Application is responding correctly."
                                } else if (httpResult.startsWith('4') || httpResult.startsWith('5')) {
                                    echo "⚠️ HTTP ${httpResult} - Application running but may have issues"
                                } else {
                                    echo "⏳ HTTP ${httpResult} - Application still starting..."
                                }
                            } else {
                                echo "❌ Container not running: ${containerStatus}"
                            }
                            
                        } catch (Exception e) {
                            echo "Health check failed: ${e.getMessage()}"
                        }
                        
                        if (!healthCheckPassed && retryCount < maxRetries - 1) {
                            echo "⏳ Waiting ${checkInterval} seconds before next attempt..."
                            sleep(time: checkInterval, unit: 'SECONDS')
                        }
                        
                        retryCount++
                    }
                    
                    // Final verification
                    if (!healthCheckPassed) {
                        // Show detailed diagnostics
                        echo "❌ Health check failed after ${maxRetries} attempts"
                        echo "📋 Diagnostic information:"
                        
                        try {
                            sh """
                                echo "Container processes:"
                                docker exec ${DOCKER_CONTAINER} ps aux || true
                                
                                echo "Container environment:"
                                docker exec ${DOCKER_CONTAINER} env | grep -E "(JAVA|SPRING|PORT)" || true
                                
                                echo "Network connectivity:"
                                docker exec ${DOCKER_CONTAINER} netstat -tlnp || true
                                
                                echo "Recent container logs:"
                                docker logs --tail 50 ${DOCKER_CONTAINER}
                            """
                        } catch (Exception e) {
                            echo "Could not retrieve diagnostic information: ${e.getMessage()}"
                        }
                        
                        error("Application health check failed - deployment verification unsuccessful")
                    }
                    
                    // Additional verification tests
                    echo "🧪 Running additional verification tests..."
                    try {
                        // Test application endpoints (if available)
                        sh """
                            echo "Testing application endpoints..."
                            curl -s ${HEALTH_CHECK_URL} | head -10 || echo "Could not retrieve application response"
                            
                            echo "Container resource usage:"
                            docker stats ${DOCKER_CONTAINER} --no-stream
                        """
                    } catch (Exception e) {
                        echo "Additional tests failed: ${e.getMessage()}"
                    }
                }
            }
            
            post {
                success {
                    script {
                        echo "✅ All verification tests passed!"
                        echo "🎉 Application successfully deployed and verified!"
                        echo "🔗 Application URL: http://10.31.33.95:${APP_PORT}"
                        
                        // Set build result description
                        currentBuild.description = "✅ Deployed to ${params.DEPLOY_ENVIRONMENT} - Port ${APP_PORT}"
                    }
                }
                failure {
                    echo "❌ Verification failed!"
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
                echo "📊 PIPELINE SUMMARY"
                echo "========================================="
                echo "Build #${BUILD_NUMBER} completed"
                echo "Duration: ${currentBuild.durationString}"
                echo "Environment: ${params.DEPLOY_ENVIRONMENT}"
                echo "Docker Image: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                echo "Container: ${DOCKER_CONTAINER}"
                echo "Application URL: http://10.31.33.95:${APP_PORT}"
                echo "========================================="
            }
            
            // Clean up workspace
            cleanWs()
        }
        
        success {
            script {
                echo "🎉 PIPELINE SUCCESSFUL!"
                echo "✅ Application deployed at: http://10.31.33.95:${APP_PORT}"
                
                // Optional: Send success notification
                // Example: Slack, email, etc.
            }
        }
        
        failure {
            script {
                echo "💥 PIPELINE FAILED!"
                echo "❌ Check build logs for details"
                
                // Show container logs if available
                try {
                    sh """
                        echo "Final container logs:"
                        docker logs ${DOCKER_CONTAINER} | tail -100 || echo "Could not retrieve logs"
                        
                        echo "Container status:"
                        docker ps -a | grep devopsexample || echo "No containers found"
                    """
                } catch (Exception e) {
                    echo "Could not retrieve failure diagnostics: ${e.getMessage()}"
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