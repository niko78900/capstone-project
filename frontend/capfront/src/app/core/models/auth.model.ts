export type UserRole = 'USER' | 'ADMIN';

export interface AuthUserDto {
  id: number;
  email: string;
  displayName: string;
  role: UserRole;
}

export interface AuthResponse {
  accessToken: string;
  tokenType: string;
  expiresInMs: number;
  user: AuthUserDto;
}

export interface LoginRequest {
  email: string;
  password: string;
}

export interface AuthSession {
  accessToken: string;
  user: AuthUserDto;
}
