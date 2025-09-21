#!/bin/bash

# Update and install required packages
yum update -y
yum install -y amazon-cloudwatch-agent nginx
#!/bin/bash
yum install -y amazon-ssm-agent

# Enable and start the SSM agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

if systemctl enable amazon-ssm-agent && systemctl start amazon-ssm-agent; then
  echo "SSM Agent started successfully" >> /var/log/user-data.log
else
  echo "SSM Agent failed to start" >> /var/log/user-data.log
fi

# Enable and start nginx
systemctl enable nginx
systemctl start nginx

if systemctl status nginx | grep "active (running)"; then
  echo "Nginx started successfully" >> /var/log/user-data.log
else
  echo "Nginx failed to start" >> /var/log/user-data.log
fi

# Create a simple HTML page showing instance ID
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)

cat << EOF > /usr/share/nginx/html/index.html
<html>
  <head><title>Welcome to NGINX</title></head>
  <body>
    <h1>Welcome to NGINX on instance: $INSTANCE_ID</h1>
  </body>
</html>
EOF

# Setup CloudWatch Agent to send /var/log/messages to CloudWatch Logs
cat <<EOF > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/var/log/messages",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
EOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a start
