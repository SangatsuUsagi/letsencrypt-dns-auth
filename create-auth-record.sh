#!/bin/bash

# create-auth-record.sh
# Script to create DNS TXT record for Let's Encrypt DNS challenge using ConoHa V3 API
# Called by certbot during the authentication phase

set -euo pipefail # Exit on error, undefined variables, and pipe failures

# Change to script directory for relative path resolution
cd "$(dirname "$0")"

# Source the ConoHa control functions
if [[ -f "conoha-ctl.sh" ]]; then
  source conoha-ctl.sh
else
  echo "Error: conoha-ctl.sh not found in $(pwd)" >&2
  exit 1
fi

# Validate required environment variables from certbot
if [[ -z ${CERTBOT_DOMAIN:-} ]]; then
  echo "Error: CERTBOT_DOMAIN environment variable is not set" >&2
  exit 1
fi

if [[ -z ${CERTBOT_VALIDATION:-} ]]; then
  echo "Error: CERTBOT_VALIDATION environment variable is not set" >&2
  exit 1
fi

# Prepare domain and record names with trailing dots (required by ConoHa API)
readonly DOMAIN_WITH_TRAILINGDOT="${CERTBOT_DOMAIN}."
readonly RECORD_NAME_WITH_TRAILINGDOT="_acme-challenge.${DOMAIN_WITH_TRAILINGDOT}"

echo "Creating DNS TXT record for Let's Encrypt challenge"
echo "Domain: ${CERTBOT_DOMAIN}"
echo "Record: _acme-challenge.${CERTBOT_DOMAIN}"
echo "Validation: ${CERTBOT_VALIDATION}"

# Get domain ID from ConoHa DNS
echo "Retrieving domain ID..."
DOMAIN_ID=$(get_domain_id)

if [[ -z $DOMAIN_ID || $DOMAIN_ID == "null" ]]; then
  echo "Error: Domain '${CERTBOT_DOMAIN}' not found in ConoHa DNS" >&2
  echo "Please ensure the domain is registered in your ConoHa DNS service" >&2
  exit 1
fi

echo "Domain ID: $DOMAIN_ID"

# Set record parameters
readonly TYPE="TXT"
readonly DATA="$CERTBOT_VALIDATION"

# Create the DNS TXT record
echo "Creating TXT record..."
RECORD_RESPONSE=$(create_record)
RECORD_CREATION_STATUS=$?

if [[ $RECORD_CREATION_STATUS -ne 0 ]]; then
  echo "Error: Failed to create DNS TXT record" >&2
  exit 1
fi

# Extract record ID from response for cleanup
RECORD_ID=$(echo "$RECORD_RESPONSE" | jq -r '.uuid // .id // empty' 2>/dev/null || echo "")

if [[ -n $RECORD_ID && $RECORD_ID != "null" ]]; then
  # Save record ID for cleanup script
  echo "$RECORD_ID" >"/tmp/certbot-conoha-record-${CERTBOT_DOMAIN//[^a-zA-Z0-9]/-}"
  echo "Record created successfully with ID: $RECORD_ID"
else
  echo "Warning: Could not extract record ID from response" >&2
  echo "Response: $RECORD_RESPONSE" >&2
fi

# Wait for DNS propagation
echo "Waiting for DNS propagation (60 seconds)..."
sleep 60

echo "DNS TXT record creation completed successfully"
