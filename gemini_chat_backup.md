**User:**
You said

This chat will be dedicated for portfolio tracking on cryptocurrency centralized exchange personal accounts and cryptocurrency wallet and all other APIs on google spread sheet utilizing app scripts.

---

**Gemini:**
That sounds like a solid project. Using Google Apps Script (GAS) to bridge CEXs and on-chain wallets into a single Google Sheet is a powerful way to regain control of your data without relying on third-party trackers.

To get started, we should organize the sheet structure and identify the specific APIs you'll need.

1. The Tech Stack

Centralized Exchanges (CEX): Most (Binance, Coinbase, Kraken) use HMAC SHA256 signatures for private data (balances). GAS handles this well with Utilities.computeHmacSignature().

On-Chain Wallets: You'll likely use explorers like Etherscan, BscScan, or Polygonscan. These are generally easier because they use simple API keys without complex signing.

Market Prices: For "Live" valuation, CoinGecko or CoinMarketCap APIs are the standard.

2. Suggested Spreadsheet Architecture

I recommend splitting your workbook into these core sheets:

Dashboard: Your bird's-eye view (Total Net Worth, Allocation %, 24h Change).

Balances: The "Raw Data" sheet where Apps Script dumps the results from your API calls.

Setup: Where you store your API Keys and Secrets (Keep these private!).

Transactions: (Optional) For manual entry of trades or off-exchange moves.

3. A Simple Starting Script (Market Price)

To make sure your Apps Script environment is ready, here is a basic function to fetch a price using the CoinGecko public API (no key required for basic use).

JavaScript
/**
 * Fetches the current price of a cryptocurrency.
 * @param {string} id The CoinGecko ID (e.g., "bitcoin", "ethereum").
 * @return {number} The current price in USD.
 * @customfunction
 */
function GET_CRYPTO_PRICE(id = "bitcoin") {
  const url = `https://api.coingecko.com/api/v3/simple/price?ids=${id}&vs_currencies=usd`;
  const response = UrlFetchApp.fetch(url);
  const data = JSON.parse(response.getContentText());
  return data[id].usd;
}

4. Important Security Warning

Since you are dealing with API Keys:

Never share your spreadsheet with anyone if it contains your "Secret Keys."

API Permissions: When creating keys on Binance/Coinbase, enable "Read-Only" or "View Balance" permissions. DO NOT enable "Enable Withdrawals" or "Enable Spot & Margin Trading."

Where should we begin? Would you like to start by writing the script to pull balances from a specific Exchange (CEX), or should we focus on an On-Chain Wallet (like an Ethereum/EVM address) first?

---

**User:**
You said

We skip binance because:




```

7:00:16 PM Notice Execution started

7:00:16 PM Info Error: {

"code": 0,

"msg": "Service unavailable from a restricted location according to 'b. Eligibility' in https://www.binance.com/en/terms. Please contact customer service if you believe you received this message in error."

}

```

Do you agree?

---

**Gemini:**
Yes, I agree. We should skip Binance for now.

Here is exactly why that error happened:
Even though you are in Indonesia, the Google Apps Script runs on Google's servers, which are mostly located in the USA. Binance.com strictly blocks all web traffic from US IP addresses (including Google's data centers).

Recommended Next Step: Track an On-Chain Wallet

Since we can't easily access Binance, the most reliable place to start is tracking a "self-custody" wallet (like MetaMask, Trust Wallet, or Ledger). This is often easier because blockchain data is public and doesn't require complex HMAC signatures.

Let's build a script to track an EVM address (Ethereum, BNB Chain, Polygon, etc.).

Do you have a wallet address you want to track?
If yes, please paste the public address (it starts with 0x...) and tell me which network it's on (e.g., Ethereum, BSC, Arbitrum).

Note: It is safe to share your public address here; it only allows viewing balances, not spending funds.

---

**User:**
You said

We will go next with Kucoin. Generate app script to get my account balance. Let me input the api key and secret and etc.

---

**Gemini:**
That is a good choice. KuCoin allows API access from more regions than Binance, but it requires a slightly more complex authentication method (API Key Version 2) where the Passphrase itself must be encrypted, not just the signature.

The Plan

Get your KuCoin API Keys:

Go to KuCoin Profile > API Management.

Create a new API Key.

Important: Select "V2" (which is usually default now).

Permissions: Check "General" (Spot/Margin/Futures reading). Do NOT check "Trade" or "Withdraw".

Write down your Key, Secret, and Passphrase.

The App Script:
I have written a complete script below. It handles the specific "Passphrase Encryption" required by KuCoin V2.

Step 1: The Code

Open your Google Sheet, go to Extensions > Apps Script, delete any code there, and paste this in:

JavaScript
/**
 * KUCOIN PORTFOLIO TRACKER
 * ------------------------
 * 1. Go to Project Settings (gear icon) -> Script Properties
 * 2. Add these three properties:
 * - KUCOIN_KEY
 * - KUCOIN_SECRET
 * - KUCOIN_PASSPHRASE
 * 3. Save and run "refreshKucoinBalances"
 */

function onOpen() {
  const ui = SpreadsheetApp.getUi();
  ui.createMenu('🪙 Crypto Tracker')
    .addItem('Refresh KuCoin Balances', 'refreshKucoinBalances')
    .addToUi();
}

function refreshKucoinBalances() {
  // 1. Retrieve Keys from Script Properties (Secure Storage)
  const scriptProperties = PropertiesService.getScriptProperties();
  const apiKey = scriptProperties.getProperty('KUCOIN_KEY');
  const apiSecret = scriptProperties.getProperty('KUCOIN_SECRET');
  const apiPassphrase = scriptProperties.getProperty('KUCOIN_PASSPHRASE');

  if (!apiKey || !apiSecret || !apiPassphrase) {
    SpreadsheetApp.getUi().alert('Error: API Credentials missing. Please add them in Project Settings > Script Properties.');
    return;
  }

  // 2. Setup the Request
  const baseUrl = "https://api.kucoin.com";
  const endpoint = "/api/v1/accounts"; // Fetches Spot & Margin accounts
  const timestamp = Date.now().toString();
  
  // 3. Generate Signatures (V2 Requirement)
  // V2 requires the Passphrase to be encrypted via HMAC-SHA256 using the Secret
  const encryptedPassphrase = signRequest(apiPassphrase, apiSecret);
  
  // Standard Request Signature: timestamp + method + endpoint + body
  const method = "GET";
  const strToSign = timestamp + method + endpoint; 
  const signature = signRequest(strToSign, apiSecret);

  const headers = {
    "KC-API-KEY": apiKey,
    "KC-API-SIGN": signature,
    "KC-API-TIMESTAMP": timestamp,
    "KC-API-PASSPHRASE": encryptedPassphrase,
    "KC-API-KEY-VERSION": "2" // Crucial for V2 keys
  };

  // 4. Fetch Data
  try {
    const response = UrlFetchApp.fetch(baseUrl + endpoint, {
      method: method,
      headers: headers,
      muteHttpExceptions: true
    });

    const json = JSON.parse(response.getContentText());

    if (json.code !== "200000") {
      Logger.log("API Error: " + json.msg);
      SpreadsheetApp.getUi().alert("API Error: " + json.msg);
      return;
    }

    // 5. Process & Filter Zero Balances
    const balances = json.data;
    const activeAssets = balances.filter(item => parseFloat(item.balance) > 0);
    
    // 6. Dump to Sheet
    const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName('Balances') || SpreadsheetApp.getActiveSpreadsheet().insertSheet('Balances');
    sheet.clear(); // Clear old data
    
    // Set Headers
    sheet.getRange(1, 1, 1, 4).setValues([["Currency", "Type", "Total Balance", "Available"]]).setFontWeight("bold");

    if (activeAssets.length > 0) {
      const output = activeAssets.map(asset => [
        asset.currency,
        asset.type, // 'trade' (spot) or 'main' (funding)
        parseFloat(asset.balance),
        parseFloat(asset.available)
      ]);
      
      sheet.getRange(2, 1, output.length, 4).setValues(output);
    }
    
    SpreadsheetApp.getUi().alert(`Success! Retrieved ${activeAssets.length} assets.`);

  } catch (e) {
    Logger.log("Fetch Error: " + e.toString());
    SpreadsheetApp.getUi().alert("Script Error: " + e.toString());
  }
}

/**
 * Helper function to sign data using HMAC-SHA256 and Base64 encoding
 */
function signRequest(text, secret) {
  const signature = Utilities.computeHmacSignature(
    Utilities.MacAlgorithm.HMAC_SHA_256,
    text,
    secret
  );
  return Utilities.base64Encode(signature);
}

Step 2: Securely Store Your Keys

Instead of pasting your keys directly into the code (which is risky if you share the sheet), we will use Script Properties:

