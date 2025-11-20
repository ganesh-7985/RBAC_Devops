#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Server IPs
STAGING_IP="18.119.167.57"
PROD_IP="18.191.192.108"
AWS_KEY="~/Downloads/my-ec2-key.pem"
SSH_USER="ubuntu"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setting up Staging and Production Servers${NC}"
echo -e "${GREEN}========================================${NC}\n"

# Step 1: Copy setup script to both servers
echo -e "${YELLOW}Step 1: Copying setup script to servers...${NC}"

echo "Copying to staging server (${STAGING_IP})..."
scp -i ${AWS_KEY} deploy/scripts/setup-vm.sh ${SSH_USER}@${STAGING_IP}:~
echo -e "${GREEN}✓ Copied to staging${NC}"

echo "Copying to production server (${PROD_IP})..."
scp -i ${AWS_KEY} deploy/scripts/setup-vm.sh ${SSH_USER}@${PROD_IP}:~
echo -e "${GREEN}✓ Copied to production${NC}\n"

# Step 2: Run setup on staging
echo -e "${YELLOW}Step 2: Running setup on STAGING server...${NC}"
ssh -i ${AWS_KEY} ${SSH_USER}@${STAGING_IP} << 'ENDSSH'
chmod +x setup-vm.sh
./setup-vm.sh
ENDSSH
echo -e "${GREEN}✓ Staging setup complete${NC}\n"

# Step 3: Run setup on production
echo -e "${YELLOW}Step 3: Running setup on PRODUCTION server...${NC}"
ssh -i ${AWS_KEY} ${SSH_USER}@${PROD_IP} << 'ENDSSH'
chmod +x setup-vm.sh
./setup-vm.sh
ENDSSH
echo -e "${GREEN}✓ Production setup complete${NC}\n"

# Step 4: Retrieve JWT secrets
echo -e "${YELLOW}Step 4: Retrieving JWT secrets...${NC}"
echo "Getting staging JWT secret..."
STAGING_JWT=$(ssh -i ${AWS_KEY} ${SSH_USER}@${STAGING_IP} 'sudo cat /etc/gateway/jwt-secret')
echo -e "${GREEN}Staging JWT Secret:${NC} ${STAGING_JWT}"

echo "Getting production JWT secret..."
PROD_JWT=$(ssh -i ${AWS_KEY} ${SSH_USER}@${PROD_IP} 'sudo cat /etc/gateway/jwt-secret')
echo -e "${GREEN}Production JWT Secret:${NC} ${PROD_JWT}"

# Save to file
cat > jwt-secrets.txt << EOF
STAGING JWT SECRET
==================
${STAGING_JWT}

PRODUCTION JWT SECRET
=====================
${PROD_JWT}

IMPORTANT: Store these secrets securely and delete this file after saving them elsewhere!
Generated on: $(date)
EOF
echo -e "${GREEN}✓ JWT secrets saved to jwt-secrets.txt${NC}\n"

# Step 5: Copy SSH keys to deploy user
echo -e "${YELLOW}Step 5: Configuring SSH access for deploy user...${NC}"

echo "Configuring staging server..."
ssh -i ${AWS_KEY} ${SSH_USER}@${STAGING_IP} << ENDSSH
# Add Jenkins public key to deploy user
sudo mkdir -p /home/deploy/.ssh
sudo chmod 700 /home/deploy/.ssh
echo "$(cat ~/.ssh/jenkins_deploy.pub)" | sudo tee /home/deploy/.ssh/authorized_keys
sudo chmod 600 /home/deploy/.ssh/authorized_keys
sudo chown -R deploy:deploy /home/deploy/.ssh
ENDSSH
echo -e "${GREEN}✓ Staging SSH configured${NC}"

echo "Configuring production server..."
ssh -i ${AWS_KEY} ${SSH_USER}@${PROD_IP} << ENDSSH
# Add Jenkins public key to deploy user
sudo mkdir -p /home/deploy/.ssh
sudo chmod 700 /home/deploy/.ssh
echo "$(cat ~/.ssh/jenkins_deploy.pub)" | sudo tee /home/deploy/.ssh/authorized_keys
sudo chmod 600 /home/deploy/.ssh/authorized_keys
sudo chown -R deploy:deploy /home/deploy/.ssh
ENDSSH
echo -e "${GREEN}✓ Production SSH configured${NC}\n"

# Step 6: Test SSH access
echo -e "${YELLOW}Step 6: Testing SSH access as deploy user...${NC}"

echo "Testing staging..."
if ssh -i ~/.ssh/jenkins_deploy deploy@${STAGING_IP} 'docker ps' &>/dev/null; then
    echo -e "${GREEN}✓ Staging SSH access works!${NC}"
else
    echo -e "${RED}✗ Staging SSH access failed${NC}"
fi

echo "Testing production..."
if ssh -i ~/.ssh/jenkins_deploy deploy@${PROD_IP} 'docker ps' &>/dev/null; then
    echo -e "${GREEN}✓ Production SSH access works!${NC}"
else
    echo -e "${RED}✗ Production SSH access failed${NC}"
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo "Next steps:"
echo "1. Check jwt-secrets.txt for your JWT secrets"
echo "2. Run: ./update-jenkinsfile.sh to update Jenkinsfile with server IPs"
echo "3. Test deployment with Jenkins"
echo ""
echo "Server Information:"
echo "  Staging:    deploy@${STAGING_IP}"
echo "  Production: deploy@${PROD_IP}"
