const { NodeSSH } = require('node-ssh');

async function runSSH(machine, command) {
  const ssh = new NodeSSH();
  try {
    await ssh.connect({
      host: machine.ip,
      port: machine.sshPort || 22,
      username: machine.sshUser,
      password: machine.sshPassword,
      readyTimeout: 10000,
    });

    const result = await ssh.execCommand(command);
    return {
      success: result.code === 0,
      stdout: result.stdout,
      stderr: result.stderr,
      code: result.code,
    };
  } catch (err) {
    return { success: false, stdout: '', stderr: err.message, code: -1 };
  } finally {
    ssh.dispose();
  }
}

async function pingMachine(machine) {
  try {
    const result = await runSSH(machine, 'echo ok');
    return result.success;
  } catch {
    return false;
  }
}

module.exports = { runSSH, pingMachine };
