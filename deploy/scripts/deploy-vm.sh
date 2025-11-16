#!/bin/bash
# ==============================================================================
# Deploy Secure API Gateway to VM via SSH
# ==============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
ENVIRONMENT="${1:-staging}"
VM_HOST="${2}"
IMAGE_TAG="${3:-latest}"
REGISTRY="${REGISTRY:-ghcr.io/your-org}"
IMAGE_NAME="${REGISTRY}/secure-api-gateway"
CONTAINER_NAME="gateway"
CONTAINER_PORT="3000"

if [ -z "$VM_HOST" ]; then
    echo -e "${RED}❌ Usage: $0 <environment> <vm-host> [image-tag]${NC}"
    echo -e "   Example: $0 staging deploy@staging.example.com v1.0.0"
    exit 1
fi

echo -e "${GREEN}🚀 Deploying Secure API Gateway${NC}"
echo "=================================================="
echo "Environment: $ENVIRONMENT"
echo "VM Host: $VM_HOST"
echo "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
echo "=================================================="

# Deploy via SSH
echo -e "\n${YELLOW}Connecting to VM...${NC}"
ssh -o StrictHostKeyChecking=no "$VM_HOST" << EOF
    set -e
    
    echo "${YELLOW}Stopping old container...${NC}"
    docker stop ${CONTAINER_NAME} 2>/dev/null || true
    docker rm ${CONTAINER_NAME} 2>/dev/null || true
    
    echo "${YELLOW}Pulling new image...${NC}"
    docker pull ${IMAGE_NAME}:${IMAGE_TAG}
    
    echo "${YELLOW}Starting new container...${NC}"
    docker run -d \
        --name ${CONTAINER_NAME} \
        --restart unless-stopped \
        -p ${CONTAINER_PORT}:${CONTAINER_PORT} \
        -e NODE_ENV=production \
        -e JWT_SECRET=\$(cat /etc/gateway/jwt-secret) \
        -e PORT=${CONTAINER_PORT} \
        -e LOG_LEVEL=info \
        ${IMAGE_NAME}:${IMAGE_TAG}
    
    echo "${YELLOW}Waiting for container to be ready...${NC}"
    sleep 10
    
    echo "${YELLOW}Verifying deployment...${NC}"
    docker ps | grep ${CONTAINER_NAME}
    curl -f http://localhost:${CONTAINER_PORT}/health
    
    echo "${GREEN}✅ Deployment completed successfully!${NC}"
EOF

echo -e "\n${GREEN}✅ Deployment to ${ENVIRONMENT} completed!${NC}"
