// @vitest-environment jsdom

import React from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import ProductDescription from './product-description';

describe('ProductDescription', () => {
  it('sanitizes the description before html-react-parser renders it', () => {
    const markup = renderToStaticMarkup(
      React.createElement(ProductDescription, {
        description: `
          <iframe srcdoc="<script>window.parent.alert(1)</script>"></iframe>
          <a href="javascript:alert(1)">unsafe link</a>
          <img src="x" onerror="alert(1)">
          <svg onload="alert(1)"></svg>
          <object data="data:text/html,<script>alert(1)</script>"></object>
          <embed src="javascript:alert(1)">
          <p onclick="alert(1)"><strong>Safe text</strong></p>
        `,
        image: '/safe-product.png',
      }),
    );
    const container = document.createElement('div');
    container.innerHTML = markup;

    expect(container.querySelector('iframe, a, svg, object, embed, script')).toBeNull();
    expect(container.querySelectorAll('img')).toHaveLength(1);
    expect(
      container.querySelector('[onerror], [onload], [onclick], [srcdoc], [href^="javascript:"], [src^="javascript:"]'),
    ).toBeNull();
    expect(container.textContent).toContain('Safe text');
  });
});
