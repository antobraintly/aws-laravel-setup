#!/bin/bash

# AWS Laravel Cleanup Script
# This script removes all resources created by setup_aws_laravel.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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
        print_error "AWS CLI is not installed."
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI is not configured. Please run 'aws configure' first."
        exit 1
    fi
}

# Function to find and terminate EC2 instances
cleanup_ec2() {
    print_status "Cleaning up EC2 instances..."
    
    # Find instances with Laravel key pairs
    INSTANCES=$(aws ec2 describe-instances \
        --filters "Name=key-name,Values=laravel-key-*" \
        --query 'Reservations[].Instances[?State.Name!=`terminated`].InstanceId' \
        --output text 2>/dev/null || echo "")
    
    if [ ! -z "$INSTANCES" ]; then
        for INSTANCE_ID in $INSTANCES; do
            print_status "Terminating EC2 instance: $INSTANCE_ID"
            aws ec2 terminate-instances --instance-ids $INSTANCE_ID
        done
        
        # Wait for instances to terminate
        if [ ! -z "$INSTANCES" ]; then
            print_status "Waiting for instances to terminate..."
            aws ec2 wait instance-terminated --instance-ids $INSTANCES
        fi
    else
        print_warning "No running EC2 instances found."
    fi
}

# Function to find and delete RDS instances
cleanup_rds() {
    print_status "Cleaning up RDS instances..."
    
    # Find RDS instances with Laravel naming
    RDS_INSTANCES=$(aws rds describe-db-instances \
        --query 'DBInstances[?contains(DBInstanceIdentifier, `laravel-db`) && DBInstanceStatus!=`deleted`].DBInstanceIdentifier' \
        --output text 2>/dev/null || echo "")
    
    if [ ! -z "$RDS_INSTANCES" ]; then
        for DB_ID in $RDS_INSTANCES; do
            print_status "Deleting RDS instance: $DB_ID"
            aws rds delete-db-instance \
                --db-instance-identifier $DB_ID \
                --skip-final-snapshot \
                --delete-automated-backups
        done
    else
        print_warning "No RDS instances found."
    fi
    
    # Clean up subnet groups
    SUBNET_GROUPS=$(aws rds describe-db-subnet-groups \
        --query 'DBSubnetGroups[?contains(DBSubnetGroupName, `laravel`)].DBSubnetGroupName' \
        --output text 2>/dev/null || echo "")
    
    if [ ! -z "$SUBNET_GROUPS" ]; then
        for SUBNET_GROUP in $SUBNET_GROUPS; do
            print_status "Deleting RDS subnet group: $SUBNET_GROUP"
            aws rds delete-db-subnet-group --db-subnet-group-name $SUBNET_GROUP 2>/dev/null || true
        done
    fi
}

# Function to find and delete S3 buckets
cleanup_s3() {
    print_status "Cleaning up S3 buckets..."
    
    # Find S3 buckets with Laravel naming
    BUCKETS=$(aws s3 ls | grep laravel-app-storage | awk '{print $3}' 2>/dev/null || echo "")
    
    if [ ! -z "$BUCKETS" ]; then
        for BUCKET in $BUCKETS; do
            print_status "Deleting S3 bucket: $BUCKET"
            aws s3 rb s3://$BUCKET --force
        done
    else
        print_warning "No S3 buckets found."
    fi
}

# Function to find and delete security groups
cleanup_security_groups() {
    print_status "Cleaning up security groups..."
    
    # Find security groups with Laravel naming
    SECURITY_GROUPS=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=laravel-sg-*" \
        --query 'SecurityGroups[].GroupId' \
        --output text 2>/dev/null || echo "")
    
    if [ ! -z "$SECURITY_GROUPS" ]; then
        for SG_ID in $SECURITY_GROUPS; do
            print_status "Deleting security group: $SG_ID"
            aws ec2 delete-security-group --group-id $SG_ID 2>/dev/null || true
        done
    else
        print_warning "No security groups found."
    fi
}

# Function to find and delete key pairs
cleanup_key_pairs() {
    print_status "Cleaning up key pairs..."
    
    # Find key pairs with Laravel naming
    KEY_PAIRS=$(aws ec2 describe-key-pairs \
        --query 'KeyPairs[?contains(KeyName, `laravel-key`)].KeyName' \
        --output text 2>/dev/null || echo "")
    
    if [ ! -z "$KEY_PAIRS" ]; then
        for KEY_NAME in $KEY_PAIRS; do
            print_status "Deleting key pair: $KEY_NAME"
            aws ec2 delete-key-pair --key-name $KEY_NAME
        done
    else
        print_warning "No key pairs found."
    fi
    
    # Remove local key files
    if ls laravel-key-*.pem 1> /dev/null 2>&1; then
        print_status "Removing local key files..."
        rm -f laravel-key-*.pem
    fi
}

# Function to cleanup IAM resources
cleanup_iam() {
    print_status "Cleaning up IAM resources..."
    
    # Remove role from instance profile
    aws iam remove-role-from-instance-profile \
        --instance-profile-name LaravelEC2S3Profile \
        --role-name LaravelEC2S3Role 2>/dev/null || true
    
    # Delete instance profile
    aws iam delete-instance-profile \
        --instance-profile-name LaravelEC2S3Profile 2>/dev/null || true
    
    # Detach policies from role
    aws iam detach-role-policy \
        --role-name LaravelEC2S3Role \
        --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess 2>/dev/null || true
    
    # Delete role
    aws iam delete-role --role-name LaravelEC2S3Role 2>/dev/null || true
    
    print_warning "IAM resources cleaned up (if they existed)."
}

# Function to remove local files
cleanup_local_files() {
    print_status "Cleaning up local files..."
    
    if [ -f "laravel-aws-config.txt" ]; then
        rm -f laravel-aws-config.txt
        print_status "Removed laravel-aws-config.txt"
    fi
    
    if [ -f "setup.log" ]; then
        rm -f setup.log
        print_status "Removed setup.log"
    fi
}

# Function to show cost estimate
show_cost_info() {
    print_status "Cost Information:"
    echo "  • EC2 t2.micro: ~$8.47/month if running 24/7"
    echo "  • RDS db.t3.micro: ~$12.41/month if running 24/7"
    echo "  • S3: ~$0.023/GB/month (5GB free tier)"
    echo "  • Data Transfer: 15GB free tier, then $0.09/GB"
    echo ""
    print_warning "Remember to stop/terminate resources when not in use!"
}

# Main cleanup function
main() {
    print_status "Starting AWS Laravel cleanup..."
    
    check_aws_cli
    
    # Confirm before proceeding
    echo ""
    print_warning "This will delete ALL Laravel-related AWS resources!"
    echo "This action cannot be undone."
    echo ""
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Cleanup cancelled."
        exit 0
    fi
    
    cleanup_ec2
    cleanup_rds
    cleanup_s3
    cleanup_security_groups
    cleanup_key_pairs
    cleanup_iam
    cleanup_local_files
    
    print_status "Cleanup complete! 🎉"
    echo ""
    show_cost_info
    print_status "All Laravel AWS resources have been removed."
}

# Run main function
main "$@"
