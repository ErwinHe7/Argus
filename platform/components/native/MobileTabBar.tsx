'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { BarChart3, Home, LineChart, MessageCircle, ShieldCheck } from 'lucide-react';

const tabs = [
  { href: '/', label: 'Home', icon: Home },
  { href: '/market', label: 'Strategy', icon: BarChart3 },
  { href: '/quant/technical', label: 'KDJ', icon: LineChart },
  { href: '/inbox', label: 'Message', icon: MessageCircle },
  { href: '/terms', label: 'Rules', icon: ShieldCheck },
];

export function MobileTabBar() {
  const pathname = usePathname();

  return (
    <nav className="native-tabbar" aria-label="AXIO7 iOS navigation">
      {tabs.map(({ href, label, icon: Icon }) => {
        const active = href === '/' ? pathname === '/' : pathname === href || pathname.startsWith(`${href}/`);
        return (
          <Link key={href} href={href} className={active ? 'native-tab active' : 'native-tab'}>
            <Icon className="h-5 w-5" />
            <span>{label}</span>
          </Link>
        );
      })}
    </nav>
  );
}
