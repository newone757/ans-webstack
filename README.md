# Web Stack Deployment Extension (for ans-hard)

This extends the existing `ans-hard` VPS hardening project with a complete web stack deployment featuring Docker, Traefik, and Nginx with flexible header configuration for flexibilty.

## 🚀 Features

- **Modular Installation**: Optionally install Docker, Docker Compose, Traefik, and Nginx
- **Header Control**: Configure server headers for stealth, security, or transparency
- **SSL/TLS Support**: Automated Let's Encrypt certificate management via Traefik
- **Rate Limiting**: Built-in DDoS protection and request throttling
- **Monitoring**: Comprehensive logging and health checks
- **Security**: Integration with your existing UFW firewall and hardening
- **Service Management**: Systemd integration for automatic startup and management

## 📁 Project Structure

```
ans-hard/
├── vps-setup.yml              # Your existing hardening playbook
├── web-stack.yml              # New web stack deployment playbook
├── deploy-web-stack.sh        # Deployment automation script
├── inventory.ini              # Updated with web stack variables
├── group_vars/
│   └── all/
│       ├── vault.yml          # Extended with web stack secrets
│       └── vars.yml           # New web stack configuration
└── templates/
    ├── docker-compose.yml.j2  # Main docker compose configuration
    ├── traefik.yml.j2         # Traefik static configuration
    ├── traefik-dynamic.yml.j2 # Traefik dynamic configuration
    ├── nginx.conf.j2          # Nginx main configuration
    ├── default.conf.j2        # Nginx site configuration
    ├── index.html.j2          # Sample website
    └── web-stack.service.j2   # Systemd service template
```

## 🔧 Installation & Setup

### Prerequisites

Ensure your existing `ans-hard` setup is working:
```bash
# Test your existing hardening setup
ansible all -i inventory.ini -m ping --ask-vault-pass
```

### 1. Update Your Inventory

Add the `webservers` group to your `inventory.ini`:
```ini
[webservers]
vps1 ansible_host=192.168.1.10 vault_root_password="{{ vault_root_passwords.vps1 }}"
vps2 ansible_host=192.168.1.11 vault_root_password="{{ vault_root_passwords.vps2 }}"

[webservers:vars]
install_docker=true
install_docker_compose=true
install_traefik=true
install_nginx=true
header_mode=traefik  # Options: traefik, nginx, custom
traefik_domain=your-domain.com
```

### 2. Update Your Vault File

Add web stack secrets to your existing vault:
```bash
ansible-vault edit group_vars/all/vault.yml
```

Add these sections:
```yaml
# Web Stack Secrets
vault_web_stack:
  traefik_dashboard_user: "admin"
  traefik_dashboard_password: "YourSecurePassword!"
  ssl_email: "admin@yourdomain.com"
  
  # Custom headers for stealth mode
  custom_headers:
    server_header: "Microsoft-IIS/10.0"
    powered_by: "ASP.NET"
    framework: "DotNetCore/6.0"
```

### 3. Create Templates Directory

```bash
mkdir -p templates
# Copy all the template files from the artifacts above
```

### 4. Make Deployment Script Executable

```bash
chmod +x deploy-web-stack.sh
```

## 🚀 Deployment Options

### Option 1: Interactive Deployment
```bash
./deploy-web-stack.sh
```

### Option 2: Command Line Deployment
```bash
# Deploy full stack
./deploy-web-stack.sh full

# Deploy only Docker
./deploy-web-stack.sh docker

# Deploy web services (requires Docker)
./deploy-web-stack.sh web

# Update existing deployment
./deploy-web-stack.sh update
```

### Option 3: Direct Ansible
```bash
# Full deployment
ansible-playbook -i inventory.ini web-stack.yml --ask-vault-pass

# Selective deployment
ansible-playbook -i inventory.ini web-stack.yml --ask-vault-pass \
  --extra-vars "install_docker=true install_traefik=false"
```

## 🎭 Header Configuration Modes

### 1. Traefik Mode (`header_mode=traefik`)
**Purpose**: Security-focused headers, reveals Traefik proxy
```
Server: traefik
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
Strict-Transport-Security: max-age=31536000
```

### 2. Nginx Mode (`header_mode=nginx`)
**Purpose**: Standard web server headers, reveals Nginx
```
Server: nginx/1.25.0
X-Powered-By: nginx
X-Served-By: nginx
```

### 3. Custom/Stealth Mode (`header_mode=custom`)
**Purpose**: Mimic other servers/frameworks for security through obscurity
```
Server: Microsoft-IIS/10.0
X-Powered-By: ASP.NET
X-Framework: DotNetCore/6.0
X-AspNet-Version: 4.0.30319
```

Configure custom headers in your vault or via the interactive script.

## 🔒 Security Features

### Rate Limiting
```yaml
security:
  rate_limiting:
    enabled: true
    requests_per_second: 100
    burst: 200
```

### IP Filtering
```yaml
security:
  ip_whitelist:
    - "192.168.1.0/24"
    - "10.0.0.0/8"
  ip_blacklist:
    - "203.0.113.0/24"
```

### SSL/TLS Configuration
```yaml
# In inventory.ini or vars
traefik_enable_ssl=true
ssl_config:
  provider: "letsencrypt"
  staging: false  # Set to true for testing
  key_type: "EC256"
```

## 📊 Monitoring & Management

### Service Status
```bash
# Check all services
./deploy-web-stack.sh status

# Manual check
sudo systemctl status web-stack
docker-compose -f /opt/web-stack/docker-compose.yml ps
```

