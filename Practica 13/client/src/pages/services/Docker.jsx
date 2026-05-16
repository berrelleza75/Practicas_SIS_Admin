import { useEffect, useState } from 'react';
import { getDockerContainers, dockerAction } from '../../api/client';
import StatusBadge from '../../components/StatusBadge';
import styles from './Service.module.css';

export default function Docker() {
  const [containers, setContainers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [actionLog, setActionLog] = useState('');

  async function load() {
    setLoading(true);
    try { setContainers((await getDockerContainers()).containers); }
    catch { setContainers([]); }
    setLoading(false);
  }

  useEffect(() => { load(); }, []);

  async function act(action, name) {
    try {
      const r = await dockerAction(action, name);
      setActionLog(r.stdout || r.stderr || 'OK');
      load();
    } catch (e) { setActionLog(e.message); }
  }

  return (
    <div>
      <h1 className={styles.title}>Docker</h1>
      <p className={styles.subtitle}>Contenedores en Arch Linux (práctica 10, 11, 12)</p>

      <button className={styles.refreshBtn} onClick={load} disabled={loading}>
        {loading ? '...' : '↻ Actualizar'}
      </button>

      {actionLog && <pre className={styles.pre} style={{ marginTop: 16 }}>{actionLog}</pre>}

      <div className={styles.tableWrap}>
        <table className={styles.table}>
          <thead>
            <tr>
              <th>Nombre</th>
              <th>Imagen</th>
              <th>Estado</th>
              <th>Puertos</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {containers.length === 0 ? (
              <tr><td colSpan={5} className={styles.empty}>
                {loading ? 'Cargando...' : 'Sin contenedores o VM desconectada'}
              </td></tr>
            ) : containers.map(c => (
              <tr key={c.ID}>
                <td className={styles.mono}>{c.Names}</td>
                <td className={styles.mono} style={{ color: 'var(--text2)' }}>{c.Image}</td>
                <td><StatusBadge status={c.State} /></td>
                <td className={styles.mono} style={{ fontSize: 11, color: 'var(--text2)' }}>{c.Ports || '—'}</td>
                <td>
                  <div style={{ display: 'flex', gap: 6 }}>
                    <button className={styles.btnGreen} onClick={() => act('start', c.Names)}>Iniciar</button>
                    <button className={styles.btnRed}   onClick={() => act('stop',  c.Names)}>Detener</button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