In the Apps Script editor, click the Gear Icon (Project Settings) on the left sidebar.

Scroll down to Script Properties.

Click Add script property and add these three items exactly as named:

Property: KUCOIN_KEY | Value: Your API Key

Property: KUCOIN_SECRET | Value: Your API Secret

Property: KUCOIN_PASSPHRASE | Value: Your API Passphrase

Click Save script properties.

Step 3: Run It

Refresh your Google Sheet.

You will see a new menu 🪙 Crypto Tracker at the top.

Click Refresh KuCoin Balances.

Accept the permissions (it will warn you about "unsafe" app since you wrote it—this is normal).

Next Step:
Once you confirm this pulls your KuCoin balances into the "Balances" sheet, would you like to:

Add a price fetcher to calculate the USD value of these assets?

Or move on to adding an On-Chain Wallet (like MetaMask/Ethereum)?

---

**User:**
You said

Add more logs to see where the execution is stuck and no need for UI yet where just output the logs and balances in the execution logs.

---

**Gemini:**
This is the correct approach for debugging. By stripping away the UI and spreadsheet operations, we can isolate the API connection logic and see exactly what KuCoin is returning (or rejecting).

Here is the Debug Version of the script. It logs every step of the authentication process.

The Debug Script

Replace your current code with this. After running it, view the logs by clicking "Execution Log" at the bottom of the script editor.

JavaScript
function debugKucoinConnection() {
  Logger.log("--- START DEBUGGING ---");

  // 1. Retrieve Keys
  const scriptProperties = PropertiesService.getScriptProperties();
  const apiKey = scriptProperties.getProperty('KUCOIN_KEY');
  const apiSecret = scriptProperties.getProperty('KUCOIN_SECRET');
  const apiPassphrase = scriptProperties.getProperty('KUCOIN_PASSPHRASE');

  // Log (masked) keys to ensure they are actually being read
  Logger.log(`API Key Loaded: ${apiKey ? "YES (" + apiKey.substring(0,4) + "...)" : "NO"}`);
  Logger.log(`Secret Loaded: ${apiSecret ? "YES" : "NO"}`);
  Logger.log(`Passphrase Loaded: ${apiPassphrase ? "YES" : "NO"}`);

  if (!apiKey || !apiSecret || !apiPassphrase) {
    Logger.log("❌ ERROR: Missing credentials. Check Script Properties.");
    return;
  }

  // 2. Setup Request Data
  const baseUrl = "https://api.kucoin.com";
  const endpoint = "/api/v1/accounts";
  const method = "GET";
  const timestamp = Date.now().toString();
  
  Logger.log(`Timestamp: ${timestamp}`);
  Logger.log(`Endpoint: ${baseUrl + endpoint}`);

  // 3. Generate Passphrase Signature (V2 Requirement)
  // The passphrase must be encrypted: HMAC-SHA256(passphrase, secret) -> Base64
  const encryptedPassphrase = signRequest(apiPassphrase, apiSecret);
  Logger.log(`Passphrase Encrypted: YES`);

  // 4. Generate Request Signature
  // String to sign: timestamp + method + endpoint (body is empty for GET)
  const strToSign = timestamp + method + endpoint;
  Logger.log(`String to Sign: "${strToSign}"`);
  
  const signature = signRequest(strToSign, apiSecret);
  Logger.log(`Signature Generated: YES`);

  // 5. Construct Headers
  const headers = {
    "KC-API-KEY": apiKey,
    "KC-API-SIGN": signature,
    "KC-API-TIMESTAMP": timestamp,
    "KC-API-PASSPHRASE": encryptedPassphrase,
    "KC-API-KEY-VERSION": "2", // Crucial for V2 keys
    "Content-Type": "application/json"
  };

  // 6. Execute Request
  Logger.log("--- SENDING REQUEST ---");
  try {
    const response = UrlFetchApp.fetch(baseUrl + endpoint, {
      method: method,
      headers: headers,
      muteHttpExceptions: true // Prevents script from crashing on 4xx/5xx errors
    });

    const responseCode = response.getResponseCode();
    const contentText = response.getContentText();
    
    Logger.log(`Response Code: ${responseCode}`);
    
    // Parse JSON
    const json = JSON.parse(contentText);

    if (json.code !== "200000") {
      // KuCoin Specific Error
      Logger.log(`❌ API ERROR CODE: ${json.code}`);
      Logger.log(`❌ API ERROR MSG: ${json.msg}`);
    } else {
      // Success
      Logger.log("✅ SUCCESS: Data Retrieved");
      
      const balances = json.data;
      const activeAssets = balances.filter(item => parseFloat(item.balance) > 0);

      Logger.log(`Found ${activeAssets.length} active assets:`);
      activeAssets.forEach(asset => {
        Logger.log(`- ${asset.currency} (${asset.type}): ${asset.balance}`);
      });
    }

  } catch (e) {
    Logger.log(`❌ FATAL SCRIPT ERROR: ${e.toString()}`);
  }
  
  Logger.log("--- END DEBUGGING ---");
}

/**
 * Helper: HMAC-SHA256 + Base64 Encoding
 */
function signRequest(text, secret) {
  const signature = Utilities.computeHmacSignature(
    Utilities.MacAlgorithm.HMAC_SHA_256,
    text,
    secret
  );
  return Utilities.base64Encode(signature);
}

How to Interpret the Logs

Look for the Response Code and API ERROR MSG:

400005 (Invalid KC-API-SIGN):

This usually means the strToSign is formatted wrong, or the Secret Key is incorrect.

Check: Did you accidentally include whitespace in your Secret Key when saving it?

400004 (Invalid KC-API-PASSPHRASE):

The encryptedPassphrase logic is failing, or the Passphrase you saved in properties doesn't match what you set on KuCoin.

Check: The Passphrase is case-sensitive.

401 (Unauthorized):

Your API Key might be wrong, or IP restriction is enabled on KuCoin but Google's IP isn't whitelisted. (We assume you did not enable IP restriction).

Run this and let me know the Code and Message if it fails!

---

**User:**
You said

Same thing:




```

7:23:47 PMInfo❌ API ERROR CODE: 4003027:23:47 PMInfo❌ API ERROR MSG: Our services are currently unavailable in the U.S. To ensure a seamless experience, please access the platform from a non-restricted country/region using a supported IP address. For more details, please refer to our Terms of Use. (current ip: 34.116.22.40 and current area: US)

```




Now for binance and kucoin, write me a html css js instead. I request only 3 input box which are key, secret, and phrase. I am thinking of output box as only a field box or div but you may decide if there are better.

---

**Gemini:**
This is the correct move. Since Google's servers are in the US, they will always be blocked. By moving this to HTML/JS running locally in your browser, the request comes from your Indonesian IP, which is allowed.

The Challenge: CORS

Browsers have a security feature called CORS that blocks websites (or local files) from calling APIs that don't explicitly allow it. Binance and KuCoin generally block these "direct from browser" calls.

To make this work, you have two options:

Use a Browser Extension: Install a "Allow CORS: Access-Control-Allow-Origin" extension (e.g., this one for Chrome) and toggle it ON before using the tool.

Use a Proxy: Route requests through a proxy (complex to set up).

I recommend Option 1 for this local tool.

Here is a complete, single-file solution. Save this code as crypto-tracker.html and open it in your browser.

