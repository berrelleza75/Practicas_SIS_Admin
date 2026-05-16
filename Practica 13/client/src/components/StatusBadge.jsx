import styles from './StatusBadge.module.css';

export default function StatusBadge({ status }) {
  const active = status === 'active' || status === 'online' || status === 'running';
  const inactive = status === 'inactive' || status === 'offline' || status === 'stopped' || status === 'exited';

  const cls = active ? styles.green : inactive ? styles.red : styles.yellow;
  const label = active ? 'Activo' : inactive ? 'Inactivo' : status || 'Desconocido';

  return <span className={`${styles.badge} ${cls}`}>{label}</span>;
}
