# 🔄 Deployment Flow - Complete Explanation

## 📊 Overview: How Code Reaches Production

This document explains EXACTLY how your code goes from your laptop to running in production.

---

## 🎯 The Big Picture

```
Your Laptop → GitHub → Jenkins → Docker Registry → VMs → Running Application
```

---

## 📝 PART 1: INITIAL SETUP (One-Time)

### Step 1: VM Preparation

You have TWO virtual machines (VMs) in the cloud:
- **Staging VM**: `18.190.253.152` (Test environment)
- **Production VM**: `3.133.157.227` (Live environment)

**What you did to set them up**:

```bash
# 1. Create VM on cloud provider (AWS EC2, DigitalOcean, etc.)

# 2. Copy setup script to VM
scp deploy/scripts/setup-vm.sh ubuntu@18.190.253.152:~

# 3. SSH into VM and run setup
ssh ubuntu@18.190.253.152
chmod +x setup-vm.sh
sudo ./setup-vm.sh
```

**What setup-vm.sh does automatically**:

```
┌─────────────────────────────────────────┐
│         VM Setup Script Actions         │
├─────────────────────────────────────────┤
│                                         │
│ 1. Update system packages               │
│    └─ apt-get update && upgrade         │
│                                         │
│ 2. Install Docker                       │
│    └─ Allows running containers         │
│                                         │
│ 3. Create 'deploy' user                 │
│    └─ Non-root user for security        │
│    └─ Add to docker group               │
│                                         │
│ 4. Generate JWT Secret                  │
│    └─ openssl rand -base64 32           │
│    └─ Save to /etc/gateway/jwt-secret   │
│    └─ chmod 600 (only deploy can read)  │
│                                         │
│ 5. Configure Firewall (UFW)             │
│    └─ Allow port 22 (SSH)               │
│    └─ Allow port 3000 (API)             │
│    └─ Allow port 80/443 (HTTP/HTTPS)    │
│                                         │
│ 6. Install tools                        │
│    └─ curl, wget, git, jq               │
│                                         │
│ 7. Setup log rotation                   │
│    └─ Prevent disk from filling up      │
│                                         │
└─────────────────────────────────────────┘
```

**Result**: VM is now ready to receive deployments!

---

### Step 2: Jenkins Setup

**Jenkins Credentials Configuration**:

```
┌──────────────────────────────────────┐
│      Jenkins Credentials             │
├──────────────────────────────────────┤
│                                      │
│ 1. docker-registry-url               │
│    Type: Secret Text                 │
│    Value: ghcr.io/your-username      │
│    Purpose: Where to push images     │
│                                      │
│ 2. docker-registry-creds             │
│    Type: Username + Password         │
│    Purpose: Login to push images     │
│                                      │
│ 3. vm-ssh-key                        │
│    Type: SSH Private Key             │
│    Username: deploy                  │
│    Purpose: SSH into VMs             │
│                                      │
└──────────────────────────────────────┘
```

**Jenkinsfile Configuration** (already done in your project):

```groovy
// File: Jenkinsfile (lines 17-18)
STAGING_VM_HOST = 'deploy@18.190.253.152'
PROD_VM_HOST = 'deploy@3.133.157.227'
```

---

## 🚀 PART 2: DEPLOYMENT PROCESS (Every Code Change)

### Trigger: You Push Code to Git

```bash
# You make a change
vim src/app.js

# Commit and push
git add .
git commit -m "Add new feature"
git push origin main
```

**What happens next?**

---

### Stage 1: Jenkins Detects Change

```
GitHub Webhook → Jenkins
"Hey Jenkins, new code was pushed!"

Jenkins: "Got it! Starting pipeline..."
```

---

### Stage 2: Checkout Code

```
┌────────────────────────────┐
│   Jenkins Agent            │
├────────────────────────────┤
│ $ git clone <repo>         │
│ $ cd rbac-ssd              │
│                            │
│ Build #42 started          │
│ Commit: abc123def456       │
└────────────────────────────┘
```

---

### Stage 3: Security Audit

```bash
# Jenkins runs:
npm audit --audit-level=moderate

# Checks for:
# - Known vulnerabilities in dependencies
# - Outdated packages with security issues

# If CRITICAL issues found → FAIL BUILD
```

**Example Output**:
```
✅ found 0 vulnerabilities
Pipeline continues...

OR

❌ found 3 critical vulnerabilities
Pipeline STOPS! Fix issues first.
```

---

### Stage 4: Lint & Test

