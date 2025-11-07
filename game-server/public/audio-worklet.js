class QueuePlayerProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    this.queue = [];
    this.port.onmessage = (e) => {
      try {
        const buf = e.data && e.data.buffer;
        if (buf) this.queue.push(new Float32Array(buf));
      } catch (_) {}
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
      } else {
        this.queue[0] = chunk.subarray(avail);
      }
    }
    return true;
  }
}

registerProcessor('queue-player', QueuePlayerProcessor);


