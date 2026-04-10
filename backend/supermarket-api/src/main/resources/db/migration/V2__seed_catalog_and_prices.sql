INSERT INTO categories (name, created_at) VALUES
    ('Fruits & Vegetables', CURRENT_TIMESTAMP),
    ('Bakery', CURRENT_TIMESTAMP),
    ('Dairy & Eggs', CURRENT_TIMESTAMP),
    ('Meat & Fish', CURRENT_TIMESTAMP),
    ('Pasta & Rice', CURRENT_TIMESTAMP),
    ('Canned & Jarred', CURRENT_TIMESTAMP),
    ('Snacks', CURRENT_TIMESTAMP),
    ('Beverages', CURRENT_TIMESTAMP),
    ('Frozen', CURRENT_TIMESTAMP),
    ('Household', CURRENT_TIMESTAMP);

INSERT INTO supermarkets (name, created_at) VALUES
    ('Tinex', CURRENT_TIMESTAMP),
    ('Vero', CURRENT_TIMESTAMP),
    ('KAM Market', CURRENT_TIMESTAMP),
    ('Ramstore', CURRENT_TIMESTAMP),
    ('Stokomak', CURRENT_TIMESTAMP);

INSERT INTO branches (supermarket_id, name, address_line, city, active, created_at) VALUES
    (1, 'Tinex - Centar', 'Partizanski Odredi 18', 'Skopje', TRUE, CURRENT_TIMESTAMP),
    (1, 'Tinex - Aerodrom', 'Jane Sandanski 102', 'Skopje', TRUE, CURRENT_TIMESTAMP),
    (2, 'Vero - Downtown', 'Dimitrie Chupovski 14', 'Skopje', TRUE, CURRENT_TIMESTAMP),
    (2, 'Vero - Karpos', 'Bulevar Ilinden 95', 'Skopje', TRUE, CURRENT_TIMESTAMP),
    (3, 'KAM - Kisela Voda', 'Naroden Front 6', 'Skopje', TRUE, CURRENT_TIMESTAMP),
    (3, 'KAM - Chair', 'Braka Millaadinovci 45', 'Skopje', TRUE, CURRENT_TIMESTAMP),
    (4, 'Ramstore Mall', 'Sv. Kiril i Metodij 13', 'Skopje', TRUE, CURRENT_TIMESTAMP),
    (4, 'Ramstore Gjorce', 'Boris Sarafov 75', 'Skopje', TRUE, CURRENT_TIMESTAMP),
    (5, 'Stokomak - Centar', 'Makedonija 9', 'Skopje', TRUE, CURRENT_TIMESTAMP),
    (5, 'Stokomak - Aerodrom', 'Vasko Karangeleski 8', 'Skopje', TRUE, CURRENT_TIMESTAMP);

