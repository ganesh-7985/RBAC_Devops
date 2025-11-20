# 🎓 Professor Presentation Guide - Secure API Gateway RBAC Project

## 📌 Quick Project Overview
**Project Name**: Secure API Gateway with Role-Based Access Control  
**Technology Stack**: Node.js, Express, Docker, Jenkins CI/CD  
**Deployment**: VM-based deployment using SSH (No Kubernetes)  
**Security Features**: JWT Authentication, RBAC, Input Validation, Container Hardening

---

## 🎯 Part 1: PROJECT EXPLANATION (5-7 minutes)

### What This Project Does

**"Professor, I've built a production-ready API Gateway that demonstrates enterprise-level security practices and DevOps automation."**

#### Core Functionality:
1. **Secure Authentication**: Users login with username/password and receive a JWT token
2. **Role-Based Access Control (RBAC)**: Three roles (Admin, User, Guest) with different permissions
3. **Protected APIs**: Different endpoints require different authorization levels
4. **Automated Deployment**: Jenkins CI/CD pipeline automatically builds, tests, and deploys

---

### System Architecture

```
┌─────────────────────────────────────────────────────┐
│                  JENKINS CI/CD                      │
│  (Build → Test → Security Scan → Deploy)           │
└────────────────┬────────────────────────────────────┘
                 │
         SSH Deployment
                 │
    ┌────────────┴────────────┐
    │                         │
    ▼                         ▼
┌─────────────┐         ┌─────────────┐
│ Staging VM  │         │ Production  │
│             │         │     VM      │
│  Docker     │         │  Docker     │
│ Container   │         │ Container   │
│  (Gateway)  │         │  (Gateway)  │
└─────────────┘         └─────────────┘
```

---

### Technology Stack Explanation

#### Backend Application:
- **Node.js 20**: Runtime environment
- **Express.js**: Web framework for API routes
- **JWT (jsonwebtoken)**: Token-based authentication
- **Helmet.js**: Security headers (CSP, HSTS, X-Frame-Options)
- **Zod**: Input validation and sanitization
- **Winston**: Structured logging

#### Security Features:
1. **JWT Authentication**: Stateless, encrypted tokens
2. **RBAC System**: Role hierarchy (Admin > User > Guest)
3. **Input Validation**: XSS prevention using Zod
4. **Security Headers**: Protection against common attacks
5. **Container Hardening**: Non-root user, minimal Alpine image

#### DevOps/Infrastructure:
- **Docker**: Containerization (multi-stage builds)
- **Jenkins**: CI/CD automation
- **Trivy**: Container vulnerability scanning
- **SSH**: Secure VM deployment
- **UFW Firewall**: Network security

---

## 🎬 Part 2: LIVE DEMO SCRIPT (10-15 minutes)

### Demo Sequence:

#### **Step 1: Show the Code Structure (2 minutes)**

```bash
# Navigate to project
cd /Users/shankarganesh/Coding/rbac-ssd

# Show file structure
tree -L 2 -I node_modules
```

**Explain**:
- `src/` - Application code (auth, RBAC, API routes)
- `Dockerfile` - Container configuration
- `Jenkinsfile` - CI/CD pipeline
- `deploy/` - Deployment scripts

---

#### **Step 2: Local Development Demo (3 minutes)**

```bash
# 1. Show environment configuration
cat .env.example

# 2. Start the application locally
npm install
npm run dev

# Server starts on http://localhost:3000
```

**In another terminal window:**

```bash
# Test health endpoint (public)
curl http://localhost:3000/health

# Show API documentation
curl http://localhost:3000/

# Try to access protected endpoint WITHOUT token (should fail)
curl http://localhost:3000/api/protected
# Expected: 401 Unauthorized - "No token provided"
```

---

#### **Step 3: Authentication Demo (4 minutes)**

```bash
# 1. Login as GUEST user
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"guest","password":"Guest@123"}' | jq

# Copy the token from response
GUEST_TOKEN="<paste-token-here>"

# 2. Test guest access (should work)
curl http://localhost:3000/api/guest \
  -H "Authorization: Bearer $GUEST_TOKEN" | jq

# 3. Try to access admin endpoint as guest (should FAIL)
curl http://localhost:3000/api/admin \
  -H "Authorization: Bearer $GUEST_TOKEN" | jq
# Expected: 403 Forbidden - "Insufficient permissions"

# 4. Login as ADMIN
ADMIN_TOKEN=$(curl -s -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Admin@123"}' | jq -r '.token')

# 5. Access admin endpoint (should work)
curl http://localhost:3000/api/admin \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq
# Expected: Success with admin data
```

