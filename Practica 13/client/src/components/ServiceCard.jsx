import { useState } from 'react';
import StatusBadge from './StatusBadge';
import { startService, stopService, getServiceStatus } from '../api/client';
import styles from './ServiceCard.module.css';

export default function ServiceCard({ serviceKey, title, icon, extra }) {
  const [status, setStatus] = useState(null);
  const [loading, setLoading] = useState(false);
  const [log, setLog] = useState('');

  async function refresh() {
    setLoading(true);
    try {
      const data = await getServiceStatus(serviceKey);
      setStatus(data.status);
    } catch { setStatus('error'); }
    setLoading(false);
  }

  async function action(fn) {
    setLoading(true);
    try {
      const r = await fn(serviceKey);
      setLog(r.stdout || r.stderr || 'OK');
      await refresh();
    } catch (e) { setLog(e.message); }
    setLoading(false);
  }

  return (
    <div className={styles.card}>
      <div className={styles.header}>
        <span className={styles.icon}>{icon}</span>
        <span className={styles.title}>{title}</span>
        {status && <StatusBadge status={status} />}
      </div>
      <div className={styles.actions}>
        <button className={styles.btnGhost} onClick={refresh} disabled={loading}>
          {loading ? '...' : 'Estado'}
        </button>
        <button className={styles.btnGreen} onClick={() => action(startService)} disabled={loading}>
          Iniciar
        </button>
        <button className={styles.btnRed} onClick={() => action(stopService)} disabled={loading}>
          Detener
        </button>
      </div>
      {extra}
      {log && <pre className={styles.log}>{log}</pre>}
    </div>
  );
}
