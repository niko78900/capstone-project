import { Routes } from '@angular/router';
import { adminAuthGuard } from './core/guards/admin-auth.guard';
import { authGuard } from './core/guards/auth.guard';

export const routes: Routes = [
  { path: '', pathMatch: 'full', redirectTo: 'products' },
  {
    path: 'products',
    loadComponent: () =>
      import('./features/public/product-list/product-list.page').then(
        (module) => module.ProductListPageComponent,
      ),
  },
  {
    path: 'products/:id',
    loadComponent: () =>
      import('./features/public/product-detail/product-detail.page').then(
        (module) => module.ProductDetailPageComponent,
      ),
  },
  {
    path: 'login',
    loadComponent: () =>
      import('./features/admin/admin-login/admin-login.page').then(
        (module) => module.AdminLoginPageComponent,
      ),
  },
  { path: 'admin/login', pathMatch: 'full', redirectTo: 'login' },
  {
    path: 'rewards',
    canActivate: [authGuard],
    loadComponent: () =>
      import('./features/admin/admin-rewards/admin-rewards.page').then(
        (module) => module.AdminRewardsPageComponent,
      ),
  },
  {
    path: 'admin',
    pathMatch: 'full',
    canActivate: [adminAuthGuard],
    loadComponent: () =>
      import('./features/admin/admin-dashboard/admin-dashboard.page').then(
        (module) => module.AdminDashboardPageComponent,
      ),
  },
  {
    path: 'admin/submissions',
    canActivate: [adminAuthGuard],
    loadComponent: () =>
      import('./features/admin/admin-submissions/admin-submissions.page').then(
        (module) => module.AdminSubmissionsPageComponent,
      ),
  },
  {
    path: 'admin/submissions/:id',
    canActivate: [adminAuthGuard],
    loadComponent: () =>
      import('./features/admin/admin-submissions/admin-submission-detail.page').then(
        (module) => module.AdminSubmissionDetailPageComponent,
      ),
  },
  { path: 'admin/rewards', pathMatch: 'full', redirectTo: 'rewards' },
  { path: '**', redirectTo: 'products' },
];
