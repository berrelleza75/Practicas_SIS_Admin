const express = require('express');
const router = express.Router();
const machinesConfig = require('../config/machines.json');
const { runSSH } = require('../lib/ssh-client');

function getMachine(id) {
  return machinesConfig.machines.find((m) => m.id === id);
}

async function ssh(machineId, cmd) {
  const m = getMachine(machineId);
  if (!m) return { success: false, stderr: 'Maquina no configurada' };
  return runSSH(m, cmd);
}

// ─── SSH ───────────────────────────────────────────────────────────────
router.get('/ssh/status', async (req, res) => {
  const r = await ssh('arch-linux', 'systemctl is-active sshd');
  res.json({ service: 'sshd', status: r.stdout.trim(), raw: r });
});

router.post('/ssh/start', async (req, res) => {
  res.json(await ssh('arch-linux', 'systemctl start sshd'));
});

router.post('/ssh/stop', async (req, res) => {
  res.json(await ssh('arch-linux', 'systemctl stop sshd'));
});

// ─── DHCP ──────────────────────────────────────────────────────────────
router.get('/dhcp/status', async (req, res) => {
  const r = await ssh('arch-linux', 'systemctl is-active dhcpd 2>/dev/null || systemctl is-active isc-dhcp-server 2>/dev/null || echo inactive');
  res.json({ service: 'dhcp', status: r.stdout.trim(), raw: r });
});

router.post('/dhcp/start', async (req, res) => {
  res.json(await ssh('arch-linux', 'systemctl start dhcpd 2>/dev/null || systemctl start isc-dhcp-server'));
});

router.post('/dhcp/stop', async (req, res) => {
  res.json(await ssh('arch-linux', 'systemctl stop dhcpd 2>/dev/null || systemctl stop isc-dhcp-server'));
});

router.get('/dhcp/leases', async (req, res) => {
  const r = await ssh('arch-linux', 'cat /var/lib/dhcpd/dhcpd.leases 2>/dev/null || cat /var/lib/dhcp/dhcpd.leases 2>/dev/null || echo "Sin concesiones"');
  res.json({ leases: r.stdout });
});

// ─── DNS ───────────────────────────────────────────────────────────────
router.get('/dns/status', async (req, res) => {
  const r = await ssh('arch-linux', 'systemctl is-active named 2>/dev/null || systemctl is-active bind9 2>/dev/null || echo inactive');
  res.json({ service: 'dns', status: r.stdout.trim(), raw: r });
});

router.post('/dns/start', async (req, res) => {
  res.json(await ssh('arch-linux', 'systemctl start named 2>/dev/null || systemctl start bind9'));
});

router.post('/dns/stop', async (req, res) => {
  res.json(await ssh('arch-linux', 'systemctl stop named 2>/dev/null || systemctl stop bind9'));
});

router.get('/dns/zones', async (req, res) => {
  const r = await ssh('arch-linux', 'named-checkconf -p 2>/dev/null | grep zone | head -20');
  res.json({ zones: r.stdout });
});

// ─── FTP ───────────────────────────────────────────────────────────────
router.get('/ftp/status', async (req, res) => {
  const r = await ssh('arch-linux', 'systemctl is-active vsftpd 2>/dev/null || systemctl is-active proftpd 2>/dev/null || echo inactive');
  res.json({ service: 'ftp', status: r.stdout.trim(), raw: r });
});

router.post('/ftp/start', async (req, res) => {
  res.json(await ssh('arch-linux', 'systemctl start vsftpd 2>/dev/null || systemctl start proftpd'));
});

router.post('/ftp/stop', async (req, res) => {
  res.json(await ssh('arch-linux', 'systemctl stop vsftpd 2>/dev/null || systemctl stop proftpd'));
});

// ─── SSL / HTTPS ───────────────────────────────────────────────────────
router.get('/ssl/certs', async (req, res) => {
  const r = await ssh('arch-linux', 'ls -la /etc/ssl/certs/ 2>/dev/null | head -20');
  res.json({ certs: r.stdout });
});

router.get('/ssl/status', async (req, res) => {
  const r = await ssh('arch-linux', 'systemctl is-active nginx 2>/dev/null || systemctl is-active apache2 2>/dev/null || systemctl is-active httpd 2>/dev/null || echo inactive');
  res.json({ service: 'web', status: r.stdout.trim(), raw: r });
});

// ─── DOCKER ────────────────────────────────────────────────────────────
router.get('/docker/containers', async (req, res) => {
  const r = await ssh('arch-linux', 'docker ps -a --format "{{json .}}" 2>/dev/null');
  const lines = r.stdout.trim().split('\n').filter(Boolean);
  const containers = lines.map(l => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean);
  res.json({ containers });
});

router.post('/docker/start', async (req, res) => {
  const { container } = req.body;
  if (!container) return res.status(400).json({ error: 'container requerido' });
  res.json(await ssh('arch-linux', `docker start ${container}`));
});

router.post('/docker/stop', async (req, res) => {
  const { container } = req.body;
  if (!container) return res.status(400).json({ error: 'container requerido' });
  res.json(await ssh('arch-linux', `docker stop ${container}`));
});

// ─── CORREO ────────────────────────────────────────────────────────────
router.get('/mail/status', async (req, res) => {
  const r = await ssh('arch-linux', 'docker inspect p12_mailserver --format "{{.State.Status}}" 2>/dev/null || echo "no encontrado"');
  res.json({ service: 'mailserver', status: r.stdout.trim() });
});

router.get('/mail/accounts', async (req, res) => {
  const r = await ssh('arch-linux', 'docker exec p12_mailserver setup email list 2>/dev/null || echo "Sin cuentas"');
  res.json({ accounts: r.stdout });
});

module.exports = router;