**Key Points to Explain**:
- JWT tokens contain user role and permissions
- RBAC middleware checks permissions before allowing access
- Different roles have different capabilities

---

#### **Step 4: Show Security Features (2 minutes)**

```bash
# 1. Show security headers
curl -I http://localhost:3000/health

# Point out:
# - X-Content-Type-Options: nosniff
# - X-Frame-Options: DENY
# - Strict-Transport-Security (HSTS)
# - Content-Security-Policy (CSP)

# 2. Show input validation
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"<script>alert(1)</script>","password":"test"}'
# Expected: Validation error - XSS attempt blocked
```

---

#### **Step 5: Docker Demonstration (3 minutes)**

```bash
# 1. Show Dockerfile multi-stage build
cat Dockerfile

# 2. Build Docker image
docker build -t secure-api-gateway:demo .

# 3. Show image is secure (non-root user)
docker run --rm secure-api-gateway:demo id
# Expected: uid=1001(nodejs) gid=1001(nodejs) - NOT root!

# 4. Run security scan
trivy image --severity HIGH,CRITICAL secure-api-gateway:demo

# 5. Run container
docker run -d --name gateway-demo \
  -p 3000:3000 \
  -e JWT_SECRET="demo-secret-key-12345" \
  secure-api-gateway:demo

# 6. Test containerized application
curl http://localhost:3000/health

# 7. Show logs
docker logs gateway-demo

# 8. Cleanup
docker stop gateway-demo && docker rm gateway-demo
```

---

#### **Step 6: Show CI/CD Pipeline (2 minutes)**

**Open Jenkins and show**:

```bash
# Show Jenkinsfile
cat Jenkinsfile
```

**Explain the stages**:
1. **Checkout**: Get code from Git
2. **Security Audit**: `npm audit` for vulnerabilities
3. **Lint & Test**: Code quality checks
4. **Build**: Create Docker image
5. **Trivy Scan**: Security vulnerability scanning
6. **Push**: Upload to Docker registry
7. **Deploy Staging**: SSH to staging VM → Deploy
8. **Smoke Tests**: Verify staging works
9. **Manual Approval**: ⏸️ WAIT for approval
10. **Deploy Production**: SSH to prod VM → Deploy
11. **Verify**: Health checks

**Key Points**:
- Automated security checks at every stage
- Manual approval gate prevents accidental production deployments
- SSH-based deployment (no cloud lock-in)

---

## 📊 Part 3: DEPLOYMENT EXPLANATION (Deep Dive)

### Deployment Architecture

```
┌──────────────────────────────────────────────┐
│         Developer Pushes Code to Git        │
└──────────────────┬───────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────────┐
│              JENKINS PIPELINE                │
├──────────────────────────────────────────────┤
│ 1. Checkout Code                             │
│ 2. npm audit (check dependencies)            │
│ 3. ESLint (code quality)                     │
│ 4. Build Docker Image (multi-stage)          │
│ 5. Trivy Scan (security vulnerabilities)     │
│ 6. Push to Docker Registry (GHCR/Docker Hub) │
└──────────────────┬───────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────────┐
│         DEPLOY TO STAGING VM (via SSH)      │
├──────────────────────────────────────────────┤
│ • SSH into staging VM                        │
│ • Stop old container                         │
│ • Pull new Docker image                      │
│ • Run new container with:                    │
│   - JWT_SECRET from /etc/gateway/jwt-secret  │
│   - Port 3000 exposed                        │
│   - Auto-restart enabled                     │
│ • Health check: curl /health                 │
└──────────────────┬───────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────────┐
│           SMOKE TESTS (Automated)            │
├──────────────────────────────────────────────┤
│ • Health endpoint returns 200 OK             │
│ • Public API accessible                      │
│ • Authentication works                       │
│ • RBAC enforced correctly                    │
└──────────────────┬───────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────────┐
│       ⏸️ MANUAL APPROVAL GATE                │
├──────────────────────────────────────────────┤
│ Jenkins PAUSES and asks:                     │
│ "Deploy to Production?"                      │
│                                              │
│ Only admin/release-manager can approve      │
│                                              │
│ [ Deploy ]  [ Abort ]                        │
└──────────────────┬───────────────────────────┘
                   │
         (If Approved)
                   │
                   ▼
┌──────────────────────────────────────────────┐
│       DEPLOY TO PRODUCTION VM (via SSH)      │
├──────────────────────────────────────────────┤
│ Same process as staging:                     │
│ • SSH to production VM                       │
│ • Stop old container                         │
│ • Pull new image                             │
│ • Start new container                        │
│ • Health check                               │
└──────────────────┬───────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────────┐
│         PRODUCTION VERIFICATION              │
├──────────────────────────────────────────────┤
│ • Container running                          │
│ • Health check passes                        │
│ • Logs show no errors                        │
└──────────────────────────────────────────────┘
```

