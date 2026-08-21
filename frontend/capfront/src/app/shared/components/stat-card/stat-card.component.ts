// File purpose: Implements the Angular component for stat card component.
import { Component, input } from '@angular/core';
import { MatCardModule } from '@angular/material/card';

type StatTone = 'neutral' | 'pending' | 'approved' | 'rejected';

@Component({
  selector: 'app-stat-card',
  imports: [MatCardModule],
  template: `
    <mat-card
      class="stat-card"
      appearance="outlined"
      [class.stat-pending]="tone() === 'pending'"
      [class.stat-approved]="tone() === 'approved'"
      [class.stat-rejected]="tone() === 'rejected'"
    >
      <p class="label">{{ label() }}</p>
      <p class="value">{{ value() }}</p>
      @if (hint()) {
        <p class="hint">{{ hint() }}</p>
      }
      <ng-content />
    </mat-card>
  `,
  styles: `
    .stat-card {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 12px;
      box-shadow: 0 8px 18px var(--card-shadow);
      display: grid;
      gap: 6px;
      min-height: 118px;
      padding: 14px;
    }

    .label {
      color: var(--text-muted);
      font-size: 0.8rem;
      font-weight: 700;
      letter-spacing: 0.4px;
      margin: 0;
      text-transform: uppercase;
    }

    .value {
      font-size: 2rem;
      font-weight: 700;
      line-height: 1;
      margin: 0;
    }

    .hint {
      color: var(--text-muted);
      font-size: 0.85rem;
      margin: 0;
    }

    .stat-pending {
      border-color: rgba(245, 158, 11, 0.42);
      box-shadow:
        0 8px 18px var(--card-shadow),
        inset 0 1px 0 rgba(245, 158, 11, 0.45);
    }

    .stat-approved {
      border-color: rgba(34, 197, 94, 0.42);
      box-shadow:
        0 8px 18px var(--card-shadow),
        inset 0 1px 0 rgba(34, 197, 94, 0.5);
    }

    .stat-rejected {
      border-color: rgba(220, 38, 38, 0.42);
      box-shadow:
        0 8px 18px var(--card-shadow),
        inset 0 1px 0 rgba(220, 38, 38, 0.54);
    }
  `,
})
export class StatCardComponent {
  readonly label = input.required<string>();
  readonly value = input.required<string | number>();
  readonly hint = input<string>('');
  readonly tone = input<StatTone>('neutral');
}
