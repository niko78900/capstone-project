// File purpose: Defines Angular TypeScript models for moderation model.
export type SubmissionStatus = 'PENDING' | 'APPROVED' | 'REJECTED';
export type SubmissionType = 'PRODUCT' | 'PRICE' | 'NUTRITION' | 'AVAILABILITY';
export type RejectionSeverity = 'MISTAKE' | 'BAD' | 'FRAUD';
export type SubmissionSortToken = 'createdAt,desc' | 'createdAt,asc' | 'contributorScore,desc';

export interface ModerationListQuery {
  status?: SubmissionStatus;
  type?: SubmissionType;
  q?: string;
  page?: number;
  size?: number;
  sort?: SubmissionSortToken | string;
}

export interface ModerationAiSummary {
  analysisId: number | null;
  analysisType: string;
  status: string;
  model: string | null;
  promptVersion: string | null;
  confidence: number | null;
  flags: string[];
  warnings: string[];
  updatedAt: string;
}

export interface ModerationSubmissionDto {
  id: number;
  type: SubmissionType;
  status: SubmissionStatus;
  payload: unknown;
  notes: string | null;
  reviewReason: string | null;
  submittedByUserId: number;
  submittedByEmail: string;
  contributorScore: number | null;
  createdAt: string;
  updatedAt: string;
}

export interface ModerationSubmissionPage {
  items: ModerationSubmissionDto[];
  totalElements: number;
  page: number;
  size: number;
  totalPages: number;
}

export interface ModerationSubmissionDetail extends ModerationSubmissionDto {
  aiSummary: ModerationAiSummary | null;
}

export interface SubmissionDecisionRequest {
  reason?: string;
  rejectionSeverity?: RejectionSeverity;
}

export interface SubmissionDecisionResponse {
  submissionId: number;
  status: SubmissionStatus;
  action: 'APPROVED' | 'REJECTED';
  reason: string | null;
  rejectionSeverity: RejectionSeverity | null;
  reviewedAt: string;
}

export interface SubmissionPayloadPatchRequest {
  payload: unknown;
  editReason?: string | null;
  expectedUpdatedAt?: string | null;
}

export interface SubmissionPayloadPatchResponse {
  submission: ModerationSubmissionDetail;
  changedFieldCount: number;
}

export interface SubmissionHistoryEntry {
  kind: 'EDIT' | 'REVIEW' | string;
  actorEmail: string;
  action: string;
  reason: string | null;
  rejectionSeverity: RejectionSeverity | null;
  changedFieldCount: number | null;
  beforePayload: unknown;
  afterPayload: unknown;
  createdAt: string;
}

export interface SubmissionHistoryResponse {
  submissionId: number;
  entries: SubmissionHistoryEntry[];
}
