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

INSERT INTO roles (nombre, descripcion) VALUES
    ('ADMIN',  'Acceso total'),
    ('CAJERO', 'Vende y recibe abonos'),
    ('BODEGA', 'Recibe compras y ajusta inventario');

INSERT INTO permisos (codigo, descripcion) VALUES
    ('PRODUCTO_CREAR',          'Crear y editar productos'),
    ('PRODUCTO_CAMBIAR_PRECIO', 'Cambiar el precio de venta'),
    ('COMPRA_REGISTRAR',        'Registrar compras a proveedores'),
    ('INVENTARIO_AJUSTAR',      'Hacer ajustes y bajas de inventario'),
    ('VENTA_REGISTRAR',         'Registrar ventas'),
    ('VENTA_ANULAR',            'Anular ventas'),
    ('VENTA_FIAR',              'Vender a crédito (fiado)'),
    ('ABONO_REGISTRAR',         'Recibir abonos de clientes'),
    ('USUARIO_ADMINISTRAR',     'Crear usuarios, roles y permisos');

-- ADMIN tiene todos los permisos.
INSERT INTO rol_permisos (rol_id, permiso_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permisos p WHERE r.nombre = 'ADMIN';

INSERT INTO rol_permisos (rol_id, permiso_id)
SELECT r.id, p.id FROM roles r JOIN permisos p
  ON p.codigo IN ('VENTA_REGISTRAR', 'VENTA_FIAR', 'ABONO_REGISTRAR')
WHERE r.nombre = 'CAJERO';

INSERT INTO rol_permisos (rol_id, permiso_id)
SELECT r.id, p.id FROM roles r JOIN permisos p
  ON p.codigo IN ('COMPRA_REGISTRAR', 'INVENTARIO_AJUSTAR', 'PRODUCTO_CREAR')
WHERE r.nombre = 'BODEGA';
-- Hash de ejemplo (no es una clave real). En la app se genera con bcrypt.
INSERT INTO usuarios (username, password_hash, nombre_completo, rol_id) VALUES
    ('admin',  '$2a$12$EJEMPLO.NO.ES.UNA.CLAVE.REAL.xxxxxxxxxxxxxxxxxxxxxxxx', 'Administrador', 1),
    ('caja1',  '$2a$12$EJEMPLO.NO.ES.UNA.CLAVE.REAL.yyyyyyyyyyyyyyyyyyyyyyyy', 'Cajero Uno',    2),
    ('bodega1','$2a$12$EJEMPLO.NO.ES.UNA.CLAVE.REAL.zzzzzzzzzzzzzzzzzzzzzzzz', 'Bodeguero Uno', 3);

-- ---------- SKU autogenerado (así lo haría Java) ----------
UPDATE consecutivos SET ultimo = LAST_INSERT_ID(ultimo + 1) WHERE clave = 'SKU-LAC';
SET @sku_leche = CONCAT('LAC-', LPAD(LAST_INSERT_ID(), 4, '0'));   -- LAC-0001

INSERT INTO productos (sku, codigo_barras, nombre, categoria_id, marca_id, unidad_id,
                       contenido, impuesto_id, precio_venta_iva_incluido, stock_minimo, maneja_vencimiento)
VALUES (@sku_leche, '7702129001014', 'Leche entera Colanta 1 L', 5, 1, 5, 1, 1, 4500.00, 10, TRUE);
SET @id_leche = LAST_INSERT_ID();

UPDATE consecutivos SET ultimo = LAST_INSERT_ID(ultimo + 1) WHERE clave = 'SKU-ELE';
INSERT INTO productos (sku, nombre, categoria_id, marca_id, unidad_id, contenido,
                       impuesto_id, precio_venta_iva_incluido, maneja_vencimiento, meses_garantia)
VALUES (CONCAT('ELE-', LPAD(LAST_INSERT_ID(), 4, '0')), 'Audífonos Bluetooth', 4, 4, 1, 1,
        3, 85000.00, FALSE, 12);

INSERT INTO proveedores (nit, razon_social, telefono) VALUES
    ('890904478-6', 'Distribuidora Lácteos Antioquia S.A.S.', '6045550000');
INSERT INTO producto_proveedor (producto_id, proveedor_id, codigo_proveedor, ultimo_costo)
VALUES (@id_leche, 1, 'COL-ENT-1L', 3600.00);

-- ---------- Pedido → recepción a crédito, con varios lotes ----------
-- 1) Pedido (BORRADOR): todavía no hay factura ni lotes.
INSERT INTO compras (proveedor_id, fecha_pedido, creado_por, forma_pago, fecha_limite_pago)
VALUES (1, '2026-11-01', 3, 'CREDITO', '2026-12-01');
SET @compra = LAST_INSERT_ID();
INSERT INTO compra_detalles (compra_id, producto_id, cantidad_pedida, costo_unitario_sin_iva, porcentaje_impuesto)
VALUES (@compra, @id_leche, 5, 3600.00, 0), (@compra, @id_leche, 40, 3600.00, 0);
SET @cd1 = (SELECT MIN(id) FROM compra_detalles WHERE compra_id = @compra);
SET @cd2 = (SELECT MAX(id) FROM compra_detalles WHERE compra_id = @compra);

