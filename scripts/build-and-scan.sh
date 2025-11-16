#!/bin/bash
# ==============================================================================
# Build and Security Scan Script for Secure API Gateway
# ==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Secure API Gateway - Build and Security Scan${NC}"
echo "=================================================="

# Configuration
IMAGE_NAME="${IMAGE_NAME:-secure-api-gateway}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
TRIVY_SEVERITY="${TRIVY_SEVERITY:-CRITICAL,HIGH}"

echo -e "\n${YELLOW}📦 Building Docker image...${NC}"
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .

echo -e "\n${YELLOW}🔍 Running security scans...${NC}"

# 1. NPM Audit
echo -e "\n${YELLOW}1. NPM Audit${NC}"
npm audit --audit-level=moderate || echo -e "${RED}⚠️  NPM audit found vulnerabilities${NC}"

# 2. Trivy - Filesystem scan
echo -e "\n${YELLOW}2. Trivy Filesystem Scan${NC}"
if command -v trivy &> /dev/null; then
    trivy fs --severity ${TRIVY_SEVERITY} .
else
    echo -e "${RED}Trivy not installed. Install from: https://github.com/aquasecurity/trivy${NC}"
fi

# 3. Trivy - Image scan
echo -e "\n${YELLOW}3. Trivy Image Scan${NC}"
if command -v trivy &> /dev/null; then
    trivy image --severity ${TRIVY_SEVERITY} ${IMAGE_NAME}:${IMAGE_TAG}
    
    # Generate JSON report
    trivy image --format json --output trivy-report.json ${IMAGE_NAME}:${IMAGE_TAG}
    echo -e "${GREEN}✅ Trivy report saved to trivy-report.json${NC}"
else
    echo -e "${RED}Trivy not installed. Skipping image scan.${NC}"
fi

# 4. Docker Scout (if available)
echo -e "\n${YELLOW}4. Docker Scout Scan${NC}"
if docker scout --version &> /dev/null; then
    docker scout cves ${IMAGE_NAME}:${IMAGE_TAG}
else
    echo -e "${YELLOW}Docker Scout not available. Skipping.${NC}"
fi

echo -e "\n${GREEN}✅ Build and scan completed!${NC}"
echo -e "\nImage: ${IMAGE_NAME}:${IMAGE_TAG}"
echo -e "To run the container:"
echo -e "  docker run -p 3000:3000 -e JWT_SECRET=your-secret ${IMAGE_NAME}:${IMAGE_TAG}"
