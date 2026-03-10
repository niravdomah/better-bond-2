'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useSession } from 'next-auth/react';

import { Button } from '@/components/ui/button';
import { UserRole } from '@/types/roles';

interface NavLink {
  href: string;
  label: string;
}

const NAV_LINKS: NavLink[] = [
  { href: '/', label: 'Dashboard' },
  { href: '/payment-management', label: 'Payment Management' },
];

const ADMIN_NAV_LINKS: NavLink[] = [
  { href: '/payments-made', label: 'Payments Made' },
];

export function NavBar() {
  const pathname = usePathname();
  const { data: session } = useSession();

  const isAdmin = session?.user?.role === UserRole.ADMIN;

  const visibleLinks = isAdmin ? [...NAV_LINKS, ...ADMIN_NAV_LINKS] : NAV_LINKS;

  return (
    <nav className="bg-white border-b border-gray-200 px-6 py-4">
      <div className="flex items-center justify-between max-w-7xl mx-auto">
        <div className="flex items-center gap-8">
          <span className="text-lg font-bold text-gray-900">MortgageMax</span>
          <ul className="flex items-center gap-6 list-none m-0 p-0">
            {visibleLinks.map((link) => {
              const isActive = pathname === link.href;
              return (
                <li key={link.href}>
                  <Link
                    href={link.href}
                    aria-current={isActive ? 'page' : undefined}
                    className={
                      isActive
                        ? 'font-semibold text-blue-600 underline'
                        : 'text-gray-700 hover:text-blue-600'
                    }
                  >
                    {link.label}
                  </Link>
                </li>
              );
            })}
          </ul>
        </div>
        {isAdmin && (
          <Button variant="outline" size="sm">
            Reset Demo
          </Button>
        )}
      </div>
    </nav>
  );
}
