import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { AuthService, UserProfile } from './auth.service';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="container">
      <header class="header">
        <h1>Enterprise Portal (Angular 18+ & Keycloak)</h1>
        <div class="auth-actions">
          <ng-container *ngIf="user$ | async as user; else loginTpl">
            <span class="user-badge">{{ user.name || user.username }} ({{ user.email }})</span>
            <button class="btn btn-logout" (click)="logout()">Sign Out</button>
          </ng-container>
          <ng-template #loginTpl>
            <button class="btn btn-login" (click)="login()">Sign In with Keycloak SSO</button>
          </ng-template>
        </div>
      </header>

      <main class="content">
        <section class="card" *ngIf="user$ | async as user; else noAuthTpl">
          <h2>Active Identity Claims</h2>
          <p><strong>Username:</strong> {{ user.username }}</p>
          <p><strong>Email:</strong> {{ user.email }}</p>
          <div class="claims-section">
            <h3>Assigned Realm Roles</h3>
            <span class="tag role-tag" *ngFor="let role of user.roles">{{ role }}</span>
          </div>
          <div class="claims-section">
            <h3>Enterprise Groups (Entra ID / AD)</h3>
            <span class="tag group-tag" *ngFor="let group of user.groups">{{ group }}</span>
          </div>
        </section>

        <ng-template #noAuthTpl>
          <div class="hero-box">
            <h2>Welcome to Enterprise OpenShift Identity</h2>
            <p>Authenticate securely using OAuth 2.1 Authorization Code Flow with PKCE.</p>
          </div>
        </ng-template>
      </main>
    </div>
  `,
  styles: [`
    .container { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; max-width: 900px; margin: 0 auto; padding: 2rem; }
    .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 2px solid #e2e8f0; padding-bottom: 1rem; }
    .btn { padding: 0.6rem 1.2rem; border-radius: 6px; font-weight: 600; cursor: pointer; border: none; }
    .btn-login { background-color: #0284c7; color: white; }
    .btn-logout { background-color: #ef4444; color: white; }
    .user-badge { margin-right: 1rem; font-weight: 500; }
    .card { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 1.5rem; margin-top: 1.5rem; }
    .claims-section { margin-top: 1rem; }
    .tag { display: inline-block; padding: 0.25rem 0.6rem; border-radius: 9999px; font-size: 0.85rem; font-weight: 600; margin-right: 0.5rem; margin-top: 0.25rem; }
    .role-tag { background-color: #dbeafe; color: #1e40af; }
    .group-tag { background-color: #dcfce7; color: #166534; }
    .hero-box { text-align: center; padding: 4rem 2rem; background: #f1f5f9; border-radius: 8px; margin-top: 2rem; }
  `]
})
export class AppComponent implements OnInit {
  user$ = this.authService.user$;

  constructor(private authService: AuthService) {}

  async ngOnInit(): Promise<void> {
    if (window.location.search.includes('code=')) {
      try {
        await this.authService.handleCallback();
        window.history.replaceState({}, document.title, window.location.pathname);
      } catch (err) {
        console.error('Authentication callback error:', err);
      }
    }
  }

  login(): void {
    this.authService.login();
  }

  logout(): void {
    this.authService.logout();
  }
}
