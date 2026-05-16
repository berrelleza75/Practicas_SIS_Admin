const express = require('express');
const router = express.Router();
const { exec } = require('child_process');
const machinesConfig = require('../config/machines.json');
const { pingMachine } = require('../lib/ssh-client');

function pingIP(ip) {
  return new Promise((resolve) => {
    exec(`ping -n 1 -w 1000 ${ip}`, (err, stdout) => {
      resolve(!err && stdout.includes('TTL='));
    });
  });
}

router.get('/', async (req, res) => {
  const results = await Promise.all(
    machinesConfig.machines.map(async (m) => {
      const online = await pingIP(m.ip);
      return {
        id: m.id,
        name: m.name,
        type: m.type,
        ip: m.ip,
        online,
        services: m.services,
      };
    })
  );
  res.json(results);
});

router.put('/:id', (req, res) => {
  const { id } = req.params;
  const machine = machinesConfig.machines.find((m) => m.id === id);
  if (!machine) return res.status(404).json({ error: 'Maquina no encontrada' });

  const { ip, sshUser, sshPassword, winrmUser, winrmPassword } = req.body;
  if (ip) machine.ip = ip;
  if (sshUser) machine.sshUser = sshUser;
  if (sshPassword) machine.sshPassword = sshPassword;
  if (winrmUser) machine.winrmUser = winrmUser;
  if (winrmPassword) machine.winrmPassword = winrmPassword;

  const fs = require('fs');
  const configPath = require('path').join(__dirname, '../config/machines.json');
  fs.writeFileSync(configPath, JSON.stringify(machinesConfig, null, 2));

  res.json({ success: true, machine });
});

module.exports = router;