```bash
# Jenkins runs:
npm ci              # Clean install dependencies
npm run lint        # Check code quality (ESLint)
npm run test        # Run unit tests

# Ensures:
# - Code follows style guidelines
# - No syntax errors
# - Tests pass
```

---

### Stage 5: Build Docker Image

**This is where your app becomes a container!**

```bash
# Jenkins runs:
docker build --platform linux/amd64 \
  --tag ghcr.io/ganesh/secure-api-gateway:42-abc123d \
  --tag ghcr.io/ganesh/secure-api-gateway:latest \
  .
```

**What happens during build**:

```
Dockerfile Multi-Stage Build:
────────────────────────────────────────
Stage 1: Builder
  ├─ FROM node:20-alpine
  ├─ COPY package*.json
  ├─ RUN npm ci --only=production
  └─ Result: node_modules/ folder

Stage 2: Production
  ├─ FROM node:20-alpine (fresh start)
  ├─ Create non-root user (nodejs:1001)
  ├─ COPY node_modules from Stage 1
  ├─ COPY src/ (your application code)
  ├─ USER nodejs (switch to non-root)
  ├─ EXPOSE 3000
  └─ CMD ["node", "src/app.js"]

Final Image Size: ~150MB (optimized!)
```

**Why multi-stage?**
- Stage 1 has build tools (large)
- Stage 2 only has runtime files (small)
- Result: Smaller, faster, more secure image

---

### Stage 6: Security Scan (Trivy)

```bash
# Jenkins runs:
trivy image --severity CRITICAL,HIGH \
  ghcr.io/ganesh/secure-api-gateway:42-abc123d
```

**What Trivy checks**:

```
┌─────────────────────────────────────────┐
│        Trivy Vulnerability Scan         │
├─────────────────────────────────────────┤
│                                         │
│ Scanning:                               │
│  ├─ Base image (node:20-alpine)         │
│  ├─ System packages (apk)               │
│  ├─ Node.js dependencies (npm)          │
│  └─ Application code                    │
│                                         │
│ Looking for:                            │
│  ├─ Known CVE vulnerabilities           │
│  ├─ Outdated packages                   │
│  ├─ Security misconfigurations          │
│  └─ Exposed secrets                     │
│                                         │
│ Severity Levels:                        │
│  ├─ CRITICAL → Fail build               │
│  ├─ HIGH → Fail build                   │
│  ├─ MEDIUM → Warning only               │
│  └─ LOW → Info only                     │
│                                         │
└─────────────────────────────────────────┘
```

**Example Results**:
```
✅ Total: 0 CRITICAL, 0 HIGH
Pipeline continues...

OR

❌ Total: 2 CRITICAL, 5 HIGH
  - node: CVE-2023-12345 (CRITICAL)
  - express: CVE-2023-67890 (HIGH)
Pipeline STOPS! Update packages first.
```

---

### Stage 7: Push to Docker Registry

```bash
# Jenkins runs:
echo $REGISTRY_PASS | docker login ghcr.io -u $REGISTRY_USER --password-stdin
docker push ghcr.io/ganesh/secure-api-gateway:42-abc123d
docker push ghcr.io/ganesh/secure-api-gateway:latest
docker logout ghcr.io
```

**What's happening**:

```
Local Jenkins Server          Docker Registry (GitHub)
┌────────────────┐            ┌──────────────────┐
│  Docker Image  │  ─────────>│  ghcr.io         │
│  150MB         │    Push     │                  │
│                │            │  Images stored:  │
│  Tag: 42-abc   │            │  - 42-abc123d    │
│  Tag: latest   │            │  - latest        │
└────────────────┘            └──────────────────┘
```

**Why push to registry?**
- VMs can pull the image from anywhere
- Image is version-controlled (rollback possible)
- Multiple VMs can use same image

---

### Stage 8: Deploy to Staging VM

**This is where it gets deployed!**

```bash
# Jenkins runs:
ssh deploy@18.190.253.152 '
  # Stop old container
  docker stop gateway || true
  docker rm gateway || true
  
  # Pull new image
  docker pull ghcr.io/ganesh/secure-api-gateway:42-abc123d
  
  # Run new container
  docker run -d \
    --name gateway \
    --restart unless-stopped \
    -p 3000:3000 \
    -e NODE_ENV=production \
    -e JWT_SECRET=$(cat /etc/gateway/jwt-secret) \
    -e PORT=3000 \
    ghcr.io/ganesh/secure-api-gateway:42-abc123d
  
  # Verify it started
  docker ps | grep gateway
  sleep 10
  curl -f http://localhost:3000/health
'
```

**Step-by-step breakdown**:

