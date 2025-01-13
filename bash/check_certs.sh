#!/bin/bash
# Script to check the expiration date of an SSL certificate.
# Works with both normal HTTPS servers as well as SMTP/IMAP.
# Designed to work with Nagios.

get_cert_expiry(){
    expiration_epoch=$(date -d "$expiration_date" +%s)
    echo "$expiration_epoch"
}

calculate_remaining_seconds(){
    expiration_epoch="$1"
    current_epoch=$(date +%s)
    remaining_seconds=$((expiration_epoch - current_epoch))
    echo $remaining_seconds
}

domain_name="$1"
port_number="$2"

# check if the domain name or port number is null.
if [ -z "$domain_name" ] || [ -z "$port_number" ]
then
    echo "You must enter a domain name and a port number. Example: check_cert.sh mail.domain.com 993"
    exit 3 
fi

expiration_date=$(openssl s_client -servername "$1" -connect "$1:$2" </dev/null 2>/dev/null | openssl x509 -enddate -noout | cut -d= -f 2)

expiration_epoch=$(get_cert_expiry "$domain_name")
remaining_seconds=$(calculate_remaining_seconds "$expiration_epoch")

if [ "$remaining_seconds" -lt 604800 ]
then
    echo "1 week remaining on server certificate! CHECK NOW!"
    exit 1
elif [ "$remaining_seconds" -lt 2419200 ]
then
    echo "4 weeks remaining on server certificate. Check status."
    exit 2
else
    echo "Certificate Expiration Date: $expiration_date"
    exit 0
fi
