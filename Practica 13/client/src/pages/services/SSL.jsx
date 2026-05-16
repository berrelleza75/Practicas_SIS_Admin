import { useEffect, useState } from 'react';
import ServiceCard from '../../components/ServiceCard';
import { getSslCerts } from '../../api/client';
import styles from './Service.module.css';

export default function SSL() {
  const [certs, setCerts] = useState('');

  useEffect(() => {
    getSslCerts().then(d => setCerts(d.certs)).catch(() => {});
  }, []);

  return (
    <div>
      <h1 className={styles.title}>SSL / HTTPS</h1>
      <p className={styles.subtitle}>Certificados y servidor web seguro (práctica 7)</p>
      <div className={styles.grid}>
        <ServiceCard serviceKey="ssl" title="Servidor Web (nginx / apache)" icon="🔒" />
      </div>
      {certs && (
        <div className={styles.section}>
          <h2 className={styles.sectionTitle}>Certificados en /etc/ssl/certs/</h2>
          <pre className={styles.pre}>{certs}</pre>
        </div>
      )}
    </div>
  );
}
