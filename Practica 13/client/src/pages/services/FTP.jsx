import ServiceCard from '../../components/ServiceCard';
import styles from './Service.module.css';

export default function FTP() {
  return (
    <div>
      <h1 className={styles.title}>FTP</h1>
      <p className={styles.subtitle}>Servidor FTP en Arch Linux (práctica 5, 6)</p>
      <div className={styles.grid}>
        <ServiceCard serviceKey="ftp" title="vsftpd / proftpd" icon="⇅" />
      </div>
    </div>
  );
}
