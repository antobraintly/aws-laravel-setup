# 🚀 AWS Laravel Free Tier Setup

This automated setup script creates a complete Laravel-ready infrastructure on AWS using **Free Tier eligible services**. The script provisions EC2, RDS, S3, and Security Groups with proper connectivity and security configurations.

## ✨ Features

- **Free Tier Optimized**: Uses t2.micro EC2, db.t3.micro RDS, and minimal S3 storage
- **Secure by Default**: IAM roles, encrypted storage, restricted security groups
- **Automated Setup**: One-command deployment of complete infrastructure
- **Laravel Ready**: Pre-configured with PHP, Apache, and database connectivity
- **Cost Conscious**: Stays within AWS Free Tier limits (750 hours/month)
- **Complete Toolset**: Includes setup, monitoring, and cleanup scripts

## 📁 Available Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `setup_aws_laravel.sh` | Deploy complete Laravel infrastructure | `./setup_aws_laravel.sh` |
| `monitor_costs.sh` | Monitor AWS usage and costs | `./monitor_costs.sh` |
| `cleanup_aws_resources.sh` | Remove all AWS resources | `./cleanup_aws_resources.sh` |

## 📋 Prerequisites

Before running the script, ensure you have:

- **AWS Account** with Free Tier eligibility
- **AWS CLI** installed and configured ([Install Guide](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html))
- **Bash shell** (macOS, Linux, or WSL on Windows)
- **Git** (for cloning the repository)

### AWS CLI Configuration
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter your default region (us-east-1 recommended for free tier)
# Enter your output format (json)
```

## 🚀 Quick Start

### 1. Clone and Setup
```bash
git clone https://github.com/antobraintly/aws-laravel-setup.git
cd aws-laravel-setup
chmod +x setup_aws_laravel.sh
chmod +x cleanup_aws_resources.sh
chmod +x monitor_costs.sh
```

### 2. (Optional) Customize Configuration
```bash
cp config.env.example config.env
# Edit config.env with your preferred settings
```

### 3. Run the Deployment Script
```bash
./setup_aws_laravel.sh
```

The script will:
- ✅ Create EC2 key pair for SSH access
- ✅ Set up IAM role for EC2-S3 connectivity
- ✅ Create security group with proper rules
- ✅ Launch t2.micro EC2 instance with PHP/Apache
- ✅ Create db.t3.micro RDS MySQL instance
- ✅ Create S3 bucket for file storage
- ✅ Generate configuration file with all connection details

### 3. Access Your Infrastructure

After the script completes, you'll find a `laravel-aws-config.txt` file with all connection details:

```bash
cat laravel-aws-config.txt
```

## 🔧 Laravel Application Setup

### 1. SSH into Your EC2 Instance
```bash
ssh -i laravel-key-*.pem ec2-user@YOUR_PUBLIC_IP
```

### 2. Install Composer and Laravel
```bash
# Install Composer
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

# Create Laravel project
cd /var/www/html
sudo composer create-project laravel/laravel laravel
sudo chown -R apache:apache laravel
sudo chmod -R 775 laravel/storage laravel/bootstrap/cache
```

### 3. Configure Laravel Environment
```bash
cd laravel
sudo cp .env.example .env
sudo nano .env
```

Update the `.env` file with your AWS configuration:
```env
APP_NAME=Laravel
APP_ENV=production
APP_KEY=base64:your-key-here
APP_DEBUG=false
APP_URL=http://YOUR_PUBLIC_IP

DB_CONNECTION=mysql
DB_HOST=YOUR_RDS_ENDPOINT
DB_PORT=3306
DB_DATABASE=laravel_app
DB_USERNAME=admin
DB_PASSWORD=LaravelSecurePass123!

AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_DEFAULT_REGION=us-east-1
AWS_BUCKET=your-s3-bucket-name
AWS_USE_PATH_STYLE_ENDPOINT=false
```

### 4. Configure Apache Virtual Host
```bash
sudo nano /etc/httpd/conf.d/laravel.conf
```

Add this configuration:
```apache
<VirtualHost *:80>
    DocumentRoot /var/www/html/laravel/public
    ServerName YOUR_PUBLIC_IP
    
    <Directory /var/www/html/laravel/public>
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog logs/laravel_error.log
    CustomLog logs/laravel_access.log combined
</VirtualHost>
```

### 5. Restart Apache and Generate App Key
```bash
sudo systemctl restart httpd
cd /var/www/html/laravel
sudo php artisan key:generate
sudo php artisan migrate
```

### 6. Access Your Laravel Application
Visit `http://YOUR_PUBLIC_IP` in your browser!

## 💰 AWS Free Tier Limits & Costs

### ⚠️ **IMPORTANT: Free Tier Expires After 12 Months!**

This setup uses AWS Free Tier eligible services, but **you will be charged** after your first 12 months or if you exceed these limits:

| Service | Free Tier Limit | Monthly Cost After Free Tier | What Happens When Exceeded |
|---------|----------------|------------------------------|---------------------------|
| **EC2 t2.micro** | 750 hours/month | ~$8.47/month (24/7) | Charged per hour: ~$0.0116/hour |
| **RDS db.t3.micro** | 750 hours/month | ~$12.41/month (24/7) | Charged per hour: ~$0.017/hour |
| **S3 Storage** | 5GB | ~$0.023/GB/month | Charged per GB: $0.023/GB |
| **S3 Requests** | 20K GET, 2K PUT | ~$0.0004 per 1K requests | Charged per request |
| **Data Transfer** | 15GB outbound | ~$0.09/GB | Charged per GB: $0.09/GB |

