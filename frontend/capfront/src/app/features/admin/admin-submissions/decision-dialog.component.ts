import { Component, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';

export interface DecisionDialogData {
  mode: 'approve' | 'reject';
  submissionId: number;
  submissionRef: string;
  title?: string;
}

@Component({
  selector: 'app-decision-dialog',
  imports: [ReactiveFormsModule, MatDialogModule, MatButtonModule, MatFormFieldModule, MatInputModule],
  template: `
    <h2 mat-dialog-title>{{ data.title || (data.mode === 'approve' ? 'Approve' : 'Reject') + ' submission' }}</h2>
    <mat-dialog-content>
      <p>Ref {{ data.submissionRef }}</p>
      <mat-form-field appearance="outline" class="reason-field">
        <mat-label>{{ data.mode === 'reject' ? 'Reason (required)' : 'Reason (optional)' }}</mat-label>
        <textarea matInput rows="4" formControlName="reason"></textarea>
        @if (form.controls.reason.hasError('required')) {
          <mat-error>Reason is required when rejecting a submission.</mat-error>
        }
        @if (form.controls.reason.hasError('maxlength')) {
          <mat-error>Reason must be at most 1000 characters.</mat-error>
        }
      </mat-form-field>
    </mat-dialog-content>
    <mat-dialog-actions align="end">
      <button mat-button type="button" (click)="dialogRef.close()">Cancel</button>
      <button mat-flat-button color="primary" type="button" (click)="confirm()">
        {{ data.mode === 'approve' ? 'Approve' : 'Reject' }}
      </button>
    </mat-dialog-actions>
  `,
  styles: `
    .reason-field {
      margin-top: 6px;
      width: 100%;
    }
  `,
})
export class DecisionDialogComponent {
  readonly data = inject<DecisionDialogData>(MAT_DIALOG_DATA);
  readonly dialogRef = inject(MatDialogRef<DecisionDialogComponent, string | undefined>);
  private readonly formBuilder = inject(FormBuilder);

  readonly form = this.formBuilder.group({
    reason: [
      '',
      this.data.mode === 'reject'
        ? [Validators.required, Validators.maxLength(1000)]
        : [Validators.maxLength(1000)],
    ],
  });

  confirm(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }
    const reason = (this.form.controls.reason.value ?? '').trim();
    this.dialogRef.close(reason);
  }
}
