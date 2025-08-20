#!/bin/bash

# conoha-ctl.sh
# ConoHa API control functions for DNS record management
# Provides functions to interact with ConoHa DNS service API

set -euo pipefail # Exit on error, undefined variables, and pipe failures

# Change to script directory
cd "$(dirname "$0")"

# Load configuration variables
if [[ -f "vars" ]]; then
  source vars
else
  echo "Error: vars configuration file not found" >&2
  echo "Please create 'vars' file with your ConoHa API credentials" >&2
  exit 1
fi

# Validate required configuration variables
readonly REQUIRED_VARS=("OS_USERNAME" "OS_PASSWORD" "OS_TENANT_ID")
for var in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "Error: Required variable $var is not set in vars file" >&2
    exit 1
  fi
done

# ConoHa API endpoints
readonly IDENTITY_ENDPOINT="https://identity.c3j1.conoha.io/v3/auth/tokens"
readonly DNS_ENDPOINT="https://dns-service.c3j1.conoha.io/v1"

# Function to get authentication token from ConoHa Identity API
# Returns: Authentication token string
function get_token() {
  local token_response
  local token

  echo "Authenticating with ConoHa API..." >&2

  # Make authentication request
  token_response=$(curl -sSf -i -X POST \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -d '{
            "auth": {
                "identity": {
                    "methods": ["password"],
                    "password": {
                        "user": {
                            "id": "'"$OS_USERNAME"'",
                            "password": "'"$OS_PASSWORD"'"
                        }
                    }
                },
                "scope": {
                    "project": {
                        "id": "'"$OS_TENANT_ID"'"
                    }
                }
            }
        }' \
    "$IDENTITY_ENDPOINT" 2>/dev/null) || {
    echo "Error: Failed to authenticate with ConoHa API" >&2
    return 1
  }

  # Extract token from x-subject-token header
  token=$(echo "$token_response" | grep -i "x-subject-token:" | awk '{gsub(/\r$/,"",$2); print $2}')

  if [[ -z "$token" ]]; then
    echo "Error: Could not extract authentication token from response" >&2
    return 1
  fi

  echo "Authentication successful" >&2
  echo "$token"
}

# Function to get domain ID by domain name
# Uses: TOKEN, DOMAIN_WITH_TRAILINGDOT (global variables)
# Returns: Domain UUID
function get_domain_id() {
  if [[ -z "${TOKEN:-}" ]]; then
    echo "Error: TOKEN variable not set" >&2
    return 1
  fi

  if [[ -z "${DOMAIN_WITH_TRAILINGDOT:-}" ]]; then
    echo "Error: DOMAIN_WITH_TRAILINGDOT variable not set" >&2
    return 1
  fi

  local domain_response
  local domain_id

  echo "Fetching domain information..." >&2

  domain_response=$(curl -sSf -X GET \
    -H "Accept: application/json" \
    -H "X-Auth-Token: $TOKEN" \
    "$DNS_ENDPOINT/domains" 2>/dev/null) || {
    echo "Error: Failed to fetch domains from ConoHa DNS API" >&2
    return 1
  }

  # Extract domain UUID using jq
  domain_id=$(echo "$domain_response" | jq -r --arg domain "$DOMAIN_WITH_TRAILINGDOT" \
    '.domains[] | select(.name == $domain) | .uuid' 2>/dev/null || echo "")

  if [[ -z "$domain_id" || "$domain_id" == "null" ]]; then
    echo "Error: Domain '$DOMAIN_WITH_TRAILINGDOT' not found" >&2
    echo "Available domains:" >&2
    echo "$domain_response" | jq -r '.domains[]?.name // "No domains found"' >&2
    return 1
  fi

  echo "$domain_id"
}

