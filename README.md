# Let's Encrypt DNS Authentication for ConoHa VPS (V3 API)

## Overview
Scripts to obtain and renew wildcard Let's Encrypt certificates using DNS authentication on ConoHa VPS. This project is forked from [smitch/letsencrypt-dns-auth](https://github.com/smitch/letsencrypt-dns-auth), which originally supported ConoHa V2 API. This version has been updated to support the newer ConoHa V3 API and drops V2 API support.

## Installation
No specific installation process is required. Simply place the scripts in a directory on your server.

## Dependencies
- certbot
- bash
- curl
- jq
- ConoHa VPS account
- Your own domain configured with ConoHa DNS

## Usage

### Configuration
1. Rename `vars.sample` to `vars`
2. Set your username, password, and tenant ID in the `vars` file

### Getting a Certificate
Use the provided convenience script:
```bash
./certbot_conoha_v3.sh create example.com webmaster@example.com
```

Or run certbot directly:
```bash
certbot certonly --manual -d "*.example.com" -m "webmaster@example.com" --agree-tos --manual-public-ip-logging-ok --preferred-challenges dns-01 --server https://acme-v02.api.letsencrypt.org/directory --manual-auth-hook /path/to/create-auth-record.sh --manual-cleanup-hook /path/to/delete-auth-record.sh
```

### Renewing Certificates
Use the provided convenience script:
```bash
./certbot_conoha_v3.sh renew example.com webmaster@example.com
```

Or run certbot directly:
```bash
certbot renew --manual -m "webmaster@example.com" --agree-tos --manual-public-ip-logging-ok --preferred-challenges dns-01 --server https://acme-v02.api.letsencrypt.org/directory --manual-auth-hook /path/to/create-auth-record.sh --manual-cleanup-hook /path/to/delete-auth-record.sh --post-hook "systemctl restart httpd"
```

**Note:** Adding the `--quiet` option is recommended when setting up cron jobs for automatic renewal.

### Cron Job Example
For automatic certificate renewal, add a cron job like this:
```bash
0 2 * * * /path/to/certbot_conoha_v3.sh renew example.com webmaster@example.com --quiet
```

## References
- [ConoHa API Tokens Guide](https://www.conoha.jp/guide/apitokens.php) - Username and password for ConoHa API
- [ConoHa DNS Guide](https://www.conoha.jp/guide/geodns.php) - DNS configuration for ConoHa
- [Certbot Documentation](https://certbot.eff.org/docs/using.html) - Official certbot documentation

## Changes from Original
- Updated to use ConoHa V3 API
- Dropped support for ConoHa V2 API
- Added convenience wrapper script (`certbot_conoha_v3.sh`)
- Improved error handling and validation

## License
This software is released under the MIT License.