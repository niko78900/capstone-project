import { NgTemplateOutlet } from '@angular/common';
import { Component, computed, input, signal } from '@angular/core';
import { MatIconModule } from '@angular/material/icon';

type MarketLogoSize = 'sm' | 'md' | 'lg';

interface MarketLogoConfig {
  src: string;
  darkTile?: boolean;
}

const MARKET_LOGOS_BY_NAME: Partial<Record<string, MarketLogoConfig>> = {
  tinex: { src: '/market-logos/tinex.png?v=20260517' },
  vero: { src: '/market-logos/vero.png?v=20260517' },
  'kam market': { src: '/market-logos/kam.svg' },
  ramstore: { src: '/market-logos/ramstore.png' },
  stokomak: { src: '/market-logos/stokomak.png', darkTile: true },
  'kit-go market': { src: '/market-logos/kit-go.png' },
  kipper: { src: '/market-logos/kipper.png?v=20260517' },
  zur: { src: '/market-logos/zur.png' },
  reptil: { src: '/market-logos/reptil.png' },
  zhito: { src: '/market-logos/zhito.png' },
  'zhito marketi': { src: '/market-logos/zhito.png' },
};

@Component({
  selector: 'app-market-logo',
  imports: [MatIconModule, NgTemplateOutlet],
  template: `
    <span
      class="market-logo"
      [class.market-logo-sm]="size() === 'sm'"
      [class.market-logo-lg]="size() === 'lg'"
      [class.market-logo-dark]="logo()?.darkTile"
      [attr.aria-label]="supermarketName() + ' logo'"
    >
      @if (logo(); as logo) {
        @if (!imageLoadFailed()) {
          <img
            [src]="logo.src"
            [alt]="supermarketName() + ' logo'"
            loading="lazy"
            (error)="onImageError()"
          />
        } @else {
          <ng-container *ngTemplateOutlet="fallback"></ng-container>
        }
      } @else {
        <ng-container *ngTemplateOutlet="fallback"></ng-container>
      }

      <ng-template #fallback>
        <mat-icon aria-hidden="true">storefront</mat-icon>
        <span class="fallback-text">{{ initials() }}</span>
      </ng-template>
    </span>
  `,
  styles: `
    .market-logo {
      align-items: center;
      background: var(--surface-muted);
      border: 1px solid var(--border);
      border-radius: 10px;
      box-sizing: border-box;
      display: inline-flex;
      flex: 0 0 auto;
      height: 36px;
      justify-content: center;
      overflow: hidden;
      padding: 4px;
      vertical-align: middle;
      width: 44px;
    }

    .market-logo-sm {
      border-radius: 8px;
      height: 28px;
      padding: 3px;
      width: 34px;
    }

    .market-logo-lg {
      border-radius: 12px;
      height: 48px;
      padding: 6px;
      width: 58px;
    }

    .market-logo-dark {
      background: #0f1713;
    }

    img {
      display: block;
      max-height: 100%;
      max-width: 100%;
      object-fit: contain;
    }

    mat-icon {
      color: var(--text-muted);
      font-size: 16px;
      height: 16px;
      width: 16px;
    }

    .fallback-text {
      color: var(--text-muted);
      font-size: 0.68rem;
      font-weight: 700;
      line-height: 1;
      margin-left: 2px;
    }
  `,
})
export class MarketLogoComponent {
  readonly supermarketName = input.required<string>();
  readonly size = input<MarketLogoSize>('md');
  readonly imageLoadFailed = signal(false);

  readonly logo = computed<MarketLogoConfig | null>(() => {
    return MARKET_LOGOS_BY_NAME[this.normalizeMarketName(this.supermarketName())] ?? null;
  });

  readonly initials = computed(() => {
    const tokens = this.normalizeMarketName(this.supermarketName())
      .split(' ')
      .filter(Boolean);
    const initials = tokens
      .slice(0, 2)
      .map((token) => token[0])
      .join('')
      .toUpperCase();
    return initials || '?';
  });

  onImageError(): void {
    this.imageLoadFailed.set(true);
  }

  private normalizeMarketName(value: string): string {
    return value.trim().toLowerCase().replace(/\s+/g, ' ');
  }
}
