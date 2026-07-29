'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { BookOpen, FlaskConical, Home, Info } from 'lucide-react';

const tabs = [
  { href: '/', label: 'Home', icon: Home, match: (path: string) => path === '/' },
  {
    href: '/learn',
    label: 'Curriculum',
    icon: BookOpen,
    match: (path: string) => path.startsWith('/learn'),
  },
  {
    href: '/learn#case-studies',
    label: 'Case studies',
    icon: FlaskConical,
    match: () => false,
  },
  {
    href: '/about',
    label: 'About',
    icon: Info,
    match: (path: string) => path.startsWith('/about'),
  },
];

export function NavTabs() {
  const pathname = usePathname() || '/';

  return (
    <div aria-label="Primary navigation" className="nav-pill">
      {tabs.map((tab) => {
        const active = tab.match(pathname);
        const Icon = tab.icon;

        return (
          <Link
            key={tab.href}
            href={tab.href}
            aria-current={active ? 'page' : undefined}
            className={active ? 'active' : undefined}
          >
            <span className="relative inline-flex">
              <Icon className="h-5 w-5 sm:h-[22px] sm:w-[22px]" strokeWidth={active ? 2.6 : 2.1} />
            </span>
            <span>{tab.label}</span>
          </Link>
        );
      })}
    </div>
  );
}
