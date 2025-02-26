# WordPress AWS Deployment Scripts

This repository contains scripts for deploying WordPress on AWS using a robust, scalable architecture with Auto Scaling Groups (ASG), Application Load Balancer (ALB), and RDS.

## Architecture Overview

The solution implements a secure, scalable WordPress deployment using:

- **VPC** with public and private subnets across multiple Availability Zones
- **RDS MySQL** database in dedicated database subnets
- **Application Load Balancer** in public subnets
- **Auto Scaling Group** of WordPress instances in private subnets
- **Bastion Host** for secure SSH access to private instances

## Scripts

### wp-launch-template-aws.sh

This script is designed for Amazon Linux 2023 and serves as user data for EC2 launch templates. It:

- Installs and configures Apache, PHP, and PHP-FPM
- Downloads and configures WordPress
- Connects WordPress to an existing RDS MySQL database
- Sets proper permissions and SELinux contexts
- Includes performance optimizations for Apache
- Performs validation checks and logs important information

#### Key Features:

- Comprehensive error checking and verification
- PHP-FPM configuration for better performance
- Security-focused setup with proper file permissions
- Support for WordPress behind a load balancer

### apache-script-sample.sh

A simplified script for basic Apache and PHP configuration on Amazon Linux. This script:

- Installs Apache and PHP
- Configures basic settings
- Can be used for development or testing environments

## Security Group Configuration

For proper deployment, configure security groups as follows:

1. **Load Balancer Security Group:**
   - Inbound: HTTP (80) from anywhere
   - Outbound: HTTP (80) to ASG security group

2. **ASG Security Group:**
   - Inbound: HTTP (80) from Load Balancer security group
   - Inbound: SSH (22) from Bastion security group
   - Outbound: MySQL (3306) to RDS security group
   - Outbound: All traffic to internet (for updates)

3. **RDS Security Group:**
   - Inbound: MySQL (3306) from ASG security group
   - Outbound: All traffic

4. **Bastion Security Group:**
   - Inbound: SSH (22) from trusted IPs
   - Outbound: All traffic

## Usage Instructions

1. Create a VPC with public, private, and database subnets
2. Launch an RDS MySQL instance in database subnets
3. Create the WordPress database: `CREATE DATABASE wordpress;`
4. Configure security groups as described above
5. Create a launch template using `wp-launch-template-aws.sh` as user data
6. Create an Application Load Balancer in public subnets
7. Create an Auto Scaling Group using the launch template in private subnets
8. Access WordPress via the ALB DNS name

## Customization

Modify the database connection details in the script:
```bash
define( 'DB_NAME', 'wordpress' );
define( 'DB_USER', 'admin' );
define( 'DB_PASSWORD', 'password' );
define( 'DB_HOST', 'your-rds-endpoint.region.rds.amazonaws.com' );
```

## License

[MIT License](LICENSE)