### Logs
```bash
# Traefik logs
docker logs traefik

# Nginx logs  
docker logs nginx

# System service logs
journalctl -u web-stack -f
```

### Health Endpoints
- `http://your-domain/health` - Basic health check
- `http://your-domain/status` - Server status with configured headers
- `http://your-domain/api/` - API endpoint test
- `http://your-domain:8080` - Traefik dashboard (if enabled)

## 🔧 Configuration Examples

### Example 1: Public Website with SSL
```yaml
# In inventory.ini [webservers:vars]
traefik_enable_ssl=true
traefik_domain=mysite.com
header_mode=traefik
configure_firewall=true
```

### Example 2: Internal Development
```yaml
traefik_enable_ssl=false
traefik_domain=dev.local
header_mode=nginx
traefik_admin_port=8080
```

### Example 3: Stealth/Security Testing
```yaml
header_mode=custom
custom_server_header=Apache/2.4.41
custom_powered_by=PHP/8.1.0
custom_framework=Laravel/9.0
security.rate_limiting.enabled=true
```

## 🛠️ Troubleshooting

### Common Issues

#### 1. Docker Installation Fails
```bash
# Check if user is in docker group
ansible webservers -i inventory.ini -m shell -a "groups $USER" --ask-vault-pass

# Manually add user to docker group
ansible webservers -i inventory.ini -m user -a "name={{ vault_admin_username }} groups=docker append=yes" --become --ask-vault-pass
```

#### 2. Services Not Starting
```bash
# Check logs
docker-compose -f /opt/web-stack/docker-compose.yml logs

# Check systemd service
journalctl -u web-stack --no-pager
```

#### 3. Port Conflicts
```bash
# Check what's using ports
ss -tlnp | grep -E ':(80|443|8080)'

# Modify ports in inventory.ini
traefik_http_port=8000
traefik_https_port=8443
traefik_admin_port=9080
```

#### 4. SSL Certificate Issues
```bash
# Check certificate status
docker exec traefik cat /acme/acme.json

# Use staging for testing
ssl_config.staging=true
```

### Firewall Configuration
The playbook automatically configures UFW, but verify:
```bash
# Check UFW status
sudo ufw status numbered

# Manual firewall rules if needed
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8080/tcp
```

## 🔄 Integration with Existing Hardening

This web stack deployment integrates seamlessly with your existing `ans-hard` hardening:

### Combined Deployment
```bash
# First run your existing hardening
ansible-playbook -i inventory.ini vps-setup.yml --ask-vault-pass

# Then deploy the web stack
ansible-playbook -i inventory.ini web-stack.yml --ask-vault-pass
```

### Shared Configuration
- Uses the same admin user created by hardening
- Integrates with existing UFW firewall
- Respects SSH port and security settings
- Uses the same vault file structure

## 📈 Performance Tuning

### Docker Optimization
```yaml
# In group_vars/all/vars.yml
docker_daemon_options:
  log-driver: "json-file"
  log-opts:
    max-size: "10m"
    max-file: "3"
```

### Nginx Optimization
```nginx
# The nginx.conf.j2 template includes:
worker_processes auto;
worker_connections 1024;
sendfile on;
tcp_nopush on;
gzip on;
```

### Traefik Optimization
```yaml
# Built-in optimizations:
- Connection pooling
- HTTP/2 support
- Automatic service discovery
- Health checks
```

## 🔐 Security Considerations

### Best Practices Implemented
1. **Non-root containers**: All services run as non-root users
2. **Network isolation**: Separate networks for internal and external traffic  
3. **Minimal permissions**: Services have only required permissions
4. **Regular updates**: Automated security updates via your existing hardening
5. **Log monitoring**: Comprehensive logging for security analysis

### Additional Hardening
```yaml
# Disable unused features
web_stack_config:
  traefik:
    enable_api: false
    enable_dashboard: false

# Enable additional security headers
header_configurations:
  traefik:
    custom_headers:
      Content-Security-Policy: "default-src 'self'"
      Permissions-Policy: "geolocation=(), microphone=(), camera=()"
```

## 📚 Advanced Usage

### Custom Docker Compose Services
Add additional services to the docker-compose template:
```yaml
# Add to docker-compose.yml.j2
  database:
    image: postgres:15-alpine
    environment:
      POSTGRES_PASSWORD: "{{ vault_database.postgresql_password }}"
    networks:
      - {{ network_config.internal_network }}
```

### Multi-Domain Setup
```yaml
# Configure multiple domains
vault_domains:
  primary: "site1.com"
  secondary: "site2.com"
  staging: "staging.site1.com"
```

### Backup Integration
```yaml
# Backup configuration
vault_backup:
  s3_bucket: "my-backup-bucket"
  schedule: "0 2 * * *"  # Daily at 2 AM
```

## 🤝 Contributing

This extends your existing `ans-hard` project. Follow the same contribution guidelines:

1. Test changes on non-production servers
2. Use `--check` mode first
3. Document any new variables in the vault template
4. Maintain compatibility with existing hardening

## 📄 License

Follows the same license as your `ans-hard` project.

## 🆘 Support

For issues specific to the web stack deployment:
1. Check the troubleshooting section above
2. Review logs using the provided commands
3. Test with minimal configuration first
4. Verify integration with existing hardening setup

Remember: This builds upon your solid VPS hardening foundation to provide a production-ready web hosting platform with flexible header management for security testing and operational needs.
