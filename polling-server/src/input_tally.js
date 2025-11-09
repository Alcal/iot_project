const TALLY_SIZE = Number(process.env.INPUT_TALLY_SIZE || 8);
const LOG_INTERVAL_MS = Number(process.env.INPUT_TALLY_LOG_INTERVAL_MS || 10000);
const COMMAND_INTERVAL_MS = Number(process.env.INPUT_TALLY_COMMAND_INTERVAL_MS || 1000);

// Persistent tally for the lifetime of the process
const tally = Array.from({ length: TALLY_SIZE }, () => 0);

function increment(inputId) {
  if (!Number.isInteger(inputId)) return;
  if (inputId < 0 || inputId >= tally.length) return;
  tally.splice(inputId, 1, tally[inputId] + 1);
}

function getTally() {
  // Return a shallow copy to avoid external mutation
  return [...tally];
}

let logIntervalId = null;
let suppressUntilNonZero = false;
let commandIntervalId = null;

function startLogging(publishFn) {
  if (logIntervalId) return;
  logIntervalId = setInterval(() => {
    // Optionally publish on each interval with suppression of repeated all-zero tallies
    try {
      if (typeof publishFn === 'function') {
        const snapshot = [...tally];
        const hasAny = snapshot.some((v) => v > 0);
        if (suppressUntilNonZero) {
          if (hasAny) {
            suppressUntilNonZero = false;
            publishFn(snapshot);
          }
          // else: skip until non-zero appears
        } else {
          publishFn(snapshot);
          if (!hasAny) {
            suppressUntilNonZero = true;
          }
        }
      }
    } catch (_) {
      // no-op
    }
  }, LOG_INTERVAL_MS);
}

function startCommandPublishing(publishCommandFn) {
  if (commandIntervalId) return;
  commandIntervalId = setInterval(() => {
    try {
      if (typeof publishCommandFn !== 'function') return;
      const snapshot = [...tally];
      // Find index of largest count, preferring lower indices on ties
      let maxValue = 0;
      let bestIndex = 0;
      for (let i = 0; i < snapshot.length; i++) {
        const value = snapshot[i];
        if (value > maxValue) {
          maxValue = value;
          bestIndex = i;
        }
      }
      // Only publish if any tally item is greater than zero
      if (maxValue > 0) {
        publishCommandFn(String(bestIndex));
        // Reset tally to zeroes after publishing
        for (let i = 0; i < tally.length; i++) {
          tally[i] = 0;
        }
        // Reset suppression so the next logging cycle publishes one zero snapshot, then suppresses until non-zero
        suppressUntilNonZero = false;
      }
    } catch (_) {
      // no-op
    }
  }, COMMAND_INTERVAL_MS);
}

function stopLogging() {
  if (!logIntervalId) return;
  clearInterval(logIntervalId);
  logIntervalId = null;
}

function stopCommandPublishing() {
  if (!commandIntervalId) return;
  clearInterval(commandIntervalId);
  commandIntervalId = null;
}

module.exports = {
  increment,
  getTally,
  tally,
  startLogging,
  stopLogging,
  startCommandPublishing,
  stopCommandPublishing,
};