-- 2) Llega la mercancía: todo en UNA transacción.
--    La línea de 40 trae dos fechas → dos lotes.  (uno vencido a propósito)
START TRANSACTION;
UPDATE compra_detalles SET cantidad_recibida = cantidad_pedida WHERE compra_id = @compra;

INSERT INTO lotes (producto_id, compra_detalle_id, codigo_lote, fecha_vencimiento,
                   cantidad_inicial, cantidad_actual, costo_unitario_sin_iva)
VALUES (@id_leche, @cd1, 'L-VIEJO', CURRENT_DATE - INTERVAL 3 DAY, 5, 5, 3600.00);
INSERT INTO movimientos_inventario (lote_id, tipo, cantidad, compra_detalle_id, usuario_id)
VALUES (LAST_INSERT_ID(), 'ENTRADA_COMPRA', 5, @cd1, 3);

INSERT INTO lotes (producto_id, compra_detalle_id, codigo_lote, fecha_vencimiento,
                   cantidad_inicial, cantidad_actual, costo_unitario_sin_iva)
VALUES (@id_leche, @cd2, 'L-30DIC', '2026-12-30', 20, 20, 3600.00);
INSERT INTO movimientos_inventario (lote_id, tipo, cantidad, compra_detalle_id, usuario_id)
VALUES (LAST_INSERT_ID(), 'ENTRADA_COMPRA', 20, @cd2, 3);

INSERT INTO lotes (producto_id, compra_detalle_id, codigo_lote, fecha_vencimiento,
                   cantidad_inicial, cantidad_actual, costo_unitario_sin_iva)
VALUES (@id_leche, @cd2, 'L-05ENE', '2027-01-05', 20, 20, 3600.00);
INSERT INTO movimientos_inventario (lote_id, tipo, cantidad, compra_detalle_id, usuario_id)
VALUES (LAST_INSERT_ID(), 'ENTRADA_COMPRA', 20, @cd2, 3);

UPDATE compras
SET estado = 'RECIBIDA', numero_factura = 'FV-1001', fecha_recepcion = NOW(), recibido_por = 3,
    subtotal = 162000.00, total_impuestos = 0, total = 162000.00
WHERE id = @compra;
COMMIT;

-- 3) Abono al proveedor: queda debiendo 62.000.
INSERT INTO pagos_proveedores (compra_id, monto, metodo, referencia, usuario_id)
VALUES (@compra, 100000.00, 'TRANSFERENCIA', 'TRF-889911', 1);

SELECT 'Stock antes de vender' AS paso, sku, stock_total, stock_vendible FROM v_stock_producto;

