# ⚡ Quick Start Checklist

## Phase 1: Local Development ✅

```bash
# 1. Clone and install
git clone <repo-url> && cd rbac-ssd
npm install

# 2. Setup environment
cp .env.example .env
echo "JWT_SECRET=$(openssl rand -base64 32)" >> .env

# 3. Start server
npm run dev

# 4. Test
curl http://localhost:3000/health
```

- [ ] Server runs on port 3000
- [ ] Health check returns OK
- [ ] Can login with admin/Admin@123

---

## Phase 2: Docker Setup 🐳

```bash
# 1. Build
docker build -t secure-api-gateway:latest .

# 2. Run
docker run -d --name gateway -p 3000:3000 \
  -e JWT_SECRET="$(openssl rand -base64 32)" \
  -e NODE_ENV=production \
  secure-api-gateway:latest

# 3. Verify
docker ps && curl http://localhost:3000/health
```

- [ ] Image builds successfully
- [ ] Container runs
- [ ] Health check passes

---

## Phase 3: Keys & Credentials 🔑

### Generate JWT Secrets
```bash
# Staging
openssl rand -base64 32 > staging-jwt.txt

# Production  
openssl rand -base64 32 > production-jwt.txt
```

### Generate SSH Keys
```bash
ssh-keygen -t ed25519 -C "jenkins-deploy" -f ~/.ssh/jenkins_deploy
```

### Docker Registry (Choose one)

**GitHub Container Registry:**
1. GitHub → Settings → Developer settings → Personal access tokens
2. Generate token with `write:packages` scope
3. Save token securely

**Docker Hub:**
1. hub.docker.com → Account Settings → Security
2. Create access token
3. Save token securely

- [ ] JWT secrets generated
- [ ] SSH keys created
- [ ] Registry credentials ready

---

## Phase 4: VM Setup 🖥️

### For EACH VM (staging + production):

```bash
# 1. Copy setup script
scp deploy/scripts/setup-vm.sh user@vm-ip:~

# 2. SSH and run
ssh user@vm-ip
chmod +x setup-vm.sh
./setup-vm.sh

# 3. Save JWT secret shown by script
sudo cat /etc/gateway/jwt-secret

# 4. Setup SSH access
exit
ssh-copy-id -i ~/.ssh/jenkins_deploy.pub deploy@vm-ip

# 5. Test
ssh -i ~/.ssh/jenkins_deploy deploy@vm-ip 'docker ps'
```

- [ ] Staging VM setup complete
- [ ] Production VM setup complete
- [ ] SSH access configured
- [ ] JWT secrets saved

---

## Phase 5: Jenkins Setup 🔄

### Install Jenkins
```bash
# Docker method
docker run -d --name jenkins -p 8080:8080 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts
```

### Add Credentials
Go to: Manage Jenkins → Credentials → Add

1. **docker-registry-url** (Secret text)
   - Value: `ghcr.io/your-username`

2. **docker-registry-creds** (Username/Password)
   - Username: Your registry username
   - Password: Your token

3. **vm-ssh-key** (SSH Username with private key)
   - Username: `deploy`
   - Private Key: Content of `~/.ssh/jenkins_deploy`

### Update Jenkinsfile
```groovy
STAGING_VM_HOST = 'deploy@your-staging-ip'
PROD_VM_HOST = 'deploy@your-production-ip'
```

### Create Pipeline Job
1. New Item → Pipeline
2. Pipeline from SCM → Git
3. Repository URL: your-repo
4. Script Path: Jenkinsfile

- [ ] Jenkins installed
- [ ] Credentials added
- [ ] Jenkinsfile updated
- [ ] Pipeline job created

---

## Phase 6: First Deployment 🚀

```bash
# 1. Commit changes
git add .
git commit -m "Setup complete"
git push

# 2. Trigger build in Jenkins
# Click "Build Now"

# 3. Monitor pipeline
# Watch console output

# 4. Approve production
# Click "Approve" when prompted
```

- [ ] Build succeeds
- [ ] Deploys to staging
- [ ] Staging tests pass
- [ ] Production approved
- [ ] Deploys to production
- [ ] Production verified

---

## Verification Commands 🧪

```bash
# Local
curl http://localhost:3000/health

# Staging
ssh deploy@staging-ip 'curl http://localhost:3000/health'

# Production
ssh deploy@production-ip 'curl http://localhost:3000/health'

# Full test
TOKEN=$(curl -s -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Admin@123"}' | jq -r '.token')

curl http://localhost:3000/api/admin \
  -H "Authorization: Bearer $TOKEN"
```

---

## Troubleshooting 🔧

| Problem | Solution |
|---------|----------|
| Port in use | `lsof -i :3000` then `kill -9 <PID>` |
| Module not found | `rm -rf node_modules && npm install` |
| SSH fails | `chmod 600 ~/.ssh/jenkins_deploy` |
| Docker fails | `docker system prune -a` |
| JWT invalid | Generate new: `openssl rand -base64 32` |

---

## Quick Commands Reference

```bash
# Development
npm run dev              # Start with auto-reload
npm test                 # Run tests
npm run lint             # Check code

# Docker
docker ps                # List containers
docker logs gateway      # View logs
docker restart gateway   # Restart

# VM
ssh deploy@vm-ip         # Connect
docker ps                # Check containers
docker logs gateway      # View logs
```

**📖 For detailed instructions, see [SETUP_GUIDE.md](./SETUP_GUIDE.md)**
