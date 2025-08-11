#!/bin/bash

# AWS Cost Monitoring Script for Laravel Setup
# This script helps monitor AWS costs and usage

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_header() {
    echo -e "${BLUE}$1${NC}"
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

# Function to show current month costs
show_current_costs() {
    print_header "=== Current Month AWS Costs ==="
    
    # Get current month costs (requires Cost Explorer)
    CURRENT_COST=$(aws ce get-cost-and-usage \
        --time-period Start=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
        --granularity MONTHLY \
        --metrics BlendedCost \
        --query 'ResultsByTime[0].Total.BlendedCost.Amount' \
        --output text 2>/dev/null || echo "N/A")
    
    if [ "$CURRENT_COST" != "N/A" ]; then
        echo "Current Month Cost: $${CURRENT_COST}"
        
        # Check if over free tier
        if (( $(echo "$CURRENT_COST > 0" | bc -l) )); then
            print_warning "You have incurred costs this month!"
        else
            print_status "No costs incurred this month."
        fi
    else
        print_warning "Cost Explorer data not available. Check AWS Console."
    fi
}

# Function to show resource usage
show_resource_usage() {
    print_header "=== Resource Usage ==="
    
    # EC2 Instances
    print_status "EC2 Instances:"
    EC2_INSTANCES=$(aws ec2 describe-instances \
        --filters "Name=key-name,Values=laravel-key-*" \
        --query 'Reservations[].Instances[?State.Name!=`terminated`].[InstanceId,InstanceType,State.Name,LaunchTime]' \
        --output table 2>/dev/null || echo "No instances found")
    
    if [ "$EC2_INSTANCES" != "No instances found" ]; then
        echo "$EC2_INSTANCES"
    else
        echo "  No running EC2 instances found."
    fi
    
    echo ""
    
    # RDS Instances
    print_status "RDS Instances:"
    RDS_INSTANCES=$(aws rds describe-db-instances \
        --query 'DBInstances[?contains(DBInstanceIdentifier, `laravel-db`) && DBInstanceStatus!=`deleted`].[DBInstanceIdentifier,DBInstanceClass,DBInstanceStatus,Engine]' \
        --output table 2>/dev/null || echo "No RDS instances found")
    
    if [ "$RDS_INSTANCES" != "No RDS instances found" ]; then
        echo "$RDS_INSTANCES"
    else
        echo "  No RDS instances found."
    fi
    
    echo ""
    
    # S3 Buckets
    print_status "S3 Buckets:"
    S3_BUCKETS=$(aws s3 ls | grep laravel-app-storage 2>/dev/null || echo "No S3 buckets found")
    
    if [ "$S3_BUCKETS" != "No S3 buckets found" ]; then
        echo "$S3_BUCKETS"
        
        # Show bucket sizes
        for BUCKET in $(echo "$S3_BUCKETS" | awk '{print $3}'); do
            SIZE=$(aws s3 ls s3://$BUCKET --recursive --human-readable --summarize 2>/dev/null | tail -1 | awk '{print $3, $4}' || echo "Unknown")
            echo "  $BUCKET: $SIZE"
        done
    else
        echo "  No S3 buckets found."
    fi
}

# Function to show free tier limits
show_free_tier_limits() {
    print_header "=== AWS Free Tier Limits ==="
    
    echo "EC2 (t2.micro):"
    echo "  • 750 hours per month"
    echo "  • ~$8.47/month if running 24/7"
    echo ""
    
    echo "RDS (db.t3.micro):"
    echo "  • 750 hours per month"
    echo "  • ~$12.41/month if running 24/7"
    echo ""
    
    echo "S3:"
    echo "  • 5GB storage"
    echo "  • 20,000 GET requests"
    echo "  • 2,000 PUT requests"
    echo "  • ~$0.023/GB/month after free tier"
    echo ""
    
    echo "Data Transfer:"
    echo "  • 15GB outbound per month"
    echo "  • ~$0.09/GB after free tier"
    echo ""
    
    echo "Total potential cost if running 24/7: ~$20.88/month"
}

# Function to show cost optimization tips
show_cost_tips() {
    print_header "=== Cost Optimization Tips ==="
    
    echo "1. Stop EC2 instances when not in use:"
    echo "   aws ec2 stop-instances --instance-ids YOUR_INSTANCE_ID"
    echo ""
    
    echo "2. Stop RDS instances when not in use:"
    echo "   aws rds stop-db-instance --db-instance-identifier YOUR_DB_ID"
    echo ""
    
    echo "3. Set up billing alerts in AWS Console"
    echo ""
    
    echo "4. Use AWS Cost Explorer to monitor spending"
    echo ""
    
    echo "5. Consider using Spot Instances for development"
    echo ""
    
    echo "6. Clean up unused resources regularly:"
    echo "   ./cleanup_aws_resources.sh"
}

# Function to show running time
show_running_time() {
    print_header "=== Resource Running Time ==="
    
    # Get EC2 running time
    EC2_INSTANCES=$(aws ec2 describe-instances \
        --filters "Name=key-name,Values=laravel-key-*" "Name=instance-state-name,Values=running" \
        --query 'Reservations[].Instances[].[InstanceId,LaunchTime]' \
        --output text 2>/dev/null || echo "")
    
    if [ ! -z "$EC2_INSTANCES" ]; then
        echo "EC2 Instances:"
        while IFS=$'\t' read -r INSTANCE_ID LAUNCH_TIME; do
            if [ ! -z "$INSTANCE_ID" ]; then
                # Calculate running time
                LAUNCH_EPOCH=$(date -d "$LAUNCH_TIME" +%s)
                CURRENT_EPOCH=$(date +%s)
                RUNNING_SECONDS=$((CURRENT_EPOCH - LAUNCH_EPOCH))
                RUNNING_HOURS=$((RUNNING_SECONDS / 3600))
                RUNNING_DAYS=$((RUNNING_HOURS / 24))
                
                echo "  $INSTANCE_ID: Running for ${RUNNING_DAYS} days, ${RUNNING_HOURS} hours"
                
                # Check if approaching free tier limit
                if [ $RUNNING_HOURS -gt 700 ]; then
                    print_warning "  ⚠️  Approaching 750-hour free tier limit!"
                fi
            fi
        done <<< "$EC2_INSTANCES"
    else
        echo "No running EC2 instances found."
    fi
    
    echo ""
    
    # Get RDS running time
    RDS_INSTANCES=$(aws rds describe-db-instances \
        --query 'DBInstances[?contains(DBInstanceIdentifier, `laravel-db`) && DBInstanceStatus==`available`].[DBInstanceIdentifier,InstanceCreateTime]' \
        --output text 2>/dev/null || echo "")
    
    if [ ! -z "$RDS_INSTANCES" ]; then
        echo "RDS Instances:"
        while IFS=$'\t' read -r DB_ID CREATE_TIME; do
            if [ ! -z "$DB_ID" ]; then
                # Calculate running time
                CREATE_EPOCH=$(date -d "$CREATE_TIME" +%s)
                CURRENT_EPOCH=$(date +%s)
                RUNNING_SECONDS=$((CURRENT_EPOCH - CREATE_EPOCH))
                RUNNING_HOURS=$((RUNNING_SECONDS / 3600))
                RUNNING_DAYS=$((RUNNING_HOURS / 24))
                
                echo "  $DB_ID: Running for ${RUNNING_DAYS} days, ${RUNNING_HOURS} hours"
                
                # Check if approaching free tier limit
                if [ $RUNNING_HOURS -gt 700 ]; then
                    print_warning "  ⚠️  Approaching 750-hour free tier limit!"
                fi
            fi
        done <<< "$RDS_INSTANCES"
    else
        echo "No running RDS instances found."
    fi
}

# Function to show quick actions
show_quick_actions() {
    print_header "=== Quick Actions ==="
    
    echo "1. Stop all resources (save money):"
    echo "   aws ec2 stop-instances --instance-ids \$(aws ec2 describe-instances --filters 'Name=key-name,Values=laravel-key-*' --query 'Reservations[].Instances[?State.Name==`running`].InstanceId' --output text)"
    echo ""
    
    echo "2. Start all resources:"
    echo "   aws ec2 start-instances --instance-ids \$(aws ec2 describe-instances --filters 'Name=key-name,Values=laravel-key-*' --query 'Reservations[].Instances[?State.Name==`stopped`].InstanceId' --output text)"
    echo ""
    
    echo "3. View all resources:"
    echo "   aws ec2 describe-instances --filters 'Name=key-name,Values=laravel-key-*' --query 'Reservations[].Instances[].[InstanceId,State.Name,PublicIpAddress]' --output table"
    echo ""
    
    echo "4. Clean up everything:"
    echo "   ./cleanup_aws_resources.sh"
}

# Main function
main() {
    print_status "AWS Laravel Cost Monitor"
    echo ""
    
    check_aws_cli
    
    show_current_costs
    echo ""
    
    show_resource_usage
    echo ""
    
    show_running_time
    echo ""
    
    show_free_tier_limits
    echo ""
    
    show_cost_tips
    echo ""
    
    show_quick_actions
    echo ""
    
    print_status "Monitor complete! Check AWS Console for detailed billing information."
}

# Run main function
main "$@"
