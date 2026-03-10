'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useSession } from 'next-auth/react';

import { UserRole } from '@/types/roles';

export default function PaymentsMadePage() {
  const router = useRouter();
  const { data: session } = useSession();

  const isAdmin = session?.user?.role === UserRole.ADMIN;

  useEffect(() => {
    if (session !== undefined && !isAdmin) {
      router.push('/');
    }
  }, [session, isAdmin, router]);

  if (!isAdmin) {
    return null;
  }

  return (
    <main className="container mx-auto px-4 py-8">
      <h1 className="text-2xl font-bold">Payments Made</h1>
      <p className="text-muted-foreground">
        Payments Made content coming in Epic 4.
      </p>
    </main>
  );
}
