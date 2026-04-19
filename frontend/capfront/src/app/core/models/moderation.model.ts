export type SubmissionStatus = 'PENDING' | 'APPROVED' | 'REJECTED';
export type SubmissionType = 'PRODUCT' | 'PRICE' | 'NUTRITION';
export type SubmissionSortToken = 'createdAt,desc' | 'createdAt,asc';

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
  contributorScore: number | null;
  aiSummary: ModerationAiSummary | null;
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
  changedFieldCount: number | null;
  beforePayload: unknown;
  afterPayload: unknown;
  createdAt: string;
}

export interface SubmissionHistoryResponse {
  submissionId: number;
  entries: SubmissionHistoryEntry[];
}
