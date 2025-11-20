# 🔧 Manual Setup Steps for Both Servers

Follow these commands in order. Copy and paste each block.

---

## Step 1: Copy Setup Script to Both Servers

```bash
# Copy to staging
scp -i ~/Downloads/my-ec2-key.pem deploy/scripts/setup-vm.sh ubuntu@18.119.167.57:~

# Copy to production
scp -i ~/Downloads/my-ec2-key.pem deploy/scripts/setup-vm.sh ubuntu@18.191.192.108:~
```

---

## Step 2: Run Setup on Staging Server

```bash
# SSH to staging
ssh -i ~/Downloads/my-ec2-key.pem ubuntu@18.119.167.57

# On the server, run:
chmod +x setup-vm.sh
./setup-vm.sh

# IMPORTANT: Copy the JWT secret shown at the end!
# Save it as: STAGING_JWT_SECRET

# Get the JWT secret again if needed:
sudo cat /etc/gateway/jwt-secret

# Exit
exit
```

---

## Step 3: Run Setup on Production Server

```bash
# SSH to production
ssh -i ~/Downloads/my-ec2-key.pem ubuntu@18.191.192.108

# On the server, run:
chmod +x setup-vm.sh
./setup-vm.sh

# IMPORTANT: Copy the JWT secret shown at the end!
# Save it as: PRODUCTION_JWT_SECRET

# Get the JWT secret again if needed:
sudo cat /etc/gateway/jwt-secret

# Exit
exit
```

---

## Step 4: Configure SSH Keys for Deploy User

### For Staging:

```bash
# Copy your Jenkins public key to staging
cat ~/.ssh/jenkins_deploy.pub | ssh -i ~/Downloads/my-ec2-key.pem ubuntu@18.119.167.57 \
  'sudo mkdir -p /home/deploy/.ssh && \
   sudo tee /home/deploy/.ssh/authorized_keys && \
   sudo chmod 700 /home/deploy/.ssh && \
   sudo chmod 600 /home/deploy/.ssh/authorized_keys && \
   sudo chown -R deploy:deploy /home/deploy/.ssh'
```

### For Production:

```bash
# Copy your Jenkins public key to production
cat ~/.ssh/jenkins_deploy.pub | ssh -i ~/Downloads/my-ec2-key.pem ubuntu@18.191.192.108 \
  'sudo mkdir -p /home/deploy/.ssh && \
   sudo tee /home/deploy/.ssh/authorized_keys && \
   sudo chmod 700 /home/deploy/.ssh && \
   sudo chmod 600 /home/deploy/.ssh/authorized_keys && \
   sudo chown -R deploy:deploy /home/deploy/.ssh'
```

---

## Step 5: Test SSH Access as Deploy User

```bash
# Test staging
ssh -i ~/.ssh/jenkins_deploy deploy@18.119.167.57 'docker ps'
# Should show: No containers running (that's OK!)

# Test production
ssh -i ~/.ssh/jenkins_deploy deploy@18.191.192.108 'docker ps'
# Should show: No containers running (that's OK!)
```

---

## Step 6: Update Jenkinsfile

```bash
# Run the update script
chmod +x update-jenkinsfile.sh
./update-jenkinsfile.sh
```

Or manually edit `Jenkinsfile` and change:
```groovy
STAGING_VM_HOST = 'deploy@18.119.167.57'
PROD_VM_HOST = 'deploy@18.191.192.108'
```

---

## Step 7: Save JWT Secrets

Create a file to save your secrets (delete after storing them securely):

```bash
# Get staging secret
echo "STAGING_JWT_SECRET:" > jwt-secrets.txt
ssh -i ~/Downloads/my-ec2-key.pem ubuntu@18.119.167.57 'sudo cat /etc/gateway/jwt-secret' >> jwt-secrets.txt

# Get production secret
echo "" >> jwt-secrets.txt
echo "PRODUCTION_JWT_SECRET:" >> jwt-secrets.txt
ssh -i ~/Downloads/my-ec2-key.pem ubuntu@18.191.192.108 'sudo cat /etc/gateway/jwt-secret' >> jwt-secrets.txt

# View the secrets
cat jwt-secrets.txt
```

**IMPORTANT:** Copy these secrets somewhere secure (password manager) then delete the file:
```bash
rm jwt-secrets.txt
```

---

## Step 8: Verify Everything

```bash
# Test staging access
echo "Testing staging..."
ssh -i ~/.ssh/jenkins_deploy deploy@18.119.167.57 'docker --version && docker ps'

# Test production access
echo "Testing production..."
ssh -i ~/.ssh/jenkins_deploy deploy@18.191.192.108 'docker --version && docker ps'

# Check Jenkinsfile was updated
grep "STAGING_VM_HOST\|PROD_VM_HOST" Jenkinsfile
```

---

## ✅ Success Checklist

- [ ] Setup script ran on staging
- [ ] Setup script ran on production
- [ ] JWT secrets saved securely
- [ ] SSH keys configured for deploy user on staging
- [ ] SSH keys configured for deploy user on production
- [ ] Can SSH to staging as deploy: `ssh -i ~/.ssh/jenkins_deploy deploy@18.119.167.57`
- [ ] Can SSH to production as deploy: `ssh -i ~/.ssh/jenkins_deploy deploy@18.191.192.108`
- [ ] Jenkinsfile updated with correct IPs
- [ ] Docker works on both servers

---

## Next: Commit and Push

```bash
git add Jenkinsfile
git commit -m "Update server IPs for deployment"
git push origin main
```

Now you're ready to set up Jenkins!
