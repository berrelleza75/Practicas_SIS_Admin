import { useEffect, useState } from 'react';
import { getMachines } from '../api/client';
import StatusBadge from '../components/StatusBadge';
import styles from './Dashboard.module.css';

const serviceLabels = {
  ssh: 'SSH', ftp: 'FTP', dns: 'DNS', dhcp: 'DHCP',
  http: 'HTTP', ssl: 'SSL', docker: 'Docker',
  'active-directory': 'Active Directory', applocker: 'AppLocker',
  fsrm: 'FSRM', mfa: 'MFA', rbac: 'RBAC', https: 'HTTPS',
};

export default function Dashboard() {
  const [machines, setMachines] = useState([]);
  const [loading, setLoading] = useState(true);

  async function load() {
    setLoading(true);
    try { setMachines(await getMachines()); }
    catch { setMachines([]); }
    setLoading(false);
  }

  useEffect(() => { load(); }, []);

  return (
    <div>
      <div className={styles.pageHeader}>
        <div>
          <h1 className={styles.title}>Dashboard</h1>
          <p className={styles.subtitle}>Estado general de las máquinas virtuales</p>
        </div>
        <button className={styles.refreshBtn} onClick={load} disabled={loading}>
          {loading ? 'Actualizando...' : '↻ Actualizar'}
        </button>
      </div>

      {loading && machines.length === 0 ? (
        <p className={styles.info}>Verificando estado de las máquinas...</p>
      ) : (
        <div className={styles.grid}>
          {machines.map(m => (
            <div key={m.id} className={styles.machineCard}>
              <div className={styles.machineHeader}>
                <div>
                  <div className={styles.machineName}>{m.name}</div>
                  <div className={styles.machineIp}>{m.ip}</div>
                </div>
                <StatusBadge status={m.online ? 'online' : 'offline'} />
              </div>
              <div className={styles.tags}>
                {m.services.map(s => (
                  <span key={s} className={styles.tag}>{serviceLabels[s] || s}</span>
                ))}
              </div>
            </div>
          ))}
        </div>
      )}

      <div className={styles.quickLinks}>
        <h2 className={styles.sectionTitle}>Acceso rápido</h2>
        <div className={styles.linkGrid}>
          {[
            { href: '/users', label: 'Crear usuario', icon: '👤', desc: 'SSH, FTP, correo y más' },
            { href: '/machines', label: 'Configurar VMs', icon: '🖥', desc: 'IPs y credenciales' },
            { href: '/services/docker', label: 'Contenedores', icon: '◻', desc: 'Estado de Docker' },
            { href: '/services/mail', label: 'Cuentas de correo', icon: '✉', desc: 'Mailserver P12' },
          ].map(l => (
            <a key={l.href} href={l.href} className={styles.quickCard}>
              <span className={styles.quickIcon}>{l.icon}</span>
              <div>
                <div className={styles.quickLabel}>{l.label}</div>
                <div className={styles.quickDesc}>{l.desc}</div>
              </div>
            </a>
          ))}
        </div>
      </div>
    </div>
  );
}
