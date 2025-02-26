#!/bin/bash

#############################################################
# WordPress Installation Script for Amazon Linux 2023
# - This script installs and configures WordPress on Amazon Linux 2023
# - Connects to an existing RDS MySQL/Aurora database
# - Optimized for use with Auto Scaling Groups
#############################################################

# Exit on any error
set -e

#############################################################
# SYSTEM UPDATE
# - Updates all installed packages to latest versions
# - Important for security and stability
#############################################################
echo "Updating system packages..."
dnf update -y

#############################################################
# INSTALL WEB SERVER AND PHP
# - httpd: Apache web server
# - php: Core PHP language package
# - php-mysqlnd: MySQL Native Driver for PHP
# - php-fpm: PHP FastCGI Process Manager (faster than mod_php)
# - Additional PHP modules needed for WordPress
#############################################################
echo "Installing Apache, PHP, and dependencies..."
echo "Installing Apache, PHP, PHP-FPM and dependencies..."
# Make sure to explicitly install PHP-FPM and verify it's installed
dnf install -y httpd php php-fpm php-mysqlnd php-json php-gd php-mbstring php-xml php-intl
# Verify PHP-FPM was installed
if ! rpm -q php-fpm > /dev/null; then
  echo "ERROR: php-fpm package failed to install. Retrying..."
  dnf install -y php-fpm
fi

#############################################################
# START AND ENABLE SERVICES
# - Starts the services immediately
# - Enables them to start automatically on boot
#############################################################
echo "Starting and enabling Apache and PHP-FPM services..."
# Start and enable the services with explicit error checking
systemctl start php-fpm || echo "Error starting PHP-FPM, checking status..."
systemctl status php-fpm
systemctl enable php-fpm

systemctl start httpd || echo "Error starting Apache, checking status..."
systemctl status httpd
systemctl enable httpd

# Make sure PHP-FPM is configured properly with Apache
echo "Configuring Apache to use PHP-FPM..."
cat > /etc/httpd/conf.d/php-fpm.conf << EOF
<FilesMatch \.php$>
    SetHandler "proxy:fcgi://127.0.0.1:9000"
</FilesMatch>
EOF

#############################################################
# DOWNLOAD AND EXTRACT WORDPRESS
# - Downloads the latest WordPress package
# - Extracts it to web root directory
# - Cleans up temporary files
#############################################################
echo "Downloading and extracting WordPress..."
cd /var/www/html
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
mv wordpress/* .
rm -rf wordpress latest.tar.gz

#############################################################
# SET PROPER OWNERSHIP AND PERMISSIONS
# - Apache user (apache) needs ownership of web files
# - 755 permissions allow read and execute access to all
#   but write permissions only to owner
#############################################################
echo "Setting correct ownership and permissions..."
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

#############################################################
# CONFIGURE SELINUX CONTEXT
# - Sets the correct SELinux security context for web content
# - httpd_sys_content_t allows Apache to read the files
# - Only matters if SELinux is enabled (default in AL2023)
#############################################################
echo "Setting SELinux context for web files..."
chcon -R -t httpd_sys_content_t /var/www/html/

#############################################################
# CREATE WORDPRESS CONFIGURATION
# - Creates wp-config.php with database connection details
# - Adds security salts from WordPress API
# - Configures WordPress for operation behind a load balancer
# - Sets table prefix for security (default: wp_)
#############################################################
echo "Creating WordPress configuration file..."
cat > /var/www/html/wp-config.php << EOF
<?php
/**
 * WordPress Configuration File
 *
 * Database settings for RDS connection
 */

// Database connection settings
define( 'DB_NAME', 'wordpress' );
define( 'DB_USER', 'admin' );
define( 'DB_PASSWORD', 'password' );
define( 'DB_HOST', 'mywpinstance.cvmc84moy7kl.us-east-1.rds.amazonaws.com' );
define( 'DB_CHARSET', 'utf8' );
define( 'DB_COLLATE', '' );

