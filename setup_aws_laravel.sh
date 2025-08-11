#!/bin/bash

# AWS Laravel Free Tier Setup Script
# This script creates EC2, RDS, S3, and Security Group for Laravel application
# Optimized to stay within AWS Free Tier limits

set -e  # Exit on any error

# Configuration Variables
REGION="us-east-1"
KEY_NAME="laravel-key-$(date +%s)"
SECURITY_GROUP="laravel-sg-$(date +%s)"
INSTANCE_TYPE="t2.micro"  # Free tier eligible (750 hours/month)
AMI_ID="ami-0c02fb55956c7d316"  # Amazon Linux 2023 (free tier eligible)
DB_INSTANCE_ID="laravel-db-$(date +%s)"
DB_USERNAME="admin"
DB_PASSWORD="LaravelSecurePass123!"  # Change this in production
DB_NAME="laravel_app"
BUCKET_NAME="laravel-app-storage-$(date +%s)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if AWS CLI is configured
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI is not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_status "AWS CLI is configured and ready."
}

# Function to create IAM role for EC2 to access S3
create_iam_role() {
    print_status "Creating IAM role for EC2 to access S3..."
    
    # Create IAM role
    aws iam create-role \
        --role-name LaravelEC2S3Role \
        --assume-role-policy-document '{
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {
                        "Service": "ec2.amazonaws.com"
                    },
                    "Action": "sts:AssumeRole"
                }
            ]
        }' || print_warning "IAM role may already exist"
    
    # Attach S3 read/write policy
    aws iam attach-role-policy \
        --role-name LaravelEC2S3Role \
        --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess || print_warning "Policy attachment failed"
    
    # Create instance profile
    aws iam create-instance-profile \
        --instance-profile-name LaravelEC2S3Profile || print_warning "Instance profile may already exist"
    
    aws iam add-role-to-instance-profile \
        --instance-profile-name LaravelEC2S3Profile \
        --role-name LaravelEC2S3Role || print_warning "Role addition to profile failed"
    
    print_status "IAM role created successfully."
}

# Function to create key pair
create_key_pair() {
    print_status "Creating EC2 key pair..."
    
    if aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text > $KEY_NAME.pem 2>/dev/null; then
        chmod 400 $KEY_NAME.pem
        print_status "Key pair created: $KEY_NAME.pem"
    else
        print_warning "Key pair may already exist, using existing one."
    fi
}

