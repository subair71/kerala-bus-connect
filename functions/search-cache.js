/// Short public-response cache with shared in-flight requests. No private data.
export class SearchCache {
  constructor({ttl = 10000, maximum = 128, maxBytes = 2 * 1024 * 1024, now = Date.now} = {}) {
    this.ttl = ttl; this.maximum = maximum; this.maxBytes = maxBytes; this.now = now;
    this.values = new Map(); this.bytes = 0; this.generation = 0;
  }
  clear() { this.generation++; this.values.clear(); this.bytes = 0; }
  async get(key, load) {
    const entry = this.values.get(key);
    if (entry && (entry.pending || this.now() < entry.until)) {
      return {...await entry.promise, cache: entry.pending ? 'shared' : 'hit', scanned: 0};
    }
    if (entry) { this.values.delete(key); this.bytes -= entry.bytes; }
    while (this.values.size >= this.maximum || this.bytes > this.maxBytes) {
      const oldest = this.values.keys().next().value;
      this.bytes -= this.values.get(oldest).bytes;
      this.values.delete(oldest);
    }
    const generation = this.generation;
    const next = {pending: true, bytes: 0, until: 0};
    next.promise = Promise.resolve().then(load);
    this.values.set(key, next);
    try {
      const result = await next.promise;
      if (this.generation === generation && this.values.get(key) === next) {
        next.pending = false; next.until = this.now() + this.ttl;
        next.bytes = Buffer.byteLength(JSON.stringify(result));
        this.bytes += next.bytes;
        while (this.bytes > this.maxBytes && this.values.size) {
          const oldest = this.values.keys().next().value;
          this.bytes -= this.values.get(oldest).bytes;
          this.values.delete(oldest);
        }
      }
      return {...result, cache: 'miss'};
    } catch (error) {
      if (this.values.get(key) === next) this.values.delete(key);
      throw error;
    }
  }
}
