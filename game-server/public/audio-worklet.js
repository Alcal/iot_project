class QueuePlayerProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    this.queue = [];
    this.totalQueued = 0; // total samples queued
    this.maxQueued = Math.floor(sampleRate * 0.5); // cap ~500ms
    this.port.onmessage = (e) => {
      try {
        const buf = e.data && e.data.buffer;
        if (buf) {
          const chunk = new Float32Array(buf);
          this.queue.push(chunk);
          this.totalQueued += chunk.length;
          while (this.totalQueued > this.maxQueued && this.queue.length > 1) {
            const oldest = this.queue.shift();
            this.totalQueued -= oldest.length;
          }
        }
      } catch (err) { console.warn('[serverboy][audio] Error processing message from AudioWorklet:', err); }
    };
  }

  process(inputs, outputs, parameters) {
    const output = outputs[0];
    const out = output && output[0];
    if (!out) return true;

    let i = 0;
    while (i < out.length) {
      if (this.queue.length === 0) {
        for (let j = i; j < out.length; j++) out[j] = 0;
        break;
      }
      const chunk = this.queue[0];
      const avail = Math.min(out.length - i, chunk.length);
      out.set(chunk.subarray(0, avail), i);
      i += avail;
      if (avail === chunk.length) {
        this.queue.shift();
        this.totalQueued -= avail;
      } else {
        this.queue[0] = chunk.subarray(avail);
        this.totalQueued -= avail;
      }
    }
    return true;
  }
}

registerProcessor('queue-player', QueuePlayerProcessor);


