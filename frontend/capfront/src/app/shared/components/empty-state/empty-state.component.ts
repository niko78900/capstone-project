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
      background: #f5f7fb;
      border: 1px dashed #c6cfdd;
      border-radius: 12px;
      color: #4b5a74;
      padding: 20px;
      text-align: center;
    }

    h3 {
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
