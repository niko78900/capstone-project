import { Component, computed, inject } from '@angular/core';
import { RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatToolbarModule } from '@angular/material/toolbar';
import { AuthService } from './core/services/auth.service';
import { AuthSessionService } from './core/services/auth-session.service';
import { ThemeService } from './core/services/theme.service';

@Component({
  selector: 'app-root',
  imports: [RouterOutlet, RouterLink, RouterLinkActive, MatButtonModule, MatToolbarModule],
  templateUrl: './app.html',
  styleUrl: './app.css',
})
export class App {
  private readonly authService = inject(AuthService);
  private readonly authSession = inject(AuthSessionService);
  private readonly theme = inject(ThemeService);

  readonly currentUser = this.authSession.session;
  readonly isAdmin = this.authSession.isAdmin;
  readonly isDarkTheme = this.theme.isDark;
  readonly themeToggleLabel = computed(() =>
    this.isDarkTheme() ? 'Light theme' : 'Dark theme',
  );
  readonly adminActionLabel = computed(() =>
    this.isAdmin() ? 'Admin Dashboard' : 'Admin Login',
  );

  toggleTheme(): void {
    this.theme.toggle();
  }

  logout(): void {
    this.authService.logout();
  }
}
