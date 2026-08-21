// File purpose: Defines Angular behavior for app.
import { Component, computed, inject } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { NavigationEnd, Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatToolbarModule } from '@angular/material/toolbar';
import { filter, map, startWith } from 'rxjs';
import { AuthService } from './core/services/auth.service';
import { AuthSessionService } from './core/services/auth-session.service';
import { ThemeService } from './core/services/theme.service';

interface NavItem {
  label: string;
  link: string;
  exact?: boolean;
}

@Component({
  selector: 'app-root',
  imports: [
    RouterOutlet,
    RouterLink,
    RouterLinkActive,
    MatButtonModule,
    MatIconModule,
    MatToolbarModule,
  ],
  templateUrl: './app.html',
  styleUrl: './app.css',
})
export class App {
  private readonly authService = inject(AuthService);
  private readonly authSession = inject(AuthSessionService);
  private readonly theme = inject(ThemeService);
  private readonly router = inject(Router);
  private readonly currentUrl = toSignal(
    this.router.events.pipe(
      filter((event): event is NavigationEnd => event instanceof NavigationEnd),
      map((event) => event.urlAfterRedirects),
      startWith(this.router.url),
    ),
    { initialValue: this.router.url },
  );

  readonly currentUser = this.authSession.session;
  readonly isAuthenticated = this.authSession.isAuthenticated;
  readonly isAdmin = this.authSession.isAdmin;
  readonly isDarkTheme = this.theme.isDark;
  readonly isLoginRoute = computed(() => this.currentUrl().startsWith('/login'));
  readonly isAdminRoute = computed(() => this.currentUrl().startsWith('/admin'));
  readonly themeToggleLabel = computed(() => (this.isDarkTheme() ? 'Light theme' : 'Dark theme'));
  readonly navItems = computed<NavItem[]>(() => {
    const items: NavItem[] = [{ label: 'Products', link: '/products', exact: true }];

    if (this.isAuthenticated()) {
      items.push({ label: 'Rewards', link: '/rewards', exact: true });
      if (this.isAdmin()) {
        items.push({ label: 'Moderation', link: '/admin/submissions' });
      }
    }

    return items;
  });

  toggleTheme(): void {
    this.theme.toggle();
  }

  logout(): void {
    this.authService.logout();
    void this.router.navigateByUrl('/products');
  }
}
