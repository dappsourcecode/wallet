#!/bin/bash

# KUCOIN BALANCE CHECKER
# Usage: ./kucoin_get.sh

echo "--- KUCOIN BALANCE CHECKER ---"

# 1. Prompt for Credentials (Input is hidden for Secret/Passphrase)
read -p "Enter API Key: " API_KEY
read -s -p "Enter API Secret: " API_SECRET
echo ""
read -s -p "Enter API Passphrase: " API_PASSPHRASE
echo ""
echo "------------------------------"

# 2. Check Dependencies
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Run 'sudo apt install jq'"
    exit 1
fi

# 3. Setup Constants
BASE_URL="https://api.kucoin.com"
ENDPOINT="/api/v1/accounts"
METHOD="GET"
TIMESTAMP=$(date +%s000)

# 4. Sign the Passphrase (HMAC-SHA256 -> Base64)
# KuCoin V2 requires the passphrase to be encrypted
PASSPHRASE_SIGN=$(echo -n "$API_PASSPHRASE" | openssl dgst -sha256 -hmac "$API_SECRET" -binary | base64)

# 5. Sign the Request (HMAC-SHA256 -> Base64)
# String to sign: timestamp + method + endpoint
STR_TO_SIGN="${TIMESTAMP}${METHOD}${ENDPOINT}"
SIGNATURE=$(echo -n "$STR_TO_SIGN" | openssl dgst -sha256 -hmac "$API_SECRET" -binary | base64)

# 6. Execute Request
# We suppress progress meter (-s) but show errors
RESPONSE=$(curl -s -X GET "${BASE_URL}${ENDPOINT}" \
     -H "KC-API-KEY: $API_KEY" \
     -H "KC-API-SIGN: $SIGNATURE" \
     -H "KC-API-TIMESTAMP: $TIMESTAMP" \
     -H "KC-API-PASSPHRASE: $PASSPHRASE_SIGN" \
     -H "KC-API-KEY-VERSION: 2" \
     -H "Content-Type: application/json")

# 7. Check for Errors and Parse
CODE=$(echo $RESPONSE | jq -r '.code')

if [ "$CODE" == "200000" ]; then
    echo "✅ Success!"
    echo "Active Balances:"
    echo "---------------------------------"
    printf "%-10s | %-10s | %s\n" "COIN" "TYPE" "BALANCE"
    echo "---------------------------------"
    
    # Filter for balance > 0 and output table
    echo $RESPONSE | jq -r '.data[] | select(.balance | tonumber > 0) | "\(.currency) \(.type) \(.balance)"' | while read currency type balance; do
        printf "%-10s | %-10s | %s\n" "$currency" "$type" "$balance"
    done
else
    echo "❌ Error:"
    echo $RESPONSE | jq
fi