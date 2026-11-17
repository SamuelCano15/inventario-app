-- =====================================================================
-- Inventario v2 · Datos de ejemplo + demostración de compra y venta FEFO
-- Ejecutar después de 01_schema_v2.sql
-- =====================================================================
USE tienda_inventario_v2;

-- ---------- Catálogo base ----------
INSERT INTO impuestos (nombre, porcentaje) VALUES
    ('IVA 0%', 0.00), ('IVA 5%', 5.00), ('IVA 19%', 19.00);

INSERT INTO unidades_medida (codigo, nombre) VALUES
    ('und', 'Unidad'), ('g', 'Gramo'), ('kg', 'Kilogramo'), ('ml', 'Mililitro'), ('L', 'Litro');

INSERT INTO marcas (nombre) VALUES ('Colanta'), ('Diana'), ('Fab'), ('Xiaomi');

-- Raíces con prefijo; las subcategorías heredan el de su raíz.
INSERT INTO categorias (id, nombre, prefijo_sku, categoria_padre_id) VALUES
    (1, 'Lácteos',     'LAC', NULL),
    (2, 'Granos',      'GRA', NULL),
    (3, 'Aseo',        'ASE', NULL),
    (4, 'Electrónica', 'ELE', NULL),
    (5, 'Leches',       NULL, 1),
    (6, 'Deslactosadas',NULL, 5),
    (7, 'Quesos',       NULL, 1);

INSERT INTO consecutivos (clave, ultimo) VALUES
    ('SKU-LAC', 0), ('SKU-GRA', 0), ('SKU-ASE', 0), ('SKU-ELE', 0), ('FACTURA-VENTA', 0);

INSERT INTO roles (nombre) VALUES ('ADMIN'), ('CAJERO'), ('BODEGA');
-- Hash de ejemplo (no es una clave real). En la app se genera con bcrypt.
INSERT INTO usuarios (username, password_hash, nombre_completo, rol_id) VALUES
    ('admin',  '$2a$12$EJEMPLO.NO.ES.UNA.CLAVE.REAL.xxxxxxxxxxxxxxxxxxxxxxxx', 'Administrador', 1),
    ('caja1',  '$2a$12$EJEMPLO.NO.ES.UNA.CLAVE.REAL.yyyyyyyyyyyyyyyyyyyyyyyy', 'Cajero Uno',    2);

-- ---------- SKU autogenerado (así lo haría Java) ----------
UPDATE consecutivos SET ultimo = LAST_INSERT_ID(ultimo + 1) WHERE clave = 'SKU-LAC';
SET @sku_leche = CONCAT('LAC-', LPAD(LAST_INSERT_ID(), 4, '0'));   -- LAC-0001

INSERT INTO productos (sku, codigo_barras, nombre, categoria_id, marca_id, unidad_id,
                       contenido, impuesto_id, precio_venta, stock_minimo, maneja_vencimiento)
VALUES (@sku_leche, '7702129001014', 'Leche entera Colanta 1 L', 5, 1, 5, 1, 1, 4500.00, 10, TRUE);
SET @id_leche = LAST_INSERT_ID();

UPDATE consecutivos SET ultimo = LAST_INSERT_ID(ultimo + 1) WHERE clave = 'SKU-ELE';
INSERT INTO productos (sku, nombre, categoria_id, marca_id, unidad_id, contenido,
                       impuesto_id, precio_venta, maneja_vencimiento, meses_garantia)
VALUES (CONCAT('ELE-', LPAD(LAST_INSERT_ID(), 4, '0')), 'Audífonos Bluetooth', 4, 4, 1, 1,
        3, 85000.00, FALSE, 12);

INSERT INTO proveedores (nit, razon_social, telefono) VALUES
    ('890904478-6', 'Distribuidora Lácteos Antioquia S.A.S.', '6045550000');
INSERT INTO producto_proveedor (producto_id, proveedor_id, codigo_proveedor, ultimo_costo)
VALUES (@id_leche, 1, 'COL-ENT-1L', 3600.00);

