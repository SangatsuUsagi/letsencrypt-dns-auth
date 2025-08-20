#!/bin/bash

# delete-auth-record.sh
# Script to delete DNS TXT record after Let's Encrypt DNS challenge completion
# Called by certbot during the cleanup phase

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
if [[ -z "${CERTBOT_DOMAIN:-}" ]]; then
  echo "Error: CERTBOT_DOMAIN environment variable is not set" >&2
  exit 1
fi

# Prepare domain and record names with trailing dots (required by ConoHa API)
readonly DOMAIN_WITH_TRAILINGDOT="${CERTBOT_DOMAIN}."
readonly RECORD_NAME_WITH_TRAILINGDOT="_acme-challenge.${DOMAIN_WITH_TRAILINGDOT}"

# Sanitize domain name for filename (replace non-alphanumeric characters with dashes)
readonly SAFE_DOMAIN_NAME="${CERTBOT_DOMAIN//[^a-zA-Z0-9]/-}"
readonly RECORD_ID_FILE="/tmp/certbot-conoha-record-${SAFE_DOMAIN_NAME}"

echo "Cleaning up DNS TXT record for Let's Encrypt challenge"
echo "Domain: ${CERTBOT_DOMAIN}"
echo "Record: _acme-challenge.${CERTBOT_DOMAIN}"

# Get domain ID from ConoHa DNS
echo "Retrieving domain ID..."
DOMAIN_ID=$(get_domain_id)

if [[ -z "$DOMAIN_ID" || "$DOMAIN_ID" == "null" ]]; then
  echo "Error: Domain '${CERTBOT_DOMAIN}' not found in ConoHa DNS" >&2
  exit 1
fi

echo "Domain ID: $DOMAIN_ID"

# Try to get record ID from saved file first
RECORD_ID=""
if [[ -f "$RECORD_ID_FILE" ]]; then
  RECORD_ID=$(cat "$RECORD_ID_FILE" 2>/dev/null || echo "")
  echo "Found saved record ID: $RECORD_ID"
fi

# If no saved record ID, try to find it by name
if [[ -z "$RECORD_ID" ]]; then
  echo "No saved record ID found, searching for record by name..."
  RECORD_ID=$(get_record_id)

  if [[ -z "$RECORD_ID" || "$RECORD_ID" == "null" ]]; then
    echo "Warning: DNS TXT record not found for cleanup" >&2
    echo "The record may have already been deleted or may not exist" >&2
    # Clean up the temporary file if it exists
    rm -f "$RECORD_ID_FILE"
    exit 0
  fi

  echo "Found record ID: $RECORD_ID"
fi

# Delete the DNS TXT record
echo "Deleting DNS TXT record with ID: $RECORD_ID"
DELETE_RESPONSE=$(delete_record)
DELETE_STATUS=$?

if [[ $DELETE_STATUS -eq 0 ]]; then
  echo "DNS TXT record deleted successfully"
else
  echo "Warning: Failed to delete DNS TXT record" >&2
  echo "Response: $DELETE_RESPONSE" >&2
fi

# Clean up the temporary record ID file
if [[ -f "$RECORD_ID_FILE" ]]; then
  rm -f "$RECORD_ID_FILE"
  echo "Cleaned up temporary record ID file"
fi

echo "DNS TXT record cleanup completed"
