#!/bin/bash

# Variables
REGION="us-east-1"
KEY_NAME="laravel-key"
SECURITY_GROUP="laravel-sg"
INSTANCE_TYPE="t4g.micro"
AMI_ID="ami-09e67e426f25ce0d7" # Amazon Linux 2 ARM (change if needed)
DB_INSTANCE_ID="laravel-db"
DB_USERNAME="admin"
DB_PASSWORD="yourpassword"

# 1. Create a Key Pair for SSH Access
aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text > $KEY_NAME.pem
chmod 400 $KEY_NAME.pem

# 2. Create a Security Group
SECURITY_GROUP_ID=$(aws ec2 create-security-group --group-name $SECURITY_GROUP --description "Laravel Security Group" --query 'GroupId' --output text)

# 3. Allow Inbound Rules
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 # SSH
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 # HTTP
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 443 --cidr 0.0.0.0/0 # HTTPS
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 3306 --cidr 0.0.0.0/0 # MySQL (Restrict in prod)

# 4. Launch EC2 Instance
INSTANCE_ID=$(aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type $INSTANCE_TYPE --key-name $KEY_NAME --security-groups $SECURITY_GROUP --query 'Instances[0].InstanceId' --output text)

# 5. Wait for Instance to be Running
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

# 6. Get Public IP
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "EC2 instance running at: http://$PUBLIC_IP"

# 7. Create RDS MySQL Instance
aws rds create-db-instance \
    --db-instance-identifier $DB_INSTANCE_ID \
    --db-instance-class db.t3.micro \
    --engine mysql \
    --allocated-storage 20 \
    --master-username $DB_USERNAME \
    --master-user-password $DB_PASSWORD \
    --no-multi-az \
    --backup-retention-period 0 \
    --publicly-accessible \
    --query 'DBInstance.Endpoint.Address' --output text

echo "RDS MySQL instance created."

# 8. Create S3 Bucket (Replace with a unique bucket name)
BUCKET_NAME="laravel-app-storage-$(date +%s)"
aws s3 mb s3://$BUCKET_NAME --region $REGION
echo "S3 Bucket created: $BUCKET_NAME"

echo "AWS Free Tier Laravel setup complete!"
