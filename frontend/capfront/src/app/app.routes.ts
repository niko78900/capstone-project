import { Routes } from '@angular/router';
import { adminAuthGuard } from './core/guards/admin-auth.guard';
import { AdminDashboardPageComponent } from './features/admin/admin-dashboard/admin-dashboard.page';
import { AdminLoginPageComponent } from './features/admin/admin-login/admin-login.page';
import { AdminRewardsPageComponent } from './features/admin/admin-rewards/admin-rewards.page';
import { AdminSubmissionDetailPageComponent } from './features/admin/admin-submissions/admin-submission-detail.page';
import { AdminSubmissionsPageComponent } from './features/admin/admin-submissions/admin-submissions.page';
import { ProductDetailPageComponent } from './features/public/product-detail/product-detail.page';
import { ProductListPageComponent } from './features/public/product-list/product-list.page';

export const routes: Routes = [
  { path: '', pathMatch: 'full', redirectTo: 'products' },
  { path: 'products', component: ProductListPageComponent },
  { path: 'products/:id', component: ProductDetailPageComponent },
  { path: 'admin/login', component: AdminLoginPageComponent },
  {
    path: 'admin',
    pathMatch: 'full',
    canActivate: [adminAuthGuard],
    component: AdminDashboardPageComponent,
  },
  {
    path: 'admin/submissions',
    canActivate: [adminAuthGuard],
    component: AdminSubmissionsPageComponent,
  },
  {
    path: 'admin/submissions/:id',
    canActivate: [adminAuthGuard],
    component: AdminSubmissionDetailPageComponent,
  },
  {
    path: 'admin/rewards',
    canActivate: [adminAuthGuard],
    component: AdminRewardsPageComponent,
  },
  { path: '**', redirectTo: 'products' },
];
