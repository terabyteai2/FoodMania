import { create } from 'zustand';

export type NavSection = 'billing' | 'tables' | 'orders' | 'ops';
export type OpsPane = 'home' | 'dashboard' | 'analytics' | 'reports' | 'menu' | 'inventory' | 'dayend' | 'printers' | 'restaurant' | 'tablesettings' | 'voiceagent' | 'sarvamvoice';

interface NavState {
  section: NavSection;
  opsPane: OpsPane;
  go: (section: NavSection) => void;
  goOps: (pane: OpsPane) => void;
}

export const useNav = create<NavState>((set) => ({
  section: 'tables',
  opsPane: 'home',
  go: (section) => set({ section, opsPane: 'home' }),
  goOps: (pane) => set({ section: 'ops', opsPane: pane }),
}));
