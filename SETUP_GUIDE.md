# 🚀 Complete Setup Guide - RBAC Secure API Gateway

This guide will walk you through **everything** needed to run and deploy this project, from local development to production deployment with Jenkins CI/CD.

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Local Development Setup](#local-development-setup)
3. [Understanding Required Keys & Secrets](#understanding-required-keys--secrets)
4. [Docker Setup](#docker-setup)
5. [VM/Server Setup](#vmserver-setup)
6. [Jenkins CI/CD Setup](#jenkins-cicd-setup)
7. [Deployment Process](#deployment-process)
8. [Testing & Verification](#testing--verification)
9. [Troubleshooting](#troubleshooting)

---

## 1️⃣ Prerequisites

### What You Need

#### For Local Development:
- **Node.js** (v20 or higher) - [Download](https://nodejs.org/)
- **npm** (v10 or higher) - Comes with Node.js
- **Git** - [Download](https://git-scm.com/)
- **Code Editor** - VS Code, Sublime, etc.

#### For Docker:
- **Docker Desktop** - [Download](https://www.docker.com/products/docker-desktop/)
- **Trivy** (for security scanning) - [Install Guide](https://aquasecurity.github.io/trivy/)

#### For VM Deployment:
- **Linux VM/Server** (Ubuntu 20.04+ recommended)
- **SSH Access** to your servers
- **Domain Names** (optional but recommended)

#### For Jenkins CI/CD:
- **Jenkins Server** (v2.400+)
- **Docker** installed on Jenkins agent
- **Trivy** installed on Jenkins agent

### Check Your System

```bash
# Check Node.js version
node --version  # Should be v20.0.0 or higher

# Check npm version
npm --version   # Should be v10.0.0 or higher

# Check Docker
docker --version

# Check Git
git --version
```

---

## 2️⃣ Local Development Setup

### Step 1: Clone the Repository

```bash
# Clone the project
git clone <your-repository-url>
cd rbac-ssd

# Verify you're in the right directory
ls -la
# You should see: package.json, Dockerfile, Jenkinsfile, src/, etc.
```

### Step 2: Install Dependencies

```bash
# Install all Node.js dependencies
npm install

# This will install:
# - express (web framework)
# - jsonwebtoken (JWT authentication)
# - helmet (security headers)
# - cors (cross-origin requests)
# - winston (logging)
# - and more...
```

### Step 3: Configure Environment Variables

```bash
# Copy the example environment file
cp .env.example .env

# Open .env in your editor
nano .env  # or use your preferred editor
```

**Edit `.env` file:**

```bash
NODE_ENV=development
PORT=3000
JWT_SECRET=your-super-secret-jwt-key-change-this-in-production
JWT_EXPIRY=1h
CORS_ORIGIN=http://localhost:3000
LOG_LEVEL=info
```

### Step 4: Generate a Strong JWT Secret

**Option A: Using OpenSSL (Recommended)**
```bash
# Generate a secure random secret
openssl rand -base64 32

# Example output: 8xK9mP2nQ4vR7sT1uW3yZ5aB6cD8eF0g
```

**Option B: Using Node.js**
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"
```

**Option C: Online Generator**
- Visit: https://generate-secret.vercel.app/32

**Update your `.env` file:**
```bash
JWT_SECRET=8xK9mP2nQ4vR7sT1uW3yZ5aB6cD8eF0g  # Use your generated secret
```

### Step 5: Start the Development Server

```bash
# Start with auto-reload (recommended for development)
npm run dev

# OR start normally
npm start
```

You should see:
```
🚀 Server running on port 3000
📝 Environment: development
🔒 JWT authentication enabled
```

### Step 6: Test Your Local Setup

**Open a new terminal and test:**

```bash
# Test health endpoint
curl http://localhost:3000/health

# Expected response:
# {"status":"ok","timestamp":"2024-11-16T..."}

# Test login
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Admin@123"}'

# Expected response:
# {"token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...","user":{...}}
```

**Test with a browser:**
- Open: http://localhost:3000
- You should see the API welcome page

✅ **Local development is now working!**

---

## 3️⃣ Understanding Required Keys & Secrets

### JWT Secret (JWT_SECRET)

**What is it?**
- A secret key used to sign and verify JWT tokens
- Like a password that proves tokens are authentic

**How to create it:**
```bash
# Method 1: OpenSSL (most secure)
openssl rand -base64 32

# Method 2: Node.js crypto
node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"

# Method 3: Manual (less secure)
# Use a password generator to create a 32+ character random string
```

**Security Rules:**
- ✅ Must be at least 32 characters
- ✅ Use different secrets for staging and production
- ✅ Never commit to Git
- ✅ Store securely (environment variables, secret managers)
- ❌ Never share or expose publicly

**Where to use it:**
- Local: `.env` file
- Docker: `-e JWT_SECRET=...` when running container
- VM: `/etc/gateway/jwt-secret` file
- Jenkins: Environment variable or secret

---

### SSH Keys (for VM Deployment)

**What are they?**
- Public/Private key pairs for secure server access
- Used by Jenkins to deploy to your VMs

**How to create them:**

```bash
# Generate a new SSH key pair
ssh-keygen -t ed25519 -C "jenkins-deploy-key" -f ~/.ssh/jenkins_deploy

# This creates two files:
# - jenkins_deploy (private key - keep secret!)
# - jenkins_deploy.pub (public key - share with servers)

# Set correct permissions
chmod 600 ~/.ssh/jenkins_deploy
chmod 644 ~/.ssh/jenkins_deploy.pub
```

**How to use them:**

1. **Copy public key to your VMs:**
```bash
# For staging server
ssh-copy-id -i ~/.ssh/jenkins_deploy.pub deploy@staging.example.com

# For production server
ssh-copy-id -i ~/.ssh/jenkins_deploy.pub deploy@production.example.com
```

2. **Test SSH access:**
```bash
ssh -i ~/.ssh/jenkins_deploy deploy@staging.example.com
```

3. **Add private key to Jenkins:**
- Go to Jenkins → Manage Jenkins → Credentials
- Add new SSH credential with private key content

---

### Docker Registry Credentials

**What are they?**
- Username and password/token to push Docker images
- Needed to store your built images

**Popular Registry Options:**

#### Option 1: GitHub Container Registry (GHCR) - FREE

**Create a Personal Access Token:**
1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Give it a name: "Docker Registry Access"
4. Select scopes:
   - ✅ `write:packages`
   - ✅ `read:packages`
   - ✅ `delete:packages`
5. Click "Generate token"
6. **COPY THE TOKEN** (you won't see it again!)

**Your credentials:**
- Registry URL: `ghcr.io/your-github-username`
- Username: Your GitHub username
- Password: The token you just created

**Test it:**
```bash
# Login
echo "YOUR_TOKEN" | docker login ghcr.io -u YOUR_USERNAME --password-stdin

# Tag an image
docker tag secure-api-gateway:latest ghcr.io/YOUR_USERNAME/secure-api-gateway:latest

# Push
docker push ghcr.io/YOUR_USERNAME/secure-api-gateway:latest
```

#### Option 2: Docker Hub - FREE (with limits)

**Create an Access Token:**
1. Go to https://hub.docker.com/settings/security
2. Click "New Access Token"
3. Name: "Jenkins Deploy"
4. Permissions: Read, Write, Delete
5. Generate and copy the token

**Your credentials:**
- Registry URL: `docker.io/your-username` (or just `your-username`)
- Username: Your Docker Hub username
- Password: The access token

#### Option 3: AWS ECR, Azure ACR, Google GCR
- Follow their respective documentation for creating credentials

---

## 4️⃣ Docker Setup

### Step 1: Install Docker

**macOS:**
```bash
# Download Docker Desktop from:
# https://www.docker.com/products/docker-desktop/

# Or use Homebrew:
brew install --cask docker
```

**Linux (Ubuntu/Debian):**
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add your user to docker group
sudo usermod -aG docker $USER

# Logout and login again for changes to take effect
```

**Verify installation:**
```bash
docker --version
docker ps
```

### Step 2: Build Your Docker Image

```bash
# Build the image
docker build -t secure-api-gateway:latest .

# This will:
# 1. Use Node.js 20 Alpine (lightweight)
# 2. Install dependencies
# 3. Copy application code
# 4. Create non-root user
# 5. Set up health checks
```

### Step 3: Run Container Locally

```bash
# Run the container
docker run -d \
  --name api-gateway \
  -p 3000:3000 \
  -e JWT_SECRET="$(openssl rand -base64 32)" \
  -e NODE_ENV="production" \
  secure-api-gateway:latest

# Check if it's running
docker ps

# View logs
docker logs api-gateway

# Test it
curl http://localhost:3000/health
```

### Step 4: Install Trivy (Security Scanner)

**macOS:**
```bash
brew install trivy
```

**Linux:**
```bash
# Ubuntu/Debian
sudo apt-get install wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install trivy
```

**Scan your image:**
```bash
# Scan for vulnerabilities
trivy image secure-api-gateway:latest

# Scan only HIGH and CRITICAL
trivy image --severity HIGH,CRITICAL secure-api-gateway:latest
```

---

## 5️⃣ VM/Server Setup

### Step 1: Prepare Your VMs

You need at least **2 VMs**:
- **Staging VM**: For testing deployments
- **Production VM**: For live application

**Recommended Specs:**
- OS: Ubuntu 20.04 LTS or newer
- CPU: 2 cores minimum
- RAM: 2GB minimum
- Disk: 20GB minimum
- Network: Public IP or domain name

### Step 2: Initial VM Configuration

**For EACH VM (staging and production), do the following:**

```bash
# SSH into your VM
ssh root@your-vm-ip

# Update system
apt-get update && apt-get upgrade -y

# Create a non-root user (if not exists)
adduser yourusername
usermod -aG sudo yourusername

# Switch to your user
su - yourusername
```

### Step 3: Run the Setup Script

**Copy the setup script to your VM:**

```bash
# From your local machine
scp deploy/scripts/setup-vm.sh yourusername@your-vm-ip:~

# SSH to the VM
ssh yourusername@your-vm-ip

# Make it executable
chmod +x setup-vm.sh

# Run the setup script
./setup-vm.sh
```

**The script will:**
1. ✅ Update system packages
2. ✅ Install Docker
3. ✅ Create `deploy` user
4. ✅ Generate JWT secret
5. ✅ Configure firewall
6. ✅ Install useful tools
7. ✅ Setup log rotation

**IMPORTANT: Save the JWT Secret!**
The script will display the generated JWT secret. Save it securely:
```bash
# View the secret
sudo cat /etc/gateway/jwt-secret

# Copy it to your password manager or secure notes
```

### Step 4: Configure SSH Access for Jenkins

**On your local machine or Jenkins server:**

```bash
# Copy your SSH public key to the VM
ssh-copy-id -i ~/.ssh/jenkins_deploy.pub deploy@your-vm-ip

# Test SSH access
ssh -i ~/.ssh/jenkins_deploy deploy@your-vm-ip

# Test Docker access
ssh -i ~/.ssh/jenkins_deploy deploy@your-vm-ip 'docker ps'
```

**Repeat for both staging and production VMs!**

### Step 5: Configure Firewall (if needed)

```bash
# SSH to your VM
ssh deploy@your-vm-ip

# Check firewall status
sudo ufw status

# Ensure these ports are open:
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 3000/tcp  # Application
sudo ufw allow 80/tcp    # HTTP (if using reverse proxy)
sudo ufw allow 443/tcp   # HTTPS (if using reverse proxy)

# Enable firewall
sudo ufw enable
```

---

## 6️⃣ Jenkins CI/CD Setup

### Step 1: Install Jenkins

**Option A: Docker (Easiest for testing)**
```bash
docker run -d \
  --name jenkins \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts
```

**Option B: Linux Installation**
```bash
# Add Jenkins repository
wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'

# Install Jenkins
sudo apt-get update
sudo apt-get install jenkins

# Start Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins
```

**Access Jenkins:**
- Open: http://your-jenkins-server:8080
- Get initial password: `sudo cat /var/jenkins_home/secrets/initialAdminPassword`
- Complete setup wizard

### Step 2: Install Required Jenkins Plugins

Go to: **Manage Jenkins → Plugins → Available**

Install these plugins:
- ✅ **Docker Pipeline**
- ✅ **SSH Agent**
- ✅ **Credentials Binding**
- ✅ **Git**
- ✅ **Pipeline**

### Step 3: Configure Jenkins Agent with Docker

**On your Jenkins agent machine:**

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add jenkins user to docker group
sudo usermod -aG docker jenkins

# Install Trivy
# (See Trivy installation steps from Docker Setup section)

# Restart Jenkins
sudo systemctl restart jenkins
```

### Step 4: Add Credentials to Jenkins

Go to: **Manage Jenkins → Credentials → System → Global credentials**

#### Credential 1: Docker Registry URL

- **Kind**: Secret text
- **Scope**: Global
- **Secret**: `ghcr.io/your-username` (or your registry URL)
- **ID**: `docker-registry-url`
- **Description**: Docker Registry URL

#### Credential 2: Docker Registry Credentials

- **Kind**: Username with password
- **Scope**: Global
- **Username**: Your registry username
- **Password**: Your registry token/password
- **ID**: `docker-registry-creds`
- **Description**: Docker Registry Credentials

#### Credential 3: SSH Private Key for VMs

- **Kind**: SSH Username with private key
- **Scope**: Global
- **ID**: `vm-ssh-key`
- **Username**: `deploy`
- **Private Key**: Click "Enter directly" and paste your private key content
- **Description**: VM SSH Deploy Key

**How to get your private key content:**
```bash
# Display your private key
cat ~/.ssh/jenkins_deploy

# Copy the entire output including:
# -----BEGIN OPENSSH PRIVATE KEY-----
# ... key content ...
# -----END OPENSSH PRIVATE KEY-----
```

### Step 5: Update Jenkinsfile with Your Details

Edit the `Jenkinsfile` in your repository:

```groovy
environment {
    // Update these lines:
    REGISTRY = credentials('docker-registry-url')  // Should match your credential ID
    
    // Update with your actual VM hostnames or IPs
    STAGING_VM_HOST = 'deploy@staging.example.com'  // Change to your staging VM
    PROD_VM_HOST = 'deploy@production.example.com'  // Change to your production VM
    
    SSH_CREDENTIALS_ID = 'vm-ssh-key'  // Should match your credential ID
}
```

**Example:**
```groovy
STAGING_VM_HOST = 'deploy@192.168.1.100'  // If using IP
PROD_VM_HOST = 'deploy@api.mycompany.com'  // If using domain
```

### Step 6: Create Jenkins Pipeline Job

1. **New Item** → Enter name: `secure-api-gateway-deploy`
2. **Type**: Pipeline
3. **Pipeline section**:
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: Your Git repository URL
   - Credentials: Add if private repo
   - Branch: `*/main` (or your branch)
   - Script Path: `Jenkinsfile`
4. **Save**

### Step 7: Configure Build Triggers (Optional)

**Option A: Poll SCM**
- Build Triggers → Poll SCM
- Schedule: `H/5 * * * *` (check every 5 minutes)

**Option B: GitHub Webhook**
- In GitHub: Settings → Webhooks → Add webhook
- Payload URL: `http://your-jenkins:8080/github-webhook/`
- Content type: `application/json`
- Events: Just the push event

---

## 7️⃣ Deployment Process

### Understanding the Pipeline Flow

```
1. Checkout Code
   ↓
2. Security: Dependency Audit (npm audit)
   ↓
3. Lint & Test
   ↓
4. Build Docker Image
   ↓
5. Security: Trivy Scan
   ↓
6. Push to Registry
   ↓
7. Deploy to Staging VM
   ↓
8. Staging Tests
   ↓
9. ⏸️  MANUAL APPROVAL (You must approve!)
   ↓
10. Deploy to Production VM
    ↓
11. Production Verification
    ↓
12. ✅ Success!
```

### First Deployment

1. **Commit and push your code:**
```bash
git add .
git commit -m "Initial setup"
git push origin main
```

2. **Trigger Jenkins build:**
   - Go to Jenkins dashboard
   - Click on your pipeline job
   - Click "Build Now"

3. **Monitor the build:**
   - Click on the build number (e.g., #1)
   - Click "Console Output" to see logs

4. **Approve production deployment:**
   - When pipeline reaches "Approve Production Deployment"
   - Click "Approve" (only if staging tests passed!)

### Manual Deployment (Without Jenkins)

If you want to deploy manually:

```bash
# Build image locally
docker build -t secure-api-gateway:latest .

# Tag for your registry
docker tag secure-api-gateway:latest ghcr.io/YOUR_USERNAME/secure-api-gateway:v1.0.0

# Push to registry
docker push ghcr.io/YOUR_USERNAME/secure-api-gateway:v1.0.0

# Deploy to VM
ssh deploy@your-vm-ip << 'EOF'
  # Stop old container
  docker stop gateway || true
  docker rm gateway || true
  
  # Pull new image
  docker pull ghcr.io/YOUR_USERNAME/secure-api-gateway:v1.0.0
  
  # Run new container
  docker run -d \
    --name gateway \
    --restart unless-stopped \
    -p 3000:3000 \
    -e NODE_ENV=production \
    -e JWT_SECRET=$(cat /etc/gateway/jwt-secret) \
    -e PORT=3000 \
    ghcr.io/YOUR_USERNAME/secure-api-gateway:v1.0.0
  
  # Verify
  docker ps | grep gateway
  sleep 5
  curl http://localhost:3000/health
EOF
```

---

## 8️⃣ Testing & Verification

### Test Local Development

```bash
# Health check
curl http://localhost:3000/health

# Login as admin
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Admin@123"}'

# Save the token from response
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

# Test protected endpoint
curl http://localhost:3000/api/protected \
  -H "Authorization: Bearer $TOKEN"

# Test admin endpoint
curl http://localhost:3000/api/admin \
  -H "Authorization: Bearer $TOKEN"

# Test RBAC - user should NOT access admin endpoint
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"user","password":"User@123"}'

USER_TOKEN="..."  # Token from response

curl http://localhost:3000/api/admin \
  -H "Authorization: Bearer $USER_TOKEN"
# Should return 403 Forbidden
```

### Test Docker Container

```bash
# Run container
docker run -d --name test-gateway -p 3000:3000 \
  -e JWT_SECRET="test-secret-key-32-chars-min" \
  -e NODE_ENV=production \
  secure-api-gateway:latest

# Wait for startup
sleep 5

# Test health
curl http://localhost:3000/health

# Check logs
docker logs test-gateway

# Cleanup
docker stop test-gateway
docker rm test-gateway
```

### Test VM Deployment

```bash
# SSH to your VM
ssh deploy@your-vm-ip

# Check container is running
docker ps | grep gateway

# Test health endpoint
curl http://localhost:3000/health

# View logs
docker logs gateway --tail=50

# Check resource usage
docker stats gateway --no-stream
```

### Complete Smoke Test Script

Save this as `smoke-test.sh`:

```bash
#!/bin/bash
set -e

BASE_URL="${1:-http://localhost:3000}"

echo "🧪 Running smoke tests against: $BASE_URL"

# Test 1: Health check
echo "Test 1: Health check..."
curl -f $BASE_URL/health || exit 1
echo "✅ Health check passed"

# Test 2: Login
echo "Test 2: Authentication..."
TOKEN=$(curl -s -X POST $BASE_URL/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Admin@123"}' \
  | jq -r '.token')
[ -z "$TOKEN" ] && echo "❌ Login failed" && exit 1
echo "✅ Authentication passed"

# Test 3: Protected endpoint
echo "Test 3: Protected endpoint..."
curl -f $BASE_URL/api/protected \
  -H "Authorization: Bearer $TOKEN" || exit 1
echo "✅ Protected endpoint passed"

# Test 4: Admin endpoint
echo "Test 4: Admin access..."
curl -f $BASE_URL/api/admin \
  -H "Authorization: Bearer $TOKEN" || exit 1
echo "✅ Admin access passed"

# Test 5: RBAC enforcement
echo "Test 5: RBAC enforcement..."
USER_TOKEN=$(curl -s -X POST $BASE_URL/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"user","password":"User@123"}' \
  | jq -r '.token')
STATUS=$(curl -s -o /dev/null -w "%{http_code}" $BASE_URL/api/admin \
  -H "Authorization: Bearer $USER_TOKEN")
[ "$STATUS" != "403" ] && echo "❌ RBAC enforcement failed" && exit 1
echo "✅ RBAC enforcement passed"

echo ""
echo "✅ All smoke tests passed!"
```

**Run it:**
```bash
chmod +x smoke-test.sh

# Test local
./smoke-test.sh http://localhost:3000

# Test staging
./smoke-test.sh http://staging.example.com

# Test production
./smoke-test.sh https://api.example.com
```

---

## 9️⃣ Troubleshooting

### Problem: "Cannot find module" errors

**Solution:**
```bash
# Delete node_modules and reinstall
rm -rf node_modules package-lock.json
npm install
```

### Problem: Port 3000 already in use

**Solution:**
```bash
# Find what's using port 3000
lsof -i :3000

# Kill the process
kill -9 <PID>

# Or use a different port
PORT=3001 npm start
```

### Problem: JWT token invalid or expired

**Solution:**
```bash
# Get a fresh token
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Admin@123"}'

# Make sure JWT_SECRET is the same everywhere
```

### Problem: Docker build fails

**Solution:**
```bash
# Clear Docker cache
docker system prune -a

# Rebuild without cache
docker build --no-cache -t secure-api-gateway:latest .
```

### Problem: Cannot SSH to VM

**Solution:**
```bash
# Check SSH key permissions
chmod 600 ~/.ssh/jenkins_deploy
chmod 700 ~/.ssh

# Test SSH with verbose output
ssh -vvv -i ~/.ssh/jenkins_deploy deploy@your-vm-ip

# Check if deploy user exists on VM
ssh root@your-vm-ip "id deploy"
```

### Problem: Jenkins cannot connect to Docker registry

**Solution:**
```bash
# Test login manually on Jenkins agent
docker login ghcr.io -u YOUR_USERNAME

# Check credential ID matches in Jenkinsfile
# Verify token has correct permissions
```

### Problem: Container starts but health check fails

**Solution:**
```bash
# Check container logs
docker logs gateway

# Check if JWT_SECRET is set
docker exec gateway env | grep JWT_SECRET

# Test health endpoint from inside container
docker exec gateway curl http://localhost:3000/health

# Check if port is exposed
docker port gateway
```

### Problem: Trivy scan fails in Jenkins

**Solution:**
```bash
# Install Trivy on Jenkins agent
# Ubuntu/Debian:
sudo apt-get install trivy

# macOS:
brew install trivy

# Verify installation
trivy --version
```

---

## 🎯 Quick Reference Commands

### Local Development
```bash
npm install              # Install dependencies
npm run dev             # Start with auto-reload
npm start               # Start normally
npm test                # Run tests
npm run lint            # Check code style
```

### Docker
```bash
docker build -t secure-api-gateway:latest .
docker run -d --name gateway -p 3000:3000 -e JWT_SECRET="..." secure-api-gateway:latest
docker ps               # List running containers
docker logs gateway     # View logs
docker stop gateway     # Stop container
docker rm gateway       # Remove container
```

### VM Management
```bash
ssh deploy@vm-ip                    # Connect to VM
docker ps                           # Check running containers
docker logs gateway --tail=100      # View logs
docker restart gateway              # Restart container
sudo systemctl status gateway       # Check systemd service
```

### Jenkins
```bash
# Restart Jenkins
sudo systemctl restart jenkins

# View Jenkins logs
sudo journalctl -u jenkins -f

# Check Jenkins agent
ssh jenkins-agent "docker ps"
```

---

## 📚 Additional Resources

- **Project README**: [README.md](./README.md)
- **VM Deployment Guide**: [VM_DEPLOYMENT_GUIDE.md](./VM_DEPLOYMENT_GUIDE.md)
- **Quick Reference**: [QUICK_REFERENCE.md](./QUICK_REFERENCE.md)
- **Docker Documentation**: https://docs.docker.com/
- **Jenkins Documentation**: https://www.jenkins.io/doc/
- **Node.js Documentation**: https://nodejs.org/docs/

---

## ✅ Setup Checklist

Use this checklist to track your progress:

### Local Development
- [ ] Node.js v20+ installed
- [ ] Repository cloned
- [ ] Dependencies installed (`npm install`)
- [ ] `.env` file created with JWT_SECRET
- [ ] Development server runs (`npm run dev`)
- [ ] Can login and get JWT token
- [ ] Protected endpoints work

### Docker
- [ ] Docker installed and running
- [ ] Can build image successfully
- [ ] Can run container locally
- [ ] Trivy installed
- [ ] Security scan passes

### VM Setup
- [ ] Staging VM provisioned
- [ ] Production VM provisioned
- [ ] Setup script run on both VMs
- [ ] JWT secrets generated and saved
- [ ] SSH keys created
- [ ] SSH access configured for deploy user
- [ ] Firewall configured
- [ ] Can SSH and run docker commands

### Docker Registry
- [ ] Registry account created (GitHub/Docker Hub)
- [ ] Access token generated
- [ ] Can login to registry
- [ ] Can push images

### Jenkins
- [ ] Jenkins installed and running
- [ ] Required plugins installed
- [ ] Docker available on Jenkins agent
- [ ] Trivy installed on Jenkins agent
- [ ] Docker registry credentials added
- [ ] SSH credentials added
- [ ] Jenkinsfile updated with VM hosts
- [ ] Pipeline job created
- [ ] First build successful

### Deployment
- [ ] Can deploy to staging
- [ ] Staging tests pass
- [ ] Can deploy to production
- [ ] Production verification passes
- [ ] Smoke tests pass on all environments

---

## 🆘 Need Help?

If you're stuck:

1. **Check the logs** - Most issues show up in logs
2. **Review this guide** - Make sure you didn't skip a step
3. **Check permissions** - SSH keys, file permissions, user groups
4. **Verify credentials** - Tokens, secrets, passwords
5. **Test connectivity** - SSH, Docker registry, network

---

**🎉 Congratulations!** 

If you've completed all steps, you now have a fully functional, secure API gateway with automated CI/CD deployment!

**Version**: 1.0  
**Last Updated**: 2024-11-16  
**Author**: Ganesh N
