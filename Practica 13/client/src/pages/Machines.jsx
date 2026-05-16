import { useEffect, useState } from 'react';
import { getMachines, updateMachine } from '../api/client';
import StatusBadge from '../components/StatusBadge';
import styles from './Machines.module.css';

export default function Machines() {
  const [machines, setMachines] = useState([]);
  const [editing, setEditing] = useState(null);
  const [form, setForm] = useState({});
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState('');

  useEffect(() => {
    getMachines().then(setMachines).catch(() => {});
  }, []);

  function startEdit(m) {
    setEditing(m.id);
    setForm({
      ip: m.ip,
      sshUser: m.sshUser || '',
      sshPassword: '',
    });
    setMsg('');
  }

  async function save(id) {
    setSaving(true);
    try {
      await updateMachine(id, form);
      setMsg('Guardado correctamente');
      setEditing(null);
      getMachines().then(setMachines);
    } catch { setMsg('Error al guardar'); }
    setSaving(false);
  }

  return (
    <div>
      <h1 className={styles.title}>Máquinas</h1>
      <p className={styles.subtitle}>
        Configura las IPs y credenciales de cada VM. Esta información se usa para conectarse por SSH.
      </p>
      {msg && <p className={styles.msg}>{msg}</p>}
      <div className={styles.list}>
        {machines.map(m => (
          <div key={m.id} className={styles.card}>
            <div className={styles.cardTop}>
              <div>
                <div className={styles.name}>{m.name}</div>
                <div className={styles.type}>{m.type}</div>
              </div>
              <StatusBadge status={m.online ? 'online' : 'offline'} />
            </div>

            {editing === m.id ? (
              <div className={styles.editForm}>
                <label className={styles.label}>IP de la VM</label>
                <input
                  className={styles.input}
                  value={form.ip}
                  onChange={e => setForm(p => ({ ...p, ip: e.target.value }))}
                  placeholder="192.168.1.100"
                />
                {m.type === 'linux' && (
                  <>
                    <label className={styles.label}>Usuario SSH</label>
                    <input
                      className={styles.input}
                      value={form.sshUser}
                      onChange={e => setForm(p => ({ ...p, sshUser: e.target.value }))}
                      placeholder="root"
                    />
                    <label className={styles.label}>Contraseña SSH</label>
                    <input
                      className={styles.input}
                      type="password"
                      value={form.sshPassword}
                      onChange={e => setForm(p => ({ ...p, sshPassword: e.target.value }))}
                      placeholder="Dejar vacío para no cambiar"
                    />
                  </>
                )}
                <div className={styles.editActions}>
                  <button className={styles.btnSave} onClick={() => save(m.id)} disabled={saving}>
                    {saving ? 'Guardando...' : 'Guardar'}
                  </button>
                  <button className={styles.btnCancel} onClick={() => setEditing(null)}>Cancelar</button>
                </div>
              </div>
            ) : (
              <div className={styles.info}>
                <span className={styles.ip}>IP: {m.ip}</span>
                <button className={styles.editBtn} onClick={() => startEdit(m)}>Editar</button>
              </div>
            )}

            <div className={styles.services}>
              {m.services.map(s => <span key={s} className={styles.tag}>{s}</span>)}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
