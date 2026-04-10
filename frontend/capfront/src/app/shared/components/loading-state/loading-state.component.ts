import { Component, input } from '@angular/core';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';

@Component({
  selector: 'app-loading-state',
  imports: [MatProgressSpinnerModule],
  template: `
    <div class="loading-state">
      <mat-progress-spinner mode="indeterminate" diameter="32" />
      <span>{{ message() }}</span>
    </div>
  `,
  styles: `
    .loading-state {
      align-items: center;
      color: #3a4a60;
      display: inline-flex;
      gap: 12px;
      padding: 16px 0;
    }
  `,
})
export class LoadingStateComponent {
  readonly message = input('Loading...');
}
