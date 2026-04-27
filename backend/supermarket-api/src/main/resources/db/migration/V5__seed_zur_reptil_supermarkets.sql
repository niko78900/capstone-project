INSERT INTO supermarkets (name, created_at)
SELECT 'Zur', CURRENT_TIMESTAMP
WHERE NOT EXISTS (
    SELECT 1
    FROM supermarkets
    WHERE LOWER(name) = LOWER('Zur')
);

INSERT INTO supermarkets (name, created_at)
SELECT 'Reptil', CURRENT_TIMESTAMP
WHERE NOT EXISTS (
    SELECT 1
    FROM supermarkets
    WHERE LOWER(name) = LOWER('Reptil')
);
