import { Component, input } from '@angular/core';

@Component({
  selector: 'app-empty-state',
  template: `
    <section class="empty-state">
      <h3>{{ title() }}</h3>
      <p>{{ message() }}</p>
    </section>
  `,
  styles: `
    .empty-state {
      background: var(--surface);
      border: 1px dashed var(--border);
      border-radius: 12px;
      color: var(--text-muted);
      padding: 20px;
      text-align: center;
    }

    h3 {
      color: var(--app-text);
      margin: 0 0 8px;
    }

    p {
      margin: 0;
    }
  `,
})
export class EmptyStateComponent {
  readonly title = input('No data');
  readonly message = input('There is nothing to display yet.');
}
