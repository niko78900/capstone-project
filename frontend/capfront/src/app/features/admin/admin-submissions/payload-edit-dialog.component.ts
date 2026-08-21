// File purpose: Implements the Angular component for payload edit dialog component.
import { Component, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatDialogModule, MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';

export interface PayloadEditDialogData {
  submissionId: number;
  submissionRef: string;
  initialPayloadJson: string;
}

export interface PayloadEditDialogResult {
  payload: Record<string, unknown>;
  editReason: string | null;
}

@Component({
  selector: 'app-payload-edit-dialog',
  imports: [
    ReactiveFormsModule,
    MatDialogModule,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
  ],
  template: `
    <h2 mat-dialog-title>Edit Submission Fields</h2>
    <mat-dialog-content>
      <p>Ref {{ data.submissionRef }}</p>
      <p class="hint">Update any payload fields, then save the patch.</p>

      <mat-form-field appearance="outline" class="payload-field">
        <mat-label>Payload JSON</mat-label>
        <textarea matInput rows="14" [formControl]="form.controls.payloadJson"></textarea>
        @if (form.controls.payloadJson.hasError('required')) {
          <mat-error>Payload JSON is required.</mat-error>
        }
        @if (jsonError(); as jsonError) {
          <mat-error>{{ jsonError }}</mat-error>
        }
      </mat-form-field>

      <mat-form-field appearance="outline" class="reason-field">
        <mat-label>Edit reason (optional)</mat-label>
        <textarea matInput rows="3" [formControl]="form.controls.editReason"></textarea>
        @if (form.controls.editReason.hasError('maxlength')) {
          <mat-error>Edit reason must be at most 1000 characters.</mat-error>
        }
      </mat-form-field>
    </mat-dialog-content>

    <mat-dialog-actions align="end">
      <button mat-button type="button" (click)="dialogRef.close()">Cancel</button>
      <button mat-flat-button color="primary" type="button" (click)="confirm()">Save Patch</button>
    </mat-dialog-actions>
  `,
  styles: `
    .hint {
      color: var(--text-muted);
      margin: 0 0 8px;
    }

    .payload-field,
    .reason-field {
      margin-top: 6px;
      width: 100%;
    }
  `,
})
export class PayloadEditDialogComponent {
  readonly data = inject<PayloadEditDialogData>(MAT_DIALOG_DATA);
  readonly dialogRef = inject(
    MatDialogRef<PayloadEditDialogComponent, PayloadEditDialogResult | undefined>,
  );
  private readonly formBuilder = inject(FormBuilder);

  readonly jsonError = signal<string | null>(null);

  readonly form = this.formBuilder.group({
    payloadJson: [this.data.initialPayloadJson, [Validators.required]],
    editReason: ['', [Validators.maxLength(1000)]],
  });

  confirm(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }

    this.jsonError.set(null);
    const payloadJson = (this.form.controls.payloadJson.value ?? '').trim();

    let parsedPayload: unknown;
    try {
      parsedPayload = JSON.parse(payloadJson);
    } catch {
      this.jsonError.set('Payload must be valid JSON.');
      return;
    }

    if (
      parsedPayload == null ||
      Array.isArray(parsedPayload) ||
      typeof parsedPayload !== 'object'
    ) {
      this.jsonError.set('Payload must be a JSON object.');
      return;
    }

    const reason = (this.form.controls.editReason.value ?? '').trim();
    this.dialogRef.close({
      payload: parsedPayload as Record<string, unknown>,
      editReason: reason.length > 0 ? reason : null,
    });
  }
}
