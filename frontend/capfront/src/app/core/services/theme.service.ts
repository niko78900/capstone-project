// File purpose: Wraps Angular client-side service logic for theme service.
import { DOCUMENT } from '@angular/common';
import { Inject, Injectable, computed, signal } from '@angular/core';

type ThemeMode = 'light' | 'dark';

const THEME_STORAGE_KEY = 'capfront_theme_mode';
const DARK_THEME_CLASS = 'dark-theme';

@Injectable({ providedIn: 'root' })
export class ThemeService {
  private readonly modeSignal = signal<ThemeMode>(this.readInitialMode());

  readonly mode = computed(() => this.modeSignal());
  readonly isDark = computed(() => this.modeSignal() === 'dark');

  constructor(@Inject(DOCUMENT) private readonly document: Document) {
    this.applyMode(this.modeSignal());
  }

  toggle(): void {
    const nextMode: ThemeMode = this.isDark() ? 'light' : 'dark';
    this.setMode(nextMode);
  }

  setMode(mode: ThemeMode): void {
    if (this.modeSignal() === mode) {
      return;
    }

    this.modeSignal.set(mode);
    localStorage.setItem(THEME_STORAGE_KEY, mode);
    this.applyMode(mode);
  }

  private readInitialMode(): ThemeMode {
    const stored = localStorage.getItem(THEME_STORAGE_KEY);
    return stored === 'dark' ? 'dark' : 'light';
  }

  private applyMode(mode: ThemeMode): void {
    this.document.body.classList.toggle(DARK_THEME_CLASS, mode === 'dark');
  }
}
