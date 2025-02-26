#!/bin/bash

# Update and install Apache
dnf update -y
dnf install httpd -y

# Get IMDSv2 token
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`

# Get metadata using the token
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)
AVAILABILITY_ZONE=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)

# Create index.html with instance details
cat > /var/www/html/index.html <<EOF
<html>
<head>
    <title>EC2 Instance Details</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .info { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
    </style>
</head>
<body>
    <h1>Hello from EC2 Instance!</h1>
    <div class="info">
        <h2>Instance Details:</h2>
        <p><strong>Instance ID:</strong> $INSTANCE_ID</p>
        <p><strong>Private IP:</strong> $PRIVATE_IP</p>
        <p><strong>Availability Zone:</strong> $AVAILABILITY_ZONE</p>
        <p><strong>Timestamp:</strong> $(date)</p>
    </div>
</body>
</html>
EOF

# Ensure Apache is running
systemctl enable httpd
systemctl start httpd