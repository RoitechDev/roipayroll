# RoiPayroll production build script
# Usage: .\build.ps1

flutter build web `
  --dart-define=ROI_ZOHO_CLIENT_ID=1000.XNSIQ0JPL7AWSKE39ZUFBA7IIMPUZH `
  --dart-define=ROI_ZOHO_CLIENT_SECRET=b0a24ee79cf15f4fba862e967ddd1a730428f24ace `
  --dart-define=ROI_ZOHO_PROXY_URL=https://roipayroll-zoho-proxy.onrender.com

Write-Host "Build complete. Run 'firebase deploy --only hosting --project roipayroll-72aef' to deploy."
