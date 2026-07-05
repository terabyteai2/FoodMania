// Minimal CSV serialization + browser download (used by the back-office report exports).

function csvCell(v: string | number): string {
  const s = String(v ?? '');
  return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

/** Rows → RFC-4180-ish CSV text (CRLF line endings, quoted when needed). */
export function toCsv(rows: (string | number)[][]): string {
  return rows.map((row) => row.map(csvCell).join(',')).join('\r\n');
}

/** Trigger a client-side download of `rows` as `filename`. No-op friendly outside a DOM. */
export function downloadCsv(filename: string, rows: (string | number)[][]): void {
  const blob = new Blob([toCsv(rows)], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
