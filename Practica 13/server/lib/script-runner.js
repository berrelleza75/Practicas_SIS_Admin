const { exec } = require('child_process');
const path = require('path');

const SCRIPTS_BASE = path.join(__dirname, '..', '..', '..', 'Modulos');

function runPowerShell(scriptRelPath, args = []) {
  const scriptPath = path.join(SCRIPTS_BASE, 'powershell', scriptRelPath);
  const argsStr = args.map(a => `"${a}"`).join(' ');
  const cmd = `powershell -NoProfile -ExecutionPolicy Bypass -File "${scriptPath}" ${argsStr}`;

  return new Promise((resolve) => {
    exec(cmd, { timeout: 30000 }, (err, stdout, stderr) => {
      resolve({
        success: !err,
        stdout: stdout || '',
        stderr: stderr || (err ? err.message : ''),
      });
    });
  });
}

function runBash(scriptRelPath, args = [], machine = null) {
  if (!machine) {
    return Promise.resolve({ success: false, stdout: '', stderr: 'Se requiere maquina para bash' });
  }
  const { runSSH } = require('./ssh-client');
  const scriptPath = `/tmp/sis-admin/${scriptRelPath}`;
  const argsStr = args.join(' ');
  return runSSH(machine, `bash ${scriptPath} ${argsStr}`);
}

module.exports = { runPowerShell, runBash };
