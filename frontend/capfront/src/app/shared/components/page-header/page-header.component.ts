// File purpose: Implements the Angular component for page header component.
import { Component, input } from '@angular/core';

@Component({
  selector: 'app-page-header',
  template: `
    <header class="page-header">
      <div class="copy">
        @if (eyebrow()) {
          <p class="eyebrow">{{ eyebrow() }}</p>
        }
        <h1>{{ title() }}</h1>
        @if (subtitle()) {
          <p class="subtitle">{{ subtitle() }}</p>
        }
      </div>
      <div class="actions">
        <ng-content select="[header-actions]" />
      </div>
    </header>
  `,
  styles: `
    .page-header {
      align-items: flex-start;
      display: flex;
      flex-wrap: wrap;
      gap: 14px;
      justify-content: space-between;
    }

    .copy {
      display: grid;
      gap: 6px;
    }

    .eyebrow {
      color: var(--text-muted);
      font-size: 0.74rem;
      font-weight: 700;
      letter-spacing: 0.45px;
      margin: 0;
      text-transform: uppercase;
    }

    h1 {
      letter-spacing: 0.2px;
      line-height: 1.15;
      margin: 0;
    }

    .subtitle {
      color: var(--text-muted);
      margin: 0;
      max-width: 76ch;
    }

    .actions {
      align-items: center;
      display: inline-flex;
      gap: 10px;
    }
  `,
})
export class PageHeaderComponent {
  readonly title = input.required<string>();
  readonly subtitle = input<string>('');
  readonly eyebrow = input<string>('');
}
