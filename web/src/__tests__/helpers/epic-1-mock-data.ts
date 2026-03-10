/**
 * Shared mock data factories for Epic 1: Application Shell and Navigation.
 *
 * Import from this file in all Epic 1 test files.
 * Never duplicate these factories per test file.
 */

import { UserRole } from '@/types/roles';

export interface MockSession {
  user: {
    id: string;
    name: string;
    email: string;
    role: UserRole;
  };
}

export const createMockAdminSession = (
  overrides: Partial<MockSession['user']> = {},
): MockSession => ({
  user: {
    id: 'user-admin-1',
    name: 'Admin User',
    email: 'admin@mortgagemax.co.za',
    role: UserRole.ADMIN,
    ...overrides,
  },
});

export const createMockViewerSession = (
  overrides: Partial<MockSession['user']> = {},
): MockSession => ({
  user: {
    id: 'user-viewer-1',
    name: 'Viewer User',
    email: 'viewer@mortgagemax.co.za',
    role: UserRole.STANDARD_USER,
    ...overrides,
  },
});