HTML
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Local Crypto Portfolio Tracker</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/crypto-js/4.1.1/crypto-js.min.js"></script>
</head>
<body class="bg-gray-900 text-gray-100 min-h-screen p-8 font-mono">

    <div class="max-w-3xl mx-auto bg-gray-800 p-6 rounded-lg shadow-xl border border-gray-700">
        <h1 class="text-2xl font-bold mb-4 text-green-400">Local CEX Balance Checker</h1>
        <p class="text-sm text-gray-400 mb-6">
            Requests run locally from your IP. <br>
            <span class="text-yellow-500 font-bold">⚠️ REQUIREMENT:</span> You must enable a "CORS Unblock" browser extension for this to work.
        </p>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
            
            <div class="col-span-1 md:col-span-2">
                <label class="block text-xs uppercase text-gray-500 mb-1">Exchange</label>
                <select id="exchangeSelect" class="w-full bg-gray-700 border border-gray-600 rounded p-2 focus:outline-none focus:border-green-500 transition" onchange="togglePassphrase()">
                    <option value="kucoin">KuCoin</option>
                    <option value="binance">Binance</option>
                </select>
            </div>

            <div>
                <label class="block text-xs uppercase text-gray-500 mb-1">API Key</label>
                <input type="text" id="apiKey" placeholder="Paste API Key" class="w-full bg-gray-700 border border-gray-600 rounded p-2 focus:outline-none focus:border-green-500 transition">
            </div>

            <div>
                <label class="block text-xs uppercase text-gray-500 mb-1">API Secret</label>
                <input type="password" id="apiSecret" placeholder="Paste API Secret" class="w-full bg-gray-700 border border-gray-600 rounded p-2 focus:outline-none focus:border-green-500 transition">
            </div>

            <div id="passphraseContainer" class="col-span-1 md:col-span-2">
                <label class="block text-xs uppercase text-gray-500 mb-1">Passphrase (KuCoin Only)</label>
                <input type="password" id="apiPassphrase" placeholder="Paste Passphrase" class="w-full bg-gray-700 border border-gray-600 rounded p-2 focus:outline-none focus:border-green-500 transition">
            </div>

        </div>

        <button onclick="fetchBalances()" class="w-full bg-green-600 hover:bg-green-700 text-white font-bold py-3 px-4 rounded transition duration-200 shadow-lg">
            Fetch Balances
        </button>

        <div class="mt-8">
            <label class="block text-xs uppercase text-gray-500 mb-1">Response / Logs</label>
            <div id="output" class="w-full bg-black text-green-400 p-4 rounded h-64 overflow-auto text-xs whitespace-pre-wrap border border-gray-700 font-mono">Waiting for input...</div>
        </div>
    </div>

    <script>
        // Toggle Passphrase visibility based on exchange selection
        function togglePassphrase() {
            const exchange = document.getElementById('exchangeSelect').value;
            const container = document.getElementById('passphraseContainer');
            if (exchange === 'binance') {
                container.style.display = 'none';
            } else {
                container.style.display = 'block';
            }
        }

        // Logger Helper
        function log(msg, type = "info") {
            const output = document.getElementById('output');
            const timestamp = new Date().toLocaleTimeString();
            let color = type === "error" ? "text-red-400" : "text-green-400";
            output.innerHTML = `<span class="text-gray-500">[${timestamp}]</span> <span class="${color}">${msg}</span>\n` + output.innerHTML;
        }

        async function fetchBalances() {
            const exchange = document.getElementById('exchangeSelect').value;
            const apiKey = document.getElementById('apiKey').value.trim();
            const apiSecret = document.getElementById('apiSecret').value.trim();
            const apiPassphrase = document.getElementById('apiPassphrase').value.trim();

            if (!apiKey || !apiSecret) {
                log("Error: Key and Secret are required.", "error");
                return;
            }

            document.getElementById('output').innerHTML = ""; // Clear log
            log(`Starting fetch for ${exchange.toUpperCase()}...`);

            try {
                if (exchange === 'kucoin') {
                    await fetchKucoin(apiKey, apiSecret, apiPassphrase);
                } else if (exchange === 'binance') {
                    await fetchBinance(apiKey, apiSecret);
                }
            } catch (error) {
                log(`Fetch Failed: ${error.message}`, "error");
                if (error.message.includes("Failed to fetch")) {
                    log("CORS ERROR: The browser blocked the request. Please install a 'Allow CORS' extension.", "error");
                }
            }
        }

        // --- KUCOIN LOGIC ---
        async function fetchKucoin(key, secret, passphrase) {
            if (!passphrase) {
                log("Error: Passphrase is required for KuCoin.", "error");
                return;
            }

            const baseUrl = "https://api.kucoin.com";
            const endpoint = "/api/v1/accounts";
            const timestamp = Date.now().toString();
            
            // Signatures
            const strToSign = timestamp + "GET" + endpoint;
            const signature = CryptoJS.HmacSHA256(strToSign, secret).toString(CryptoJS.enc.Base64);
            const passphraseSign = CryptoJS.HmacSHA256(passphrase, secret).toString(CryptoJS.enc.Base64);

            const headers = {
                "KC-API-KEY": key,
                "KC-API-SIGN": signature,
                "KC-API-TIMESTAMP": timestamp,
                "KC-API-PASSPHRASE": passphraseSign,
                "KC-API-KEY-VERSION": "2",
                "Content-Type": "application/json"
            };

            log("Sending Request to KuCoin...");
            
            const response = await fetch(baseUrl + endpoint, { method: "GET", headers: headers });
            const data = await response.json();

            if (data.code !== "200000") {
                log(`API Error: ${data.msg}`, "error");
            } else {
                displayBalances(data.data, 'kucoin');
            }
        }

        // --- BINANCE LOGIC ---
        async function fetchBinance(key, secret) {
            const baseUrl = "https://api.binance.com";
            const endpoint = "/api/v3/account";
            const timestamp = Date.now().toString();
            
            const queryString = `timestamp=${timestamp}`;
            const signature = CryptoJS.HmacSHA256(queryString, secret).toString(CryptoJS.enc.Hex);
            
            const fullUrl = `${baseUrl}${endpoint}?${queryString}&signature=${signature}`;

            const headers = {
                "X-MBX-APIKEY": key
            };

            log("Sending Request to Binance...");

            const response = await fetch(fullUrl, { method: "GET", headers: headers });
            
            if (!response.ok) {
                const errText = await response.text();
                throw new Error(`HTTP ${response.status}: ${errText}`);
            }

            const data = await response.json();
            displayBalances(data.balances, 'binance');
        }

        // --- DISPLAY LOGIC ---
        function displayBalances(data, exchange) {
            let activeAssets = [];

            if (exchange === 'kucoin') {
                activeAssets = data.filter(item => parseFloat(item.balance) > 0);
            } else if (exchange === 'binance') {
                activeAssets = data.filter(item => parseFloat(item.free) > 0 || parseFloat(item.locked) > 0);
            }

            if (activeAssets.length === 0) {
                log("Success: Request valid, but no non-zero balances found.");
                return;
            }

            log(`Success! Found ${activeAssets.length} assets.`);
            
            // Format output nicely
            let table = "\nASSET      | BALANCE\n-----------|-----------\n";
            activeAssets.forEach(asset => {
                let coin = exchange === 'kucoin' ? asset.currency : asset.asset;
                let bal = exchange === 'kucoin' ? asset.balance : parseFloat(asset.free) + parseFloat(asset.locked);
                table += `${coin.padEnd(10)} | ${bal}\n`;
            });
            
            log(table);
        }
    </script>
</body>
</html>

How to Use This

Save: Copy the code above and save it as index.html on your desktop.

