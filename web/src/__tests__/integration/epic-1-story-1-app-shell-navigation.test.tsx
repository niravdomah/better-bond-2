/**
 * Story Metadata:
 * - Route: / (home page), /payment-management (stub), /payments-made (stub)
 * - Target File: app/page.tsx (modify_existing), app/payment-management/page.tsx (create_new), app/payments-made/page.tsx (create_new)
 * - Page Action: modify_existing for home page; create_new for route stubs
 *
 * Tests for Epic 1 Story 1: App Shell, Navigation Bar, and Route Structure.
 * Verifies the NavBar renders correctly with RBAC-gated links and that route stubs exist.
 */

import { render, screen } from '@testing-library/react';
import { axe } from 'vitest-axe';
import 'vitest-axe/extend-expect';
import { vi, describe, it, expect, beforeEach } from 'vitest';

// next/navigation must be mocked before importing components that use it
const mockPush = vi.fn();
const mockPathname = vi.fn(() => '/');

vi.mock('next/navigation', () => ({
  usePathname: () => mockPathname(),
  useRouter: () => ({ push: mockPush, replace: vi.fn(), prefetch: vi.fn() }),
}));

// Mock next-auth/react — NavBar reads session from useSession
vi.mock('next-auth/react', () => ({
  useSession: vi.fn(),
}));

// These imports will fail until the components are implemented — expected TDD red phase
import { NavBar } from '@/components/layout/NavBar';
import PaymentManagementPage from '@/app/payment-management/page';
import PaymentsMadePage from '@/app/payments-made/page';

import { useSession } from 'next-auth/react';
import {
  createMockAdminSession,
  createMockViewerSession,
} from '../helpers/epic-1-mock-data';

const mockUseSession = useSession as ReturnType<typeof vi.fn>;

// ---------------------------------------------------------------------------
// Helper: render NavBar with a given session
// ---------------------------------------------------------------------------
function renderNavBarAs(
  session:
    | ReturnType<typeof createMockAdminSession>
    | ReturnType<typeof createMockViewerSession>
    | null,
) {
  mockUseSession.mockReturnValue({
    data: session,
    status: session ? 'authenticated' : 'unauthenticated',
  });
  return render(<NavBar />);
}

// ---------------------------------------------------------------------------
// NavBar — Branding
// ---------------------------------------------------------------------------
describe('NavBar — Branding', () => {
  beforeEach(() => vi.clearAllMocks());

  it('displays MortgageMax brand name', () => {
    renderNavBarAs(createMockAdminSession());
    expect(screen.getByText(/MortgageMax/i)).toBeInTheDocument();
  });
});

// ---------------------------------------------------------------------------
// NavBar — Links (always-visible)
// ---------------------------------------------------------------------------
describe('NavBar — Links', () => {
  beforeEach(() => vi.clearAllMocks());

  it('contains a Dashboard navigation link', () => {
    renderNavBarAs(createMockAdminSession());
    expect(
      screen.getByRole('link', { name: /dashboard/i }),
    ).toBeInTheDocument();
  });

  it('contains a Payment Management navigation link', () => {
    renderNavBarAs(createMockAdminSession());
    expect(
      screen.getByRole('link', { name: /payment management/i }),
    ).toBeInTheDocument();
  });

  it('shows Payments Made link for Admin users', () => {
    renderNavBarAs(createMockAdminSession());
    expect(
      screen.getByRole('link', { name: /payments made/i }),
    ).toBeInTheDocument();
  });

  it('hides Payments Made link for Viewer users', () => {
    renderNavBarAs(createMockViewerSession());
    expect(
      screen.queryByRole('link', { name: /payments made/i }),
    ).not.toBeInTheDocument();
  });
});

// ---------------------------------------------------------------------------
// NavBar — RBAC: Reset Demo button
// ---------------------------------------------------------------------------
describe('NavBar — Reset Demo button', () => {
  beforeEach(() => vi.clearAllMocks());

  it('shows Reset Demo button for Admin users', () => {
    renderNavBarAs(createMockAdminSession());
    expect(
      screen.getByRole('button', { name: /reset demo/i }),
    ).toBeInTheDocument();
  });

  it('hides Reset Demo button for Viewer users', () => {
    renderNavBarAs(createMockViewerSession());
    expect(
      screen.queryByRole('button', { name: /reset demo/i }),
    ).not.toBeInTheDocument();
  });
});

// ---------------------------------------------------------------------------
// NavBar — Active Link Highlighting
// ---------------------------------------------------------------------------
describe('NavBar — Active link highlighting', () => {
  beforeEach(() => vi.clearAllMocks());

  it('marks Dashboard link as active when on /', () => {
    mockPathname.mockReturnValue('/');
    renderNavBarAs(createMockAdminSession());
    const dashboardLink = screen.getByRole('link', { name: /dashboard/i });
    // The link should have an aria-current="page" attribute when active
    expect(dashboardLink).toHaveAttribute('aria-current', 'page');
  });

  it('marks Payment Management link as active when on /payment-management', () => {
    mockPathname.mockReturnValue('/payment-management');
    renderNavBarAs(createMockAdminSession());
    const pmLink = screen.getByRole('link', { name: /payment management/i });
    expect(pmLink).toHaveAttribute('aria-current', 'page');
  });

  it('does not mark Dashboard as active when on /payment-management', () => {
    mockPathname.mockReturnValue('/payment-management');
    renderNavBarAs(createMockAdminSession());
    const dashboardLink = screen.getByRole('link', { name: /dashboard/i });
    expect(dashboardLink).not.toHaveAttribute('aria-current', 'page');
  });
});

// ---------------------------------------------------------------------------
// NavBar — Accessibility
// ---------------------------------------------------------------------------
describe('NavBar — Accessibility', () => {
  beforeEach(() => vi.clearAllMocks());

  it('has no accessibility violations for Admin view', async () => {
    const { container } = renderNavBarAs(createMockAdminSession());
    expect(await axe(container)).toHaveNoViolations();
  });

  it('has no accessibility violations for Viewer view', async () => {
    const { container } = renderNavBarAs(createMockViewerSession());
    expect(await axe(container)).toHaveNoViolations();
  });
});

// ---------------------------------------------------------------------------
// Route Stubs — /payment-management
// ---------------------------------------------------------------------------
describe('Route stub — /payment-management', () => {
  beforeEach(() => vi.clearAllMocks());

  it('renders a Payment Management heading', () => {
    render(<PaymentManagementPage />);
    expect(
      screen.getByRole('heading', { name: /payment management/i }),
    ).toBeInTheDocument();
  });
});

// ---------------------------------------------------------------------------
// Route Stubs — /payments-made (Admin)
// ---------------------------------------------------------------------------
describe('Route stub — /payments-made', () => {
  beforeEach(() => vi.clearAllMocks());

  it('renders a Payments Made heading for Admin', () => {
    mockUseSession.mockReturnValue({
      data: createMockAdminSession(),
      status: 'authenticated',
    });
    render(<PaymentsMadePage />);
    expect(
      screen.getByRole('heading', { name: /payments made/i }),
    ).toBeInTheDocument();
  });

  it('redirects Viewer away from /payments-made to /', () => {
    mockUseSession.mockReturnValue({
      data: createMockViewerSession(),
      status: 'authenticated',
    });
    render(<PaymentsMadePage />);
    expect(mockPush).toHaveBeenCalledWith('/');
  });
});