// Security salts - randomly generated for enhanced security
$(wget -qO- https://api.wordpress.org/secret-key/1.1/salt/)

// Table prefix - for security and multiple WordPress installations
\$table_prefix = 'wp_';

// Load balancer configuration
// Allows WordPress to work correctly behind AWS ELB/ALB
define('WP_HOME', 'http://' . \$_SERVER['HTTP_HOST']);
define('WP_SITEURL', 'http://' . \$_SERVER['HTTP_HOST']);

// For developers: debugging mode
define( 'WP_DEBUG', false );

/* That's all, stop editing! Happy publishing. */

// Absolute path to the WordPress directory
if ( ! defined( 'ABSPATH' ) ) {
    define( 'ABSPATH', __DIR__ . '/' );
}

// Sets up WordPress variables and included files
require_once ABSPATH . 'wp-settings.php';
EOF

#############################################################
# ENSURE CORRECT CONFIG FILE PERMISSIONS
# - Makes sure wp-config.php is owned by Apache
# - This is crucial since it contains sensitive information
#############################################################
echo "Setting correct permissions for wp-config.php..."
chown apache:apache /var/www/html/wp-config.php

#############################################################
# CONFIGURE APACHE FOR PERFORMANCE 
# - Optional: Adds server-level configuration for better performance
#############################################################
echo "Adding Apache performance configurations..."
cat > /etc/httpd/conf.d/wordpress-performance.conf << EOF
# Enable compression for text files
<IfModule mod_deflate.c>
  AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css text/javascript application/javascript application/x-javascript application/json
</IfModule>

# Enable browser caching
<IfModule mod_expires.c>
  ExpiresActive On
  ExpiresByType image/jpg "access plus 1 year"
  ExpiresByType image/jpeg "access plus 1 year"
  ExpiresByType image/gif "access plus 1 year"
  ExpiresByType image/png "access plus 1 year"
  ExpiresByType image/webp "access plus 1 year"
  ExpiresByType text/css "access plus 1 month"
  ExpiresByType application/javascript "access plus 1 month"
</IfModule>
EOF

#############################################################
# RESTART APACHE TO APPLY CHANGES
# - Ensures all configuration changes take effect
#############################################################
# Ensure PHP-FPM configuration is correct
echo "Configuring PHP-FPM..."
sed -i 's/;listen.owner = nobody/listen.owner = apache/g' /etc/php-fpm.d/www.conf
sed -i 's/;listen.group = nobody/listen.group = apache/g' /etc/php-fpm.d/www.conf
sed -i 's/user = apache/user = apache/g' /etc/php-fpm.d/www.conf
sed -i 's/group = apache/group = apache/g' /etc/php-fpm.d/www.conf

echo "Restarting PHP-FPM and Apache to apply all changes..."
systemctl restart php-fpm
systemctl restart httpd

# Verify services are running properly
echo "Verifying services status:"
systemctl status php-fpm --no-pager
systemctl status httpd --no-pager

#############################################################
# CHECK SERVICE LOGS
# - Checks Apache and PHP-FPM logs for any errors
# - Helps diagnose issues during instance startup
#############################################################
echo "Checking Apache error logs..."
if [ -f /var/log/httpd/error_log ]; then
  echo "Last 20 lines of Apache error log:"
  tail -n 20 /var/log/httpd/error_log
else
  echo "Apache error log file not found"
fi

echo "Checking PHP-FPM logs..."
if [ -f /var/log/php-fpm/error.log ]; then
  echo "Last 20 lines of PHP-FPM error log:"
  tail -n 20 /var/log/php-fpm/error.log
elif [ -f /var/log/php-fpm/www-error.log ]; then
  echo "Last 20 lines of PHP-FPM www-error log:"
  tail -n 20 /var/log/php-fpm/www-error.log
else
  echo "Looking for any PHP-FPM logs in /var/log:"
  find /var/log -name "*php*" -type f
  find /var/log -name "*fpm*" -type f
fi

# Try to make a test PHP request to verify
echo "Testing PHP processing..."
echo "<?php phpinfo(); ?>" > /var/www/html/test.php
chmod 644 /var/www/html/test.php
chown apache:apache /var/www/html/test.php
curl -s http://localhost/test.php | head -n 20
rm -f /var/www/html/test.php

#############################################################
# INSTALLATION COMPLETE
# - Prints completion message
#############################################################
echo "WordPress installation complete!"
echo "Database: wordpress"
echo "DB Host: mywpinstance.cvmc84moy7kl.us-east-1.rds.amazonaws.com"
echo "You can now access WordPress to complete the setup"