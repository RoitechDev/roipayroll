# Automated Payslip Email Setup

This project now writes payslip email jobs to Firestore collection: `mail`.

Code path:
- `lib/services/payroll_service.dart`
- method `_notifyAndQueuePayslip(...)`

It creates:
- in-app notification to the employee user
- one Firestore `mail` document with PDF attachment (base64)

To actually send email, enable Firebase "Trigger Email" extension.

## 1. Install Extension

In Firebase Console for project `roipayroll-72aef`:

1. Open `Extensions`
2. Install extension: `Trigger Email` (`firestore-send-email`)
3. Use these values:
   - Firestore collection: `mail`
   - Default "from" name/address: your payroll sender
   - SMTP connection string: from your SMTP provider

SMTP format example:

`smtps://USERNAME:PASSWORD@smtp.yourprovider.com:465`

Common providers:
- SendGrid SMTP
- Mailgun SMTP
- Zoho SMTP
- Office365 SMTP

## 2. Firestore Rules (mail)

Add the `mail` match block from:

- `firestore.mail.rules.snippet`

into your main Firestore rules under:

`match /databases/{database}/documents { ... }`

## 3. Deploy Firestore Rules

If your rules are managed in repo:

1. merge snippet into your `firestore.rules`
2. deploy:
   - `firebase deploy --only firestore:rules`

If your rules are managed in Firebase Console:

1. open Firestore Rules tab
2. paste snippet into your existing rules structure
3. publish rules

## 4. Validate End-to-End

1. Process payroll from app
2. Confirm employee gets in-app notification
3. Confirm Firestore has new document in `mail`
4. Wait for extension to process
5. Confirm:
   - message leaves `pending` state
   - employee receives payslip email attachment

## 5. Troubleshooting

If no emails are sent:

1. Check extension logs in Firebase Console -> Extensions -> Trigger Email -> Logs
2. Verify SMTP credentials are valid
3. Verify SMTP sender is allowed by provider
4. Confirm app has permission to create `mail` docs for the payroll user role
5. Confirm employee records have valid `email` values

