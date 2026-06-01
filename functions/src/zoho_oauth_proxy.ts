import fetch from 'node-fetch';
import * as functions from 'firebase-functions';

type ZohoGrantType = 'authorization_code' | 'refresh_token';

interface ZohoOAuthTokenExchangeData {
  code?: string;
  redirectUri?: string;
  grantType?: ZohoGrantType;
  refreshToken?: string;
}

interface ZohoTokenApiResponse {
  access_token?: string;
  refresh_token?: string;
  expires_in?: number;
  error?: string;
  error_description?: string;
}

export const zohoOAuthTokenExchange = functions.https.onCall(
  async (data: ZohoOAuthTokenExchangeData) => {
    const clientId = process.env.ZOHO_CLIENT_ID?.trim();
    const clientSecret = process.env.ZOHO_CLIENT_SECRET?.trim();

    if (!clientId || !clientSecret) {
      throw new functions.https.HttpsError(
        'internal',
        'Zoho OAuth credentials are not configured.',
      );
    }

    const grantType = data?.grantType;
    if (
      grantType !== 'authorization_code' &&
      grantType !== 'refresh_token'
    ) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'grantType must be either "authorization_code" or "refresh_token".',
      );
    }

    const body = new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      grant_type: grantType,
    });

    if (grantType === 'authorization_code') {
      const code = data?.code?.trim() ?? '';
      const redirectUri = data?.redirectUri?.trim() ?? '';
      if (!code || !redirectUri) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'code and redirectUri are required for authorization_code exchanges.',
        );
      }

      body.set('code', code);
      body.set('redirect_uri', redirectUri);
    } else {
      const refreshToken = data?.refreshToken?.trim() ?? '';
      if (!refreshToken) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'refreshToken is required for refresh_token exchanges.',
        );
      }

      body.set('refresh_token', refreshToken);
    }

    try {
      const response = await fetch('https://accounts.zoho.com/oauth/v2/token', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body.toString(),
      });

      const payload = (await response.json()) as ZohoTokenApiResponse;

      if (!response.ok || !payload.access_token) {
        throw new functions.https.HttpsError(
          'internal',
          payload.error_description ||
            payload.error ||
            'Zoho OAuth token exchange failed.',
        );
      }

      return {
        accessToken: payload.access_token,
        refreshToken: payload.refresh_token ?? null,
        expiresIn: payload.expires_in ?? 3600,
      };
    } catch (error) {
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      throw new functions.https.HttpsError(
        'internal',
        'Zoho OAuth token exchange failed.',
        error instanceof Error ? error.message : String(error),
      );
    }
  },
);
