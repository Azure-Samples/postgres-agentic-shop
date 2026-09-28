import DOMPurify from 'dompurify';

const PRODUCT_DESCRIPTION_ALLOWED_TAGS = ['h3', 'p', 'strong'];

const sanitizeProductDescription = (description: string) =>
  DOMPurify.sanitize(description, {
    ALLOWED_TAGS: PRODUCT_DESCRIPTION_ALLOWED_TAGS,
    ALLOWED_ATTR: [],
    ALLOW_ARIA_ATTR: false,
    ALLOW_DATA_ATTR: false,
  });

export default sanitizeProductDescription;