```
┌─────────────────────────────────────────────────────┐
│           Staging VM: 18.190.253.152                │
├─────────────────────────────────────────────────────┤
│                                                     │
│ BEFORE Deployment:                                  │
│ ┌──────────────────────┐                           │
│ │ Container: gateway   │                           │
│ │ Image: v41 (old)     │  ← Running old version    │
│ │ Status: Running      │                           │
│ └──────────────────────┘                           │
│                                                     │
│ Step 1: docker stop gateway                        │
│ ┌──────────────────────┐                           │
│ │ Container: gateway   │                           │
│ │ Status: Stopped      │  ← Stops gracefully       │
│ └──────────────────────┘                           │
│                                                     │
│ Step 2: docker rm gateway                          │
│ ┌──────────────────────┐                           │
│ │ (Container removed)  │  ← Deleted                │
│ └──────────────────────┘                           │
│                                                     │
│ Step 3: docker pull ...42-abc123d                  │
│ ┌──────────────────────┐                           │
│ │ Image downloaded     │  ← New version pulled     │
│ │ Size: 150MB          │     from registry         │
│ └──────────────────────┘                           │
│                                                     │
│ Step 4: docker run ...                             │
│ ┌──────────────────────┐                           │
│ │ Container: gateway   │                           │
│ │ Image: 42-abc123d    │  ← Running new version!   │
│ │ Status: Running      │                           │
│ │ Port: 0.0.0.0:3000   │                           │
│ │ JWT_SECRET: (loaded) │                           │
│ └──────────────────────┘                           │
│                                                     │
│ Step 5: Health check                               │
│ $ curl http://localhost:3000/health                │
│ {"status":"healthy","uptime":5}  ✅               │
│                                                     │
└─────────────────────────────────────────────────────┘
```

**Key Point**: The JWT secret is READ from the VM's file system, not stored in the Docker image!

```
Container Environment:
  NODE_ENV=production
  JWT_SECRET=$(cat /etc/gateway/jwt-secret)  ← Loaded at runtime
  PORT=3000
```

---

### Stage 9: Smoke Tests on Staging

```bash
# Jenkins runs automated tests:
ssh deploy@18.190.253.152 '
  # Test 1: Health check
  curl -f http://localhost:3000/health
  
  # Test 2: Public endpoint
  curl -f http://localhost:3000/api/public
'
```

**What smoke tests verify**:
```
✅ Container is running
✅ Port 3000 is accessible
✅ Health endpoint returns 200 OK
✅ API responds correctly
✅ No crashes in logs
```

---

### Stage 10: Manual Approval Gate ⏸️

**Jenkins PAUSES here!**

```
┌────────────────────────────────────────┐
│     🚦 MANUAL APPROVAL REQUIRED        │
├────────────────────────────────────────┤
│                                        │
│  Build #42 is waiting for approval    │
│                                        │
│  Staging deployment successful:        │
│  ✅ Tests passed                       │
│  ✅ Health check OK                    │
│  ✅ No errors in logs                  │
│                                        │
│  Deploy to PRODUCTION?                 │
│                                        │
│  [ ✅ Deploy ]  [ ❌ Abort ]           │
│                                        │
│  Only admin/release-manager can        │
│  approve this step                     │
│                                        │
│  Timeout: 24 hours                     │
│                                        │
└────────────────────────────────────────┘
```

**Why this gate exists**:
- Prevents automatic production deployment
- Allows manual testing on staging
- Gives time to verify everything works
- Production deploys are deliberate, not accidental

**What you should do before approving**:
1. Test staging environment manually
2. Check logs for errors
3. Verify all features work
4. Get team approval (if team project)
5. Click "Deploy" button in Jenkins

---

### Stage 11: Deploy to Production VM

**SAME process as staging, but on production VM**:

```bash
ssh deploy@3.133.157.227 '
  docker stop gateway || true
  docker rm gateway || true
  docker pull ghcr.io/ganesh/secure-api-gateway:42-abc123d
  docker run -d \
    --name gateway \
    --restart unless-stopped \
    -p 3000:3000 \
    -e NODE_ENV=production \
    -e JWT_SECRET=$(cat /etc/gateway/jwt-secret) \
    ghcr.io/ganesh/secure-api-gateway:42-abc123d
  sleep 10
  curl -f http://localhost:3000/health
'
```

