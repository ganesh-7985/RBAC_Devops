pipeline {
    agent any

    environment {
        // Application
        APP_NAME = 'secure-api-gateway'
        
        // Docker Registry (configure in Jenkins)
        REGISTRY = credentials('docker-registry-url')  // e.g., ghcr.io/your-org
        REGISTRY_CREDENTIALS = 'docker-registry-creds'
        
        // Image configuration
        IMAGE_NAME = "${REGISTRY}/${APP_NAME}"
        IMAGE_TAG = "${BUILD_NUMBER}-${GIT_COMMIT.take(7)}"
        
        // VM/SSH Configuration
        STAGING_VM_HOST = 'deploy@18.190.253.152'
        PROD_VM_HOST = 'deploy@3.133.157.227'
        SSH_CREDENTIALS_ID = 'vm-ssh-key'
        CONTAINER_NAME = 'gateway'
        CONTAINER_PORT = '3000'
        
        // Security
        TRIVY_SEVERITY = 'CRITICAL,HIGH'
        NPM_AUDIT_LEVEL = 'moderate'
        
        // Node environment
        NODE_ENV = 'production'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    stages {
        stage('Checkout') {
            steps {
                script {
                    echo "Checking out source code..."
                    checkout scm
                    
                    // Display build info
                    sh '''
                        echo "Build: ${BUILD_NUMBER}"
                        echo "Commit: ${GIT_COMMIT}"
                        echo "Branch: ${GIT_BRANCH}"
                        echo "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
                    '''
                }
            }
        }

        stage('Security: Dependency Audit') {
            steps {
                script {
                    echo "Running npm audit..."
                    sh """
                        npm audit --audit-level=${NPM_AUDIT_LEVEL} || true
                    """
                }
            }
        }

        stage('Lint & Test') {
            steps {
                script {
                    echo "Running linting and tests..."
                    sh '''
                        npm ci
                        npm run lint || true
                        npm run test || true
                    '''
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    echo "Building Docker image..."
                    sh """
                        docker build \
                            --tag ${IMAGE_NAME}:${IMAGE_TAG} \
                            --tag ${IMAGE_NAME}:latest \
                            --build-arg BUILD_DATE=\$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
                            --build-arg VCS_REF=${GIT_COMMIT} \
                            --build-arg VERSION=${IMAGE_TAG} \
                            .
                    """
                }
            }
        }

        stage('Security: Trivy Image Scan') {
            steps {
                script {
                    echo "Scanning Docker image with Trivy..."
                    sh """
                        trivy image \
                            --severity ${TRIVY_SEVERITY} \
                            --exit-code 0 \
                            --no-progress \
                            --format table \
                            ${IMAGE_NAME}:${IMAGE_TAG}
                        
                        # Generate JSON report
                        trivy image \
                            --severity ${TRIVY_SEVERITY} \
                            --format json \
                            --output trivy-report.json \
                            ${IMAGE_NAME}:${IMAGE_TAG}
                    """
                    
                    // Archive the report
                    archiveArtifacts artifacts: 'trivy-report.json', allowEmptyArchive: true
                }
            }
        }

        stage('Push to Registry') {
            steps {
                script {
                    echo "Pushing image to registry..."
                    withCredentials([usernamePassword(
                        credentialsId: REGISTRY_CREDENTIALS,
                        usernameVariable: 'REGISTRY_USER',
                        passwordVariable: 'REGISTRY_PASS'
                    )]) {
                        sh """
                            echo \$REGISTRY_PASS | docker login ${REGISTRY} -u \$REGISTRY_USER --password-stdin
                            docker push ${IMAGE_NAME}:${IMAGE_TAG}
                            docker push ${IMAGE_NAME}:latest
                            docker logout ${REGISTRY}
                        """
                    }
                }
            }
        }

        stage('Deploy to Staging') {
            steps {
                script {
                    echo "Deploying to Staging VM via SSH..."
                    withCredentials([usernamePassword(
                        credentialsId: REGISTRY_CREDENTIALS,
                        usernameVariable: 'REGISTRY_USER',
                        passwordVariable: 'REGISTRY_PASS'
                    )]) {
                        sshagent(credentials: [SSH_CREDENTIALS_ID]) {
                            sh """
                                # Deploy to staging VM
                                ssh -o StrictHostKeyChecking=no ${STAGING_VM_HOST} '
                                    # Stop and remove old container
                                    docker stop ${CONTAINER_NAME} || true
                                    docker rm ${CONTAINER_NAME} || true
                                    
                                    # Pull new image
                                    echo "${REGISTRY_PASS}" | docker login ${REGISTRY} -u ${REGISTRY_USER} --password-stdin
                                    docker pull ${IMAGE_NAME}:${IMAGE_TAG}
                                    docker logout ${REGISTRY}
                                    
                                    # Run new container
                                    docker run -d \
                                        --name ${CONTAINER_NAME} \
                                        --restart unless-stopped \
                                        -p ${CONTAINER_PORT}:${CONTAINER_PORT} \
                                        -e NODE_ENV=production \
                                        -e JWT_SECRET=\$(cat /etc/gateway/jwt-secret) \
                                        -e PORT=${CONTAINER_PORT} \
                                        -e LOG_LEVEL=info \
                                        ${IMAGE_NAME}:${IMAGE_TAG}
                                    
                                    # Verify container is running
                                    docker ps | grep ${CONTAINER_NAME}
                                    
                                    # Wait for health check
                                    sleep 10
                                    curl -f http://localhost:${CONTAINER_PORT}/health || exit 1
                                '
                            """
                        }
                    }
                }
            }
        }

        stage('Staging Tests') {
            steps {
                script {
                    echo "Smoke tests on Staging VM..."
                    sshagent(credentials: [SSH_CREDENTIALS_ID]) {
                        sh """
                            ssh -o StrictHostKeyChecking=no ${STAGING_VM_HOST} '
                                # Health check
                                curl -f http://localhost:${CONTAINER_PORT}/health
                                
                                # Test public endpoint
                                curl -f http://localhost:${CONTAINER_PORT}/api/public
                            '
                        """
                    }
                    echo " Smoke tests passed"
                }
            }
        }

        stage('Approve Production Deployment') {
            steps {
                script {
                    echo " Waiting for manual approval..."
                    timeout(time: 24, unit: 'HOURS') {
                        input message: 'Deploy to Production?',
                              ok: 'Deploy',
                              submitter: 'admin,release-manager'
                    }
                }
            }
        }

        stage('Deploy to Production') {
            steps {
                script {
                    echo "Deploying to Production VM via SSH..."
                    withCredentials([usernamePassword(
                        credentialsId: REGISTRY_CREDENTIALS,
                        usernameVariable: 'REGISTRY_USER',
                        passwordVariable: 'REGISTRY_PASS'
                    )]) {
                        sshagent(credentials: [SSH_CREDENTIALS_ID]) {
                            sh """
                                ssh -o StrictHostKeyChecking=no ${PROD_VM_HOST} '
                                    docker stop ${CONTAINER_NAME} || true
                                    docker rm ${CONTAINER_NAME} || true
                                    
                                    # Pull new image
                                    echo "${REGISTRY_PASS}" | docker login ${REGISTRY} -u ${REGISTRY_USER} --password-stdin
                                    docker pull ${IMAGE_NAME}:${IMAGE_TAG}
                                    docker logout ${REGISTRY}
                                    
                                    # Run new container
                                    docker run -d \
                                        --name ${CONTAINER_NAME} \
                                        --restart unless-stopped \
                                        -p ${CONTAINER_PORT}:${CONTAINER_PORT} \
                                        -e NODE_ENV=production \
                                        -e JWT_SECRET=\$(cat /etc/gateway/jwt-secret) \
                                        -e PORT=${CONTAINER_PORT} \
                                        -e LOG_LEVEL=warn \
                                        ${IMAGE_NAME}:${IMAGE_TAG}
                                    
                                    # Verify container is running
                                    docker ps | grep ${CONTAINER_NAME}
                                    
                                    # Wait for health check
                                    sleep 10
                                    curl -f http://localhost:${CONTAINER_PORT}/health || exit 1
                                '
                            """
                        }
                    }
                }
            }
        }

        stage('Production Verification') {
            steps {
                script {
                    echo "Verifying Production deployment..."
                    sshagent(credentials: [SSH_CREDENTIALS_ID]) {
                        sh """
                            ssh -o StrictHostKeyChecking=no ${PROD_VM_HOST} '
                                docker ps | grep ${CONTAINER_NAME}
                                curl -f http://localhost:${CONTAINER_PORT}/health
                                
                                # Check container logs
                                docker logs --tail=50 ${CONTAINER_NAME}
                            '
                        """
                    }
                    echo "Production deployment verified"
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline completed successfully!"
        }
        failure {
            echo "Pipeline failed!"
        }
        always {
            echo "Cleaning up..."
        }
    }
}
