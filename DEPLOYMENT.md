# Production Deployment Guide

This guide covers deploying the Video Resume Application to production environments.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Deployment Options](#deployment-options)
3. [Server Setup](#server-setup)
4. [Database Configuration](#database-configuration)
5. [Web Server Configuration](#web-server-configuration)
6. [Security Best Practices](#security-best-practices)
7. [Monitoring and Maintenance](#monitoring-and-maintenance)

## Prerequisites

- Linux server (Ubuntu 20.04+ recommended)
- Python 3.8+
- PostgreSQL 12+ (recommended for production)
- Nginx or Apache
- SSL certificate (Let's Encrypt recommended)
- Domain name

## Deployment Options

### Option 1: Traditional VPS Deployment

**Platforms**: DigitalOcean, Linode, AWS EC2, Google Cloud, Azure

**Pros**: Full control, customizable
**Cons**: Requires manual setup and maintenance

### Option 2: Platform as a Service (PaaS)

**Platforms**: Heroku, Railway, Render, PythonAnywhere

**Pros**: Easy deployment, managed infrastructure
**Cons**: Less control, potentially higher costs

### Option 3: Containerized Deployment

**Platforms**: Docker, Kubernetes

**Pros**: Portable, scalable
**Cons**: More complex setup

---

## Server Setup

### 1. Update System

```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Install Dependencies

```bash
# Python and pip
sudo apt install python3 python3-pip python3-venv -y

# PostgreSQL
sudo apt install postgresql postgresql-contrib -y

# Nginx
sudo apt install nginx -y

# System utilities
sudo apt install git curl -y
```

### 3. Create Application User

```bash
# Create dedicated user
sudo adduser --system --group videoapp

# Switch to application user
sudo su - videoapp
```

### 4. Clone/Upload Application

```bash
cd /home/videoapp
git clone <your-repo-url> video_resume
cd video_resume

# Or upload files via SCP/SFTP
```

### 5. Set Up Virtual Environment

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
pip install gunicorn psycopg2-binary
```

---

## Database Configuration

### PostgreSQL Setup

```bash
# Switch to postgres user
sudo -u postgres psql

# Create database and user
CREATE DATABASE video_resumes;
CREATE USER videoapp_user WITH PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE video_resumes TO videoapp_user;
\q
```

### Update Configuration

Edit `config.py`:

```python
class ProductionConfig(Config):
    DEBUG = False
    SQLALCHEMY_DATABASE_URI = 'postgresql://videoapp_user:your_secure_password@localhost/video_resumes'
    SECRET_KEY = 'your-very-secure-secret-key-here'
```

Or use environment variables:

```bash
export DATABASE_URL='postgresql://videoapp_user:your_secure_password@localhost/video_resumes'
export SECRET_KEY='your-very-secure-secret-key-here'
export FLASK_ENV='production'
```

### Initialize Database

```bash
python init_db.py
```

---

## Web Server Configuration

### Gunicorn Setup

Create systemd service file: `/etc/systemd/system/videoapp.service`

```ini
[Unit]
Description=Video Resume Application
After=network.target

[Service]
User=videoapp
Group=videoapp
WorkingDirectory=/home/videoapp/video_resume
Environment="PATH=/home/videoapp/video_resume/venv/bin"
Environment="DATABASE_URL=postgresql://videoapp_user:your_secure_password@localhost/video_resumes"
Environment="SECRET_KEY=your-very-secure-secret-key-here"
ExecStart=/home/videoapp/video_resume/venv/bin/gunicorn --workers 4 --bind unix:videoapp.sock -m 007 video_resume_app:app

[Install]
WantedBy=multi-user.target
```

Start and enable service:

```bash
sudo systemctl start videoapp
sudo systemctl enable videoapp
sudo systemctl status videoapp
```

### Nginx Configuration

Create Nginx config: `/etc/nginx/sites-available/videoapp`

```nginx
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;

    # Redirect to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com www.your-domain.com;

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # Upload size limit
    client_max_body_size 100M;

    # Static files
    location /static {
        alias /home/videoapp/video_resume/static;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # Application
    location / {
        include proxy_params;
        proxy_pass http://unix:/home/videoapp/video_resume/videoapp.sock;
        
        # Timeouts for large uploads
        proxy_connect_timeout 600;
        proxy_send_timeout 600;
        proxy_read_timeout 600;
        send_timeout 600;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
}
```

Enable site and restart Nginx:

```bash
sudo ln -s /etc/nginx/sites-available/videoapp /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### SSL Certificate (Let's Encrypt)

```bash
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d your-domain.com -d www.your-domain.com
sudo systemctl reload nginx
```

---

## Security Best Practices

### 1. Environment Variables

Never commit sensitive data. Use environment variables:

```bash
# Create .env file (add to .gitignore)
echo "SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_hex(32))')" > .env
echo "DATABASE_URL=postgresql://user:pass@localhost/dbname" >> .env
```

### 2. File Permissions

```bash
# Uploads directory
sudo chown -R videoapp:videoapp /home/videoapp/video_resume/uploads
sudo chmod -R 755 /home/videoapp/video_resume/uploads

# Application files
sudo chmod -R 755 /home/videoapp/video_resume
sudo chmod 600 /home/videoapp/video_resume/.env
```

### 3. Firewall Configuration

```bash
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS
sudo ufw enable
```

### 4. Database Security

```bash
# Edit PostgreSQL config
sudo nano /etc/postgresql/12/main/pg_hba.conf

# Use md5 authentication, not trust
# Restrict to localhost only
local   all             all                                     md5
host    all             all             127.0.0.1/32            md5
```

### 5. Regular Updates

```bash
# System updates
sudo apt update && sudo apt upgrade -y

# Python dependencies
source venv/bin/activate
pip install --upgrade -r requirements.txt
```

---

## Monitoring and Maintenance

### Application Logs

```bash
# View application logs
sudo journalctl -u videoapp -f

# Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### Disk Space Monitoring

```bash
# Check disk usage
df -h

# Monitor uploads directory
du -sh /home/videoapp/video_resume/uploads
```

### Database Backup

Create backup script: `/home/videoapp/backup.sh`

```bash
#!/bin/bash
BACKUP_DIR="/home/videoapp/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup database
pg_dump video_resumes > $BACKUP_DIR/db_$DATE.sql

# Backup uploads
tar -czf $BACKUP_DIR/uploads_$DATE.tar.gz /home/videoapp/video_resume/uploads

# Keep only last 7 days
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
```

Set up cron job:

```bash
crontab -e

# Add daily backup at 2 AM
0 2 * * * /home/videoapp/backup.sh
```

### Health Check Endpoint

Add to `video_resume_app.py`:

```python
@app.route('/health')
def health_check():
    """Health check endpoint for monitoring"""
    try:
        # Check database connection
        db.session.execute('SELECT 1')
        return jsonify({'status': 'healthy', 'database': 'connected'}), 200
    except Exception as e:
        return jsonify({'status': 'unhealthy', 'error': str(e)}), 500
```

### Monitoring Tools

- **Uptime Monitoring**: UptimeRobot, Pingdom
- **Performance**: New Relic, Datadog
- **Logs**: Papertrail, Loggly
- **Errors**: Sentry

---

## Heroku Deployment (Quick PaaS Option)

### 1. Create Procfile

```
web: gunicorn video_resume_app:app
```

### 2. Create runtime.txt

```
python-3.11.0
```

### 3. Deploy

```bash
# Login to Heroku
heroku login

# Create app
heroku create your-app-name

# Add PostgreSQL addon
heroku addons:create heroku-postgresql:hobby-dev

# Set environment variables
heroku config:set SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_hex(32))')

# Deploy
git push heroku main

# Initialize database
heroku run python init_db.py

# Open application
heroku open
```

---

## Docker Deployment

### Dockerfile

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN mkdir -p uploads/videos

EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "4", "video_resume_app:app"]
```

### docker-compose.yml

```yaml
version: '3.8'

services:
  web:
    build: .
    ports:
      - "5000:5000"
    environment:
      - DATABASE_URL=postgresql://postgres:password@db:5432/video_resumes
      - SECRET_KEY=your-secret-key
    depends_on:
      - db
    volumes:
      - ./uploads:/app/uploads

  db:
    image: postgres:14
    environment:
      - POSTGRES_DB=video_resumes
      - POSTGRES_PASSWORD=password
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

### Deploy

```bash
docker-compose up -d
docker-compose exec web python init_db.py
```

---

## Troubleshooting Production Issues

### Application Won't Start

```bash
# Check service status
sudo systemctl status videoapp

# Check logs
sudo journalctl -u videoapp -n 50

# Test Gunicorn manually
cd /home/videoapp/video_resume
source venv/bin/activate
gunicorn --bind 0.0.0.0:5000 video_resume_app:app
```

### 502 Bad Gateway

```bash
# Check if app is running
sudo systemctl status videoapp

# Check socket file
ls -la /home/videoapp/video_resume/videoapp.sock

# Check Nginx error log
sudo tail -f /var/log/nginx/error.log
```

### Database Connection Error

```bash
# Test database connection
psql -U videoapp_user -d video_resumes -h localhost

# Check PostgreSQL status
sudo systemctl status postgresql
```

---

## Performance Optimization

### 1. Caching

Install Redis:

```bash
sudo apt install redis-server
```

Add to requirements.txt:

```
Flask-Caching
redis
```

### 2. CDN for Static Files

Use CloudFlare, AWS CloudFront, or similar for static assets.

### 3. Video Compression

Install FFmpeg:

```bash
sudo apt install ffmpeg

# Add video compression in video_resume_app.py
import subprocess

def compress_video(input_path, output_path):
    subprocess.run([
        'ffmpeg', '-i', input_path,
        '-vcodec', 'libx264', '-crf', '28',
        output_path
    ])
```

### 4. Database Optimization

```sql
-- Add indexes for faster queries
CREATE INDEX idx_candidates_email ON candidates(email);
CREATE INDEX idx_candidates_submission_date ON candidates(submission_date);
```

---

## Conclusion

Your Video Resume Application is now production-ready! Remember to:

- ✅ Keep system and dependencies updated
- ✅ Monitor logs regularly
- ✅ Back up database daily
- ✅ Monitor disk space
- ✅ Set up SSL/HTTPS
- ✅ Use strong passwords
- ✅ Implement rate limiting (optional)
- ✅ Set up monitoring/alerting

For questions or issues, refer to the main [README](VIDEO_RESUME_README.md).

**Good luck with your deployment! 🚀**
