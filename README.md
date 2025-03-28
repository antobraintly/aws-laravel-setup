# 🚀 AWS Laravel MVP Setup (Free Tier)  

This setup script automates the deployment of a Laravel-ready environment on AWS using the **Free Tier**.  

## 📌 Prerequisites  

Before running the script, ensure you have:  

- An **AWS account** (with CLI configured using `aws configure`)  
- **AWS CLI** installed ([Install Guide](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html))  
- **Bash shell** (for running the script)  
- **Docker** (for Laravel Sail, optional if using local development)  

## 📜 Steps to Deploy  

### **1️⃣ Clone the Repository**  
```bash
git clone https://github.com/antobraintly/aws-laravel-setup.git
cd aws-laravel-setup
```
### **2️⃣ Run the AWS Deployment Script**  
```
chmod +x setup_aws_laravel.sh
./setup_aws_laravel.sh
```
### **3️⃣ Connect to Your EC2 Instance**
```
ssh -i laravel-key.pem ec2-user@YOUR_PUBLIC_IP
```

### **4️⃣ Install Docker & Laravel Sail**
```bash
sudo yum update -y
sudo yum install docker -y
sudo service docker start
sudo usermod -aG docker ec2-user
newgrp docker
```

### **5️⃣ Clone Your Laravel Project & Start Sail**
```
git clone https://github.com/your-repo/laravel-project.git
cd laravel-project
./vendor/bin/sail up -d
```

### **6️⃣ Configure Laravel to Use RDS & S3**
```
DB_CONNECTION=mysql
DB_HOST=YOUR_RDS_ENDPOINT
DB_PORT=3306
DB_DATABASE=your_database
DB_USERNAME=admin
DB_PASSWORD=yourpassword

AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_DEFAULT_REGION=us-east-1
AWS_BUCKET=your-bucket-name
```

### **7️⃣ Access Your Laravel App**

Once Laravel is running, access it via:
```
http://YOUR_PUBLIC_IP
```

🎉 Your Laravel MVP is now live on AWS Free Tier! 🚀