-- ---------- Abre turno de caja: caja1 arranca con 100.000 de base ----------
INSERT INTO turnos_caja (usuario_id, base_inicial) VALUES (2, 100000.00);
SET @turno = LAST_INSERT_ID();

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
INSERT INTO ventas (numero_factura, usuario_id, turno_id, subtotal, total_impuestos, total)
VALUES (CONCAT('FV-', LPAD(LAST_INSERT_ID(), 6, '0')), 2, @turno, 112500.00, 0, 112500.00);
SET @venta = LAST_INSERT_ID();

INSERT INTO venta_detalles (venta_id, producto_id, cantidad, precio_unitario_iva_incluido, porcentaje_impuesto)
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

INSERT INTO venta_pagos (venta_id, metodo, monto, monto_recibido, referencia) VALUES
    (@venta, 'EFECTIVO', 100000.00, 100000.00, NULL),
    (@venta, 'NEQUI',     12500.00,      NULL, 'NEQ-55120');
COMMIT;

-- ---------- Venta fiada: doña Marta se lleva 2 leches y paga después ----------
INSERT INTO clientes (tipo_documento, numero_documento, nombre, telefono, cupo_fiado)
VALUES ('CC', '43123456', 'Marta Gómez', '3001234567', 50000.00);
SET @marta = LAST_INSERT_ID();
SET @lote_ene = (SELECT id FROM lotes WHERE codigo_lote = 'L-05ENE');

START TRANSACTION;
SELECT id FROM lotes WHERE id = @lote_ene FOR UPDATE;
UPDATE consecutivos SET ultimo = LAST_INSERT_ID(ultimo + 1) WHERE clave = 'FACTURA-VENTA';
INSERT INTO ventas (numero_factura, cliente_id, usuario_id, turno_id, subtotal, total_impuestos, total)
VALUES (CONCAT('FV-', LPAD(LAST_INSERT_ID(), 6, '0')), @marta, 2, @turno, 9000.00, 0, 9000.00);
SET @venta_fiada = LAST_INSERT_ID();
INSERT INTO venta_detalles (venta_id, producto_id, cantidad, precio_unitario_iva_incluido, porcentaje_impuesto)
VALUES (@venta_fiada, @id_leche, 2, 4500.00, 0);
SET @vd2 = LAST_INSERT_ID();
UPDATE lotes SET cantidad_actual = cantidad_actual - 2 WHERE id = @lote_ene;
INSERT INTO movimientos_inventario (lote_id, tipo, cantidad, venta_detalle_id, usuario_id)
VALUES (@lote_ene, 'SALIDA_VENTA', 2, @vd2, 2);
INSERT INTO venta_pagos (venta_id, metodo, monto) VALUES (@venta_fiada, 'FIADO', 9000.00);
COMMIT;

-- Abona 5.000 en efectivo (entra a la caja del turno).
INSERT INTO abonos_clientes (cliente_id, monto, metodo, usuario_id, turno_id, nota)
VALUES (@marta, 5000.00, 'EFECTIVO', 2, @turno, 'Abono parcial');

-- ---------- Producto con IVA 19 %: jabón Fab a 12.900 (precio de estantería) ----------
UPDATE consecutivos SET ultimo = LAST_INSERT_ID(ultimo + 1) WHERE clave = 'SKU-ASE';
INSERT INTO productos (sku, nombre, categoria_id, marca_id, unidad_id, contenido,
                       impuesto_id, precio_venta_iva_incluido, maneja_vencimiento)
VALUES (CONCAT('ASE-', LPAD(LAST_INSERT_ID(), 4, '0')), 'Detergente Fab 1 kg', 3, 3, 3, 1, 3, 12900.00, FALSE);
SET @id_jabon = LAST_INSERT_ID();

START TRANSACTION;   -- compra de contado, recibida al momento
INSERT INTO compras (proveedor_id, numero_factura, fecha_pedido, fecha_recepcion, creado_por,
                     recibido_por, estado, subtotal, total_impuestos, total)