-- ---------- Compra con 3 lotes de la MISMA leche ----------
-- (uno ya vencido a propósito, para ver que no se vende)
START TRANSACTION;
INSERT INTO compras (proveedor_id, numero_factura, fecha_compra, usuario_id, estado,
                     subtotal, total_impuestos, total)
VALUES (1, 'FV-1001', '2026-11-01', 1, 'RECIBIDA', 162000.00, 0, 162000.00);
SET @compra = LAST_INSERT_ID();

INSERT INTO compra_detalles (compra_id, producto_id, cantidad, costo_unitario, porcentaje_impuesto)
VALUES (@compra, @id_leche, 5, 3600.00, 0);
SET @cd1 = LAST_INSERT_ID();
INSERT INTO lotes (producto_id, compra_detalle_id, codigo_lote, fecha_vencimiento,
                   cantidad_inicial, cantidad_actual, costo_unitario)
VALUES (@id_leche, @cd1, 'L-VIEJO', CURRENT_DATE - INTERVAL 3 DAY, 5, 5, 3600.00);
INSERT INTO movimientos_inventario (lote_id, tipo, cantidad, compra_detalle_id, usuario_id)
VALUES (LAST_INSERT_ID(), 'ENTRADA_COMPRA', 5, @cd1, 1);

INSERT INTO compra_detalles (compra_id, producto_id, cantidad, costo_unitario, porcentaje_impuesto)
VALUES (@compra, @id_leche, 20, 3600.00, 0);
SET @cd2 = LAST_INSERT_ID();
INSERT INTO lotes (producto_id, compra_detalle_id, codigo_lote, fecha_vencimiento,
                   cantidad_inicial, cantidad_actual, costo_unitario)
VALUES (@id_leche, @cd2, 'L-30DIC', '2026-12-30', 20, 20, 3600.00);
INSERT INTO movimientos_inventario (lote_id, tipo, cantidad, compra_detalle_id, usuario_id)
VALUES (LAST_INSERT_ID(), 'ENTRADA_COMPRA', 20, @cd2, 1);

INSERT INTO compra_detalles (compra_id, producto_id, cantidad, costo_unitario, porcentaje_impuesto)
VALUES (@compra, @id_leche, 20, 3600.00, 0);
SET @cd3 = LAST_INSERT_ID();
INSERT INTO lotes (producto_id, compra_detalle_id, codigo_lote, fecha_vencimiento,
                   cantidad_inicial, cantidad_actual, costo_unitario)
VALUES (@id_leche, @cd3, 'L-05ENE', '2027-01-05', 20, 20, 3600.00);
INSERT INTO movimientos_inventario (lote_id, tipo, cantidad, compra_detalle_id, usuario_id)
VALUES (LAST_INSERT_ID(), 'ENTRADA_COMPRA', 20, @cd3, 1);
COMMIT;

SELECT 'Stock antes de vender' AS paso, sku, stock_total, stock_vendible FROM v_stock_producto;

-- ---------- Venta de 25 leches con FEFO ----------
-- Debe tomar 20 del lote 30-dic y 5 del lote 05-ene, ignorando el vencido.
START TRANSACTION;

-- 1) Bloquear los lotes vendibles en orden FEFO (FOR UPDATE evita el lost update).
SELECT id, codigo_lote, fecha_vencimiento, cantidad_actual
FROM lotes
WHERE producto_id = @id_leche
  AND cantidad_actual > 0
  AND (fecha_vencimiento IS NULL OR fecha_vencimiento >= CURRENT_DATE)
ORDER BY fecha_vencimiento IS NULL, fecha_vencimiento, id     -- los sin fecha, al final
FOR UPDATE;