### 🚨 **Cost Warnings:**

**Running 24/7 for 1 month after free tier:**
- **EC2 + RDS**: ~$20.88/month
- **S3**: ~$0.12/month (5GB)
- **Data Transfer**: Varies by usage
- **Total**: ~$21+ per month

**Running 24/7 for 1 year after free tier:**
- **Total**: ~$250+ per year

### 📊 **Free Tier Usage Examples:**

| Scenario | EC2 Hours | RDS Hours | Cost |
|----------|-----------|-----------|------|
| **Development (8h/day)** | 240/month | 240/month | **$0** ✅ |
| **Testing (24h/day for 1 week)** | 168/month | 168/month | **$0** ✅ |
| **Production (24/7)** | 730/month | 730/month | **$0** ✅ (within free tier) |
| **Multiple instances** | >750/month | >750/month | **$20.88+** ⚠️ |

### 💡 **Cost Monitoring & Alerts**

Monitor your AWS usage with the provided script:

```bash
./monitor_costs.sh
```

This script will show:
- ✅ Current month costs
- ✅ Resource usage and running time
- ✅ Free tier limits and warnings
- ✅ Cost optimization tips
- ✅ Quick actions for resource management

**Essential Monitoring:**
- ⚠️ **Set up AWS billing alerts** in AWS Console
- ⚠️ **Monitor usage daily** during development
- ⚠️ **Stop resources when not in use**
- ⚠️ **Clean up resources** after testing

### 🛡️ **How to Avoid Charges:**

1. **Stop resources when not developing:**
   ```bash
   aws ec2 stop-instances --instance-ids YOUR_INSTANCE_ID
   aws rds stop-db-instance --db-instance-identifier YOUR_DB_ID
   ```

2. **Clean up after testing:**
   ```bash
   ./cleanup_aws_resources.sh
   ```

3. **Set billing alerts in AWS Console:**
   - Go to AWS Billing Dashboard
   - Set up alerts at $1, $5, $10 thresholds

4. **Monitor your free tier usage:**
   - Check AWS Free Tier Dashboard regularly
   - Use `./monitor_costs.sh` weekly

### 📅 **Free Tier Timeline:**
- **Month 1-12**: Everything is FREE (within limits)
- **Month 13+**: You start paying for resources
- **Any time**: You pay if you exceed free tier limits

## 🔒 Security Best Practices

### Immediate Actions (Recommended)
1. **Change Default Passwords**: Update RDS and application passwords
2. **Restrict SSH Access**: Limit SSH to your IP address
3. **Enable HTTPS**: Set up SSL certificate (Let's Encrypt recommended)
4. **Regular Updates**: Keep your instance updated

### Security Group Rules
The script creates a security group with:
- **Port 22**: SSH (restrict to your IP in production)
- **Port 80**: HTTP
- **Port 443**: HTTPS
- **Port 3306**: MySQL (internal only)

## 🛠️ Troubleshooting

### Common Issues

**EC2 Instance Not Accessible**
```bash
# Check security group rules
aws ec2 describe-security-groups --group-ids YOUR_SECURITY_GROUP_ID

# Check instance status
aws ec2 describe-instances --instance-ids YOUR_INSTANCE_ID
```

**RDS Connection Issues**
```bash
# Verify RDS endpoint
aws rds describe-db-instances --db-instance-identifier YOUR_DB_ID

# Check security group allows EC2 to RDS
```

**S3 Access Issues**
```bash
# Verify IAM role attachment
aws iam get-instance-profile --instance-profile-name LaravelEC2S3Profile
```

### Useful Commands

**Stop/Start Services** (to save costs)
```bash
# Stop EC2 instance
aws ec2 stop-instances --instance-ids YOUR_INSTANCE_ID

# Start EC2 instance
aws ec2 start-instances --instance-ids YOUR_INSTANCE_ID

# Stop RDS instance
aws rds stop-db-instance --db-instance-identifier YOUR_DB_ID
```

## 🧹 Cleanup

### Automated Cleanup
Use the provided cleanup script to remove all resources:

```bash
./cleanup_aws_resources.sh
```

This script will:
- ✅ Terminate all EC2 instances
- ✅ Delete all RDS instances
- ✅ Remove all S3 buckets
- ✅ Delete security groups
- ✅ Remove key pairs
- ✅ Clean up IAM roles
- ✅ Remove local configuration files

### Manual Cleanup
If you prefer manual cleanup:

```bash
# Terminate EC2 instance
aws ec2 terminate-instances --instance-ids YOUR_INSTANCE_ID

# Delete RDS instance
aws rds delete-db-instance --db-instance-identifier YOUR_DB_ID --skip-final-snapshot

# Delete S3 bucket
aws s3 rb s3://YOUR_BUCKET_NAME --force

# Delete security group
aws ec2 delete-security-group --group-id YOUR_SECURITY_GROUP_ID

# Delete key pair
aws ec2 delete-key-pair --key-name YOUR_KEY_NAME
```

## 📚 Additional Resources

- [Laravel Documentation](https://laravel.com/docs)
- [AWS Free Tier](https://aws.amazon.com/free/)
- [AWS CLI Documentation](https://docs.aws.amazon.com/cli/)
- [Laravel on AWS Best Practices](https://aws.amazon.com/blogs/developer/laravel-on-aws/)

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

---

**Happy Coding! 🚀**

Your Laravel application is now running on AWS Free Tier infrastructure!