VALUES (1, 'FV-2002', CURRENT_DATE, NOW(), 3, 3, 'RECIBIDA', 85000.00, 16150.00, 101150.00);
SET @compra2 = LAST_INSERT_ID();
INSERT INTO compra_detalles (compra_id, producto_id, cantidad_pedida, cantidad_recibida,
                             costo_unitario_sin_iva, porcentaje_impuesto)
VALUES (@compra2, @id_jabon, 10, 10, 8500.00, 19);
SET @cd_jabon = LAST_INSERT_ID();
INSERT INTO lotes (producto_id, compra_detalle_id, cantidad_inicial, cantidad_actual, costo_unitario_sin_iva)
VALUES (@id_jabon, @cd_jabon, 10, 10, 8500.00);
SET @lote_jabon = LAST_INSERT_ID();
INSERT INTO movimientos_inventario (lote_id, tipo, cantidad, compra_detalle_id, usuario_id)
VALUES (@lote_jabon, 'ENTRADA_COMPRA', 10, @cd_jabon, 3);
INSERT INTO pagos_proveedores (compra_id, monto, metodo, usuario_id) VALUES (@compra2, 101150.00, 'TRANSFERENCIA', 1);
COMMIT;

-- Venta de 3 jabones; el cliente paga con un billete de 50.000.
START TRANSACTION;
SELECT id FROM lotes WHERE id = @lote_jabon FOR UPDATE;
UPDATE consecutivos SET ultimo = LAST_INSERT_ID(ultimo + 1) WHERE clave = 'FACTURA-VENTA';
INSERT INTO ventas (numero_factura, usuario_id, turno_id, subtotal, total_impuestos, total)
VALUES (CONCAT('FV-', LPAD(LAST_INSERT_ID(), 6, '0')), 2, @turno, 0, 0, 0);
SET @venta_jabon = LAST_INSERT_ID();
INSERT INTO venta_detalles (venta_id, producto_id, cantidad, precio_unitario_iva_incluido, porcentaje_impuesto)
VALUES (@venta_jabon, @id_jabon, 3, 12900.00, 19);
SET @vd_jabon = LAST_INSERT_ID();
-- los totales de la venta = suma de las líneas
UPDATE ventas v
JOIN (SELECT venta_id, SUM(base_linea) b, SUM(iva_linea) i, SUM(total_linea) t
      FROM venta_detalles WHERE venta_id = @venta_jabon GROUP BY venta_id) x ON x.venta_id = v.id
SET v.subtotal = x.b, v.total_impuestos = x.i, v.total = x.t;
UPDATE lotes SET cantidad_actual = cantidad_actual - 3 WHERE id = @lote_jabon;
INSERT INTO movimientos_inventario (lote_id, tipo, cantidad, venta_detalle_id, usuario_id)
VALUES (@lote_jabon, 'SALIDA_VENTA', 3, @vd_jabon, 2);
INSERT INTO venta_pagos (venta_id, metodo, monto, monto_recibido) VALUES (@venta_jabon, 'EFECTIVO', 38700.00, 50000.00);
COMMIT;

-- Devolución parcial: trae 1 jabón. Vuelve al lote del que salió (se busca en el kardex).
START TRANSACTION;
INSERT INTO devoluciones (venta_id, usuario_id, turno_id, motivo, metodo_reembolso, total_reembolsado)
VALUES (@venta_jabon, 2, @turno, 'No era el que necesitaba', 'EFECTIVO', 12900.00);
SET @dev = LAST_INSERT_ID();
INSERT INTO devolucion_detalles (devolucion_id, venta_detalle_id, cantidad) VALUES (@dev, @vd_jabon, 1);
SET @lote_origen = (SELECT lote_id FROM movimientos_inventario
                    WHERE venta_detalle_id = @vd_jabon AND tipo = 'SALIDA_VENTA' LIMIT 1);
UPDATE lotes SET cantidad_actual = cantidad_actual + 1 WHERE id = @lote_origen;
INSERT INTO movimientos_inventario (lote_id, tipo, cantidad, venta_detalle_id, usuario_id)
VALUES (@lote_origen, 'DEVOLUCION_CLIENTE', 1, @vd_jabon, 2);
COMMIT;

