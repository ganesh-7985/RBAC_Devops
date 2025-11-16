#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🔧 Setting up VM for Secure API Gateway${NC}"
echo "=================================================="

echo -e "\n${YELLOW}1. Updating system packages...${NC}"
sudo apt-get update
sudo apt-get upgrade -y
echo -e "\n${YELLOW}2. Installing Docker...${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    echo -e "${GREEN} Docker installed${NC}"
else
    echo -e "${GREEN} Docker already installed${NC}"
fi

echo -e "\n${YELLOW}3. Creating deploy user...${NC}"
if ! id -u deploy &>/dev/null; then
    sudo useradd -m -s /bin/bash deploy
    sudo usermod -aG docker deploy
    echo -e "${GREEN} User 'deploy' created${NC}"
else
    echo -e "${GREEN} User 'deploy' already exists${NC}"
fi
echo -e "\n${YELLOW}4. Creating configuration directory...${NC}"
sudo mkdir -p /etc/gateway
sudo chown deploy:deploy /etc/gateway
sudo chmod 700 /etc/gateway

echo -e "\n${YELLOW}5. Generating JWT secret...${NC}"
if [ ! -f /etc/gateway/jwt-secret ]; then
    openssl rand -base64 32 | sudo tee /etc/gateway/jwt-secret > /dev/null
    sudo chown deploy:deploy /etc/gateway/jwt-secret
    sudo chmod 600 /etc/gateway/jwt-secret
    echo -e "${GREEN} JWT secret generated${NC}"
    echo -e "${YELLOW} IMPORTANT: Save this secret securely!${NC}"
    echo -e "JWT Secret: $(sudo cat /etc/gateway/jwt-secret)"
else
    echo -e "${GREEN} JWT secret already exists${NC}"
fi

# Configure firewall
echo -e "\n${YELLOW}6. Configuring firewall...${NC}"
if command -v ufw &> /dev/null; then
    sudo ufw allow 22/tcp
    sudo ufw allow 3000/tcp
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw --force enable
    echo -e "${GREEN} Firewall configured${NC}"
else
    echo -e "${YELLOW}  UFW not installed, skipping firewall configuration${NC}"
fi

# Install useful tools
echo -e "\n${YELLOW}7. Installing additional tools...${NC}"
sudo apt-get install -y curl wget git jq

# Setup log rotation
echo -e "\n${YELLOW}8. Setting up log rotation...${NC}"
sudo tee /etc/logrotate.d/docker-gateway > /dev/null << 'EOF'
/var/lib/docker/containers/*/*.log {
    rotate 7
    daily
    compress
    missingok
    delaycompress
    copytruncate
}
EOF

echo -e "\n${GREEN} VM setup completed!${NC}"
echo -e "\nNext steps:"
echo -e "1. Copy your SSH public key to /home/deploy/.ssh/authorized_keys"
echo -e "2. Test SSH access: ssh deploy@<vm-ip>"
echo -e "3. Deploy the application using Jenkins or manual deployment script"
