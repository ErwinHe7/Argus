'use client';

import { useEffect } from 'react';

export function MarketingReveal() {
  useEffect(() => {
    const nodes = Array.from(document.querySelectorAll<HTMLElement>('.sr'));
    for (const node of nodes) node.classList.add('show');
  }, []);

  return null;
}