INSERT INTO products (
    category_id, name, brand, normalized_name, normalized_brand, barcode, active, created_at
) VALUES
    (1, 'Banana', 'Fresh Farms', 'banana', 'fresh farms', '1000000000001', TRUE, CURRENT_TIMESTAMP),
    (1, 'Apple Gala', 'Fresh Farms', 'apple gala', 'fresh farms', '1000000000002', TRUE, CURRENT_TIMESTAMP),
    (1, 'Tomato', 'Fresh Farms', 'tomato', 'fresh farms', '1000000000003', TRUE, CURRENT_TIMESTAMP),
    (1, 'Cucumber', 'Fresh Farms', 'cucumber', 'fresh farms', '1000000000004', TRUE, CURRENT_TIMESTAMP),
    (2, 'White Bread 500g', 'Zito', 'white bread 500g', 'zito', '1000000000005', TRUE, CURRENT_TIMESTAMP),
    (2, 'Toast Bread', 'Zito', 'toast bread', 'zito', '1000000000006', TRUE, CURRENT_TIMESTAMP),
    (3, 'Milk 3.2% 1L', 'Bucen Kozjak', 'milk 3.2% 1l', 'bucen kozjak', '1000000000007', TRUE, CURRENT_TIMESTAMP),
    (3, 'Yogurt 1L', 'Bucen Kozjak', 'yogurt 1l', 'bucen kozjak', '1000000000008', TRUE, CURRENT_TIMESTAMP),
    (3, 'Eggs 10 Pack', 'Domasni', 'eggs 10 pack', 'domasni', '1000000000009', TRUE, CURRENT_TIMESTAMP),
    (3, 'Cheese Sirenje 400g', 'Mlekara', 'cheese sirenje 400g', 'mlekara', '1000000000010', TRUE, CURRENT_TIMESTAMP),
    (4, 'Chicken Breast 1kg', 'Delikates', 'chicken breast 1kg', 'delikates', '1000000000011', TRUE, CURRENT_TIMESTAMP),
    (4, 'Ground Beef 500g', 'Delikates', 'ground beef 500g', 'delikates', '1000000000012', TRUE, CURRENT_TIMESTAMP),
    (5, 'Spaghetti 500g', 'Barilla', 'spaghetti 500g', 'barilla', '1000000000013', TRUE, CURRENT_TIMESTAMP),
    (5, 'Rice Long Grain 1kg', 'Zrno', 'rice long grain 1kg', 'zrno', '1000000000014', TRUE, CURRENT_TIMESTAMP),
    (6, 'Tuna Can 160g', 'Adriatic', 'tuna can 160g', 'adriatic', '1000000000015', TRUE, CURRENT_TIMESTAMP),
    (6, 'Tomato Paste 200g', 'Vitaminka', 'tomato paste 200g', 'vitaminka', '1000000000016', TRUE, CURRENT_TIMESTAMP),
    (7, 'Potato Chips 150g', 'Vitaminka', 'potato chips 150g', 'vitaminka', '1000000000017', TRUE, CURRENT_TIMESTAMP),
    (7, 'Salted Peanuts 200g', 'Gricko', 'salted peanuts 200g', 'gricko', '1000000000018', TRUE, CURRENT_TIMESTAMP),
    (8, 'Still Water 1.5L', 'Pelisterka', 'still water 1.5l', 'pelisterka', '1000000000019', TRUE, CURRENT_TIMESTAMP),
    (8, 'Orange Juice 1L', 'Viva', 'orange juice 1l', 'viva', '1000000000020', TRUE, CURRENT_TIMESTAMP),
    (8, 'Cola 2L', 'Coca-Cola', 'cola 2l', 'coca-cola', '1000000000021', TRUE, CURRENT_TIMESTAMP),
    (9, 'Frozen Peas 450g', 'Frikom', 'frozen peas 450g', 'frikom', '1000000000022', TRUE, CURRENT_TIMESTAMP),
    (9, 'Frozen Pizza 350g', 'Frikom', 'frozen pizza 350g', 'frikom', '1000000000023', TRUE, CURRENT_TIMESTAMP),
    (10, 'Dish Soap 500ml', 'Sano', 'dish soap 500ml', 'sano', '1000000000024', TRUE, CURRENT_TIMESTAMP),
    (10, 'Laundry Detergent 2L', 'Ariel', 'laundry detergent 2l', 'ariel', '1000000000025', TRUE, CURRENT_TIMESTAMP);

INSERT INTO products (
    category_id, name, brand, normalized_name, normalized_brand, barcode, active, created_at
)
WITH RECURSIVE seq(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM seq WHERE n < 75
)
SELECT
    MOD(n - 1, 10) + 1,
    CONCAT('Seed Product ', n),
    'Capstone',
    LOWER(CONCAT('seed product ', n)),
    'capstone',
    LPAD(CAST(2000000000000 + n AS VARCHAR(13)), 13, '0'),
    TRUE,
    CURRENT_TIMESTAMP
FROM seq;

INSERT INTO product_nutrition (
    product_id, calories, protein_g, carbs_g, fat_g, serving_size, created_at
)
SELECT
    p.id,
    ROUND(45 + MOD(p.id * 11, 260), 2),
    ROUND(1 + MOD(p.id * 3, 30), 2),
    ROUND(2 + MOD(p.id * 5, 65), 2),
    ROUND(1 + MOD(p.id * 7, 25), 2),
    '100g',
    CURRENT_TIMESTAMP
FROM products p
WHERE p.id <= 40;

INSERT INTO verified_prices (
    product_id, supermarket_id, price, currency, observed_at, source_type, created_at
)
SELECT
    p.id,
    s.id,
    ROUND(20 + MOD((p.id * 37 + s.id * 13), 700) / 10.0, 2),
    'MKD',
    CURRENT_TIMESTAMP,
    'SYSTEM',
    CURRENT_TIMESTAMP
FROM products p
CROSS JOIN supermarkets s;
