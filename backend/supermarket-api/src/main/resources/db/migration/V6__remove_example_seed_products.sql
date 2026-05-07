-- Removes example/demo products that were inserted by the early seed migration.
-- This intentionally keeps supermarkets, branches, categories, users, and submissions.
-- It targets only the original seeded product barcode ranges and obvious Seed Product names.

DELETE FROM verified_prices
WHERE product_id IN (
  SELECT id
  FROM products
  WHERE barcode BETWEEN '1000000000001' AND '1000000000025'
     OR barcode BETWEEN '2000000000001' AND '2000000000075'
     OR name LIKE 'Seed Product %'
);

DELETE FROM product_nutrition
WHERE product_id IN (
  SELECT id
  FROM products
  WHERE barcode BETWEEN '1000000000001' AND '1000000000025'
     OR barcode BETWEEN '2000000000001' AND '2000000000075'
     OR name LIKE 'Seed Product %'
);

DELETE FROM products
WHERE id IN (
  SELECT id
  FROM products
  WHERE barcode BETWEEN '1000000000001' AND '1000000000025'
     OR barcode BETWEEN '2000000000001' AND '2000000000075'
     OR name LIKE 'Seed Product %'
);
