#!/bin/bash
# GATE.IO BALANCE CHECKER (FIXED)
# Usage: ./gateio_get.sh

echo "--- GATE.IO BALANCE CHECKER ---"

# 1. Prompt for Credentials
read -p "Enter API Key: " API_KEY
read -s -p "Enter API Secret: " API_SECRET
echo ""
echo "------------------------------"

# 2. Setup Constants
HOST="https://api.gateio.ws"
PREFIX="/api/v4"
URL="/spot/accounts"
METHOD="GET"
QUERY_STRING=""
TIMESTAMP=$(date +%s)

# 3. Construct Signature (Gate.io V4)

# Step A: Hash the payload (Empty string for GET) -> SHA512 Hex
# We use printf to ensure no trailing newline is added to the input
PAYLOAD_HASH=$(printf "" | openssl dgst -sha512 | sed 's/^.* //')

# Step B: Create String to Sign
# Format: METHOD \n URL \n QUERY_STRING \n PAYLOAD_HASH \n TIMESTAMP
# We use printf to enforce exact newlines (\n)
SIGN_STR=$(printf "${METHOD}\n${PREFIX}${URL}\n${QUERY_STRING}\n${PAYLOAD_HASH}\n${TIMESTAMP}")

# Step C: Sign with Secret -> HMAC-SHA512 Hex
SIGNATURE=$(printf "$SIGN_STR" | openssl dgst -sha512 -hmac "$API_SECRET" | sed 's/^.* //')

# Debugging (Optional: Uncomment to see what is being signed)
# echo "DEBUG: Payload Hash: $PAYLOAD_HASH"
# echo "DEBUG: String to Sign: $SIGN_STR"
# echo "DEBUG: Signature: $SIGNATURE"

# 4. Execute Request
RESPONSE=$(curl -s -X GET "${HOST}${PREFIX}${URL}" \
     -H "KEY: $API_KEY" \
     -H "Timestamp: $TIMESTAMP" \
     -H "SIGN: $SIGNATURE" \
     -H "Content-Type: application/json")

# 5. Output
if echo "$RESPONSE" | grep -q "\"label\""; then
    echo "❌ API Error:"
    echo $RESPONSE | jq
else
    echo "✅ Success!"
    echo "Active Balances:"
    echo "---------------------------------"
    printf "%-10s | %-10s | %s\n" "CURRENCY" "AVAILABLE" "LOCKED"
    echo "---------------------------------"

    # Gate.io returns an array directly. Filter > 0.
    echo "$RESPONSE" | jq -r '.[] | select((.available | tonumber > 0) or (.locked | tonumber > 0)) | "\(.currency) \(.available) \(.locked)"' | while read currency available locked; do
        printf "%-10s | %-10s | %s\n" "$currency" "$available" "$locked"
    done
fi