```
┌─────────────────────────────────────────────────────┐
│         Production VM: 3.133.157.227                │
├─────────────────────────────────────────────────────┤
│                                                     │
│ Old container stopped and removed                  │
│ New container started with v42                     │
│ Health check: ✅ PASSED                            │
│                                                     │
│ 🎉 PRODUCTION IS LIVE WITH NEW VERSION!            │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

### Stage 12: Production Verification

```bash
# Jenkins verifies deployment:
ssh deploy@3.133.157.227 '
  # Check container is running
  docker ps | grep gateway
  
  # Health check
  curl -f http://localhost:3000/health
  
  # View recent logs
  docker logs --tail=50 gateway
'
```

**Pipeline Complete!** 🎉

```
┌────────────────────────────────────┐
│   ✅ Pipeline Successful!          │
├────────────────────────────────────┤
│                                    │
│ Build #42 completed                │
│ Duration: 8 minutes 32 seconds     │
│                                    │
│ ✅ Security audit passed           │
│ ✅ Tests passed                    │
│ ✅ Docker build successful         │
│ ✅ Trivy scan passed               │
│ ✅ Image pushed to registry        │
│ ✅ Staging deployed                │
│ ✅ Smoke tests passed              │
│ ✅ Production deployed             │
│ ✅ Verification passed             │
│                                    │
│ Your code is now LIVE! 🚀          │
│                                    │
└────────────────────────────────────┘
```

---

## 🔄 PART 3: RE-DEPLOYMENT SCENARIOS

### Scenario 1: Bug Fix

```
Developer finds bug → Fix code → Push to Git
                                    ↓
                        Same pipeline runs again!
                                    ↓
                      New Docker image: v43
                                    ↓
                         Deployed to staging
                                    ↓
                         Manual approval
                                    ↓
                      Deployed to production
                                    ↓
                         Bug is fixed! ✅
```

---

### Scenario 2: Rollback (Emergency!)

**Problem**: New version (v43) has critical bug in production!

**Solution**: Rollback to previous version (v42)

```bash
# Option 1: Jenkins Rollback
1. Go to Jenkins
2. Find Build #42 (previous successful build)
3. Click "Rebuild"
4. Approve production deployment
5. Production now running v42 again

# Option 2: Manual Rollback (faster)
ssh deploy@3.133.157.227
docker stop gateway
docker rm gateway
docker run -d --name gateway \
  -p 3000:3000 \
  -e JWT_SECRET=$(cat /etc/gateway/jwt-secret) \
  ghcr.io/ganesh/secure-api-gateway:42-abc123d  ← Old version!

curl http://localhost:3000/health
# Rollback complete in ~30 seconds!
```

**Why rollback is easy**:
- Old Docker images are still in registry
- Just run previous tag
- No need to rebuild anything

---

## 🔐 PART 4: HOW SECRETS ARE MANAGED

### The JWT Secret Story

**Problem**: Application needs a secret key to sign JWT tokens, but:
- ❌ Can't put in code (would be in Git)
- ❌ Can't put in Docker image (anyone can see it)
- ❌ Can't hardcode (same secret everywhere)

**Solution**: Store on VM filesystem, load at runtime

```
┌──────────────────────────────────────────────────────┐
│              VM Filesystem                           │
├──────────────────────────────────────────────────────┤
│                                                      │
│ /etc/gateway/                                        │
│   └── jwt-secret  ← File with secret                │
│       Permissions: 600 (only deploy user can read)   │
│       Owner: deploy:deploy                           │
│       Content: "R7x9K2mPqW8vB3nF5cL1hJ6gD4sA0t..."   │
│                                                      │
└──────────────────────────────────────────────────────┘

When container starts:
  docker run -e JWT_SECRET=$(cat /etc/gateway/jwt-secret) ...
                            ↑
                    Reads from file system
                    Only accessible from VM
                    Different per environment
```

**Key Points**:
- Staging VM has different JWT secret than Production
- Secret persists even if container is deleted
- Secret is NOT in Docker image
- Secret is NOT in Git repository

---

## 📊 PART 5: CONTAINER LIFECYCLE

### What Happens to Containers

```
Container States:
─────────────────

CREATE     ──>   RUNNING   ──>   STOPPED   ──>   REMOVED
  ↑                 │                               │
  │                 │                               │
  └─────────────────┴───────────────────────────────┘
           Can restart                    Gone forever
```

**During deployment**:

```
1. Old Container (v41):
   Running → Stop → Remove (deleted from system)

2. New Container (v42):
   Create → Start → Running

