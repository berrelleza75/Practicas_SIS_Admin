import { useEffect, useState } from 'react';
import { getMailAccounts } from '../../api/client';
import StatusBadge from '../../components/StatusBadge';
import styles from './Service.module.css';

export default function Mail() {
  const [status, setStatus] = useState(null);
  const [accounts, setAccounts] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      fetch('/api/services/mail/status').then(r => r.json()),
      getMailAccounts(),
    ]).then(([s, a]) => {
      setStatus(s.status);
      setAccounts(a.accounts);
    }).catch(() => {}).finally(() => setLoading(false));
  }, []);

  return (
    <div>
      <h1 className={styles.title}>Correo</h1>
      <p className={styles.subtitle}>Servidor de correo Docker (práctica 12) — docker-mailserver + Roundcube</p>

      <div className={styles.statusRow}>
        <span className={styles.serviceLabel}>p12_mailserver</span>
        {loading ? <span style={{ color: 'var(--text2)', fontSize: 13 }}>verificando...</span>
                 : <StatusBadge status={status} />}
      </div>

      <div className={styles.section}>
        <h2 className={styles.sectionTitle}>Cuentas de correo</h2>
        {accounts
          ? <pre className={styles.pre}>{accounts}</pre>
          : <p style={{ color: 'var(--text2)', fontSize: 13 }}>Sin cuentas o VM desconectada</p>
        }
      </div>
    </div>
  );
}
