"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.zohoOAuthTokenExchange = void 0;
const node_fetch_1 = __importDefault(require("node-fetch"));
const functions = __importStar(require("firebase-functions"));
exports.zohoOAuthTokenExchange = functions.https.onCall(async (data) => {
    const clientId = process.env.ZOHO_CLIENT_ID?.trim();
    const clientSecret = process.env.ZOHO_CLIENT_SECRET?.trim();
    if (!clientId || !clientSecret) {
        throw new functions.https.HttpsError('internal', 'Zoho OAuth credentials are not configured.');
    }
    const grantType = data?.grantType;
    if (grantType !== 'authorization_code' &&
        grantType !== 'refresh_token') {
        throw new functions.https.HttpsError('invalid-argument', 'grantType must be either "authorization_code" or "refresh_token".');
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
            throw new functions.https.HttpsError('invalid-argument', 'code and redirectUri are required for authorization_code exchanges.');
        }
        body.set('code', code);
        body.set('redirect_uri', redirectUri);
    }
    else {
        const refreshToken = data?.refreshToken?.trim() ?? '';
        if (!refreshToken) {
            throw new functions.https.HttpsError('invalid-argument', 'refreshToken is required for refresh_token exchanges.');
        }
        body.set('refresh_token', refreshToken);
    }
    try {
        const response = await (0, node_fetch_1.default)('https://accounts.zoho.com/oauth/v2/token', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: body.toString(),
        });
        const payload = (await response.json());
        if (!response.ok || !payload.access_token) {
            throw new functions.https.HttpsError('internal', payload.error_description ||
                payload.error ||
                'Zoho OAuth token exchange failed.');
        }
        return {
            accessToken: payload.access_token,
            refreshToken: payload.refresh_token ?? null,
            expiresIn: payload.expires_in ?? 3600,
        };
    }
    catch (error) {
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', 'Zoho OAuth token exchange failed.', error instanceof Error ? error.message : String(error));
    }
});
//# sourceMappingURL=zoho_oauth_proxy.js.map