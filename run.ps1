# RoiPayroll quick run script
# Usage: .\run.ps1
# Usage with local proxy: .\run.ps1 -local

param(
  [switch]$local
)

$proxyUrl = if ($local) {
  "http://localhost:3000"
} else {
  "https://roipayroll-zoho-proxy.onrender.com"
}

flutter run -d edge `
  --dart-define=ROI_ZOHO_CLIENT_ID=1000.XNSIQ0JPL7AWSKE39ZUFBA7IIMPUZH `
  --dart-define=ROI_ZOHO_CLIENT_SECRET=b0a24ee79cf15f4fba862e967ddd1a730428f24ace `
  --dart-define=ROI_ZOHO_PROXY_URL=$proxyUrl
