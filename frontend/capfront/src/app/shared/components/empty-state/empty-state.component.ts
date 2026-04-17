import { Component, input } from '@angular/core';
import { MatIconModule } from '@angular/material/icon';

@Component({
  selector: 'app-empty-state',
  imports: [MatIconModule],
  template: `
    <section class="empty-state">
      <mat-icon class="icon" aria-hidden="true">{{ icon() }}</mat-icon>
      <h3>{{ title() }}</h3>
      <p>{{ message() }}</p>
      <div class="actions">
        <ng-content />
      </div>
    </section>
  `,
  styles: `
    .empty-state {
      background: var(--surface);
      border: 1px dashed var(--border);
      border-radius: 12px;
      color: var(--text-muted);
      display: grid;
      gap: 8px;
      justify-items: center;
      padding: 22px;
      text-align: center;
    }

    .icon {
      color: var(--text-muted);
      font-size: 26px;
      height: 26px;
      width: 26px;
    }

    h3 {
      color: var(--app-text);
      margin: 0;
    }

    p {
      margin: 0;
      max-width: 54ch;
    }

    .actions {
      display: inline-flex;
      gap: 8px;
      margin-top: 4px;
    }
  `,
})
export class EmptyStateComponent {
  readonly icon = input('inbox');
  readonly title = input('No data');
  readonly message = input('There is nothing to display yet.');
}
