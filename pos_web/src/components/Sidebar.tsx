import { type OpsPane, useNav } from '../state/nav';
import { useSession } from '../state/session';
import './sidebar.css';

type SItem = { pane: OpsPane; label: string; icon: JSX.Element; role?: 'manager' | 'owner' };

const DashboardIcon = () => (
  <svg viewBox="0 0 24 24" width="22" height="22" fill="currentColor">
    <path d="M4 13h6c.55 0 1-.45 1-1V4c0-.55-.45-1-1-1H4c-.55 0-1 .45-1 1v8c0 .55.45 1 1 1zm0 8h6c.55 0 1-.45 1-1v-4c0-.55-.45-1-1-1H4c-.55 0-1 .45-1 1v4c0 .55.45 1 1 1zm10 0h6c.55 0 1-.45 1-1v-8c0-.55-.45-1-1-1h-6c-.55 0-1 .45-1 1v8c0 .55.45 1 1 1zM13 4v4c0 .55.45 1 1 1h6c.55 0 1-.45 1-1V4c0-.55-.45-1-1-1h-6c-.55 0-1 .45-1 1z"/>
  </svg>
);

const AnalyticsIcon = () => (
  <svg viewBox="0 0 24 24" width="22" height="22" fill="currentColor">
    <path d="M6.4 9.2h.2c.77 0 1.4.63 1.4 1.4v7c0 .77-.63 1.4-1.4 1.4h-.2c-.77 0-1.4-.63-1.4-1.4v-7c0-.77.63-1.4 1.4-1.4zM12 5c.77 0 1.4.63 1.4 1.4v11.2c0 .77-.63 1.4-1.4 1.4s-1.4-.63-1.4-1.4V6.4c0-.77.63-1.4 1.4-1.4zm5.6 2.4h.2c.77 0 1.4.63 1.4 1.4v8.8c0 .77-.63 1.4-1.4 1.4h-.2c-.77 0-1.4-.63-1.4-1.4V8.8c0-.77.63-1.4 1.4-1.4z"/>
  </svg>
);

const ReportsIcon = () => (
  <svg viewBox="0 0 24 24" width="22" height="22" fill="currentColor">
    <path d="M19.5 3.5 18 2l-1.5 1.5L15 2l-1.5 1.5L12 2l-1.5 1.5L9 2 7.5 3.5 6 2 4.5 3.5 3 2v20l1.5-1.5L6 22l1.5-1.5L9 22l1.5-1.5L12 22l1.5-1.5L15 22l1.5-1.5L18 22l1.5-1.5L21 22V2l-1.5 1.5zM19 19.09H5V4.91h14v14.18zM6 15h12v2H6zm0-4h12v2H6zm0-4h12v2H6z"/>
  </svg>
);

const MenuIcon = () => (
  <svg viewBox="0 0 24 24" width="22" height="22" fill="currentColor">
    <path d="M8.1 13.34c1.22.83 2.7 1.66 4.4 1.66.97 0 1.9-.21 2.72-.62l4.36 4.36c.39.39 1.02.39 1.41 0s.39-1.02 0-1.41l-4.36-4.36c.41-.82.62-1.75.62-2.72 0-1.7-.83-3.18-1.66-4.4l-6.5 6.5c.02.01.01.01 0 0zm3.8-3.75c.57.22 1.1.52 1.56.92l-7.02 7.02c-.39.39-1.02.39-1.41 0s-.39-1.02 0-1.41L8.2 12.3c-.29-.74-.45-1.55-.45-2.41 0-2.38 1.19-4.47 3-5.74-1.67-.7-3.59-.63-5.2.42l6.5 6.5z"/>
  </svg>
);

const InventoryIcon = () => (
  <svg viewBox="0 0 24 24" width="22" height="22" fill="currentColor">
    <path d="M20 2H4c-1 0-2 .9-2 2v3.01c0 .72.43 1.34 1 1.69V20c0 1.1 1.1 2 2 2h14c.9 0 2-.9 2-2V8.7c.57-.35 1-.97 1-1.69V4c0-1.1-1-2-2-2zm-5 12H9c-.55 0-1-.45-1-1s.45-1 1-1h6c.55 0 1 .45 1 1s-.45 1-1 1zm5-7H4V4h16v3z"/>
  </svg>
);

