#!/bin/bash

# File containing the list of sites
SITE_FILE="sites.txt"
# File to record sites with expired SSL certificates
EXPIRED_SSL_FILE="expired_ssl_sites.txt"

# Clear the expired SSL file
> "$EXPIRED_SSL_FILE"

# Loop through each site in the file
while IFS= read -r site
do
    # Skip empty lines
    if [ -z "$site" ]; then
        continue
    fi

    # Check if site starts with http:// or https://, if not add https://
    if [[ ! "$site" =~ ^http:// && ! "$site" =~ ^https:// ]]; then
        site="https://$site"
    fi

    # Check the site using curl
    HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" "$site")

    if [ "$HTTP_STATUS" -eq 200 ]; then
        echo "$site is up."
    else
        echo "$site is down---****-ALART*******----. (HTTP Status: $HTTP_STATUS)"
        continue
    fi

    # Extract domain from URL
    DOMAIN=$(echo "$site" | awk -F[/:] '{print $4}')

    # Check SSL certificate expiration
    EXPIRY_DATE=$(echo | openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" 2>/dev/null | openssl x509 -noout -dates | grep 'notAfter=' | sed 's/notAfter=//')
    
    # Check if we got a valid expiry date
    if [ -z "$EXPIRY_DATE" ]; then
        echo "Could not retrieve SSL certificate for $site."
        echo "$site" >> "$EXPIRED_SSL_FILE"
        continue
    fi

    EXPIRY_TIMESTAMP=$(date -d "$EXPIRY_DATE" +%s)
    CURRENT_TIMESTAMP=$(date +%s)
    DAYS_LEFT=$(( (EXPIRY_TIMESTAMP - CURRENT_TIMESTAMP) / 86400 ))

    if [ $DAYS_LEFT -lt 0 ]; then
        echo "SSL certificate for $site has expired and ***************alart*************."
        echo "$site" >> "$EXPIRED_SSL_FILE"
    else
        echo "SSL certificate for $site is valid and expires in $DAYS_LEFT days."
    fi

done < "$SITE_FILE"

