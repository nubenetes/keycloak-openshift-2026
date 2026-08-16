import { Injectable } from '@angular/core';
import { BehaviorSubject, Observable } from 'rxjs';

export interface UserProfile {
  username: string;
  email: string;
  name: string;
  roles: string[];
  groups: string[];
}

@Injectable({
  providedIn: 'root',
})
export class AuthService {
  private readonly issuerUrl = 'https://sso.enterprise.example.com/realms/enterprise';
  private readonly clientId = 'angular-spa';
  private readonly redirectUri = window.location.origin + '/callback';

  private userSubject = new BehaviorSubject<UserProfile | null>(null);
  public user$: Observable<UserProfile | null> = this.userSubject.asObservable();

  constructor() {
    this.checkSession();
  }

  /**
   * Generates a cryptographically random code_verifier (OAuth 2.1 RFC 7636)
   */
  private generateRandomString(length: number): string {
    const charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    let result = '';
    const values = new Uint8Array(length);
    crypto.getRandomValues(values);
    for (let i = 0; i < length; i++) {
      result += charset[values[i] % charset.length];
    }
    return result;
  }

  /**
   * Generates SHA-256 code_challenge for PKCE
   */
  private async generateCodeChallenge(verifier: string): Promise<string> {
    const encoder = new TextEncoder();
    const data = encoder.encode(verifier);
    const digest = await crypto.subtle.digest('SHA-256', data);
    return btoa(String.fromCharCode(...new Uint8Array(digest)))
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '');
  }

  /**
   * Initiates Authorization Code Flow with PKCE
   */
  public async login(): Promise<void> {
    const codeVerifier = this.generateRandomString(64);
    const state = this.generateRandomString(32);
    const codeChallenge = await this.generateCodeChallenge(codeVerifier);

    sessionStorage.setItem('pkce_verifier', codeVerifier);
    sessionStorage.setItem('oauth_state', state);

    const authUrl = new URL(`${this.issuerUrl}/protocol/openid-connect/auth`);
    authUrl.searchParams.append('client_id', this.clientId);
    authUrl.searchParams.append('response_type', 'code');
    authUrl.searchParams.append('scope', 'openid profile email groups microservices.read');
    authUrl.searchParams.append('redirect_uri', this.redirectUri);
    authUrl.searchParams.append('state', state);
    authUrl.searchParams.append('code_challenge', codeChallenge);
    authUrl.searchParams.append('code_challenge_method', 'S256');

    window.location.href = authUrl.toString();
  }

  /**
   * Handles callback from Keycloak after authentication
   */
  public async handleCallback(): Promise<void> {
    const params = new URLSearchParams(window.location.search);
    const code = params.get('code');
    const state = params.get('state');
    const savedState = sessionStorage.getItem('oauth_state');
    const codeVerifier = sessionStorage.getItem('pkce_verifier');

    if (!code || state !== savedState || !codeVerifier) {
      throw new Error('Invalid OAuth 2.1 PKCE state or authorization code missing.');
    }

    const tokenUrl = `${this.issuerUrl}/protocol/openid-connect/token`;
    const body = new URLSearchParams({
      grant_type: 'authorization_code',
      client_id: this.clientId,
      code,
      redirect_uri: this.redirectUri,
      code_verifier: codeVerifier,
    });

    const response = await fetch(tokenUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString(),
    });

    if (!response.ok) {
      throw new Error(`Token exchange failed with status ${response.status}`);
    }

    const tokenData = await response.json();
    sessionStorage.setItem('access_token', tokenData.access_token);
    sessionStorage.setItem('id_token', tokenData.id_token);

    // Clean up temporary PKCE values
    sessionStorage.removeItem('pkce_verifier');
    sessionStorage.removeItem('oauth_state');

    this.parseTokenClaims(tokenData.id_token);
  }

  private parseTokenClaims(idToken: string): void {
    const payloadBase64 = idToken.split('.')[1];
    const claims = JSON.parse(atob(payloadBase64));
    this.userSubject.next({
      username: claims.preferred_username || claims.sub,
      email: claims.email || '',
      name: claims.name || '',
      roles: claims.realm_access?.roles || [],
      groups: claims.groups || [],
    });
  }

  public logout(): void {
    sessionStorage.clear();
    const logoutUrl = `${this.issuerUrl}/protocol/openid-connect/logout?post_logout_redirect_uri=${encodeURIComponent(window.location.origin)}`;
    window.location.href = logoutUrl;
  }

  private checkSession(): void {
    const idToken = sessionStorage.getItem('id_token');
    if (idToken) {
      this.parseTokenClaims(idToken);
    }
  }
}
