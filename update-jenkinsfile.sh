#!/bin/bash

# Update Jenkinsfile with actual server IPs
sed -i '' "s|STAGING_VM_HOST = 'deploy@staging.example.com'|STAGING_VM_HOST = 'deploy@18.119.167.57'|g" Jenkinsfile
sed -i '' "s|PROD_VM_HOST = 'deploy@production.example.com'|PROD_VM_HOST = 'deploy@18.191.192.108'|g" Jenkinsfile

echo "✓ Jenkinsfile updated with server IPs:"
echo "  Staging:    deploy@18.119.167.57"
echo "  Production: deploy@18.191.192.108"
