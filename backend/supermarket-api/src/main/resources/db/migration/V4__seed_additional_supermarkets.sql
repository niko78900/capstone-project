INSERT INTO supermarkets (name, created_at)
SELECT 'Kit-go market', CURRENT_TIMESTAMP
WHERE NOT EXISTS (
    SELECT 1
    FROM supermarkets
    WHERE LOWER(name) = LOWER('Kit-go market')
);

INSERT INTO supermarkets (name, created_at)
SELECT 'Kipper', CURRENT_TIMESTAMP
WHERE NOT EXISTS (
    SELECT 1
    FROM supermarkets
    WHERE LOWER(name) = LOWER('Kipper')
);