const DayEndIcon = () => (
  <svg viewBox="0 0 24 24" width="22" height="22" fill="currentColor">
    <path d="M15.59 3.59c-.38-.38-.89-.59-1.42-.59H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V9.83c0-.53-.21-1.04-.59-1.41l-5.82-5.83zM8 7.5C8 8.33 7.33 9 6.5 9S5 8.33 5 7.5 5.67 6 6.5 6 8 6.67 8 7.5zm3 9c0 .83-.67 1.5-1.5 1.5S8 17.33 8 16.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5zm0-4.5c0 .83-.67 1.5-1.5 1.5S8 12.83 8 12s.67-1.5 1.5-1.5 1.5.67 1.5 1.5zm0-4.5c0 .83-.67 1.5-1.5 1.5S8 8.33 8 7.5 8.67 6 9.5 6s1.5.67 1.5 1.5zM14 19h-2v-2h2v2zm0-3h-2v-6h2v6z"/>
  </svg>
);

const PrintersIcon = () => (
  <svg viewBox="0 0 24 24" width="22" height="22" fill="currentColor">
    <path d="M19 8H5c-1.66 0-3 1.34-3 3v6h4v4h12v-4h4v-6c0-1.66-1.34-3-3-3zm-3 11H8v-5h8v5zm3-7c-.55 0-1-.45-1-1s.45-1 1-1 1 .45 1 1-.45 1-1 1zm-1-9H6v4h12V3z"/>
  </svg>
);

const ITEMS: SItem[] = [
  { pane: 'dashboard', label: 'Dashboard', icon: <DashboardIcon />, role: 'manager' },
  { pane: 'analytics', label: 'Analytics', icon: <AnalyticsIcon />, role: 'manager' },
  { pane: 'reports', label: 'Reports', icon: <ReportsIcon />, role: 'manager' },
  { pane: 'menu', label: 'Menu', icon: <MenuIcon />, role: 'manager' },
  { pane: 'inventory', label: 'Inventory', icon: <InventoryIcon />, role: 'owner' },
  { pane: 'dayend', label: 'Day End', icon: <DayEndIcon /> },
  { pane: 'printers', label: 'Printers', icon: <PrintersIcon /> },
];

export function Sidebar() {
  const opsPane = useNav((s) => s.opsPane);
  const goOps = useNav((s) => s.goOps);
  const session = useSession((s) => s.session);

  const role = session?.role;
  const visible = role ? ITEMS.filter((it) => !it.role || (it.role === 'owner' ? role === 'owner' : role === 'owner' || role === 'manager')) : ITEMS;

  return (
    <aside className="sidebar">
      <nav className="sidebar-nav">
        {visible.map((it) => (
          <button
            key={it.pane}
            className={`sidebar-btn${opsPane === it.pane ? ' active' : ''}`}
            onClick={() => goOps(it.pane)}
            title={it.label}
          >
            <span className="sidebar-icon">{it.icon}</span>
            <span className="sidebar-label">{it.label}</span>
            {opsPane === it.pane && (
              <svg className="sidebar-chevron" viewBox="0 0 24 24" width="18" height="18" fill="currentColor">
                <path d="M9.29 6.71c-.39.39-.39 1.02 0 1.41L13.17 12l-3.88 3.88c-.39.39-.39 1.02 0 1.41s1.02.39 1.41 0l4.59-4.59c.39-.39.39-1.02 0-1.41L10.7 6.7c-.38-.38-1.02-.38-1.41.01z"/>
              </svg>
            )}
          </button>
        ))}
      </nav>

      <div className="sidebar-user">
        <div className="sidebar-avatar">
          {session?.account.displayName?.charAt(0).toUpperCase() || session?.account.username?.charAt(0).toUpperCase() || 'U'}
        </div>
        <div className="sidebar-user-info">
          <div className="sidebar-user-name">{session?.account.displayName || session?.account.username || ''}</div>
          <div className="sidebar-user-role">{session?.role}</div>
        </div>
      </div>
    </aside>
  );
}