# Function to create security group
create_security_group() {
    print_status "Creating security group..."
    
    SECURITY_GROUP_ID=$(aws ec2 create-security-group \
        --group-name $SECURITY_GROUP \
        --description "Security group for Laravel application" \
        --query 'GroupId' --output text 2>/dev/null || \
        aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=$SECURITY_GROUP" \
        --query 'SecurityGroups[0].GroupId' --output text)
    
    # Allow SSH (port 22) - restrict to your IP in production
    aws ec2 authorize-security-group-ingress \
        --group-id $SECURITY_GROUP_ID \
        --protocol tcp --port 22 --cidr 0.0.0.0/0 2>/dev/null || true
    
    # Allow HTTP (port 80)
    aws ec2 authorize-security-group-ingress \
        --group-id $SECURITY_GROUP_ID \
        --protocol tcp --port 80 --cidr 0.0.0.0/0 2>/dev/null || true
    
    # Allow HTTPS (port 443)
    aws ec2 authorize-security-group-ingress \
        --group-id $SECURITY_GROUP_ID \
        --protocol tcp --port 443 --cidr 0.0.0.0/0 2>/dev/null || true
    
    # Allow MySQL from EC2 to RDS (port 3306) - only within security group
    aws ec2 authorize-security-group-ingress \
        --group-id $SECURITY_GROUP_ID \
        --protocol tcp --port 3306 --source-group $SECURITY_GROUP_ID 2>/dev/null || true
    
    print_status "Security group created: $SECURITY_GROUP_ID"
}

# Function to create RDS instance
create_rds_instance() {
    print_status "Creating RDS MySQL instance (free tier eligible)..."
    
    # Create RDS subnet group (required for RDS)
    aws rds create-db-subnet-group \
        --db-subnet-group-name laravel-subnet-group \
        --db-subnet-group-description "Subnet group for Laravel RDS" \
        --subnet-ids $(aws ec2 describe-subnets --query 'Subnets[0:2].SubnetId' --output text) 2>/dev/null || \
        print_warning "Subnet group may already exist"
    
    # Create RDS instance
    RDS_ENDPOINT=$(aws rds create-db-instance \
        --db-instance-identifier $DB_INSTANCE_ID \
        --db-instance-class db.t3.micro \
        --engine mysql \
        --engine-version 8.0.35 \
        --allocated-storage 20 \
        --storage-type gp2 \
        --master-username $DB_USERNAME \
        --master-user-password $DB_PASSWORD \
        --db-name $DB_NAME \
        --vpc-security-group-ids $SECURITY_GROUP_ID \
        --db-subnet-group-name laravel-subnet-group \
        --no-multi-az \
        --backup-retention-period 0 \
        --no-publicly-accessible \
        --storage-encrypted \
        --query 'DBInstance.Endpoint.Address' --output text 2>/dev/null || \
        aws rds describe-db-instances \
        --db-instance-identifier $DB_INSTANCE_ID \
        --query 'DBInstances[0].Endpoint.Address' --output text)
    
    print_status "RDS instance created: $RDS_ENDPOINT"
}

# Function to create S3 bucket
create_s3_bucket() {
    print_status "Creating S3 bucket..."
    
    aws s3 mb s3://$BUCKET_NAME --region $REGION 2>/dev/null || \
        print_warning "S3 bucket may already exist"
    
    # Configure bucket for website hosting (optional)
    aws s3 website s3://$BUCKET_NAME --index-document index.html --error-document error.html 2>/dev/null || true
    
    print_status "S3 bucket created: $BUCKET_NAME"
}

# Function to launch EC2 instance
launch_ec2_instance() {
    print_status "Launching EC2 instance..."
    
    # Wait for IAM role to propagate
    sleep 10
    
    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id $AMI_ID \
        --count 1 \
        --instance-type $INSTANCE_TYPE \
        --key-name $KEY_NAME \
        --security-group-ids $SECURITY_GROUP_ID \
        --iam-instance-profile Name=LaravelEC2S3Profile \
        --user-data '#!/bin/bash
yum update -y
yum install -y httpd php php-mysqlnd php-json php-mbstring php-xml php-curl php-zip unzip git
systemctl start httpd
systemctl enable httpd
usermod -a -G apache ec2-user
chown -R ec2-user:apache /var/www
chmod 2775 /var/www
find /var/www -type d -exec chmod 2775 {} \;
find /var/www -type f -exec chmod 0664 {} \;
echo "<?php phpinfo(); ?>" > /var/www/html/info.php' \
        --query 'Instances[0].InstanceId' --output text)
    
    print_status "EC2 instance launched: $INSTANCE_ID"
    
    # Wait for instance to be running
    print_status "Waiting for instance to be running..."
    aws ec2 wait instance-running --instance-ids $INSTANCE_ID
    
    # Get public IP
    PUBLIC_IP=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
    
    print_status "EC2 instance is running at: http://$PUBLIC_IP"
}

# Function to create configuration file
create_config_file() {
    print_status "Creating configuration file..."
    
    cat > laravel-aws-config.txt << EOF
# AWS Laravel Configuration
# Generated on: $(date)

## EC2 Instance
Instance ID: $INSTANCE_ID
Public IP: $PUBLIC_IP
SSH Command: ssh -i $KEY_NAME.pem ec2-user@$PUBLIC_IP

## RDS Database
Endpoint: $RDS_ENDPOINT
Database: $DB_NAME
Username: $DB_USERNAME
Password: $DB_PASSWORD

## S3 Bucket
Bucket Name: $BUCKET_NAME
Region: $REGION

## Security Group
Security Group ID: $SECURITY_GROUP_ID
Security Group Name: $SECURITY_GROUP

## Laravel Environment Variables (.env)
DB_CONNECTION=mysql
DB_HOST=$RDS_ENDPOINT
DB_PORT=3306
DB_DATABASE=$DB_NAME
DB_USERNAME=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD

AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_DEFAULT_REGION=$REGION
AWS_BUCKET=$BUCKET_NAME
AWS_USE_PATH_STYLE_ENDPOINT=false

## Next Steps:
1. SSH into your EC2 instance: ssh -i $KEY_NAME.pem ec2-user@$PUBLIC_IP
2. Install Composer: curl -sS https://getcomposer.org/installer | php && mv composer.phar /usr/local/bin/composer
3. Create Laravel project: composer create-project laravel/laravel /var/www/html/laravel
4. Configure Laravel .env file with the database and S3 settings above
5. Set proper permissions: chown -R apache:apache /var/www/html/laravel
6. Configure Apache virtual host to point to /var/www/html/laravel/public

## Free Tier Limits:
- EC2: 750 hours/month (t2.micro)
- RDS: 750 hours/month (db.t3.micro)
- S3: 5GB storage, 20,000 GET requests, 2,000 PUT requests
- Data Transfer: 15GB outbound

## Security Notes:
- Change default passwords
- Restrict SSH access to your IP address
- Enable HTTPS with SSL certificate
- Regularly update your instance
EOF

    print_status "Configuration saved to: laravel-aws-config.txt"
}

# Main execution
main() {
    print_status "Starting AWS Laravel Free Tier Setup..."
    
    check_aws_cli
    create_iam_role
    create_key_pair
    create_security_group
    create_rds_instance
    create_s3_bucket
    launch_ec2_instance
    create_config_file
    
    print_status "Setup complete! 🎉"
    print_status "Your Laravel application infrastructure is ready."
    print_status "Check laravel-aws-config.txt for connection details."
    print_warning "Remember to stay within AWS Free Tier limits!"
}

# Run main function
main "$@"
