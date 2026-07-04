// Which top-level section is showing. A tiny store (not React state in Shell) so
// Tables/Orders can route into Billing after prepping the cart.

import { create } from 'zustand';

export type NavSection = 'billing' | 'tables' | 'orders' | 'ops';

interface NavState {
  section: NavSection;
  go: (section: NavSection) => void;
}

export const useNav = create<NavState>((set) => ({
  section: 'billing',
  go: (section) => set({ section }),
}));