-- ---------- Baja del lote vencido (ajuste con motivo obligatorio) ----------
SET @lote_viejo = (SELECT id FROM lotes WHERE codigo_lote = 'L-VIEJO');
START TRANSACTION;
UPDATE lotes SET cantidad_actual = 0 WHERE id = @lote_viejo;
INSERT INTO movimientos_inventario (lote_id, tipo, cantidad, usuario_id, motivo)
VALUES (@lote_viejo, 'BAJA_VENCIMIENTO', 5, 1, 'Vencido, se desecha');
COMMIT;

-- ---------- Conteo físico: el sistema dice 13 leches, en la estantería hay 12 ----------
START TRANSACTION;
INSERT INTO conteos_inventario (usuario_id) VALUES (3);
SET @conteo = LAST_INSERT_ID();
INSERT INTO conteo_detalles (conteo_id, producto_id, cantidad_sistema, cantidad_contada)
VALUES (@conteo, @id_leche, (SELECT stock_total FROM v_stock_producto WHERE id = @id_leche), 12);
-- al cerrar, el faltante (−1) se descuenta del lote FEFO
UPDATE lotes SET cantidad_actual = cantidad_actual - 1 WHERE id = @lote_ene;
INSERT INTO movimientos_inventario (lote_id, tipo, cantidad, conteo_id, usuario_id)
VALUES (@lote_ene, 'AJUSTE_SALIDA', 1, @conteo, 3);
UPDATE conteos_inventario SET estado = 'CERRADO', cerrado_en = NOW() WHERE id = @conteo;
COMMIT;

-- ---------- Corrección: se registró una baja de 2 que en realidad era de 1 ----------
START TRANSACTION;
UPDATE lotes SET cantidad_actual = cantidad_actual - 2 WHERE id = @lote_ene;
INSERT INTO movimientos_inventario (lote_id, tipo, cantidad, usuario_id, motivo)
VALUES (@lote_ene, 'AJUSTE_SALIDA', 2, 3, 'Empaque roto');
SET @mov_error = LAST_INSERT_ID();
-- se reversa completo (no se edita) y luego se registra lo correcto
UPDATE lotes SET cantidad_actual = cantidad_actual + 2 WHERE id = @lote_ene;
INSERT INTO movimientos_inventario (lote_id, tipo, cantidad, usuario_id, motivo, corrige_movimiento_id)
VALUES (@lote_ene, 'AJUSTE_ENTRADA', 2, 3, 'Reversa: se digitó 2 en vez de 1', @mov_error);
UPDATE lotes SET cantidad_actual = cantidad_actual - 1 WHERE id = @lote_ene;
INSERT INTO movimientos_inventario (lote_id, tipo, cantidad, usuario_id, motivo)
VALUES (@lote_ene, 'AJUSTE_SALIDA', 1, 3, 'Empaque roto (valor correcto)');
COMMIT;

-- ---------- Cierre del turno: el cajero cuenta 230.000 ----------
UPDATE turnos_caja SET estado = 'CERRADO', cerrado_en = NOW(), efectivo_contado = 230000.00 WHERE id = @turno;

-- ---------- Resultados ----------
SELECT numero_factura, subtotal, total_impuestos, total FROM ventas;
SELECT id, total_linea, base_linea, iva_linea FROM venta_detalles;
SELECT metodo, monto, monto_recibido, cambio FROM venta_pagos;
SELECT * FROM v_cuadre_turnos;
SELECT * FROM v_ganancia_productos;
SELECT * FROM v_ventas_por_dia;
SELECT * FROM v_cuentas_por_pagar;
SELECT * FROM v_mermas;
SELECT conteo_id, cantidad_sistema, cantidad_contada, diferencia FROM conteo_detalles;
SELECT * FROM v_saldo_clientes;
SELECT rol, GROUP_CONCAT(DISTINCT permiso ORDER BY permiso SEPARATOR ', ') AS permisos
FROM v_permisos_usuario GROUP BY rol;
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
