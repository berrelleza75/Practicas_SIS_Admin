import { useEffect, useState } from 'react';
import ServiceCard from '../../components/ServiceCard';
import { getDnsZones } from '../../api/client';
import styles from './Service.module.css';

export default function DNS() {
  const [zones, setZones] = useState('');

  useEffect(() => {
    getDnsZones().then(d => setZones(d.zones)).catch(() => {});
  }, []);

  return (
    <div>
      <h1 className={styles.title}>DNS</h1>
      <p className={styles.subtitle}>Servidor DNS BIND en Arch Linux (práctica 3, 4)</p>
      <div className={styles.grid}>
        <ServiceCard serviceKey="dns" title="BIND9 / named" icon="◎" />
      </div>
      {zones && (
        <div className={styles.section}>
          <h2 className={styles.sectionTitle}>Zonas configuradas</h2>
          <pre className={styles.pre}>{zones}</pre>
        </div>
      )}
    </div>
  );
}
