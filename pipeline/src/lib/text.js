const NAMED = {
  amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ',
  ndash: '–', mdash: '—', lsquo: '‘', rsquo: '’', ldquo: '“', rdquo: '”',
  hellip: '…', middot: '·', bull: '•', copy: '©', reg: '®',
};

function decodeOnce(s) {
  return s.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (whole, body) => {
    if (body[0] === '#') {
      const code = body[1].toLowerCase() === 'x' ? parseInt(body.slice(2), 16) : parseInt(body.slice(1), 10);
      try {
        return String.fromCodePoint(code);
      } catch {
        return whole;
      }
    }
    return NAMED[body.toLowerCase()] ?? whole;
  });
}

/** Decode HTML entities, drop tags, collapse whitespace. Null/empty -> ''. */
export function cleanText(input) {
  if (input == null) return '';
  let s = String(input);
  s = decodeOnce(decodeOnce(s)); // some feeds double-encode ("&amp;#8217;")
  s = s.replace(/<[^>]*>/g, ' ');
  return s.replace(/[\s ]+/g, ' ').trim();
}

/** Truncate at a word boundary, adding an ellipsis. */
export function truncate(s, max) {
  if (s.length <= max) return s;
  const cut = s.slice(0, max - 1);
  const space = cut.lastIndexOf(' ');
  return (space > max * 0.6 ? cut.slice(0, space) : cut).replace(/[\s,.;:–-]+$/, '') + '…';
}

/** Light markdown strip for sources that author descriptions in markdown. */
export function stripMarkdown(s) {
  return s
    .replace(/!?\[([^\]]*)\]\([^)]*\)/g, '$1')
    .replace(/(\*\*|__)(.*?)\1/g, '$2')
    .replace(/^\s{0,3}#{1,6}\s+/gm, '')
    .replace(/[*`]+/g, '');
}

/**
 * "EAST  149 STREET between MORRIS AVENUE and PARK AVENUE" -> "East 149 Street
 * between Morris Avenue and Park Avenue". Only touches strings that are mostly
 * upper case, so mixed-case input and acronyms in normal prose are left alone.
 */
export function unshout(s) {
  const letters = s.replace(/[^A-Za-z]/g, '');
  const upper = letters.replace(/[^A-Z]/g, '');
  if (letters.length < 4 || upper.length / letters.length < 0.6) return s;
  return s.replace(/\b([A-Z]{2,})\b/g, (w) => w[0] + w.slice(1).toLowerCase());
}
