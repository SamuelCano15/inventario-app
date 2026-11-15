-- Run as: app_inventario (DML only)
-- Insertar las 4 Categorias
INSERT INTO categorias (nombre) VALUES
    ('Lácteos'),
    ('Aseo'),
    ('Electrónica'),
    ('Granos');

#SELECT * FROM categorias;

-- Insertar Productos, con Subconsultas para Verificar que si Existe y no por Indice "(1=Lácteos |...| 1=Granos)"
INSERT INTO productos
    (sku, nombre, precio, stock, categoria_id, tipo, fecha_vencimiento, meses_garantia)
VALUES
    ('LAC-001', 'Leche entera 1L', 4500.00, 30,
        (SELECT id FROM categorias WHERE nombre = 'Lácteos'), #Verificar si Existe la Categoria
        'PERECEDERO', '2026-12-01', NULL),

    ('GRA-001', 'Arroz 500g', 3200.00, 50,
        (SELECT id FROM categorias WHERE nombre = 'Granos'), #Verificar si Existe la Categoria
        'PERECEDERO', '2027-06-15', NULL),

    ('ASE-001', 'Jabón en barra', 2800.00, 40,
        (SELECT id FROM categorias WHERE nombre = 'Aseo'), #Verificar si Existe la Categoria
        'NO_PERECEDERO', NULL, NULL),

    ('ELE-001', 'Audífonos básicos', 35000.00, 10,
        (SELECT id FROM categorias WHERE nombre = 'Electrónica'), #Verificar si Existe la Categoria
        'NO_PERECEDERO', NULL, 6);

/*
-- Ver Datos con su Categoria (JOIN)
SELECT p.sku,
       p.nombre,
       c.nombre AS categoria,
       p.tipo,
       p.precio,
       p.stock,
       p.fecha_vencimiento,
       p.meses_garantia
FROM productos p
JOIN categorias c ON c.id = p.categoria_id
ORDER BY p.sku;


-- Intentar Insertar Productos INCORRECTAMENTE

-- A) Perishable WITHOUT expiration date → must fail
INSERT INTO productos (sku, nombre, precio, stock, categoria_id, tipo)
VALUES ('TEST-A', 'Yogur', 3000, 5, 1, 'PERECEDERO');

-- B) Negative stock → must fail
INSERT INTO productos (sku, nombre, precio, stock, categoria_id, tipo)
VALUES ('TEST-B', 'Shampoo', 9000, -3, 2, 'NO_PERECEDERO');

-- C) Duplicate SKU → must fail
INSERT INTO productos (sku, nombre, precio, stock, categoria_id, tipo)
VALUES ('ASE-001', 'Otro jabón', 2500, 5, 2, 'NO_PERECEDERO');

-- D) Category that doesn't exist → must fail
INSERT INTO productos (sku, nombre, precio, stock, categoria_id, tipo)
VALUES ('TEST-D', 'Fantasma', 1000, 1, 999, 'NO_PERECEDERO');

-- E) Delete a category that has products → must fail
DELETE FROM categorias WHERE nombre = 'Lácteos';

SELECT COUNT(*) FROM productos;   -- must still be 4
*/