Docker Images (on VM):
┌─────────────────────┐
│ v41 (unused)        │  ← Still exists, can rollback
│ v42 (running)       │  ← Currently active
│ v43 (pulled)        │  ← Ready for next deploy
└─────────────────────┘
```

**Cleanup old images**:
```bash
# Remove unused images to save disk space
docker image prune -a --filter "until=720h"  # Keep last 30 days
```

---

## 🌐 PART 6: NETWORK FLOW

### How Users Access Your API

```
Internet User
     │
     │ HTTPS Request
     │
     ▼
┌─────────────────────┐
│   Nginx (Optional)  │  ← Reverse Proxy
│   - HTTPS/SSL       │     (recommended for production)
│   - Rate Limiting   │
└──────────┬──────────┘
           │
           │ HTTP Request
           │
           ▼
┌─────────────────────┐
│   VM: 3.133.157.227 │
│   ┌───────────────┐ │
│   │ Docker        │ │
│   │ Container     │ │
│   │               │ │
│   │ Port 3000     │ │
│   │ Node.js App   │ │
│   └───────────────┘ │
└─────────────────────┘
           │
           │ Response
           │
           ▼
     Internet User
```

**Port Mapping**:
```
-p 3000:3000
   │    │
   │    └─ Container internal port
   └────── Host (VM) external port

Meaning: VM's port 3000 → Container's port 3000
```

---

## 🔍 PART 7: MONITORING & DEBUGGING

### Check Deployment Status

```bash
# SSH to VM
ssh deploy@3.133.157.227

# Check if container is running
docker ps | grep gateway
# Expected: CONTAINER ID, IMAGE, STATUS: Up X minutes

# View logs
docker logs gateway -f
# Expected: "🚀 Secure API Gateway started"

# Test API
curl http://localhost:3000/health
# Expected: {"status":"healthy",...}

# Check container resources
docker stats gateway
# Shows: CPU%, MEM%, NET I/O
```

### Common Issues

**Issue 1: Container won't start**
```bash
# Check logs
docker logs gateway

# Common causes:
# - JWT_SECRET missing
# - Port already in use
# - Application error
```

**Issue 2: Health check fails**
```bash
# Check if app is listening
docker exec gateway netstat -tlnp | grep 3000

# Test from inside container
docker exec gateway curl http://localhost:3000/health

# Check environment variables
docker exec gateway env | grep JWT_SECRET
```

**Issue 3: Old version still running**
```bash
# Verify image tag
docker inspect gateway | grep Image

# Expected: v42
# If showing v41: Container wasn't updated

# Solution: Force recreation
docker stop gateway && docker rm gateway
# Then re-run deployment
```

---

## 🎯 PART 8: KEY TAKEAWAYS

### What Makes This Deployment System Good

1. **Automated**: One push triggers entire pipeline
2. **Safe**: Multiple security checks before production
3. **Controlled**: Manual approval for production
4. **Fast**: Deployment takes ~30 seconds
5. **Rollback**: Easy to revert to previous version
6. **Secure**: Secrets managed properly
7. **Auditable**: Every deployment is logged in Jenkins
8. **Reproducible**: Same process every time

---

### Deployment Checklist

**Before First Deployment**:
- [ ] VMs set up with setup-vm.sh
- [ ] Jenkins credentials configured
- [ ] SSH keys added to VMs
- [ ] Firewall rules configured
- [ ] JWT secrets generated

**Every Deployment**:
- [ ] Code pushed to Git
- [ ] Jenkins pipeline runs
- [ ] All tests pass
- [ ] Security scans pass
- [ ] Staging deployed and tested
- [ ] Manual approval given
- [ ] Production deployed
- [ ] Verification passed

---

## 📞 Quick Reference Commands

```bash
# Check deployment status
ssh deploy@<vm-ip> 'docker ps | grep gateway'

# View logs
ssh deploy@<vm-ip> 'docker logs gateway -f'

# Restart container
ssh deploy@<vm-ip> 'docker restart gateway'

# Manual deployment
./deploy/scripts/deploy-vm.sh production deploy@<vm-ip> v42

# Rollback
ssh deploy@<vm-ip>
docker stop gateway && docker rm gateway
docker run -d --name gateway -p 3000:3000 \
  -e JWT_SECRET=$(cat /etc/gateway/jwt-secret) \
  ghcr.io/your-org/secure-api-gateway:v41

# Health check
curl http://<vm-ip>:3000/health
```

---

**This is how professional DevOps teams deploy applications!** 🚀

You've implemented:
- ✅ CI/CD Pipeline
- ✅ Automated Testing
- ✅ Security Scanning
- ✅ Container Orchestration
- ✅ Secrets Management
- ✅ Rollback Strategy
- ✅ Monitoring & Logging

**Congratulations! This is production-grade deployment.** 🎉
