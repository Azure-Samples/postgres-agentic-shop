// @vitest-environment jsdom

import { describe, expect, it } from 'vitest';
import sanitizeProductDescription from './product-description.sanitize';

const renderSanitizedDescription = (description: string) => {
  const container = document.createElement('div');
  container.innerHTML = sanitizeProductDescription(description);
  return container;
};

describe('sanitizeProductDescription', () => {
  it('preserves the formatting used by seeded product descriptions', () => {
    const container = renderSanitizedDescription('<h3>Heading</h3><p>Product <strong>details</strong></p>');

    expect(container.querySelector('h3')?.textContent).toBe('Heading');
    expect(container.querySelector('p')?.textContent).toBe('Product details');
    expect(container.querySelector('strong')?.textContent).toBe('details');
    expect(Array.from(container.querySelectorAll('*')).every((element) => element.attributes.length === 0)).toBe(true);
  });

  it('removes executable elements, URLs, and attributes', () => {
    const container = renderSanitizedDescription(`
      <IFRAME srcdoc="&lt;script&gt;window.parent.alert(1)&lt;/script&gt;"></IFRAME>
      <a href="java&#x73;cript:alert(1)">unsafe link</a>
      <img src="x" onerror="alert(1)">
      <svg onload="alert(1)"><animate onbegin="alert(1)"></animate></svg>
      <object data="data:text/html,<script>alert(1)</script>"></object>
      <embed src="javascript:alert(1)">
      <p onclick="alert(1)"><strong style="background:url(javascript:alert(1))">Safe text</strong></p>
    `);

    expect(container.querySelector('iframe, a, img, svg, object, embed, script')).toBeNull();
    expect(Array.from(container.querySelectorAll('*')).map((element) => element.tagName.toLowerCase())).toEqual([
      'p',
      'strong',
    ]);
    expect(Array.from(container.querySelectorAll('*')).every((element) => element.attributes.length === 0)).toBe(true);
    expect(container.textContent).toContain('Safe text');
    expect(container.innerHTML).not.toMatch(/javascript:|onerror|onload|onclick|srcdoc/i);
  });
});
