import { Component, input } from '@angular/core';

@Component({
  selector: 'app-filter-toolbar',
  template: `
    <section class="toolbar">
      @if (title() || subtitle()) {
        <div class="meta">
          @if (title()) {
            <p class="title">{{ title() }}</p>
          }
          @if (subtitle()) {
            <p class="subtitle">{{ subtitle() }}</p>
          }
        </div>
      }
      <div class="controls">
        <ng-content />
      </div>
    </section>
  `,
  styles: `
    .toolbar {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 12px;
      box-shadow: 0 8px 18px var(--card-shadow);
      display: grid;
      gap: 12px;
      padding: 12px;
    }

    .meta {
      display: grid;
      gap: 4px;
    }

    .title {
      color: var(--app-text);
      font-size: 0.9rem;
      font-weight: 700;
      letter-spacing: 0.2px;
      margin: 0;
    }

    .subtitle {
      color: var(--text-muted);
      font-size: 0.82rem;
      margin: 0;
    }

    .controls {
      display: grid;
      gap: 10px;
      grid-template-columns: repeat(auto-fit, minmax(210px, 1fr));
    }
  `,
})
export class FilterToolbarComponent {
  readonly title = input<string>('');
  readonly subtitle = input<string>('');
}