---

### How Deployment Works (Step by Step)

#### **Initial VM Setup (One-Time)**:

```bash
# 1. Create VM (AWS EC2, DigitalOcean, etc.)

# 2. Copy setup script to VM
scp deploy/scripts/setup-vm.sh ubuntu@<vm-ip>:~

# 3. SSH to VM and run setup
ssh ubuntu@<vm-ip>
chmod +x setup-vm.sh
sudo ./setup-vm.sh
```

**What setup-vm.sh does**:
1. Updates system packages
2. Installs Docker
3. Creates `deploy` user with Docker permissions
4. Generates JWT secret (stored in `/etc/gateway/jwt-secret`)
5. Configures firewall (UFW)
6. Sets up log rotation

#### **Configure Jenkins (One-Time)**:

1. **Add Credentials**:
   - Docker registry URL and credentials
   - SSH private key for VMs

2. **Create Pipeline Job**:
   - Point to Jenkinsfile in Git repo
   - Configure webhook (auto-trigger on push)

3. **Update Jenkinsfile**:
   ```groovy
   STAGING_VM_HOST = 'deploy@18.190.253.152'  // Your staging VM
   PROD_VM_HOST = 'deploy@3.133.157.227'      // Your production VM
   ```

---

#### **Automated Deployment Flow**:

**Every time you push code to Git**:

1. **Jenkins detects the push** (via webhook)

2. **Build Stage**:
   ```bash
   docker build --platform linux/amd64 \
     --tag ghcr.io/your-org/secure-api-gateway:v1.0.0 .
   ```
   - Multi-stage build creates minimal image
   - Base: Alpine Linux (5MB vs 1GB for full Ubuntu)
   - Non-root user (UID 1001) for security

3. **Security Scan**:
   ```bash
   trivy image --severity CRITICAL,HIGH <image>
   ```
   - Scans for known vulnerabilities
   - Fails build if CRITICAL issues found

4. **Push to Registry**:
   ```bash
   docker push ghcr.io/your-org/secure-api-gateway:v1.0.0
   ```

5. **Deploy to Staging**:
   ```bash
   ssh deploy@staging-vm '
     docker stop gateway || true
     docker rm gateway || true
     docker pull ghcr.io/your-org/secure-api-gateway:v1.0.0
     docker run -d --name gateway \
       -p 3000:3000 \
       -e JWT_SECRET=$(cat /etc/gateway/jwt-secret) \
       ghcr.io/your-org/secure-api-gateway:v1.0.0
     curl -f http://localhost:3000/health
   '
   ```

6. **Smoke Tests**: Automated tests verify deployment

7. **Manual Approval**: Jenkins pauses for human approval

8. **Deploy to Production**: Same process as staging

---

### How Re-Deployment Works

**Scenario 1: Bug Fix or New Feature**

```bash
# Developer makes changes
git add .
git commit -m "Fix: Resolve login issue"
git push origin main

# Jenkins automatically:
# 1. Builds new Docker image with tag: v1.0.1
# 2. Runs all tests and security scans
# 3. Deploys to staging
# 4. Waits for approval
# 5. Deploys to production
```

**The old container is replaced**:
```bash
docker stop gateway      # Stop old version
docker rm gateway        # Remove old container
docker run ... v1.0.1   # Start new version
```

**Key Point**: Docker image tags ensure you can always rollback to previous version!

---

**Scenario 2: Rollback**

If new version has issues:

```bash
# SSH to production VM
ssh deploy@production-vm

# Stop broken version
docker stop gateway
docker rm gateway

# Run previous version
docker run -d --name gateway \
  -p 3000:3000 \
  -e JWT_SECRET=$(cat /etc/gateway/jwt-secret) \
  ghcr.io/your-org/secure-api-gateway:v1.0.0-prev

# Verify
curl http://localhost:3000/health
```

---

### Environment Variables & Secrets Management

