#!/bin/bash

# Function to generate a unique hash
generate_hash() {
    date +%s | sha256sum | base64 | head -c 8
}

# Function to prompt for input with a default value
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    read -p "$prompt [$default]: " input
    eval "$var_name=\"${input:-$default}\""
}

# Function to validate if AMI ID exists in the region
validate_ami_id() {
    local ami_id="$1"
    local region="$2"
    
    echo "Verifying if AMI $ami_id exists in region $region..."
    aws ec2 describe-images --image-ids "$ami_id" --region "$region" > /dev/null 2>&1
    return $?
}

# Header
echo "AWS Laravel Setup (ARM64 Free Tier)"
echo "-----------------------------------"

# Generate unique suffix
UNIQUE_SUFFIX=$(generate_hash)
echo "Generated unique suffix: $UNIQUE_SUFFIX"

# Prompt for configuration with defaults
prompt_with_default "Enter AWS region" "us-east-1" REGION
prompt_with_default "Enter key pair name" "laravel-key-$UNIQUE_SUFFIX" KEY_NAME
prompt_with_default "Enter security group base name" "laravel-sg" SECURITY_GROUP_BASE
SECURITY_GROUP="${SECURITY_GROUP_BASE}-${UNIQUE_SUFFIX}"
prompt_with_default "Enter EC2 instance type (ARM64)" "t4g.micro" INSTANCE_TYPE
prompt_with_default "Enter DB instance base name" "laravel-db" DB_INSTANCE_BASE
DB_INSTANCE_ID="${DB_INSTANCE_BASE}"
prompt_with_default "Enter DB instance class (ARM64)" "db.t4g.micro" DB_INSTANCE_CLASS
prompt_with_default "Enter DB storage (GB)" "20" DB_STORAGE
prompt_with_default "Enter DB username" "admin" DB_USERNAME

# Special handling for password (don't show default in prompt)
read -sp "Enter DB password [yourpassword]: " DB_PASSWORD
DB_PASSWORD=${DB_PASSWORD:-"yourpassword"}
echo ""

# Default ARM64 AMI (Amazon Linux 2)
AMI_ID="ami-09e67e426f25ce0d7"

# Loop until a valid AMI ID is entered
while true; do
    validate_ami_id "$AMI_ID" "$REGION"
    if [ $? -eq 0 ]; then
        echo "AMI $AMI_ID is valid."
        break
    else
        echo "ERROR: The AMI $AMI_ID does not exist in region $REGION. Please enter a valid AMI ID."
        read -p "Enter a valid AMI ID: " AMI_ID
    fi
done

# 1. Create SSH key pair
echo "Creating SSH key pair if it doesn't exist..."
if [ ! -f "$KEY_NAME.pem" ]; then
    aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text > $KEY_NAME.pem
    chmod 400 $KEY_NAME.pem
    echo "Key pair created: $KEY_NAME.pem"
else
    echo "Key pair $KEY_NAME.pem already exists, skipping creation"
fi

# 2. Create security group
echo "Creating security group '$SECURITY_GROUP'..."
SECURITY_GROUP_ID=$(aws ec2 create-security-group \
    --group-name "$SECURITY_GROUP" \
    --description "Laravel Security Group ($UNIQUE_SUFFIX)" \
    --query 'GroupId' \
    --output text)

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create security group. Please check your configuration."
    exit 1
fi
echo "Security Group Created:"
echo "  Name: $SECURITY_GROUP"
echo "  ID: $SECURITY_GROUP_ID"

# 3. Configure security group rules
echo "Configuring security group rules..."
aws ec2 authorize-security-group-ingress \
    --group-id $SECURITY_GROUP_ID \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0 \
    --output text && echo " - Added SSH access (port 22)"

aws ec2 authorize-security-group-ingress \
    --group-id $SECURITY_GROUP_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 \
    --output text && echo " - Added HTTP access (port 80)"

aws ec2 authorize-security-group-ingress \
    --group-id $SECURITY_GROUP_ID \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0 \
    --output text && echo " - Added HTTPS access (port 443)"

# 4. Launch ARM64 EC2 instance
echo "Launching $INSTANCE_TYPE (ARM64) instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --count 1 \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SECURITY_GROUP_ID" \
    --query 'Instances[0].InstanceId' \
    --output text)

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to launch EC2 instance. Please check your configuration."
    exit 1
fi
echo "Instance launched successfully. Instance ID: $INSTANCE_ID"

# 5. Wait for instance to be running (checking manually)
echo "The instance is initializing. This might take several minutes."
echo "To check the instance status, use the following command:"
echo "  aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].State.Name' --output text --region $REGION"
echo "Once the instance is 'running', you can get its public IP with:"
echo "  aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text --region $REGION"

# 6. Create ARM64 RDS instance
echo "Creating ARM64 RDS instance '$DB_INSTANCE_ID' (this may take several minutes)..."
DB_ENDPOINT=$(aws rds create-db-instance \
    --db-instance-identifier "$DB_INSTANCE_ID" \
    --db-instance-class "$DB_INSTANCE_CLASS" \
    --engine mysql \
    --allocated-storage "$DB_STORAGE" \
    --master-username "$DB_USERNAME" \
    --master-user-password "$DB_PASSWORD" \
    --no-multi-az \
    --backup-retention-period 0 \
    --publicly-accessible \
    --engine-version "8.0" \
    --query 'DBInstance.Endpoint.Address' \
    --output text \
    --region "$REGION")

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create RDS database. Please check the parameters."
    exit 1
fi
echo "ARM64 MySQL RDS created successfully."
echo "You can check its status with:"
echo "  aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --query 'DBInstances[0].DBInstanceStatus' --output text --region $REGION"

# 7. Create S3 bucket (free for first 5GB)
BUCKET_NAME="laravel-app-storage-$(date +%s)"
echo "Creating S3 bucket '$BUCKET_NAME'..."
aws s3 mb "s3://$BUCKET_NAME" --region "$REGION"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create S3 bucket. Please check the parameters."
    exit 1
fi
echo "S3 bucket created: $BUCKET_NAME"

# Summary
echo ""
echo "Laravel setup completed successfully on AWS Free Tier with ARM64!"
echo "-----------------------------------------------"
echo "EC2 Instance:"
echo "  URL: http://$PUBLIC_IP"
echo "  SSH Key: $KEY_NAME.pem"
echo "  Security Group: $SECURITY_GROUP (ID: $SECURITY_GROUP_ID)"
echo ""
echo "Database:"
echo "  Endpoint: $DB_ENDPOINT"
echo "  Username: $DB_USERNAME"
echo "  Password: [hidden]"
echo ""
echo "Storage:"
echo "  S3 Bucket: $BUCKET_NAME"
echo ""
echo "Region: $REGION"
echo "Unique Suffix: $UNIQUE_SUFFIX"
echo ""
echo "Note: RDS may take 5-10 minutes to become available"
echo "Important: Save this information and secure your credentials!"
