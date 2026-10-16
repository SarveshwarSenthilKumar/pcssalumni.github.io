#!/usr/bin/env node
import { promises as fs } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const output = path.join(root, '_site');

function run(command, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { cwd: root, stdio: 'inherit', shell: process.platform === 'win32' });
    child.on('exit', (code) => code === 0 ? resolve() : reject(new Error(`${command} exited with ${code}`)));
  });
}

async function main() {
  await run('node', ['scripts/index-yearbooks.mjs']);
  await run('quarto', ['render']);
  await fs.copyFile(path.join(root, '.nojekyll'), path.join(output, '.nojekyll'));
  console.log(`Built Quarto site at ${output}`);
}

main().catch((error) => { console.error(error); process.exitCode = 1; });

