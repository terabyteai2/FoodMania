import { describe, expect, it } from 'vitest';
import { toCsv } from './csv';

describe('toCsv', () => {
  it('joins rows with CRLF and cells with commas', () => {
    expect(toCsv([['a', 'b'], [1, 2]])).toBe('a,b\r\n1,2');
  });

  it('quotes cells containing commas, quotes or newlines', () => {
    expect(toCsv([['c,d', 'e"f', 'g\nh']])).toBe('"c,d","e""f","g\nh"');
  });

  it('renders empty and numeric cells', () => {
    expect(toCsv([['', 0, 12.5]])).toBe(',0,12.5');
  });
});
