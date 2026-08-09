export class QueueCapacityError extends Error {
  constructor(code = 'queue_capacity_exceeded') {
    super(code);
    this.name = 'QueueCapacityError';
    this.code = code;
  }
}

/**
 * Small in-process concurrency gate for slow upstream calls.
 *
 * The Node process remains single-instance because the current SQLite storage
 * model is intentionally local. This gate prevents a burst of AI requests from
 * becoming an unbounded set of open sockets and response buffers.
 */
export class ConcurrencyGate {
  constructor({ limit, queueLimit }) {
    if (!Number.isInteger(limit) || limit < 1) throw new TypeError('invalid_concurrency_limit');
    if (!Number.isInteger(queueLimit) || queueLimit < 0) throw new TypeError('invalid_queue_limit');
    this.limit = limit;
    this.queueLimit = queueLimit;
    this.active = 0;
    this.queue = [];
  }

  snapshot() {
    return Object.freeze({
      limit: this.limit,
      queueLimit: this.queueLimit,
      active: this.active,
      queued: this.queue.length,
      available: Math.max(0, this.limit - this.active),
    });
  }

  async run(task) {
    if (typeof task !== 'function') throw new TypeError('task_required');
    await this.#acquire();
    try {
      return await task();
    } finally {
      this.#release();
    }
  }

  #acquire() {
    if (this.active < this.limit) {
      this.active += 1;
      return Promise.resolve();
    }
    if (this.queue.length >= this.queueLimit) {
      return Promise.reject(new QueueCapacityError('ai_queue_full'));
    }
    return new Promise((resolve) => this.queue.push(resolve));
  }

  #release() {
    const next = this.queue.shift();
    if (next) {
      // Transfer the slot directly. Keeping `active` unchanged avoids a race in
      // which a later request could jump ahead of the queued request.
      next();
      return;
    }
    this.active = Math.max(0, this.active - 1);
  }
}