-- 2) Cabecera y detalle (precios copiados del producto).
UPDATE consecutivos SET ultimo = LAST_INSERT_ID(ultimo + 1) WHERE clave = 'FACTURA-VENTA';
INSERT INTO ventas (numero_factura, usuario_id, subtotal, total_impuestos, total)
VALUES (CONCAT('FV-', LPAD(LAST_INSERT_ID(), 6, '0')), 2, 112500.00, 0, 112500.00);
SET @venta = LAST_INSERT_ID();

INSERT INTO venta_detalles (venta_id, producto_id, cantidad, precio_unitario, porcentaje_impuesto)
VALUES (@venta, @id_leche, 25, 4500.00, 0);
SET @vd = LAST_INSERT_ID();

-- 3) Descontar lote por lote (en Java esto es un bucle sobre el resultado del paso 1).
SET @lote_dic = (SELECT id FROM lotes WHERE codigo_lote = 'L-30DIC');
SET @lote_ene = (SELECT id FROM lotes WHERE codigo_lote = 'L-05ENE');

UPDATE lotes SET cantidad_actual = cantidad_actual - 20 WHERE id = @lote_dic;
INSERT INTO movimientos_inventario (lote_id, tipo, cantidad, venta_detalle_id, usuario_id)
VALUES (@lote_dic, 'SALIDA_VENTA', 20, @vd, 2);

UPDATE lotes SET cantidad_actual = cantidad_actual - 5 WHERE id = @lote_ene;
INSERT INTO movimientos_inventario (lote_id, tipo, cantidad, venta_detalle_id, usuario_id)
VALUES (@lote_ene, 'SALIDA_VENTA', 5, @vd, 2);

INSERT INTO venta_pagos (venta_id, metodo, monto) VALUES
    (@venta, 'EFECTIVO', 100000.00), (@venta, 'NEQUI', 12500.00);
COMMIT;

-- ---------- Baja del lote vencido (ajuste con motivo obligatorio) ----------
SET @lote_viejo = (SELECT id FROM lotes WHERE codigo_lote = 'L-VIEJO');
START TRANSACTION;
UPDATE lotes SET cantidad_actual = 0 WHERE id = @lote_viejo;
INSERT INTO movimientos_inventario (lote_id, tipo, cantidad, usuario_id, motivo)
VALUES (@lote_viejo, 'BAJA_VENCIMIENTO', 5, 1, 'Vencido, se desecha');
COMMIT;

-- ---------- Resultados ----------
SELECT 'Stock después' AS paso, sku, stock_total, stock_vendible FROM v_stock_producto;
SELECT codigo_lote, fecha_vencimiento, cantidad_inicial, cantidad_actual FROM lotes ORDER BY id;
SELECT * FROM v_kardex ORDER BY id;
SELECT * FROM v_valor_inventario;
SELECT v.numero_factura, v.total, GROUP_CONCAT(CONCAT(p.metodo, ' ', p.monto) SEPARATOR ' + ') AS pagos
FROM ventas v JOIN venta_pagos p ON p.venta_id = v.id GROUP BY v.id;

-- Árbol de categorías con CTE recursivo.
WITH RECURSIVE arbol AS (
    SELECT id, nombre, prefijo_sku, CAST(nombre AS CHAR(255)) AS ruta
    FROM categorias WHERE categoria_padre_id IS NULL
    UNION ALL
    SELECT c.id, c.nombre, a.prefijo_sku, CONCAT(a.ruta, ' > ', c.nombre)
    FROM categorias c JOIN arbol a ON c.categoria_padre_id = a.id
)
SELECT ruta, prefijo_sku AS prefijo_heredado FROM arbol ORDER BY ruta;

-- Consistencia: la caché (cantidad_actual) debe cuadrar con el kardex. Esperado: 0 filas.
SELECT l.id, l.cantidad_actual, SUM(k.cantidad_con_signo) AS segun_kardex
FROM lotes l JOIN v_kardex k ON k.lote_id = l.id
GROUP BY l.id, l.cantidad_actual
HAVING l.cantidad_actual <> segun_kardex;
