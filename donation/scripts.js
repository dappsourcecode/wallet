const cryptoWalletDonationSelect = document.getElementById('crypto-wallet-donation-select');
const cryptoWalletDonationAddressText = document.getElementById('crypto-wallet-donation-address-text');
const cryptoWalletDonationAddressQR = document.getElementById('crypto-wallet-donation-address-qr');

fetch('https://0fajarpurnama0.github.io/assets/json/donation.json')
    .then(response => response.json())
    .then(data => {
        data.cryptowallet.forEach(wallet => {
            cryptoWalletDonationSelect.innerHTML += `<option value="${wallet.address}">${wallet.name}</option>`;
        });
    })
    .catch(error => console.error('Error fetching donations:', error));

cryptoWalletDonationSelect.addEventListener('change', function() {
    const selectedAddress = cryptoWalletDonationSelect.value;
    cryptoWalletDonationAddressText.innerHTML = `<a href="${selectedAddress}"><span class="wallet-address">${selectedAddress}</span></a> <button id="copy-${selectedAddress}">Copy</button>`;
    document.getElementById(`copy-${selectedAddress}`).addEventListener('click', function() {
        copyToClipBoard(selectedAddress);
    });
    cryptoWalletDonationAddressQR.innerHTML = '';
    new QRCode(cryptoWalletDonationAddressQR, selectedAddress);
});

function copyToClipBoard(text) {
    navigator.clipboard.writeText(text)
        .then(() => {
            document.getElementById(`copy-${text}`).innerText = 'Copied!';
        })
        .catch(err => {
            document.getElementById(`copy-${text}`).innerText = err.message || 'Failed to copy';
            console.error('Failed to copy: ', err);
        });
}