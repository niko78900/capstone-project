export type SubmissionStatus = 'PENDING' | 'APPROVED' | 'REJECTED';
export type SubmissionType = 'PRODUCT' | 'PRICE' | 'NUTRITION';

export interface ModerationSubmissionDto {
  id: number;
  type: SubmissionType;
  status: SubmissionStatus;
  payload: unknown;
  notes: string | null;
  submittedByUserId: number;
  submittedByEmail: string;
  createdAt: string;
  updatedAt: string;
}

export interface SubmissionDecisionRequest {
  reason?: string;
}

export interface SubmissionDecisionResponse {
  submissionId: number;
  status: SubmissionStatus;
  action: 'APPROVED' | 'REJECTED';
  reason: string | null;
  reviewedAt: string;
}
