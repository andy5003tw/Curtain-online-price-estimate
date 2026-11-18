import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createServer } from 'node:net';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(scriptDir, '..');
const deployScript = path.join(scriptDir, 'deploy-ftp.ps1');
const tempPrefix = 'curtain-deploy-ftp-test-';
let activeServer;

function sha256(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

function normalizeFtpPath(value) {
  let decoded = String(value ?? '').trim();
  try {
    decoded = decodeURIComponent(decoded);
  } catch {
    // Preserve malformed encodings as literal FTP path characters.
  }
  const parts = decoded.replaceAll('\\', '/').split('/').filter(Boolean);
  return `/${parts.join('/')}`;
}

class LocalFtpServer {
  constructor() {
    this.files = new Map();
    this.directories = new Set(['/']);
    this.failRetrPaths = new Set();
    this.commands = [];
    this.connectionCount = 0;
    this.nextConnectionId = 1;
    this.controlSockets = new Set();
    this.passiveServers = new Set();
    this.server = createServer((socket) => this.acceptControl(socket));
  }

  async start() {
    await new Promise((resolve, reject) => {
      this.server.once('error', reject);
      this.server.listen(0, '127.0.0.1', resolve);
    });
    const address = this.server.address();
    assert(address && typeof address === 'object', 'local FTP server did not bind a TCP port');
    this.port = address.port;
    return this;
  }

  async stop() {
    for (const socket of this.controlSockets) socket.destroy();
    for (const passiveServer of this.passiveServers) {
      try { passiveServer.close(); } catch { /* already closed */ }
    }
    await new Promise((resolve) => this.server.close(() => resolve()));
  }

  absolutePath(rawPath) {
    return normalizeFtpPath(rawPath);
  }

  setFile(rawPath, bytes) {
    this.files.set(this.absolutePath(rawPath), Buffer.from(bytes));
  }

  getFile(rawPath) {
    const bytes = this.files.get(this.absolutePath(rawPath));
    return bytes ? Buffer.from(bytes) : null;
  }

  countCommand(verb, rawPath = undefined) {
    const normalizedVerb = verb.toUpperCase();
    const normalizedPath = rawPath === undefined ? undefined : this.absolutePath(rawPath);
    return this.commands.filter((entry) => entry.verb === normalizedVerb &&
      (normalizedPath === undefined || entry.path === normalizedPath)).length;
  }

  acceptControl(socket) {
    socket.setNoDelay(true);
    this.connectionCount += 1;
    this.controlSockets.add(socket);
    const control = {
      id: this.nextConnectionId++,
      socket,
      buffer: '',
      queue: Promise.resolve(),
      passive: null,
      closed: false,
      send: (line) => {
        if (!socket.destroyed) socket.write(`${line}\r\n`);
      },
    };
    socket.on('data', (chunk) => {
      control.buffer += chunk.toString('utf8');
      while (true) {
        const newline = control.buffer.indexOf('\n');
        if (newline < 0) break;
        const line = control.buffer.slice(0, newline).replace(/\r$/, '');
        control.buffer = control.buffer.slice(newline + 1);
        if (!line) continue;
        control.queue = control.queue
          .then(() => this.handleCommand(control, line))
          .catch((error) => {
            this.commands.push({ connectionId: control.id, verb: 'SERVER_ERROR', arg: String(error) });
            control.send('451 Local test FTP server error');
          });
      }
    });
    socket.on('close', () => {
      control.closed = true;
      this.controlSockets.delete(socket);
      this.closePassive(control);
    });
    socket.on('error', () => {});
    control.send('220 Local test FTP ready');
  }

  closePassive(control) {
    const passive = control.passive;
    if (!passive) return;
    control.passive = null;
    passive.closed = true;
    if (passive.socket && !passive.socket.destroyed) passive.socket.destroy();
    try { passive.server.close(); } catch { /* already closed */ }
    this.passiveServers.delete(passive.server);
  }

  async openPassive(control, extended) {
    this.closePassive(control);
    const passive = {
      server: createServer((socket) => {
        socket.setNoDelay(true);
        passive.socket = socket;
        socket.on('error', () => {});
        this.maybeStartTransfer(passive);
      }),
      socket: null,
      command: null,
      started: false,
      closed: false,
      control,
    };
    this.passiveServers.add(passive.server);
    await new Promise((resolve, reject) => {
      passive.server.once('error', reject);
      passive.server.listen(0, '127.0.0.1', resolve);
    });
    const address = passive.server.address();
    assert(address && typeof address === 'object', 'passive FTP listener did not bind a TCP port');
    control.passive = passive;
    if (extended) {
      control.send(`229 Entering Extended Passive Mode (|||${address.port}|)`);
    } else {
      const p1 = Math.floor(address.port / 256);
      const p2 = address.port % 256;
      control.send(`227 Entering Passive Mode (127,0,0,1,${p1},${p2})`);
    }
  }

  maybeStartTransfer(passive) {
    if (passive.started || passive.closed || !passive.socket || !passive.command) return;
    passive.started = true;
    const { type, ftpPath } = passive.command;
    const control = passive.control;

    if (type === 'RETR') {
      const remoteBytes = this.files.get(ftpPath);
      if (this.failRetrPaths.has(ftpPath)) {
        control.send('550 Remote content read disabled by local test');
        passive.socket.destroy();
        this.closePassive(control);
        return;
      }
      if (!remoteBytes) {
        control.send('550 File not found');
        passive.socket.destroy();
        this.closePassive(control);
        return;
      }

      control.send('150 Opening binary data connection');
      passive.socket.end(Buffer.from(remoteBytes), () => {
        control.send('226 Transfer complete');
        this.closePassive(control);
      });
      return;
    }

    if (type === 'STOR') {
      const chunks = [];
      control.send('150 Opening binary data connection');
      let completed = false;
      const finish = () => {
        if (completed) return;
        completed = true;
        this.files.set(ftpPath, Buffer.concat(chunks));
        control.send('226 Transfer complete');
        this.closePassive(control);
      };
      passive.socket.on('data', (chunk) => chunks.push(Buffer.from(chunk)));
      passive.socket.once('end', finish);
      passive.socket.once('close', finish);
      return;
    }

    control.send('425 Unsupported local test data transfer');
    this.closePassive(control);
  }

  async handleCommand(control, line) {
    const separator = line.indexOf(' ');
    const verb = (separator < 0 ? line : line.slice(0, separator)).toUpperCase();
    const arg = separator < 0 ? '' : line.slice(separator + 1).trim();
    const pathVerbs = new Set(['CWD', 'MKD', 'RMD', 'SIZE', 'MDTM', 'RETR', 'STOR', 'DELE']);
    const ftpPath = pathVerbs.has(verb) ? this.absolutePath(arg) : undefined;
    this.commands.push({ connectionId: control.id, verb, arg, path: ftpPath });

    switch (verb) {
      case 'USER': control.send('331 Password required'); return;
      case 'PASS': control.send('230 Logged in'); return;
      case 'TYPE': control.send('200 Type set'); return;
      case 'OPTS': control.send('200 Option accepted'); return;
      case 'SYST': control.send('215 UNIX Type: L8'); return;
      case 'PWD': control.send('257 "/" is the current directory'); return;
      case 'CWD': control.send('250 Directory changed'); return;
      case 'NOOP': control.send('200 NOOP ok'); return;
      case 'FEAT': control.send('211-Features\r\n SIZE\r\n211 End'); return;
      case 'PASV': await this.openPassive(control, false); return;
      case 'EPSV': await this.openPassive(control, true); return;
      case 'SIZE': {
        const bytes = this.files.get(ftpPath);
        if (!bytes) control.send('550 File not found');
        else control.send(`213 ${bytes.length}`);
        return;
      }
      case 'MDTM': {
        if (!this.files.has(ftpPath)) control.send('550 File not found');
        else control.send('213 20261029000000');
        return;
      }
      case 'MKD': {
        if (this.directories.has(ftpPath)) control.send('550 Directory exists');
        else {
          this.directories.add(ftpPath);
          control.send(`257 "${ftpPath}" created`);
        }
        return;
      }
      case 'RETR': {
        const passive = control.passive;
        if (!passive) { control.send('425 Use PASV or EPSV first'); return; }
        passive.command = { type: 'RETR', ftpPath };
        this.maybeStartTransfer(passive);
        return;
      }
      case 'STOR': {
        const passive = control.passive;
        if (!passive) { control.send('425 Use PASV or EPSV first'); return; }
        passive.command = { type: 'STOR', ftpPath };
        this.maybeStartTransfer(passive);
        return;
      }
      case 'DELE':
        this.files.delete(ftpPath);
        control.send('250 File deleted');
        return;
      case 'QUIT':
        control.send('221 Goodbye');
        control.socket.end();
        return;
      default:
        control.send('200 Command accepted');
    }
  }
}

function assertUnderTempRoot(tempRoot) {
  const absoluteTempRoot = path.resolve(tempRoot);
  const absoluteTempParent = path.resolve(os.tmpdir());
  assert.equal(tempRoot, absoluteTempRoot, 'mkdtempSync must return an absolute path');
  assert.equal(path.dirname(absoluteTempRoot), absoluteTempParent, 'test temp root must be directly inside the OS temp directory');
  assert(path.basename(absoluteTempRoot).startsWith(tempPrefix), 'test temp root must retain its unique mkdtemp prefix');
  return absoluteTempRoot;
}

function writeLocalFile(tempRoot, name, bytes) {
  const localRoot = path.join(tempRoot, name, 'out');
  fs.mkdirSync(localRoot, { recursive: true });
  fs.writeFileSync(path.join(localRoot, 'fixture.bin'), bytes);
  return localRoot;
}

function invokeDeploy({ localRoot, manifestPath, port, force = false, dryRun = false }) {
  const args = [
    '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', deployScript,
    '-Mode', 'paths', '-Path', 'fixture.bin',
    '-LocalRoot', localRoot,
    '-HostName', `127.0.0.1:${port}`,
    '-RemoteRoot', 'online.hong-sen.com',
    '-UserName', 'local-test-user',
    '-Password', 'local-test-password',
    '-ManifestPath', manifestPath,
    '-Retries', '0',
    '-TimeoutSec', '10',
  ];
  if (force) args.push('-Force');
  if (dryRun) args.push('-DryRun');

  return new Promise((resolve, reject) => {
    const child = spawn(process.env.PWSH || 'pwsh', args, {
      cwd: repoRoot,
      windowsHide: true,
      env: process.env,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let stdout = '';
    let stderr = '';
    const timer = setTimeout(() => child.kill(), 30_000);
    child.stdout.setEncoding('utf8').on('data', (chunk) => { stdout += chunk; });
    child.stderr.setEncoding('utf8').on('data', (chunk) => { stderr += chunk; });
    child.once('error', (error) => {
      clearTimeout(timer);
      reject(error);
    });
    child.once('close', (status, signal) => {
      clearTimeout(timer);
      if (status !== 0) {
        reject(new Error([
          `deploy-ftp.ps1 exited with status ${status}${signal ? ` (signal ${signal})` : ''}`,
          stdout,
          stderr,
          activeServer ? `Local FTP commands: ${JSON.stringify(activeServer.commands)}` : '',
        ].filter(Boolean).join('\n')));
        return;
      }
      try {
        assert(fs.existsSync(manifestPath), `deployment manifest was not written: ${manifestPath}`);
        resolve({
          stdout,
          stderr,
          manifest: JSON.parse(fs.readFileSync(manifestPath, 'utf8')),
        });
      } catch (error) {
        reject(error);
      }
    });
  });
}

function soleFile(manifest) {
  assert(Array.isArray(manifest.files), 'deployment manifest files must be an array');
  assert.equal(manifest.files.length, 1, 'each fixture deploy must select exactly one file');
  assert.equal(manifest.files[0].relative_path, 'fixture.bin');
  return manifest.files[0];
}

async function main() {
  let tempRoot;
  let server;
  try {
    tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), tempPrefix));
    assertUnderTempRoot(tempRoot);
    server = await new LocalFtpServer().start();
    activeServer = server;

    const remotePath = '/online.hong-sen.com/fixture.bin';

    // Dry-run is isolated from the network: even the loopback server must see no connection.
    const dryBytes = Buffer.from('dry-run local payload\n');
    const dryLocalRoot = writeLocalFile(tempRoot, 'dry-run', dryBytes);
    const dryManifestPath = path.join(tempRoot, 'dry-run-manifest.json');
    const connectionsBeforeDryRun = server.connectionCount;
    const dry = await invokeDeploy({ localRoot: dryLocalRoot, manifestPath: dryManifestPath, port: server.port, dryRun: true });
    assert.equal(dry.manifest.status, 'dry_run');
    assert.equal(soleFile(dry.manifest).result, 'would_upload');
    assert.equal(server.connectionCount, connectionsBeforeDryRun, 'DryRun opened an FTP connection');
    assert.equal(server.commands.length, 0, 'DryRun sent an FTP command');

    // A same-size but different remote payload must upload after RETR hash comparison.
    const changedBytes = Buffer.from('new public content\n');
    const oldSameSizeBytes = Buffer.from('old public content\n');
    assert.equal(changedBytes.length, oldSameSizeBytes.length, 'fixture payloads must have the same byte length');
    const changedLocalRoot = writeLocalFile(tempRoot, 'changed-content', changedBytes);
    server.setFile(remotePath, oldSameSizeBytes);
    const changedManifestPath = path.join(tempRoot, 'changed-content-manifest.json');
    const changed = await invokeDeploy({ localRoot: changedLocalRoot, manifestPath: changedManifestPath, port: server.port });
    assert.equal(changed.manifest.status, 'success');
    assert.equal(soleFile(changed.manifest).result, 'uploaded', 'same-size different content was incorrectly skipped');
    assert.equal(soleFile(changed.manifest).sha256, sha256(changedBytes), 'manifest local SHA-256 is wrong');
    assert.equal(sha256(server.getFile(remotePath)), soleFile(changed.manifest).sha256, 'remote content SHA-256 does not match the manifest');
    assert.deepEqual(server.getFile(remotePath), changedBytes, 'remote content does not match the local file after upload');
    assert.equal(server.countCommand('RETR', remotePath), 1, 'same-size content comparison did not read the remote file');
    assert.equal(server.countCommand('STOR', remotePath), 1, 'same-size different content was not uploaded');

    // Identical remote and local bytes may be skipped only after their SHA-256 values match.
    const identicalBytes = Buffer.from('already current bytes\n');
    const identicalLocalRoot = writeLocalFile(tempRoot, 'same-content', identicalBytes);
    server.setFile(remotePath, identicalBytes);
    const identicalManifestPath = path.join(tempRoot, 'same-content-manifest.json');
    const storBeforeSameContent = server.countCommand('STOR', remotePath);
    const identical = await invokeDeploy({ localRoot: identicalLocalRoot, manifestPath: identicalManifestPath, port: server.port });
    const identicalFile = soleFile(identical.manifest);
    assert.equal(identical.manifest.status, 'success');
    assert.equal(identicalFile.result, 'skipped_same_hash', 'identical bytes were not recorded as skipped_same_hash');
    assert.equal(identicalFile.sha256, sha256(identicalBytes), 'same-content local SHA-256 is wrong');
    assert.equal(identicalFile.remote_sha256_before, sha256(identicalBytes), 'same-content remote SHA-256 is wrong');
    assert.equal(server.countCommand('STOR', remotePath), storBeforeSameContent, 'same-content file was uploaded instead of skipped');
    assert.deepEqual(server.getFile(remotePath), identicalBytes, 'same-content remote bytes changed unexpectedly');

    // If remote content cannot be read, the script must upload instead of trusting SIZE alone.
    const unreadableBytes = Buffer.from('replaced inaccessible payload\n');
    const unreadableOldBytes = Buffer.from('retained inaccessible payload\n');
    assert.equal(unreadableBytes.length, unreadableOldBytes.length, 'unreadable fixture payloads must have the same byte length');
    const unreadableLocalRoot = writeLocalFile(tempRoot, 'unreadable-remote', unreadableBytes);
    server.setFile(remotePath, unreadableOldBytes);
    server.failRetrPaths.add(remotePath);
    const unreadableManifestPath = path.join(tempRoot, 'unreadable-remote-manifest.json');
    const storBeforeUnreadable = server.countCommand('STOR', remotePath);
    const unreadable = await invokeDeploy({ localRoot: unreadableLocalRoot, manifestPath: unreadableManifestPath, port: server.port });
    assert.equal(soleFile(unreadable.manifest).result, 'uploaded', 'unreadable remote contents were treated as a safe skip');
    assert.equal(server.countCommand('RETR', remotePath), 3, 'the inaccessible remote content was not read/attempted');
    assert.equal(server.countCommand('STOR', remotePath), storBeforeUnreadable + 1, 'read failure did not fall back to upload');
    assert.equal(sha256(server.getFile(remotePath)), soleFile(unreadable.manifest).sha256, 'fallback-upload remote SHA-256 does not match the manifest');
    assert.deepEqual(server.getFile(remotePath), unreadableBytes, 'remote content does not match local bytes after read-failure fallback');
    server.failRetrPaths.delete(remotePath);

    // Force always uploads, including when remote and local bytes already match.
    const forceBytes = Buffer.from('force must upload this\n');
    const forceLocalRoot = writeLocalFile(tempRoot, 'force', forceBytes);
    server.setFile(remotePath, forceBytes);
    const forceManifestPath = path.join(tempRoot, 'force-manifest.json');
    const sizeBeforeForce = server.countCommand('SIZE', remotePath);
    const retrBeforeForce = server.countCommand('RETR', remotePath);
    const storBeforeForce = server.countCommand('STOR', remotePath);
    const forced = await invokeDeploy({ localRoot: forceLocalRoot, manifestPath: forceManifestPath, port: server.port, force: true });
    assert.equal(soleFile(forced.manifest).result, 'uploaded', 'Force did not upload identical remote content');
    assert.equal(server.countCommand('SIZE', remotePath), sizeBeforeForce, 'Force queried remote size');
    assert.equal(server.countCommand('RETR', remotePath), retrBeforeForce, 'Force read remote content');
    assert.equal(server.countCommand('STOR', remotePath), storBeforeForce + 1, 'Force did not issue STOR');
    assert.equal(sha256(server.getFile(remotePath)), soleFile(forced.manifest).sha256, 'Force-upload remote SHA-256 does not match the manifest');
    assert.deepEqual(server.getFile(remotePath), forceBytes, 'Force upload did not preserve the local bytes');

    console.log('PASS deploy-ftp local integration test');
    console.log('  same-size different content: uploaded and remote bytes match');
    console.log('  same content: skipped_same_hash with matching local/remote SHA-256');
    console.log('  RETR failure: uploaded successfully');
    console.log('  Force: uploaded without SIZE/RETR checks');
    console.log('  DryRun: generated manifest without opening an FTP connection');
  } finally {
    if (server) await server.stop();
    if (tempRoot) {
      const confirmedTempRoot = assertUnderTempRoot(tempRoot);
      // `tempRoot` is the exact absolute directory returned by fs.mkdtempSync above.
      assert.equal(confirmedTempRoot, tempRoot, 'refusing to clean up an unconfirmed test temp path');
      fs.rmSync(tempRoot, { recursive: true, force: true });
    }
  }
}

main().catch((error) => {
  console.error(error?.stack || String(error));
  process.exitCode = 1;
});
