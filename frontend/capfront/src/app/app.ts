import { Component, computed, inject } from '@angular/core';
import { RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatToolbarModule } from '@angular/material/toolbar';
import { AuthService } from './core/services/auth.service';
import { AuthSessionService } from './core/services/auth-session.service';

@Component({
  selector: 'app-root',
  imports: [RouterOutlet, RouterLink, RouterLinkActive, MatButtonModule, MatToolbarModule],
  templateUrl: './app.html',
  styleUrl: './app.css',
})
export class App {
  private readonly authService = inject(AuthService);
  private readonly authSession = inject(AuthSessionService);

  readonly currentUser = this.authSession.session;
  readonly isAdmin = this.authSession.isAdmin;
  readonly adminActionLabel = computed(() =>
    this.isAdmin() ? 'Admin Dashboard' : 'Admin Login',
  );

  logout(): void {
    this.authService.logout();
  }
}
