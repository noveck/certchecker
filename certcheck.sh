#!/bin/bash

# ANSI color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
BLUE='\033[0;34m'

# Column widths
COL1=40  # Domain
COL2=15  # Expiry Date
COL3=8   # Days
COL4=12  # Status
COL5=35  # CA Name

# Arrays to store grouped output
valid_entries=()
warning_entries=()
expired_entries=()
error_entries=()

# Function to extract domain from URL
get_domain() {
    local url=$1
    domain=${url#http://}
    domain=${domain#https://}
    domain=${domain%%/*}
    echo "$domain"
}

# Function to truncate string
truncate() {
    local str=$1
    local max=$2
    if [ ${#str} -gt $((max-2)) ]; then
        echo "${str:0:$((max-3))}..."
    else
        printf "%-${max}s" "$str"
    fi
}

# Function to get colored status
get_status() {
    local days=$1
    if [ "$days" = "N/A" ]; then
        echo "Error"
        return
    fi
    
    if [ $days -lt 0 ]; then
        echo "EXPIRED"
    elif [ $days -lt 30 ]; then
        echo "WARNING"
    else
        echo "Valid"
    fi
}

# Function to check SSL certificate
check_ssl() {
    local domain=$1
    local current_date=$(date +%s)
    
    cert_info=$(perl -e 'alarm 10; exec @ARGV' "openssl" "s_client" "-connect" "${domain}:443" "-servername" "${domain}" 2>/dev/null </dev/null | openssl x509 -noout -dates -issuer 2>/dev/null)
    
    if [ ! -z "$cert_info" ]; then
        end_date=$(echo "$cert_info" | grep "notAfter" | cut -d'=' -f2)
        issuer_full=$(echo "$cert_info" | grep "issuer" | cut -d'=' -f2-)
        
        if [[ $issuer_full =~ "O = "(.*?)[,/] ]]; then
            ca_name="${BASH_REMATCH[1]}"
        elif [[ $issuer_full =~ "O="(.*?)[,/] ]]; then
            ca_name="${BASH_REMATCH[1]}"
        else
            ca_name=$(echo "$issuer_full" | awk -F'[,/]' '{for(i=1;i<=NF;i++) if($i~/O=/) print $i}' | head -1 | sed 's/.*O=\s*//g')
        fi
        
        ca_name=$(echo "$ca_name" | sed 's/\"//g' | sed 's/^ *//g' | sed 's/ *$//g')
        
        if [ ! -z "$end_date" ]; then
            formatted_date=$(echo "$end_date" | sed 's/GMT//')
            end_epoch=$(date -j -f "%b %e %H:%M:%S %Y " "$formatted_date" +%s 2>/dev/null)
            
            if [ $? -eq 0 ] && [ ! -z "$end_epoch" ]; then
                seconds_remaining=$((end_epoch - current_date))
                days_remaining=$((seconds_remaining / 86400))
                expiry_formatted=$(date -j -f "%b %e %H:%M:%S %Y " "$formatted_date" "+%Y-%m-%d" 2>/dev/null)
                
                domain_trunc=$(truncate "$domain" $COL1)
                ca_name_trunc=$(truncate "$ca_name" $COL5)
                status=$(get_status "$days_remaining")
                
                # Format the days_remaining with leading spaces for alignment
                days_formatted=$(printf "%-${COL3}s" "$days_remaining")
                
                entry=$(printf "%-${COL1}s  %-${COL2}s  %-${COL3}s  %-${COL4}s  %-${COL5}s\n" \
                    "$domain_trunc" \
                    "$expiry_formatted" \
                    "$days_formatted" \
                    "$status" \
                    "$ca_name_trunc")
                
                case "$status" in
                    "Valid")
                        valid_entries+=("$entry")
                        ;;
                    "WARNING")
                        warning_entries+=("$entry")
                        ;;
                    "EXPIRED")
                        expired_entries+=("$entry")
                        ;;
                esac
            else
                status="Error"
                entry=$(printf "%-${COL1}s  %-${COL2}s  %-${COL3}s  %-${COL4}s  %-${COL5}s\n" \
                    "$domain" "Error" "N/A" "$status" "N/A")
                error_entries+=("$entry")
            fi
        else
            status="Error"
            entry=$(printf "%-${COL1}s  %-${COL2}s  %-${COL3}s  %-${COL4}s  %-${COL5}s\n" \
                "$domain" "Error" "N/A" "$status" "N/A")
            error_entries+=("$entry")
        fi
    else
        status="Error"
        entry=$(printf "%-${COL1}s  %-${COL2}s  %-${COL3}s  %-${COL4}s  %-${COL5}s\n" \
            "$domain" "Error" "N/A" "$status" "N/A")
        error_entries+=("$entry")
    fi
}

# Print status message
echo "Script is running..."

# Print header
printf "\n%bSSL Certificate Status Report%b\n\n" "${BLUE}" "${NC}"

# Process URLs
if [ $# -ne 1 ]; then
    echo "Usage: $0 urls.txt"
    exit 1
fi

while IFS= read -r url || [ -n "$url" ]; do
    [[ -z "$url" || "$url" =~ ^[[:space:]]*# ]] && continue
    domain=$(get_domain "$url")
    echo "Checking SSL for domain: $domain"
    check_ssl "$domain" 2>/dev/null
done < "$1"

# Print header
printf "%-${COL1}s  %-${COL2}s  %-${COL3}s  %-${COL4}s  %-${COL5}s\n" \
    "Domain" "Expiry" "Days" "Status" "Certificate Authority"

# Print header separator
printf "%$(($COL1+$COL2+$COL3+$COL4+$COL5+10))s\n" | tr " " "-"

# Print grouped entries
printf "\n%bValid Certificates:%b\n" "${GREEN}" "${NC}"
for entry in "${valid_entries[@]}"; do
    printf "%s\n" "$entry"
done

printf "\n%bWarning Certificates:%b\n" "${YELLOW}" "${NC}"
for entry in "${warning_entries[@]}"; do
    printf "%s\n" "$entry"
done

printf "\n%bExpired Certificates:%b\n" "${RED}" "${NC}"
for entry in "${expired_entries[@]}"; do
    printf "%s\n" "$entry"
done

printf "\n%bError Certificates:%b\n" "${NC}" "${NC}"
for entry in "${error_entries[@]}"; do
    printf "%s\n" "$entry"
done

# Print color key
printf "\nColor Key:\n"
printf "%bValid%b - More than 30 days until expiration\n" "${GREEN}" "${NC}"
printf "%bWARNING%b - Less than 30 days until expiration\n" "${YELLOW}" "${NC}"
printf "%bEXPIRED%b - Certificate has expired\n\n" "${RED}" "${NC}"

# Print completion message
echo "Script has completed."
