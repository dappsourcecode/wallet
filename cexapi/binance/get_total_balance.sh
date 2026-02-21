#!/bin/bash
# BINANCE TOTAL WALLET BALANCE (BTC VALUE)

echo "--- BINANCE WALLET VALUATION ---"

read -p "Enter API Key: " API_KEY
read -s -p "Enter API Secret: " API_SECRET
echo ""
echo "------------------------------"

BASE_URL="https://api.binance.com"
ENDPOINT="/sapi/v1/asset/wallet/balance"
TIMESTAMP=$(date +%s000)

QUERY_STRING="timestamp=$TIMESTAMP"
SIGNATURE=$(echo -n "$QUERY_STRING" | openssl dgst -sha256 -hmac "$API_SECRET" | sed 's/^.* //')

RESPONSE=$(curl -s -X GET "${BASE_URL}${ENDPOINT}?${QUERY_STRING}&signature=${SIGNATURE}" \
     -H "X-MBX-APIKEY: $API_KEY")

# Check for API error codes
if echo "$RESPONSE" | grep -q "\"code\""; then
    echo "❌ API Error:"
    echo $RESPONSE | jq
else
    echo "✅ Wallet Valuation (in BTC):"
    echo "-----------------------------"
    # The fix: Iterate through the array (.[]), selecting only wallets with balance > 0
    echo "$RESPONSE" | jq -r '.[] | select(.balance | tonumber > 0) | "\(.walletName): \(.balance) BTC"'
fi