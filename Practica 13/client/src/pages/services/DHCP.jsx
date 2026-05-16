import { useEffect, useState } from 'react';
import ServiceCard from '../../components/ServiceCard';
import { getDhcpLeases } from '../../api/client';
import styles from './Service.module.css';

export default function DHCP() {
  const [leases, setLeases] = useState('');

  useEffect(() => {
    getDhcpLeases().then(d => setLeases(d.leases)).catch(() => {});
  }, []);

  return (
    <div>
      <h1 className={styles.title}>DHCP</h1>
      <p className={styles.subtitle}>Servidor DHCP en Arch Linux (práctica 2, 4)</p>
      <div className={styles.grid}>
        <ServiceCard serviceKey="dhcp" title="DHCP Server" icon="◈" />
      </div>
      {leases && (
        <div className={styles.section}>
          <h2 className={styles.sectionTitle}>Concesiones activas</h2>
          <pre className={styles.pre}>{leases}</pre>
        </div>
      )}
    </div>
  );
}
