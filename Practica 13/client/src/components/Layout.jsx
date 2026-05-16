import { NavLink, Outlet } from 'react-router-dom';
import styles from './Layout.module.css';

const navItems = [
  { to: '/',          label: 'Dashboard',        icon: '⊞' },
  { to: '/machines',  label: 'Máquinas',          icon: '🖥' },
  { to: '/users',     label: 'Usuarios',          icon: '👤' },
  { label: 'Servicios', separator: true },
  { to: '/services/ssh',    label: 'SSH',         icon: '⌨' },
  { to: '/services/dhcp',   label: 'DHCP',        icon: '◈' },
  { to: '/services/dns',    label: 'DNS',         icon: '◎' },
  { to: '/services/ftp',    label: 'FTP',         icon: '⇅' },
  { to: '/services/ssl',    label: 'SSL / HTTPS', icon: '🔒' },
  { to: '/services/docker', label: 'Docker',      icon: '◻' },
  { to: '/services/mail',   label: 'Correo',      icon: '✉' },
];

export default function Layout() {
  return (
    <div className={styles.shell}>
      <aside className={styles.sidebar}>
        <div className={styles.brand}>
          <span className={styles.brandIcon}>⬡</span>
          <span className={styles.brandText}>SIS-ADMIN</span>
        </div>
        <nav className={styles.nav}>
          {navItems.map((item, i) =>
            item.separator ? (
              <div key={i} className={styles.separator}>{item.label}</div>
            ) : (
              <NavLink
                key={item.to}
                to={item.to}
                end={item.to === '/'}
                className={({ isActive }) =>
                  `${styles.navItem} ${isActive ? styles.active : ''}`
                }
              >
                <span className={styles.navIcon}>{item.icon}</span>
                {item.label}
              </NavLink>
            )
          )}
        </nav>
        <div className={styles.version}>Práctica 13 — v1.0</div>
      </aside>
      <main className={styles.main}>
        <Outlet />
      </main>
    </div>
  );
}
