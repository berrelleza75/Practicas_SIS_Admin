const express = require('express');
const router = express.Router();
const machinesConfig = require('../config/machines.json');
const { runSSH } = require('../lib/ssh-client');

function getMachine(id) {
  return machinesConfig.machines.find((m) => m.id === id);
}

// Crear usuario en múltiples servicios
router.post('/', async (req, res) => {
  const { username, password, services } = req.body;

  if (!username || !password || !services?.length) {
    return res.status(400).json({ error: 'username, password y services son requeridos' });
  }

  const results = {};

  for (const service of services) {
    try {
      switch (service) {
        case 'ssh': {
          const m = getMachine('arch-linux');
          const r = await runSSH(m,
            `id ${username} &>/dev/null || useradd -m ${username} && echo '${username}:${password}' | chpasswd`
          );
          results.ssh = r;
          break;
        }
        case 'ftp': {
          const m = getMachine('arch-linux');
          const r = await runSSH(m,
            `id ${username} &>/dev/null || useradd -m ${username} && echo '${username}:${password}' | chpasswd && mkdir -p /home/${username}/ftp`
          );
          results.ftp = r;
          break;
        }
        case 'mail': {
          const m = getMachine('arch-linux');
          const r = await runSSH(m,
            `docker exec p12_mailserver setup email add ${username}@$(hostname -d) '${password}'`
          );
          results.mail = r;
          break;
        }
        case 'pgadmin': {
          const m = getMachine('arch-linux');
          const r = await runSSH(m,
            `docker exec -it $(docker ps -qf name=postgres) psql -U postgres -c "CREATE USER ${username} WITH PASSWORD '${password}';" 2>/dev/null || true`
          );
          results.pgadmin = r;
          break;
        }
        case 'active-directory': {
          const m = getMachine('win-server');
          // Ejecutado vía SSH si Win Server tiene OpenSSH, o marcar para WinRM
          results['active-directory'] = {
            success: false,
            stderr: 'Requiere WinRM — configura credenciales en Maquinas',
          };
          break;
        }
        default:
          results[service] = { success: false, stderr: 'Servicio no implementado' };
      }
    } catch (err) {
      results[service] = { success: false, stderr: err.message };
    }
  }

  res.json({ username, results });
});

module.exports = router;
