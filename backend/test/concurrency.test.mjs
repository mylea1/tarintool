import test from 'node:test';
import assert from 'node:assert/strict';
import { ConcurrencyGate, QueueCapacityError } from '../src/concurrency.mjs';

const deferred = () => {
  let resolve;
  const promise = new Promise((done) => { resolve = done; });
  return { promise, resolve };
};

test('ConcurrencyGate never exceeds the configured active request limit', async () => {
  const gate = new ConcurrencyGate({ limit: 10, queueLimit: 40 });
  const releases = Array.from({ length: 25 }, deferred);
  let active = 0;
  let peak = 0;
  const tasks = releases.map((release) => gate.run(async () => {
    active += 1;
    peak = Math.max(peak, active);
    await release.promise;
    active -= 1;
  }));

  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(gate.snapshot().active, 10);
  assert.equal(gate.snapshot().queued, 15);
  assert.equal(peak, 10);

  for (const release of releases) release.resolve();
  await Promise.all(tasks);
  assert.equal(gate.snapshot().active, 0);
  assert.equal(gate.snapshot().queued, 0);
  assert.equal(peak, 10);
});

test('ConcurrencyGate rejects overflow instead of growing without bound', async () => {
  const gate = new ConcurrencyGate({ limit: 1, queueLimit: 1 });
  const firstRelease = deferred();
  const first = gate.run(() => firstRelease.promise);
  const second = gate.run(async () => 'queued');
  await assert.rejects(
    gate.run(async () => 'overflow'),
    (error) => error instanceof QueueCapacityError && error.code === 'ai_queue_full',
  );
  firstRelease.resolve();
  await first;
  assert.equal(await second, 'queued');
});
