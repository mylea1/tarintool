import fs from 'node:fs';
import fsp from 'node:fs/promises';
import path from 'node:path';
import { pipeline } from 'node:stream/promises';
import { randomId } from './security.mjs';

const extensionForType = new Map([
  ['video/mp4', '.mp4'], ['video/quicktime', '.mov'], ['video/webm', '.webm'],
  ['image/jpeg', '.jpg'], ['image/png', '.png'], ['image/webp', '.webp'],
]);

export class LocalStorage {
  constructor(root, { maxBytes = 250 * 1024 * 1024 } = {}) {
    this.root = path.resolve(root);
    this.maxBytes = maxBytes;
    fs.mkdirSync(this.root, { recursive: true });
  }

  safeKey(key) {
    if (typeof key !== 'string' || !key || key.includes('\0') || key.includes('\\') || path.posix.isAbsolute(key)) {
      throw new Error('invalid_storage_key');
    }
    const normalized = path.posix.normalize(key);
    if (normalized === '.' || normalized.startsWith('../') || normalized.includes('/../')) throw new Error('invalid_storage_key');
    const target = path.resolve(this.root, normalized);
    if (target !== this.root && !target.startsWith(`${this.root}${path.sep}`)) throw new Error('invalid_storage_key');
    return { key: normalized, target };
  }

  keyFor(prefix, id, contentType = 'application/octet-stream') {
    const ext = extensionForType.get(contentType.split(';')[0].toLowerCase()) || '.bin';
    return `${prefix}/${id}/${randomId('media_')}${ext}`;
  }

  async putBuffer(key, buffer, { maxBytes = this.maxBytes } = {}) {
    const { target } = this.safeKey(key);
    if (!Buffer.isBuffer(buffer) || buffer.length > maxBytes) throw new Error('upload_too_large');
    await fsp.mkdir(path.dirname(target), { recursive: true });
    const temporary = `${target}.${randomId('tmp_')}`;
    await fsp.writeFile(temporary, buffer, { flag: 'wx' });
    await fsp.rename(temporary, target);
    return { key, bytes: buffer.length };
  }

  async putStream(key, stream, { maxBytes = this.maxBytes } = {}) {
    const { target } = this.safeKey(key);
    await fsp.mkdir(path.dirname(target), { recursive: true });
    const temporary = `${target}.${randomId('tmp_')}`;
    let bytes = 0;
    const limited = async function* () {
      for await (const chunk of stream) {
        bytes += chunk.length;
        if (bytes > maxBytes) {
          const error = new Error('upload_too_large');
          error.code = 'upload_too_large';
          throw error;
        }
        yield chunk;
      }
    }();
    try {
      await pipeline(limited, fs.createWriteStream(temporary, { flags: 'wx' }));
      await fsp.rename(temporary, target);
    } catch (error) {
      await fsp.rm(temporary, { force: true });
      throw error;
    }
    return { key, bytes };
  }

  resolve(key) { return this.safeKey(key).target; }
  exists(key) { try { return fs.statSync(this.resolve(key)).isFile(); } catch { return false; } }
  stat(key) { return fs.statSync(this.resolve(key)); }
  createReadStream(key) { return fs.createReadStream(this.resolve(key)); }
  async remove(key) { await fsp.rm(this.resolve(key), { force: true }); }
}

export { extensionForType };