#### **JWT_SECRET Handling**:

**IMPORTANT**: JWT secret is stored securely on VM, NOT in code!

```bash
# Generated during VM setup
openssl rand -base64 32 > /etc/gateway/jwt-secret
chmod 600 /etc/gateway/jwt-secret
chown deploy:deploy /etc/gateway/jwt-secret

# Container reads it at runtime
-e JWT_SECRET=$(cat /etc/gateway/jwt-secret)
```

**Why this matters**:
- Secret never stored in Git
- Different per environment (staging vs production)
- Persists across container restarts

---

### Monitoring & Logging

```bash
# View container logs
ssh deploy@production-vm
docker logs gateway -f

# Check container status
docker ps | grep gateway

# View system resources
docker stats gateway

# Check health
curl http://localhost:3000/health
```

---

## 💡 Part 4: KEY INTERVIEW QUESTIONS & ANSWERS

### Question 1: "Why use JWT instead of sessions?"

**Answer**:
- **Stateless**: No server-side session storage needed (scalable)
- **Portable**: Token can be used across multiple services
- **Secure**: Cryptographically signed, tamper-proof
- **Expiry**: Built-in token expiration (configurable)

---

### Question 2: "How does RBAC work in your system?"

**Answer**:
```javascript
// Role hierarchy
admin: Level 3 (all permissions)
user:  Level 2 (read, write)
guest: Level 1 (read only)

// When user requests /api/admin:
1. authenticateJWT middleware: Verify token is valid
2. requireRole(['admin']) middleware: Check user.role === 'admin'
3. If not admin: Return 403 Forbidden
4. If admin: Proceed to route handler
```

---

### Question 3: "What security measures did you implement?"

**Answer**:
1. **Authentication**: JWT tokens with expiry
2. **Authorization**: RBAC with role hierarchy
3. **Input Validation**: Zod schemas prevent XSS
4. **Security Headers**: Helmet.js (CSP, HSTS, etc.)
5. **Container Security**: Non-root user, minimal image
6. **Vulnerability Scanning**: Trivy in CI/CD
7. **Secrets Management**: JWT secret not in code
8. **HTTPS Ready**: Designed for reverse proxy (nginx)

---

### Question 4: "How would you scale this application?"

**Answer**:
1. **Horizontal Scaling**: Run multiple containers with load balancer
2. **Database**: Add PostgreSQL/MongoDB for user data
3. **Redis**: Token blacklist for logout functionality
4. **Rate Limiting**: Prevent API abuse
5. **CDN**: Cache static content
6. **Monitoring**: Prometheus + Grafana for metrics
7. **Log Aggregation**: ELK stack or Loki

---

### Question 5: "Why Docker? What benefits does it provide?"

**Answer**:
1. **Consistency**: "Works on my machine" → Works everywhere
2. **Isolation**: App dependencies don't conflict with host
3. **Portability**: Same container runs on any platform
4. **Fast Deployment**: Pull image and run (seconds, not minutes)
5. **Version Control**: Tag images for easy rollback
6. **Resource Efficient**: Lightweight vs VMs

---

### Question 6: "Explain the CI/CD pipeline stages"

**Answer**:
```
Code Push → Jenkins Pipeline:
│
├─ Security Audit (npm audit)
│  ↓ Fail if vulnerabilities
│
├─ Lint & Test (ESLint)
│  ↓ Fail if code quality issues
│
├─ Build Docker Image
│  ↓ Multi-stage build
│
├─ Trivy Scan
│  ↓ Fail if CRITICAL vulnerabilities
│
├─ Push to Registry
│  ↓ Tagged image stored
│
├─ Deploy Staging (SSH)
│  ↓ Automated deployment
│
├─ Smoke Tests
│  ↓ Verify deployment
│
├─ Manual Approval ⏸️
│  ↓ Human verification
│
├─ Deploy Production (SSH)
│  ↓ Automated deployment
│
└─ Verification
   ✅ Production live
```

---

## 🎯 Part 5: DEMO CHECKLIST

### Before Professor Arrives:

- [ ] **Start local server**: `npm run dev`
- [ ] **Have terminals ready**:
  - Terminal 1: Application logs
  - Terminal 2: curl commands
- [ ] **Prepare test credentials**:
  ```
  Admin:  admin / Admin@123
  User:   user / User@123
  Guest:  guest / Guest@123
  ```
