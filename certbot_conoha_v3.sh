#!/bin/bash

# certbot_conoha_v3.sh
# Script to create or renew SSL certificates using certbot with ConoHa DNS challenge

# Check if we have the correct number of arguments
if [ $# -ne 3 ]; then
  echo "Usage: $0 <create|renew> <domain_name> <email_address>"
  echo "Example: $0 create example.com webmaster@example.com"
  exit 1
fi

ACTION=$1
DOMAIN=$2
EMAIL=$3

# Validate first argument
if [ "$ACTION" != "create" ] && [ "$ACTION" != "renew" ]; then
  echo "Error: First argument must be 'create' or 'renew'"
  echo "Usage: $0 <create|renew> <domain_name> <email_address>"
  exit 1
fi

# Basic validation for domain (check if it contains at least one dot)
if [[ ! "$DOMAIN" =~ \. ]]; then
  echo "Error: Domain name appears to be invalid: $DOMAIN"
  exit 1
fi

# Basic validation for email (check if it contains @ and at least one dot)
if [[ ! "$EMAIL" =~ @.*\. ]]; then
  echo "Error: Email address appears to be invalid: $EMAIL"
  exit 1
fi

# Check if required hook scripts exist
if [ ! -f "./create-auth-record.sh" ]; then
  echo "Error: create-auth-record.sh not found in current directory"
  exit 1
fi

if [ ! -f "./delete-auth-record.sh" ]; then
  echo "Error: delete-auth-record.sh not found in current directory"
  exit 1
fi

# Make sure hook scripts are executable
chmod +x ./create-auth-record.sh
chmod +x ./delete-auth-record.sh

echo "Starting $ACTION operation for domain: $DOMAIN"
echo "Email: $EMAIL"

if [ "$ACTION" = "create" ]; then
  echo "Creating new certificate for *.$DOMAIN"
  certbot certonly --manual \
    -d "*.$DOMAIN" \
    -d "$DOMAIN" \
    -m "$EMAIL" \
    --agree-tos \
    --manual-public-ip-logging-ok \
    --preferred-challenges dns-01 \
    --server https://acme-v02.api.letsencrypt.org/directory \
    --manual-auth-hook ./create-auth-record.sh \
    --manual-cleanup-hook ./delete-auth-record.sh
elif [ "$ACTION" = "renew" ]; then
  echo "Renewing certificates"
  certbot renew --manual \
    -m "$EMAIL" \
    --agree-tos \
    --manual-public-ip-logging-ok \
    --preferred-challenges dns-01 \
    --server https://acme-v02.api.letsencrypt.org/directory \
    --manual-auth-hook ./create-auth-record.sh \
    --manual-cleanup-hook ./delete-auth-record.sh
fi

# Check the exit status of certbot
if [ $? -eq 0 ]; then
  echo "Certificate $ACTION completed successfully!"
else
  echo "Certificate $ACTION failed!"
  exit 1
fi
