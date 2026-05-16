import { useState } from 'react';
import { createUser } from '../api/client';
import styles from './Users.module.css';

const SERVICES = [
  { key: 'ssh',             label: 'SSH',            icon: '⌨', desc: 'Acceso por terminal' },
  { key: 'ftp',             label: 'FTP',            icon: '⇅', desc: 'Acceso a archivos FTP' },
  { key: 'mail',            label: 'Correo',         icon: '✉', desc: 'Cuenta de email (P12)' },
  { key: 'pgadmin',         label: 'pgAdmin / DB',   icon: '🗄', desc: 'Usuario en PostgreSQL' },
  { key: 'active-directory',label: 'Active Directory',icon: '◈', desc: 'Usuario en AD (Win Server)' },
];

export default function Users() {
  const [form, setForm] = useState({ username: '', password: '' });
  const [selected, setSelected] = useState([]);
  const [result, setResult] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  function toggleService(key) {
    setSelected(prev =>
      prev.includes(key) ? prev.filter(k => k !== key) : [...prev, key]
    );
  }

  async function handleSubmit(e) {
    e.preventDefault();
    if (!form.username || !form.password) {
      setError('El nombre de usuario y contraseña son requeridos.');
      return;
    }
    if (!selected.length) {
      setError('Selecciona al menos un servicio.');
      return;
    }
    setError('');
    setLoading(true);
    setResult(null);
    try {
      const data = await createUser({ ...form, services: selected });
      setResult(data);
    } catch (e) {
      setError(e.response?.data?.error || e.message);
    }
    setLoading(false);
  }

  return (
    <div>
      <h1 className={styles.title}>Gestión de Usuarios</h1>
      <p className={styles.subtitle}>
        Crea un usuario y asígnalo a los servicios que necesite.
      </p>

      <div className={styles.layout}>
        <form className={styles.form} onSubmit={handleSubmit}>
          <div className={styles.field}>
            <label className={styles.label}>Nombre de usuario</label>
            <input
              className={styles.input}
              type="text"
              placeholder="ej: jberrelleza"
              value={form.username}
              onChange={e => setForm(p => ({ ...p, username: e.target.value }))}
              autoComplete="off"
            />
          </div>
          <div className={styles.field}>
            <label className={styles.label}>Contraseña</label>
            <input
              className={styles.input}
              type="password"
              placeholder="Contraseña segura"
              value={form.password}
              onChange={e => setForm(p => ({ ...p, password: e.target.value }))}
            />
          </div>

          <div className={styles.field}>
            <label className={styles.label}>Servicios a asignar</label>
            <div className={styles.serviceGrid}>
              {SERVICES.map(s => (
                <button
                  key={s.key}
                  type="button"
                  className={`${styles.serviceBtn} ${selected.includes(s.key) ? styles.selected : ''}`}
                  onClick={() => toggleService(s.key)}
                >
                  <span className={styles.serviceIcon}>{s.icon}</span>
                  <div>
                    <div className={styles.serviceLabel}>{s.label}</div>
                    <div className={styles.serviceDesc}>{s.desc}</div>
                  </div>
                </button>
              ))}
            </div>
          </div>

          {error && <p className={styles.error}>{error}</p>}

          <button className={styles.submitBtn} disabled={loading}>
            {loading ? 'Creando usuario...' : 'Crear usuario'}
          </button>
        </form>

        {result && (
          <div className={styles.results}>
            <h2 className={styles.resultsTitle}>Resultado para "{result.username}"</h2>
            {Object.entries(result.results).map(([svc, r]) => (
              <div key={svc} className={`${styles.resultItem} ${r.success ? styles.ok : styles.fail}`}>
                <div className={styles.resultHeader}>
                  <span className={styles.resultIcon}>{r.success ? '✓' : '✗'}</span>
                  <span className={styles.resultService}>
                    {SERVICES.find(s => s.key === svc)?.label || svc}
                  </span>
                </div>
                {(r.stdout || r.stderr) && (
                  <pre className={styles.resultLog}>{r.stdout || r.stderr}</pre>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