# Function to get DNS record ID by record name
# Uses: TOKEN, DOMAIN_ID, RECORD_NAME_WITH_TRAILINGDOT (global variables)
# Returns: Record UUID
function get_record_id() {
  if [[ -z "${TOKEN:-}" || -z "${DOMAIN_ID:-}" || -z "${RECORD_NAME_WITH_TRAILINGDOT:-}" ]]; then
    echo "Error: Required variables not set (TOKEN, DOMAIN_ID, RECORD_NAME_WITH_TRAILINGDOT)" >&2
    return 1
  fi

  local record_response
  local record_id

  record_response=$(curl -sSf -X GET \
    -H "Accept: application/json" \
    -H "X-Auth-Token: $TOKEN" \
    "$DNS_ENDPOINT/domains/$DOMAIN_ID/records" 2>/dev/null) || {
    echo "Error: Failed to fetch DNS records" >&2
    return 1
  }

  record_id=$(echo "$record_response" | jq -r --arg name "$RECORD_NAME_WITH_TRAILINGDOT" \
    '.records[] | select(.name == $name) | .uuid' 2>/dev/null || echo "")

  echo "$record_id"
}

# Function to update existing DNS record
# Uses: TOKEN, DOMAIN_ID, RECORD_ID, RECORD_NAME_WITH_TRAILINGDOT, TYPE, DATA (global variables)
# Returns: API response JSON
function update_record() {
  if [[ -z "${TOKEN:-}" || -z "${DOMAIN_ID:-}" || -z "${RECORD_ID:-}" ||
    -z "${RECORD_NAME_WITH_TRAILINGDOT:-}" || -z "${TYPE:-}" || -z "${DATA:-}" ]]; then
    echo "Error: Required variables not set for update_record" >&2
    return 1
  fi

  curl -sSf -X PUT \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -H "X-Auth-Token: $TOKEN" \
    -d '{
            "name": "'"$RECORD_NAME_WITH_TRAILINGDOT"'",
            "type": "'"$TYPE"'",
            "data": "'"$DATA"'"
        }' \
    "$DNS_ENDPOINT/domains/$DOMAIN_ID/records/$RECORD_ID" || {
    echo "Error: Failed to update DNS record" >&2
    return 1
  }
}

# Function to delete DNS record
# Uses: TOKEN, DOMAIN_ID, RECORD_ID (global variables)
# Returns: HTTP status code
function delete_record() {
  if [[ -z "${TOKEN:-}" || -z "${DOMAIN_ID:-}" || -z "${RECORD_ID:-}" ]]; then
    echo "Error: Required variables not set for delete_record" >&2
    return 1
  fi

  curl -sSf -X DELETE \
    -H "Accept: application/json" \
    -H "X-Auth-Token: $TOKEN" \
    "$DNS_ENDPOINT/domains/$DOMAIN_ID/records/$RECORD_ID" || {
    echo "Error: Failed to delete DNS record" >&2
    return 1
  }
}

# Function to create new DNS record
# Uses: TOKEN, DOMAIN_ID, RECORD_NAME_WITH_TRAILINGDOT, TYPE, DATA (global variables)
# Returns: API response JSON
function create_record() {
  if [[ -z "${TOKEN:-}" || -z "${DOMAIN_ID:-}" ||
    -z "${RECORD_NAME_WITH_TRAILINGDOT:-}" || -z "${TYPE:-}" || -z "${DATA:-}" ]]; then
    echo "Error: Required variables not set for create_record" >&2
    return 1
  fi

  curl -sSf -X POST \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -H "X-Auth-Token: $TOKEN" \
    -d '{
            "name": "'"$RECORD_NAME_WITH_TRAILINGDOT"'",
            "type": "'"$TYPE"'",
            "data": "'"$DATA"'"
        }' \
    "$DNS_ENDPOINT/domains/$DOMAIN_ID/records" || {
    echo "Error: Failed to create DNS record" >&2
    return 1
  }
}

# Initialize authentication token
echo "Initializing ConoHa API connection..." >&2
TOKEN=$(get_token)

if [[ -z "$TOKEN" ]]; then
  echo "Error: Failed to obtain authentication token" >&2
  exit 1
fi

echo "ConoHa API initialized successfully" >&2
