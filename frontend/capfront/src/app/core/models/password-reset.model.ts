export type PasswordResetStatus = 'PENDING' | 'APPROVED' | 'DENIED' | 'COMPLETED' | 'EXPIRED';

export interface PasswordResetRequestCreateResponse {
  requestToken: string;
  status: PasswordResetStatus;
  expiresAt: string;
}

export interface PasswordResetStatusResponse {
  status: PasswordResetStatus;
  email: string;
  expiresAt: string;
  updatedAt: string;
}

export interface PasswordResetCompleteResponse {
  status: PasswordResetStatus;
  message: string;
}

export interface AdminPasswordResetRequestDto {
  id: number;
  requesterEmail: string;
  matchedUserId: number | null;
  matchedUserDisplayName: string | null;
  status: PasswordResetStatus;
  expiresAt: string;
  decidedByEmail: string | null;
  decisionReason: string | null;
  decisionAt: string | null;
  completedAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface AdminPasswordResetPageResponse {
  items: AdminPasswordResetRequestDto[];
  totalElements: number;
  page: number;
  size: number;
  totalPages: number;
}
