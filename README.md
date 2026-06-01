# roipayroll

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Automated Payslip Notifications and Email

- In-app payroll notifications are sent when payroll is processed.
- Payslip email jobs are written to Firestore collection `mail`.
- Setup instructions: `FIREBASE_EMAIL_SETUP.md`
- Firestore rules snippet for `mail`: `firestore.mail.rules.snippet`

## Development & Build Commands

### Run locally (with Zoho proxy running on localhost)

Start the proxy first:

```powershell
cd zoho_proxy
npm install
node server.js
```

Then run the Flutter app:

```powershell
flutter run -d chrome `
  --dart-define=ROI_ZOHO_CLIENT_ID=1000.XNSIQ0JPL7AWSKE39ZUFBA7IIMPUZH `
  --dart-define=ROI_ZOHO_CLIENT_SECRET=<your Zoho client secret> `
  --dart-define=ROI_ZOHO_PROXY_URL=http://localhost:3000
```

### Build for production (after Render deployment)

```powershell
flutter build web `
  --dart-define=ROI_ZOHO_CLIENT_ID=1000.XNSIQ0JPL7AWSKE39ZUFBA7IIMPUZH `
  --dart-define=ROI_ZOHO_CLIENT_SECRET=<your Zoho client secret> `
  --dart-define=ROI_ZOHO_PROXY_URL=https://roipayroll-zoho-proxy.onrender.com
```

### Deploy to Firebase Hosting

```powershell
firebase deploy --only hosting --project roipayroll-72aef
```

### Render.com Proxy Deployment Steps

1. Push the `zoho_proxy/` folder to GitHub.
2. Go to Render.com, then choose New > Web Service.
3. Connect your GitHub repo.
4. Set root directory to `zoho_proxy`.
5. Set environment variables in the Render dashboard:
   - `ZOHO_CLIENT_ID` = your Zoho client ID
   - `ZOHO_CLIENT_SECRET` = your Zoho client secret
6. Deploy. Render gives you a URL like:
   `https://roipayroll-zoho-proxy.onrender.com`
7. Use that URL in your Flutter build command as `ROI_ZOHO_PROXY_URL`.
8. Rebuild and redeploy the Flutter web app.