- [ ] **Open files in editor**:
  - `src/app.js` - Main application
  - `src/middleware/rbac.js` - RBAC logic
  - `Dockerfile` - Container config
  - `Jenkinsfile` - CI/CD pipeline
- [ ] **Have Jenkins dashboard open** (if available)

---

### Demo Flow (15 minutes):

**5 min**: Code walkthrough
- Show architecture diagram
- Explain tech stack
- Show key files

**5 min**: Live authentication demo
- Test guest/user/admin roles
- Show 401 (unauthorized) vs 403 (forbidden)

**3 min**: Docker demo
- Build image
- Run security scan
- Run container

**2 min**: CI/CD explanation
- Show Jenkinsfile stages
- Explain manual approval gate
- Show deployment script

---

## 📝 Part 6: TALKING POINTS FOR PROFESSOR

### Opening Statement:
"Professor, this project demonstrates enterprise-grade DevOps practices including secure authentication, automated CI/CD, and container security. It's designed for real-world deployment to production VMs."

### Highlight Your Skills:
1. **Full-Stack Development**: Backend API with Node.js/Express
2. **Security Engineering**: JWT, RBAC, input validation, container hardening
3. **DevOps**: Docker, Jenkins CI/CD, automated testing
4. **System Administration**: VM setup, SSH deployment, firewall configuration
5. **Best Practices**: Code quality (ESLint), logging (Winston), error handling

### Why This Project Matters:
- **Production-Ready**: Not a toy project, designed for real deployment
- **Security-First**: Multiple layers of security
- **Automated**: CI/CD pipeline reduces human error
- **Scalable**: Can handle multiple VMs, load balancers
- **Industry-Standard**: Uses tools/practices from real companies

---

## 🚀 Part 7: ADVANCED CONCEPTS (If Asked)

### Multi-Environment Strategy:
```
Development (Local)
   ↓ Git Push
Staging VM (Auto-deploy)
   ↓ Manual Approval
Production VM (Controlled deploy)
```

### Zero-Downtime Deployment:
```bash
# Run two containers with load balancer
docker run --name gateway-v1 -p 3001:3000 ...
docker run --name gateway-v2 -p 3002:3000 ...

# Nginx load balancer switches traffic
upstream backend {
  server localhost:3001;
  server localhost:3002;
}
```

### Security Best Practices Implemented:
1. ✅ Least privilege (non-root container)
2. ✅ Defense in depth (multiple security layers)
3. ✅ Secrets management (external secret storage)
4. ✅ Regular scans (Trivy in pipeline)
5. ✅ Audit logging (Winston structured logs)
6. ✅ HTTPS ready (Helmet headers)

---

## 📚 Part 8: QUESTIONS TO EXPECT

### Technical Questions:

**Q: "What happens if the JWT secret changes?"**
A: All existing tokens become invalid. Users must re-login. That's why we persist the secret in `/etc/gateway/jwt-secret` and don't change it randomly.

**Q: "How do you handle database in production?"**
A: Currently using in-memory users for demo. In production, I would:
- Add PostgreSQL/MongoDB
- Use bcrypt for password hashing
- Implement user management endpoints
- Add token refresh mechanism

**Q: "What if deployment fails?"**
A: Jenkins pipeline:
1. Detects failure (health check returns error)
2. Stops deployment
3. Keeps old version running
4. Sends notification
5. Can manually rollback to previous image tag

**Q: "How do you prevent DDoS attacks?"**
A: Multiple layers:
1. Rate limiting at application level (express-rate-limit)
2. Firewall rules (UFW)
3. Nginx reverse proxy with rate limiting
4. CDN/WAF (Cloudflare) in front

---

## 🎬 CONCLUSION

### Summary Points:
1. **Secure by Design**: JWT + RBAC + Input Validation
2. **Automated Pipeline**: CI/CD with Jenkins
3. **Container Security**: Multi-stage builds, non-root user, Trivy scans
4. **Production-Ready**: SSH-based VM deployment
5. **Best Practices**: Code quality, testing, monitoring

### Future Enhancements:
1. Add PostgreSQL database
2. Implement refresh tokens
3. Add rate limiting at app level
4. Setup ELK for log aggregation
5. Add Prometheus metrics
6. Implement OAuth2/OpenID Connect

---

## 📞 CONTACT & RESOURCES

**Project Repository**: [Your GitHub URL]
**Documentation**: See README.md and VM_DEPLOYMENT_GUIDE.md
**Live Demo**: [If deployed to public URL]

---

**Good luck with your presentation! 🚀**