Install CORS Extension: Since you are opening a local file (file://) and trying to hit a public API (https://api.kucoin.com), modern browsers will block it.

Install a "Allow CORS" extension for your browser.

Turn it ON.

Run: Open index.html in Chrome/Edge/Brave.

Enter Keys: Select your exchange, paste your credentials, and click "Fetch Balances."

If it works, the black box will populate with your coin balances.

---

**User:**
You said

Separate kucoin and binance index.html. Will using python http server works for cors?

---

**Gemini:**
To answer your question first: No, using python -m http.server will not solve the CORS issue.

Running a local Python server moves your site from file:// to http://localhost:8000, but the browser will still block the request because Binance and KuCoin servers do not explicitly allow "localhost" to access their data.

You still have two choices:

Easiest: Use the HTML files below + a "Allow CORS" Browser Extension.

Harder (but no extension needed): Write a Python backend script to fetch the data (since Python scripts don't have CORS limits) and send it to your HTML.

Here are the separated HTML files.

1. KuCoin (kucoin.html)

Requires: Key, Secret, Passphrase.

HTML
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>KuCoin Portfolio</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/crypto-js/4.1.1/crypto-js.min.js"></script>
</head>
<body class="bg-gray-900 text-gray-100 min-h-screen flex items-center justify-center font-mono">

    <div class="w-full max-w-lg bg-gray-800 p-8 rounded-lg shadow-2xl border border-gray-700">
        <h1 class="text-3xl font-bold mb-6 text-green-500">KuCoin Tracker</h1>

        <div class="space-y-4">
            <div>
                <label class="text-xs uppercase text-gray-500">API Key</label>
                <input type="text" id="apiKey" class="w-full bg-gray-700 border border-gray-600 rounded p-3 focus:outline-none focus:border-green-500">
            </div>
            <div>
                <label class="text-xs uppercase text-gray-500">API Secret</label>
                <input type="password" id="apiSecret" class="w-full bg-gray-700 border border-gray-600 rounded p-3 focus:outline-none focus:border-green-500">
            </div>
            <div>
                <label class="text-xs uppercase text-gray-500">Passphrase</label>
                <input type="password" id="apiPassphrase" class="w-full bg-gray-700 border border-gray-600 rounded p-3 focus:outline-none focus:border-green-500">
            </div>
            
            <button onclick="fetchKucoin()" class="w-full bg-green-600 hover:bg-green-700 text-white font-bold py-3 rounded transition">
                Check Balance
            </button>
        </div>

        <div id="output" class="mt-6 bg-black p-4 rounded h-48 overflow-auto text-xs whitespace-pre-wrap text-green-400 font-mono border border-gray-700 hidden"></div>
    </div>

    <script>
        async function fetchKucoin() {
            const key = document.getElementById('apiKey').value.trim();
            const secret = document.getElementById('apiSecret').value.trim();
            const passphrase = document.getElementById('apiPassphrase').value.trim();
            const output = document.getElementById('output');
            
            output.classList.remove('hidden');
            output.innerText = "Fetching...";

            if(!key || !secret || !passphrase) {
                output.innerText = "Error: All fields are required.";
                return;
            }

            try {
                const baseUrl = "https://api.kucoin.com";
                const endpoint = "/api/v1/accounts";
                const timestamp = Date.now().toString();
                
                // 1. Sign Passphrase (V2 Requirement)
                const passphraseSign = CryptoJS.HmacSHA256(passphrase, secret).toString(CryptoJS.enc.Base64);

                // 2. Sign Request
                const strToSign = timestamp + "GET" + endpoint;
                const signature = CryptoJS.HmacSHA256(strToSign, secret).toString(CryptoJS.enc.Base64);

                const headers = {
                    "KC-API-KEY": key,
                    "KC-API-SIGN": signature,
                    "KC-API-TIMESTAMP": timestamp,
                    "KC-API-PASSPHRASE": passphraseSign,
                    "KC-API-KEY-VERSION": "2",
                    "Content-Type": "application/json"
                };

                const response = await fetch(baseUrl + endpoint, { method: "GET", headers: headers });
                const json = await response.json();

                if (json.code !== "200000") {
                    output.innerText = `Error: ${json.msg}`;
                } else {
                    const balances = json.data.filter(b => parseFloat(b.balance) > 0);
                    if(balances.length === 0) {
                        output.innerText = "Success: No active balances found.";
                    } else {
                        let txt = "COIN       | TYPE   | BALANCE\n-----------|--------|----------\n";
                        balances.forEach(b => {
                            txt += `${b.currency.padEnd(10)} | ${b.type.padEnd(6)} | ${b.balance}\n`;
                        });
                        output.innerText = txt;
                    }
                }
            } catch (e) {
                output.innerText = `Fetch Error: ${e.message}\n(Did you enable the CORS extension?)`;
            }
        }
    </script>
</body>
</html>

2. Binance (binance.html)

Requires: Key, Secret only.

HTML
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Binance Portfolio</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/crypto-js/4.1.1/crypto-js.min.js"></script>
</head>
<body class="bg-gray-900 text-gray-100 min-h-screen flex items-center justify-center font-mono">

    <div class="w-full max-w-lg bg-gray-800 p-8 rounded-lg shadow-2xl border border-gray-700">
        <h1 class="text-3xl font-bold mb-6 text-yellow-500">Binance Tracker</h1>

        <div class="space-y-4">
            <div>
                <label class="text-xs uppercase text-gray-500">API Key</label>
                <input type="text" id="apiKey" class="w-full bg-gray-700 border border-gray-600 rounded p-3 focus:outline-none focus:border-yellow-500">
            </div>
            <div>
                <label class="text-xs uppercase text-gray-500">API Secret</label>
                <input type="password" id="apiSecret" class="w-full bg-gray-700 border border-gray-600 rounded p-3 focus:outline-none focus:border-yellow-500">
            </div>
            
            <button onclick="fetchBinance()" class="w-full bg-yellow-600 hover:bg-yellow-700 text-gray-900 font-bold py-3 rounded transition">
                Check Balance
            </button>
        </div>

        <div id="output" class="mt-6 bg-black p-4 rounded h-48 overflow-auto text-xs whitespace-pre-wrap text-yellow-400 font-mono border border-gray-700 hidden"></div>
    </div>

    <script>
        async function fetchBinance() {
            const key = document.getElementById('apiKey').value.trim();
            const secret = document.getElementById('apiSecret').value.trim();
            const output = document.getElementById('output');
            
            output.classList.remove('hidden');
            output.innerText = "Fetching...";

            if(!key || !secret) {
                output.innerText = "Error: Key and Secret are required.";
                return;
            }

            try {
                const baseUrl = "https://api.binance.com";
                const endpoint = "/api/v3/account";
                const timestamp = Date.now().toString();
                
                const queryString = `timestamp=${timestamp}`;
                const signature = CryptoJS.HmacSHA256(queryString, secret).toString(CryptoJS.enc.Hex);
                
                const fullUrl = `${baseUrl}${endpoint}?${queryString}&signature=${signature}`;

                const headers = { "X-MBX-APIKEY": key };

                const response = await fetch(fullUrl, { method: "GET", headers: headers });
                
                if (!response.ok) {
                    const err = await response.text();
                    output.innerText = `Error ${response.status}: ${err}`;
                    return;
                }

                const json = await response.json();
                const balances = json.balances.filter(b => parseFloat(b.free) > 0 || parseFloat(b.locked) > 0);

                if(balances.length === 0) {
                    output.innerText = "Success: No active balances found.";
                } else {
                    let txt = "ASSET      | FREE       | LOCKED\n-----------|------------|----------\n";
                    balances.forEach(b => {
                        txt += `${b.asset.padEnd(10)} | ${parseFloat(b.free).toFixed(4).padEnd(10)} | ${parseFloat(b.locked).toFixed(4)}\n`;
                    });
                    output.innerText = txt;
                }
            } catch (e) {
                output.innerText = `Fetch Error: ${e.message}\n(Did you enable the CORS extension?)`;
            }
        }
    </script>
</body>
</html>

---

**User:**
You said

Let's put the html css js behind for now. How about a bash or shell script? I'm in Ubuntu 24.04 and will write a get.sh file. Separate the .sh files for binance and kucoin. Input the key, secret, passphrase, etc during running not in .sh file.

---

**Gemini:**
This is a great approach. Bash scripts are cleaner, faster, and native to your Ubuntu environment. Since you are running this locally on your machine in Indonesia, the IP geolocation should not be an issue.

You will need jq (JSON processor) and curl installed. If you don't have them:

Bash
sudo apt update && sudo apt install jq curl -y


Here are the two separate scripts.

1. KuCoin (kucoin_get.sh)

KuCoin V2 requires two signatures: one for the request and one for the passphrase itself.

Bash
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

2. Binance (binance_get.sh)

Binance is simpler but requires the signature in Hex format.

Bash
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

How to run them:

Save the code into files (e.g., nano kucoin_get.sh).

Make them executable:

Bash
chmod +x kucoin_get.sh binance_get.sh


Run:

Bash
./kucoin_get.sh

---

**User:**
You said

Binance:

```

------------------------------

✅ Success!

Active Balances:

---------------------------------

ASSET      | FREE       | LOCKED

---------------------------------

ETH        | 0.00590694 | 0.00000000

NEO        | 0.00097100 | 0.00000000

BNB        | 0.00001446 | 0.00000000

USDT       | 0.06486937 | 0.00000000

MTL        | 0.00100000 | 0.00000000

BAT        | 4.09733316 | 0.00000000

ZIL        | 0.07004000 | 0.00000000

WAN        | 0.00656000 | 0.00000000

VET        | 0.99800000 | 0.00000000

VTHO       | 0.09518353 | 0.00000000

USDC       | 0.16260284 | 0.00000000

ATOM       | 0.00112400 | 0.00000000

ALGO       | 0.09856244 | 0.00000000

DOGE       | 0.25020000 | 0.00000000

KAVA       | 0.68584811 | 0.00000000

BCH        | 0.00000735 | 0.00000000

LDBAT      | 537.29342280 | 0.00000000

FIO        | 1189.77900000 | 0.00000000

LDKAVA     | 8.93428430 | 0.00000000

LUNA       | 0.02429900 | 0.00000000

LDLEND     | 76.46800000 | 0.00000000

DIA        | 23.45021367 | 0.00000000

FIL        | 0.01308674 | 0.00000000

LDFIL      | 1.33723168 | 0.00000000

DODO       | 0.00919000 | 0.00000000

TKO        | 1.14277569 | 0.00000000

FORTH      | 0.00182500 | 0.00000000

SHIB       | 489.00     | 0.00

XEC        | 7.35       | 0.00

PORTO      | 0.00133100 | 0.00000000

ETHW       | 0.18302462 | 0.00000000

APT        | 0.00098400 | 0.00000000

FDUSD      | 0.00000033 | 0.00000000

AEVO       | 0.00946600 | 0.00000000

```




Kucoin:

```

✅ Success!

Active Balances:

---------------------------------

COIN       | TYPE       | BALANCE

---------------------------------

KCS        | trade      | 16.43478384

USDT       | trade      | 45.97103111

FTT        | trade      | 39.1239

ADI        | trade      | 2.60310508

WCT        | trade      | 78

KCS        | main       | 0.38096044

UDS        | trade      | 1.06030292

CYS        | trade      | 5.17915399

ZORA       | trade      | 75.32872792

NXPC       | trade      | 5.59044825

MOVA       | trade      | 0.93203164

PVT        | trade      | 1034.01460357

LUMIA      | main       | 10.19457587

SPACE      | trade      | 127.6585749

LYX        | main       | 2.00007144

PLU        | main       | 3

HLS        | trade      | 76.8606091

ESIM       | trade      | 12.27625215

LUNC       | trade      | 5598.20281814

SEEK       | trade      | 2.07303529

PLAYSOLANA | trade      | 43.91522559

KONG       | main       | 38

SHM        | main       | 787.05569195

BMB        | trade      | 12.90810942

KYO        | trade      | 2.05519011

DIGI       | trade      | 3859.82847383

PLANCK     | trade      | 7.31162772

KPOL       | main       | 94.40487475

EPT        | trade      | 29.9830304

TTD        | trade      | 16.45504426

SIGHT      | trade      | 16.35496123

PHIL       | main       | 24.69618688

LUNA       | main       | 0.08819631

BBT        | trade      | 25.03289679

USTC       | trade      | 1.00475683

USDC       | trade      | 0.0028

MISSION    | main       | 2007

SHM        | trade      | 3.29312005

AMPL       | main       | 2.86616417

ELDE       | trade      | 0.53779469

GAS        | main       | 0.000217

XRP        | trade      | 0.00000167

USTC       | main       | 0.00000057

TRX        | main       | 0.00000009

```




Do they have an api request to get the total balance for example in usd or btc?

---

**Gemini:**
Yes, they do, but with a major difference between the two exchanges:

Binance: Yes. They have a specific endpoint (/sapi/v1/asset/wallet/balance) that returns your wallet's total valuation in BTC and Fiat (USD).

KuCoin: No. They do not have a single "Total USD Value" endpoint. You receive only the raw token quantities (e.g., "16.43 KCS"). To get the total USD value, you must write a script to fetch the current price of every coin you own and multiply it yourself.

1. The Binance "Total Balance" Script (binance_total.sh)

This script uses a special endpoint that does the math for you.

Endpoint: /sapi/v1/asset/wallet/balance

Note: This endpoint requires your API Key to have "Read" permissions.

Bash
#!/bin/bash
# BINANCE TOTAL BALANCE CHECKER (BTC & USD)

echo "--- BINANCE WALLET VALUATION ---"

read -p "Enter API Key: " API_KEY
read -s -p "Enter API Secret: " API_SECRET
echo ""
echo "------------------------------"

BASE_URL="https://api.binance.com"
ENDPOINT="/sapi/v1/asset/wallet/balance"
TIMESTAMP=$(date +%s000)

# We request the 'SPOT_WALLET' valuation
QUERY_STRING="wallet=SPOT_WALLET&timestamp=$TIMESTAMP"
SIGNATURE=$(echo -n "$QUERY_STRING" | openssl dgst -sha256 -hmac "$API_SECRET" | sed 's/^.* //')

RESPONSE=$(curl -s -X GET "${BASE_URL}${ENDPOINT}?${QUERY_STRING}&signature=${SIGNATURE}" \
     -H "X-MBX-APIKEY: $API_KEY")

# Check if we got an error
if echo "$RESPONSE" | grep -q "code"; then
    echo "❌ API Error:"
    echo $RESPONSE | jq
else
    echo "✅ Spot Wallet Valuation:"
    # Extract the BTC and Fiat valuation
    echo $RESPONSE | jq -r '.data | "BTC Value: \(.availableBtcValuation)\nUSD Value: \(.availableFiatValuation) \(.fiat)"'
fi

2. The KuCoin Limitation (And Solution)

Since KuCoin forces you to do the math yourself, doing this in a Bash (.sh) script is very difficult because Bash cannot handle decimal math (floating point) or complex JSON multiplication easily.

I strongly recommend switching to Python for this specific task.
Python handles the math and the "Fetch Balances -> Fetch Prices -> Multiply" loop natively.

Would you like me to generate a single Python script (portfolio.py) that:

Connects to both Binance and KuCoin?

Fetches your balances?

Fetches live prices (via CoinGecko or the Exchange)?

Outputs a neat "Total Net Worth" summary in USD?

This would replace your separate .sh files with one robust tool.

---

**User:**
You said

Great, let's just fix the binance:




```

✅ Spot Wallet Valuation:

jq: error (at <stdin>:1): Cannot index array with string "data"

```

---

**Gemini:**
The error jq: error ... Cannot index array with string "data" happens because the Binance API endpoint /sapi/v1/asset/wallet/balance returns a list (array) of wallets, not a single data object.

Here is the fixed Bash script for the Binance Total Balance, and below that, the Python script (which is much better for calculating the USD total).

1. Fixed Bash Script (binance_total.sh)

This updated script correctly handles the array response and lists the BTC value of every wallet you have (Spot, Funding, Futures, etc.).

Bash
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

2. The "Ultimate" Python Script (crypto_portfolio.py)

Since you want the USD Total (which the API doesn't give directly) and support for both exchanges, Python is the best tool. It will:

Fetch your Binance & KuCoin balances.

Fetch live prices (USDT) for those coins.

Calculate your total Net Worth in USD.

Usage:

Install requests: pip install requests

Run: python3 crypto_portfolio.py

Enter your keys when prompted.

Python
import hmac
import hashlib
import time
import requests
import base64
import json
import getpass

# --- CONFIG ---
# If you want to hardcode keys, replace None with "your_key"
# BUT safer to leave as None and type them in on run.
BINANCE_KEY = None
BINANCE_SECRET = None

KUCOIN_KEY = None
KUCOIN_SECRET = None
KUCOIN_PASSPHRASE = None

# --- HELPERS ---
def sign_binance(query, secret):
    return hmac.new(secret.encode('utf-8'), query.encode('utf-8'), hashlib.sha256).hexdigest()

def sign_kucoin(message, secret):
    return base64.b64encode(hmac.new(secret.encode('utf-8'), message.encode('utf-8'), hashlib.sha256).digest()).decode('utf-8')

def get_binance_balances(api_key, api_secret):
    if not api_key: return {}
    try:
        base_url = "https://api.binance.com"
        endpoint = "/api/v3/account"
        timestamp = int(time.time() * 1000)
        query = f"timestamp={timestamp}"
        signature = sign_binance(query, api_secret)
        
        headers = {"X-MBX-APIKEY": api_key}
        url = f"{base_url}{endpoint}?{query}&signature={signature}"
        
        res = requests.get(url, headers=headers)
        data = res.json()
        
        balances = {}
        if 'balances' in data:
            for b in data['balances']:
                total = float(b['free']) + float(b['locked'])
                if total > 0:
                    balances[b['asset']] = total
        return balances
    except Exception as e:
        print(f"❌ Binance Error: {e}")
        return {}

def get_kucoin_balances(api_key, api_secret, passphrase):
    if not api_key: return {}
    try:
        base_url = "https://api.kucoin.com"
        endpoint = "/api/v1/accounts"
        timestamp = str(int(time.time() * 1000))
        
        # Sign Passphrase
        passphrase_sign = sign_kucoin(passphrase, api_secret)
        
        # Sign Request
        msg = timestamp + "GET" + endpoint
        signature = sign_kucoin(msg, api_secret)
        
        headers = {
            "KC-API-KEY": api_key,
            "KC-API-SIGN": signature,
            "KC-API-TIMESTAMP": timestamp,
            "KC-API-PASSPHRASE": passphrase_sign,
            "KC-API-KEY-VERSION": "2",
            "Content-Type": "application/json"
        }
        
        res = requests.get(base_url + endpoint, headers=headers)
        data = res.json()
        
        balances = {}
        if data.get('code') == '200000':
            for b in data['data']:
                amount = float(b['balance'])
                if amount > 0:
                    # KuCoin sometimes has multiple accounts per coin, we sum them
                    coin = b['currency']
                    balances[coin] = balances.get(coin, 0) + amount
        else:
            print(f"❌ KuCoin API Error: {data.get('msg')}")
            
        return balances
    except Exception as e:
        print(f"❌ KuCoin Error: {e}")
        return {}

def get_prices(coins):
    # Use Binance API to get USDT prices for all found coins
    # We map 'COIN' -> 'COINUSDT'
    if not coins: return {}
    
    try:
        url = "https://api.binance.com/api/v3/ticker/price"
        res = requests.get(url)
        data = res.json()
        
        prices = {"USDT": 1.0, "USDC": 1.0, "BUSD": 1.0} # Stablecoin defaults
        
        for item in data:
            symbol = item['symbol']
            price = float(item['price'])
            
            # Check if this symbol ends in USDT (e.g., BTCUSDT)
            if symbol.endswith("USDT"):
                coin_name = symbol[:-4] # Remove 'USDT'
                prices[coin_name] = price
                
        return prices
    except:
        return {}

# --- MAIN ---
def main():
    print("\n🚀 CRYPTO PORTFOLIO TRACKER (Python)\n")
    
    # 1. Inputs
    b_key = BINANCE_KEY or input("Enter Binance Key (Enter to skip): ").strip()
    b_sec = BINANCE_SECRET or (getpass.getpass("Enter Binance Secret: ").strip() if b_key else "")
    
    k_key = KUCOIN_KEY or input("\nEnter KuCoin Key (Enter to skip): ").strip()
    k_sec = KUCOIN_SECRET or (getpass.getpass("Enter KuCoin Secret: ").strip() if k_key else "")
    k_pass = KUCOIN_PASSPHRASE or (getpass.getpass("Enter KuCoin Passphrase: ").strip() if k_key else "")

    print("\n⏳ Fetching data...")

    # 2. Get Balances
    binance_bal = get_binance_balances(b_key, b_sec)
    kucoin_bal = get_kucoin_balances(k_key, k_sec, k_pass)
    
    # 3. Merge Unique Coins
    all_coins = set(binance_bal.keys()) | set(kucoin_bal.keys())
    
    # 4. Get Prices
    prices = get_prices(list(all_coins))
    
    # 5. Calculate & Print
    print("\n" + "="*60)
    print(f"{'ASSET':<10} | {'BINANCE':<12} | {'KUCOIN':<12} | {'USD VALUE':<12}")
    print("-" * 60)
    
    total_usd = 0.0
    
    for coin in sorted(all_coins):
        b_qty = binance_bal.get(coin, 0.0)
        k_qty = kucoin_bal.get(coin, 0.0)
        total_qty = b_qty + k_qty
        
        price = prices.get(coin, 0.0)
        
        # If we can't find a direct USDT price, maybe try fetching BTC pair? 
        # For simplicity, we skip if price is 0 (or list as 0 value)
        
        usd_val = total_qty * price
        total_usd += usd_val
        
        # Only show significant assets (> $1 or > 0.001 qty)
        if usd_val > 0.1 or total_qty > 0.001:
            print(f"{coin:<10} | {b_qty:<12.4f} | {k_qty:<12.4f} | ${usd_val:,.2f}")

    print("="*60)
    print(f"💰 TOTAL NET WORTH: ${total_usd:,.2f}")
    print("="*60 + "\n")

if __name__ == "__main__":
    main()

---

**User:**
You said

Great! Next we move on to Gate.io. Just generate .sh, also index.html if it fits in one reply eventhough we will revisit index.html later.

---

**Gemini:**
Here are the scripts for Gate.io.

Key Technical Difference:
Gate.io uses HMAC-SHA512 (not 256) and requires you to hash the "request body" (even if empty) before signing.

1. Bash Script (gateio_get.sh)

Gate.io is very strict about the signature format. Ensure you have openssl and jq installed.

Bash
#!/bin/bash
# GATE.IO BALANCE CHECKER
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
# Step A: Hash the payload (Empty string for GET) with SHA512 -> Hex
PAYLOAD_HASH=$(printf "" | openssl dgst -sha512 | sed 's/^.* //')

# Step B: Create String to Sign
# Format: METHOD \n URL \n QUERY_STRING \n PAYLOAD_HASH \n TIMESTAMP
SIGN_STR="${METHOD}\n${PREFIX}${URL}\n${QUERY_STRING}\n${PAYLOAD_HASH}\n${TIMESTAMP}"

# Step C: Sign with Secret using HMAC-SHA512 -> Hex
SIGNATURE=$(echo -n "$SIGN_STR" | openssl dgst -sha512 -hmac "$API_SECRET" | sed 's/^.* //')

# 4. Execute Request
RESPONSE=$(curl -s -X GET "${HOST}${PREFIX}${URL}" \
     -H "KEY: $API_KEY" \
     -H "Timestamp: $TIMESTAMP" \
     -H "SIGN: $SIGNATURE" \
     -H "Content-Type: application/json")

# 5. Output
# Check if "label" exists (error usually has label/message) or check for array
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

2. HTML/JS (gateio.html)

Remember, you must use a CORS Unblocker Extension for this to work in your browser, as Gate.io (like the others) blocks direct browser requests.

HTML
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Gate.io Portfolio</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/crypto-js/4.1.1/crypto-js.min.js"></script>
</head>
<body class="bg-gray-900 text-gray-100 min-h-screen flex items-center justify-center font-mono">

    <div class="w-full max-w-lg bg-gray-800 p-8 rounded-lg shadow-2xl border border-gray-700">
        <h1 class="text-3xl font-bold mb-6 text-red-500">Gate.io Tracker</h1>

        <div class="space-y-4">
            <div>
                <label class="text-xs uppercase text-gray-500">API Key</label>
                <input type="text" id="apiKey" class="w-full bg-gray-700 border border-gray-600 rounded p-3 focus:outline-none focus:border-red-500 transition">
            </div>
            <div>
                <label class="text-xs uppercase text-gray-500">API Secret</label>
                <input type="password" id="apiSecret" class="w-full bg-gray-700 border border-gray-600 rounded p-3 focus:outline-none focus:border-red-500 transition">
            </div>
            
            <button onclick="fetchGate()" class="w-full bg-red-600 hover:bg-red-700 text-white font-bold py-3 rounded transition shadow-lg">
                Check Balance
            </button>
        </div>

        <div id="output" class="mt-6 bg-black p-4 rounded h-48 overflow-auto text-xs whitespace-pre-wrap text-red-400 font-mono border border-gray-700 hidden"></div>
    </div>

    <script>
        async function fetchGate() {
            const key = document.getElementById('apiKey').value.trim();
            const secret = document.getElementById('apiSecret').value.trim();
            const output = document.getElementById('output');
            
            output.classList.remove('hidden');
            output.innerText = "Fetching...";

            if(!key || !secret) {
                output.innerText = "Error: Key and Secret are required.";
                return;
            }

            try {
                const host = "https://api.gateio.ws";
                const prefix = "/api/v4";
                const url = "/spot/accounts";
                const method = "GET";
                const query = ""; // No query params for this endpoint
                const timestamp = Math.floor(Date.now() / 1000).toString(); // Seconds, not ms

                // 1. Generate SHA512 Hash of the Payload (Empty string for GET)
                const payloadHash = CryptoJS.SHA512("").toString(CryptoJS.enc.Hex);

                // 2. Construct String to Sign
                // Format: METHOD \n URL \n QUERY \n PAYLOAD_HASH \n TIMESTAMP
                const strToSign = `${method}\n${prefix}${url}\n${query}\n${payloadHash}\n${timestamp}`;

                // 3. Generate Signature (HMAC-SHA512)
                const signature = CryptoJS.HmacSHA512(strToSign, secret).toString(CryptoJS.enc.Hex);

                const headers = {
                    "KEY": key,
                    "Timestamp": timestamp,
                    "SIGN": signature,
                    "Content-Type": "application/json"
                };

                // 4. Send Request
                const response = await fetch(host + prefix + url, { method: "GET", headers: headers });
                
                if (!response.ok) {
                    const errText = await response.text();
                    throw new Error(`HTTP ${response.status}: ${errText}`);
                }

                const data = await response.json();
                
                // Gate.io returns an array directly, or an object with 'label' on error
                if (data.label) {
                    output.innerText = `API Error: ${data.message}`;
                    return;
                }

                const balances = data.filter(b => parseFloat(b.available) > 0 || parseFloat(b.locked) > 0);

                if(balances.length === 0) {
                    output.innerText = "Success: No active balances found.";
                } else {
                    let txt = "COIN       | AVAILABLE  | LOCKED\n-----------|------------|----------\n";
                    balances.forEach(b => {
                        txt += `${b.currency.padEnd(10)} | ${parseFloat(b.available).toFixed(4).padEnd(10)} | ${parseFloat(b.locked).toFixed(4)}\n`;
                    });
                    output.innerText = txt;
                }

            } catch (e) {
                output.innerText = `Fetch Error: ${e.message}\n(Did you enable the CORS extension?)`;
            }
        }
    </script>
</body>
</html>

---

**User:**
You said

❌ API Error:

{

  "message": "Signature mismatch",

  "label": "INVALID_SIGNATURE"

}

---

**Gemini:**
This error (INVALID_SIGNATURE) is almost always caused by how the newlines (\n) are handled in the string construction or how the timestamp is formatted. Gate.io is extremely strict about this.

Here is the Fixed Bash Script. I have switched to using printf instead of echo to guarantee that the newlines are exact, and I added a check to ensure openssl output is clean.

Fixed: gateio_get.sh
Bash
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

Why this fixes it:

printf vs echo: The previous script used echo to build the signature string. Depending on your shell (bash vs zsh vs sh), echo behaves differently regarding newlines. printf is consistent.

sed Cleanup: OpenSSL output varies by version. The sed 's/^.* //' ensures we only get the hash, stripping any (stdin)= text that breaks the signature.

Try running this updated script. If it still fails, please double-check that your API Key/Secret are correct and have "Spot" read permissions.

---

**User:**
You said

We take a break with cex apis now. What is your recommended approach for evm wallet address for free? Write me an app script only for now.

---

**Gemini:**
For tracking EVM wallets (Ethereum, Base, Arbitrum, Polygon, etc.) inside Google Sheets, the best "Free" approach is The Covalent (GoldRush) API.

Why Covalent?

One API Call: Unlike other APIs, Covalent returns the USD Value (Quote) for every token in the wallet in a single request. You don't need to fetch balances and then fetch prices separately.

Multi-Chain: It works exactly the same for Ethereum (Chain ID 1), Polygon (137), Arbitrum (42161), etc.

Free Tier: Their "GoldRush" free tier is generous enough for personal portfolio tracking.

The Google Apps Script

This script creates a menu in your Google Sheet to pull your EVM wallet balances and calculated USD value.

Open your Google Sheet.

Go to Extensions > Apps Script.

Delete any code there and paste this Code.gs.

JavaScript
/**
 * EVM WALLET TRACKER (Powered by Covalent/GoldRush)
 * * 1. Get a Free API Key here: https://goldrush.dev/platform/auth/register/
 * 2. Paste it below.
 */

const API_KEY = 'YOUR_COVALENT_API_KEY_HERE'; // <--- PASTE KEY HERE
const WALLET_ADDRESS = '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045'; // <--- REPLACE (Vitalik's Addr)

// Chain IDs: Ethereum (1), Polygon (137), Arbitrum (42161), Base (8453), Optimism (10), BSC (56)
const CHAIN_ID = '1'; 

function onOpen() {
  const ui = SpreadsheetApp.getUi();
  ui.createMenu('🪙 Crypto Tracker')
    .addItem('🔄 Refresh EVM Wallet', 'fetchEvmBalances')
    .addToUi();
}

function fetchEvmBalances() {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  
  // 1. Setup the API Endpoint
  // Docs: https://goldrush.dev/docs/api/balances/get-token-balances-for-address/
  const url = `https://api.covalenthq.com/v1/${CHAIN_ID}/address/${WALLET_ADDRESS}/balances_v2/?key=${API_KEY}&nft=false&no-nft-fetch=true`;

  try {
    // 2. Call the API
    const response = UrlFetchApp.fetch(url, { muteHttpExceptions: true });
    const json = JSON.parse(response.getContentText());

    // Error Handling
    if (json.error) {
      Browser.msgBox(`API Error: ${json.error_message}`);
      return;
    }

    const items = json.data.items;

    // 3. Prepare Data for Sheet
    // Headers: Symbol | Token Name | Balance | Price (USD) | Value (USD)
    const rows = [];
    rows.push(["SYMBOL", "TOKEN", "BALANCE", "PRICE", "TOTAL VALUE (USD)"]);

    let totalNetWorth = 0;

    items.forEach(token => {
      // Logic to handle decimals correctly
      const decimals = token.contract_decimals;
      const rawBalance = token.balance;
      
      // Skip if balance is 0
      if (rawBalance === "0") return;

      // Covalent gives specific "quote" (Total Value in USD)
      // and "quote_rate" (Price of 1 token)
      const usdValue = token.quote || 0;
      const price = token.quote_rate || 0;
      
      // Calculate human-readable balance (Raw / 10^decimals)
      // Use logic to avoid scientific notation issues if possible, though JS floats are usually fine for display
      const adjustedBalance = rawBalance / Math.pow(10, decimals);

      // Only show dust if it's worth more than $1 (optional filter)
      if (usdValue > 1.00) {
        rows.push([
          token.contract_ticker_symbol,
          token.contract_name,
          adjustedBalance,
          price,
          usdValue
        ]);
        totalNetWorth += usdValue;
      }
    });

    // 4. Write to Sheet
    // Clear old data first
    sheet.getRange('A1:E100').clearContent();
    
    // Write new data
    if (rows.length > 0) {
      sheet.getRange(1, 1, rows.length, 5).setValues(rows);
    }
    
    // Formatting
    sheet.getRange("D2:E").setNumberFormat("$#,##0.00"); // Format USD columns
    sheet.getRange("A1:E1").setFontWeight("bold").setBackground("#EEE");
    
    // Add Total at the bottom
    sheet.getRange(rows.length + 2, 4).setValue("NET WORTH:");
    sheet.getRange(rows.length + 2, 5).setValue(totalNetWorth).setNumberFormat("$#,##0.00").setFontWeight("bold");

    SpreadsheetApp.flush();
    // toast(msg, title, timeoutSeconds)
    SpreadsheetApp.getActiveSpreadsheet().toast('Wallet updated successfully!', 'Success', 3);

  } catch (e) {
    Browser.msgBox(`Script Error: ${e.message}`);
  }
}

How to use this:

Get the API Key:

Go to GoldRush.dev (formerly Covalent).

Sign up (Free).

Copy your API Key.

Edit the Script:

Paste your key into API_KEY.

Paste your wallet address into WALLET_ADDRESS.

Change CHAIN_ID if you want to track a different chain (e.g., set to 137 for Polygon).

Run:

Save the script (Floppy disk icon).

Reload your Google Sheet.

You will see a new menu "🪙 Crypto Tracker". Click Refresh EVM Wallet.

Why is this "App Script Only"?

This runs entirely on Google's servers. It does not require you to run Python on your laptop or keep a terminal open. It connects directly from your Spreadsheet to the Blockchain API.

---

**User:**
You said

Gold Rush is trial 14 days now. Consider others.

---

**Gemini:**
The GoldRush (Covalent) "trial" limitation is a recent shift towards enterprise pricing. For a "Forever Free" personal portfolio tracker in Google Sheets, you need to switch to an Indexer API (to find what you own) combined with a Price API (to find what it's worth).

The best robust, free-tier alternative is Moralis.

Free Tier: Generous "Starter" plan (40,000 Compute Units/day).

Validity: Forever (not a 14-day trial).

Coverage: Ethereum, Polygon, BSC, Arbitrum, Base, etc.

The New Strategy (Hybrid Script)

Since most "free" indexers (like Moralis or Alchemy) don't give you the USD Price in their bulk balance lookup anymore (they separate it to charge for it), we will use a smart 2-step approach in this script:

Moralis: Fetches your Token Balances (Quantity, Decimals, Symbol).

CryptoCompare: Fetches the Live Prices (Batch lookup, completely free, no API key required for basic use).

The Google Apps Script (Moralis + CryptoCompare)

Get a Moralis Key: Sign up here (Free). Copy your Web3 API Key.

Install: Open your Google Sheet -> Extensions -> Apps Script -> Paste the code below.

JavaScript
/**
 * 🪙 EVM WALLET TRACKER (Moralis + CryptoCompare)
 * ------------------------------------------------
 * Replaces Covalent/GoldRush. 
 * Uses Moralis for Balances (Free Tier: 40k CUs/day)
 * Uses CryptoCompare for Pricing (Free, no key needed for basic)
 */

// 1. SETUP
const MORALIS_API_KEY = 'YOUR_MORALIS_API_KEY_HERE'; // <--- PASTE MORALIS KEY
const WALLET_ADDRESS = '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045'; // <--- PASTE WALLET ADDRESS

// 2. CHAIN SELECTION (Hex format for Moralis)
// Ethereum: '0x1' | Polygon: '0x89' | BSC: '0x38' | Arbitrum: '0xa4b1' | Base: '0x2105'
const CHAIN = '0x1'; 

function onOpen() {
  const ui = SpreadsheetApp.getUi();
  ui.createMenu('🪙 Crypto Tracker')
    .addItem('🔄 Refresh Portfolio', 'refreshPortfolio')
    .addToUi();
}

function refreshPortfolio() {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  sheet.getRange("A1").setValue("Loading Balances...");
  
  try {
    // --- STEP 1: Get Balances from Moralis ---
    // Endpoint: https://docs.moralis.io/web3-data-api/evm/reference/get-wallet-token-balances
    const url = `https://deep-index.moralis.io/api/v2.2/${WALLET_ADDRESS}/erc20?chain=${CHAIN}&exclude_spam=true`;
    
    const options = {
      'method': 'get',
      'headers': { 'X-API-Key': MORALIS_API_KEY, 'accept': 'application/json' }
    };
    
    const response = UrlFetchApp.fetch(url, options);
    const data = JSON.parse(response.getContentText());
    
    if (!data || data.length === 0) {
      Browser.msgBox("No tokens found or API Error.");
      return;
    }

    // Process Balances
    let tokens = [];
    let symbolsToFetch = [];
    
    data.forEach(token => {
      const decimals = token.decimals;
      const rawBalance = token.balance;
      const symbol = token.symbol;
      
      // Calculate readable balance
      const balance = rawBalance / Math.pow(10, decimals);
      
      // Filter dust (e.g., less than 0.0001) to save price calls and sheet space
      if (balance > 0.00001) {
        tokens.push({
          name: token.name,
          symbol: symbol,
          balance: balance,
          contract: token.token_address
        });
        // Add to list for price fetching (CryptoCompare limits batch size, but 30-50 usually ok)
        // We ensure symbols are uppercase for matching
        if(symbol) symbolsToFetch.push(symbol.toUpperCase());
      }
    });

    // --- STEP 2: Get Prices from CryptoCompare ---
    // We batch fetch prices to avoid hitting rate limits with a loop
    // Note: CryptoCompare uses Symbols. For 100% accuracy we'd use Contract Addresses, 
    // but their free Contract endpoint is stricter. Symbols work for 99% of major tokens.
    
    let priceMap = {};
    if (symbolsToFetch.length > 0) {
      // Fetch in chunks of 20 to be safe
      const chunkSize = 20;
      for (let i = 0; i < symbolsToFetch.length; i += chunkSize) {
        const chunk = symbolsToFetch.slice(i, i + chunkSize);
        const symbolsStr = chunk.join(',');
        
        // CryptoCompare Price Endpoint
        const priceUrl = `https://min-api.cryptocompare.com/data/pricemulti?fsyms=${symbolsStr}&tsyms=USD`;
        
        try {
          const priceResp = UrlFetchApp.fetch(priceUrl, {muteHttpExceptions:true});
          const priceJson = JSON.parse(priceResp.getContentText());
          
          // Merge into main price map
          for (const [sym, vals] of Object.entries(priceJson)) {
            priceMap[sym] = vals.USD;
          }
        } catch (e) {
          console.log("Price fetch error for chunk: " + symbolsStr);
        }
        
        // Slight pause to be polite to the API
        Utilities.sleep(100);
      }
    }

    // --- STEP 3: Write to Sheet ---
    const rows = [];
    rows.push(["NAME", "SYMBOL", "BALANCE", "PRICE ($)", "VALUE ($)"]);
    
    let totalValue = 0;
    
    tokens.forEach(t => {
      const price = priceMap[t.symbol.toUpperCase()] || 0;
      const value = t.balance * price;
      
      if (value > 0.01 || t.balance > 0) { // Filter out zero value lines if preferred
         rows.push([t.name, t.symbol, t.balance, price, value]);
         totalValue += value;
      }
    });

    // Clear old data
    sheet.getRange('A1:E100').clearContent();
    
    // Paste new data
    if (rows.length > 0) {
      sheet.getRange(1, 1, rows.length, 5).setValues(rows);
    }
    
    // Formatting
    sheet.getRange("D2:E").setNumberFormat("$#,##0.00");
    sheet.getRange("A1:E1").setFontWeight("bold").setBackground("#d9d9d9");
    
    // Summary
    sheet.getRange(rows.length + 2, 4).setValue("NET WORTH:");
    sheet.getRange(rows.length + 2, 5).setValue(totalValue).setNumberFormat("$#,##0.00").setFontWeight("bold");
    
    SpreadsheetApp.getActiveSpreadsheet().toast('Portfolio Updated!', 'Success', 3);

  } catch (err) {
    Browser.msgBox(`Error: ${err.message}`);
  }
}

Why this is better than GoldRush

No "Analyst" Trial: Moralis Free Tier is designed for developers building apps. It doesn't expire; it just resets your "Compute Units" (CUs) daily.

Separate Price Feed: By offloading the pricing to CryptoCompare (which is famously free/open for basic prices), you save your Moralis credits for what they are good at: scanning the blockchain.

Spam Filter: The script uses exclude_spam=true in the Moralis call, which automatically cleans up your sheet from those fake airdrop tokens that clutter Etherscan.

Other Alternatives

If you ever outgrow Moralis, here is the hierarchy of "Free" EVM data:

Provider	Pros	Cons
Moralis	Best JSON structure, Spam filter included.	Daily limit (40k CU) is generous but finite.
Alchemy	Massive free tier (30M CUs/month).	Returns raw HEX data (harder to parse in Sheets).
Chainbase	Good free tier (100k calls/day).	Newer, less documentation for Apps Script.
Etherscan	completely free keys.	Hard to "get all tokens" in one call (need to loop).
Export to Sheets

---

**User:**
You said

Remove UI etc and just print in execution log.

---

**Gemini:**
Here is the Apps Script stripped of all UI/Spreadsheet elements. It runs entirely in the backend and outputs the results to the Execution Log.

Instructions

Paste this code into the script editor.

Add your Moralis API Key and Wallet Address.

Click Run.

View the output in the Execution Log tab at the bottom of the screen (or press Ctrl + Enter).

Code.gs
JavaScript
/**
 * 🪙 EVM WALLET TRACKER (Console Version)
 * ------------------------------------------------
 * prints portfolio value directly to the Execution Log.
 */

// --- CONFIGURATION ---
const MORALIS_API_KEY = 'YOUR_MORALIS_KEY_HERE'; // <--- PASTE KEY
const WALLET_ADDRESS = '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045'; // <--- PASTE ADDRESS

// Chain IDs (Hex): Ethereum (0x1), Polygon (0x89), BSC (0x38), Arbitrum (0xa4b1)
const CHAIN = '0x1'; 

function checkPortfolio() {
  console.log(`🔍 Fetching balances for: ${WALLET_ADDRESS} (Chain: ${CHAIN})...`);
  
  try {
    // 1. Fetch Balances (Moralis)
    const url = `https://deep-index.moralis.io/api/v2.2/${WALLET_ADDRESS}/erc20?chain=${CHAIN}&exclude_spam=true`;
    const options = {
      'method': 'get',
      'headers': { 'X-API-Key': MORALIS_API_KEY, 'accept': 'application/json' }
    };
    
    const response = UrlFetchApp.fetch(url, options);
    const data = JSON.parse(response.getContentText());
    
    if (!data || data.length === 0) {
      console.warn("⚠️ No tokens found.");
      return;
    }

    // 2. Filter & Prepare for Pricing
    let tokens = [];
    let symbolsToFetch = [];

    data.forEach(token => {
      const decimals = token.decimals;
      const rawBalance = token.balance;
      const symbol = token.symbol;
      
      const balance = rawBalance / Math.pow(10, decimals);
      
      // Filter dust (e.g. < 0.001)
      if (balance > 0.001) {
        tokens.push({
          name: token.name,
          symbol: symbol,
          balance: balance,
          contract: token.token_address
        });
        if(symbol) symbolsToFetch.push(symbol.toUpperCase());
      }
    });

    console.log(`✅ Found ${tokens.length} active tokens. Fetching prices...`);

    // 3. Fetch Prices (CryptoCompare)
    let priceMap = {};
    if (symbolsToFetch.length > 0) {
      // Fetch in chunks of 20
      for (let i = 0; i < symbolsToFetch.length; i += 20) {
        const chunk = symbolsToFetch.slice(i, i + 20);
        const priceUrl = `https://min-api.cryptocompare.com/data/pricemulti?fsyms=${chunk.join(',')}&tsyms=USD`;
        
        try {
          const priceResp = UrlFetchApp.fetch(priceUrl, {muteHttpExceptions:true});
          const priceJson = JSON.parse(priceResp.getContentText());
          for (const [sym, vals] of Object.entries(priceJson)) {
            priceMap[sym] = vals.USD;
          }
        } catch (e) {
          console.error("Price fetch error:", e);
        }
        Utilities.sleep(100); // Rate limit pause
      }
    }

    // 4. Calculate & Print Report
    let totalNetWorth = 0;
    
    console.log("---------------------------------------------------------------");
    console.log("SYMBOL".padEnd(10) + " | " + "BALANCE".padEnd(15) + " | " + "PRICE".padEnd(10) + " | " + "VALUE (USD)");
    console.log("---------------------------------------------------------------");

    tokens.forEach(t => {
      const price = priceMap[t.symbol.toUpperCase()] || 0;
      const value = t.balance * price;
      
      if (value > 0.1 || t.balance > 0.01) {
        totalNetWorth += value;
        console.log(
          t.symbol.padEnd(10) + " | " + 
          t.balance.toFixed(4).padEnd(15) + " | " + 
          "$" + price.toFixed(2).padEnd(9) + " | " + 
          "$" + value.toFixed(2)
        );
      }
    });

    console.log("---------------------------------------------------------------");
    console.log(`💰 TOTAL NET WORTH: $${totalNetWorth.toFixed(2)}`);
    console.log("---------------------------------------------------------------");

  } catch (err) {
    console.error(`❌ ERROR: ${err.message}`);
  }
}

---

