import ServiceCard from '../../components/ServiceCard';
import styles from './Service.module.css';

export default function SSH() {
  return (
    <div>
      <h1 className={styles.title}>SSH</h1>
      <p className={styles.subtitle}>Gestión del servidor SSH en Arch Linux (práctica 4, 6)</p>
      <div className={styles.grid}>
        <ServiceCard serviceKey="ssh" title="OpenSSH Server" icon="⌨" />
      </div>
    </div>
  );
}
