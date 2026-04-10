import { Routes } from '@angular/router';
import { ProductDetailPageComponent } from './features/public/product-detail/product-detail.page';
import { ProductListPageComponent } from './features/public/product-list/product-list.page';

export const routes: Routes = [
  { path: '', pathMatch: 'full', redirectTo: 'products' },
  { path: 'products', component: ProductListPageComponent },
  { path: 'products/:id', component: ProductDetailPageComponent },
  { path: '**', redirectTo: 'products' },
];
