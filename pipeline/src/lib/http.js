const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
export { sleep };

/** URL with the query string removed, so tokens never reach logs. */
export function redact(url) {
  const u = new URL(url);
  return `${u.origin}${u.pathname}`;
}

/**
 * GET JSON with a timeout and retries on 429 / 5xx / network errors.
 * Errors name the URL without its query string (Legistar's token is in it).
 */
export async function fetchJson(url, { retries = 3, timeoutMs = 60_000, headers = {} } = {}) {
  const where = redact(url);
  let lastErr;
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const res = await fetch(url, {
        headers: { accept: 'application/json', 'user-agent': 'involve-pipeline/1.0', ...headers },
        signal: AbortSignal.timeout(timeoutMs),
      });
      if (res.ok) return await res.json();
      lastErr = new Error(`${where}: HTTP ${res.status} ${res.statusText}`.trim());
      lastErr.status = res.status;
      if (res.status !== 429 && res.status < 500) throw lastErr; // not retryable
      const retryAfter = Number(res.headers.get('retry-after'));
      await sleep(retryAfter > 0 ? retryAfter * 1000 : 1000 * 2 ** attempt);
    } catch (err) {
      if (err.status && err.status !== 429 && err.status < 500) throw err;
      lastErr = err.status ? err : new Error(`${where}: ${err.message}`);
      if (attempt < retries) await sleep(1000 * 2 ** attempt);
    }
  }
  throw lastErr;
}
