import type { Metadata } from 'next';
import './globals.css';
import { ToastProvider } from '@/contexts/ToastContext';
import { ToastContainer } from '@/components/toast/ToastContainer';
import { SessionProvider } from '@/components/auth/session-provider';
import { NavBar } from '@/components/layout/NavBar';
import { auth } from '@/lib/auth/auth';

export const metadata: Metadata = {
  title: 'MortgageMax Commission Payments',
  description:
    'MortgageMax administrator portal for managing commission payments',
};

export default async function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const session = await auth();

  return (
    <html lang="en">
      <body className="antialiased">
        <SessionProvider session={session}>
          <ToastProvider>
            <div className="min-h-screen flex flex-col">
              <NavBar />
              <main className="flex-1">{children}</main>
            </div>
            <ToastContainer />
          </ToastProvider>
        </SessionProvider>
      </body>
    </html>
  );
}
