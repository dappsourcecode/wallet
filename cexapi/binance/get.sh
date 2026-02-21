#!/bin/bash

# BINANCE BALANCE CHECKER
# Usage: ./binance_get.sh

echo "--- BINANCE BALANCE CHECKER ---"

# 1. Prompt for Credentials
read -p "Enter API Key: " API_KEY
read -s -p "Enter API Secret: " API_SECRET
echo ""
echo "------------------------------"

# 2. Check Dependencies
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Run 'sudo apt install jq'"
    exit 1
fi

# 3. Setup Constants
BASE_URL="https://api.binance.com"
ENDPOINT="/api/v3/account"
TIMESTAMP=$(date +%s000)

# 4. Generate Query String and Signature
QUERY_STRING="timestamp=$TIMESTAMP"

# Binance requires HMAC-SHA256 -> Hex output
# We use sed to extract just the hash from openssl output
SIGNATURE=$(echo -n "$QUERY_STRING" | openssl dgst -sha256 -hmac "$API_SECRET" | sed 's/^.* //')

# 5. Execute Request
RESPONSE=$(curl -s -X GET "${BASE_URL}${ENDPOINT}?${QUERY_STRING}&signature=${SIGNATURE}" \
     -H "X-MBX-APIKEY: $API_KEY")

# 6. Check for Errors (Binance returns "msg" field on error)
if echo "$RESPONSE" | grep -q "\"msg\""; then
    echo "❌ Error:"
    echo $RESPONSE | jq
else
    echo "✅ Success!"
    echo "Active Balances:"
    echo "---------------------------------"
    printf "%-10s | %-10s | %s\n" "ASSET" "FREE" "LOCKED"
    echo "---------------------------------"

    # Filter for free > 0 OR locked > 0
    echo $RESPONSE | jq -r '.balances[] | select((.free | tonumber > 0) or (.locked | tonumber > 0)) | "\(.asset) \(.free) \(.locked)"' | while read asset free locked; do
        printf "%-10s | %-10s | %s\n" "$asset" "$free" "$locked"
    done
fi