-- =====================================================================
-- Inventario de Tienda · Esquema v2 (propuesta)
-- Motor: MySQL 8.0+ · Ejecutar como root (contiene DDL)
-- Se crea en una BD aparte para no tocar la versión actual.
--
-- Módulos:
--   1. Catálogo      → categorias, marcas, unidades_medida, impuestos,
--                      productos, historial_precios
--   2. Seguridad     → roles, permisos, rol_permisos, usuarios
--   3. Terceros      → proveedores, producto_proveedor, clientes, abonos_clientes (fiado)
--   4. Compras       → compras, compra_detalles, pagos_proveedores
--   5. Inventario    → lotes, conteos_inventario, conteo_detalles,
--                      movimientos_inventario (kardex)
--   6. Ventas        → ventas, venta_detalles, venta_pagos
--   7. Utilidades    → consecutivos, vistas
-- =====================================================================

DROP DATABASE IF EXISTS tienda_inventario_v2;
CREATE DATABASE tienda_inventario_v2
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
USE tienda_inventario_v2;

-- =====================================================================
-- 7. UTILIDADES (va primero porque no depende de nada)
-- =====================================================================

-- Contadores atómicos para SKU (por prefijo) y número de factura.
-- Uso desde Java (atómico, sin carreras):
--   UPDATE consecutivos SET ultimo = LAST_INSERT_ID(ultimo + 1) WHERE clave = ?;
--   SELECT LAST_INSERT_ID();
CREATE TABLE consecutivos (
    clave   VARCHAR(30) PRIMARY KEY,          -- 'SKU-LAC', 'FACTURA-VENTA', ...
    ultimo  BIGINT      NOT NULL DEFAULT 0,
    CONSTRAINT chk_consecutivo_no_negativo CHECK (ultimo >= 0)
) ENGINE = InnoDB;

-- =====================================================================
-- 1. CATÁLOGO
-- =====================================================================

-- Jerarquía con lista de adyacencia: Lácteos → Leches → Deslactosadas.
-- Se recorre con un CTE recursivo (WITH RECURSIVE).
CREATE TABLE categorias (
    id                  INT AUTO_INCREMENT PRIMARY KEY,
    nombre              VARCHAR(80)  NOT NULL,
    prefijo_sku         VARCHAR(5)   NULL,     -- solo las raíces lo necesitan; las hijas heredan
    categoria_padre_id  INT          NULL,
    activa              BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_categoria_nombre  UNIQUE (nombre),
    CONSTRAINT uq_categoria_prefijo UNIQUE (prefijo_sku),
    CONSTRAINT fk_categoria_padre FOREIGN KEY (categoria_padre_id)
        REFERENCES categorias (id) ON DELETE RESTRICT,
    CONSTRAINT chk_prefijo_mayusculas CHECK (prefijo_sku = UPPER(prefijo_sku))
) ENGINE = InnoDB;

CREATE TABLE marcas (
    id      INT AUTO_INCREMENT PRIMARY KEY,
    nombre  VARCHAR(80) NOT NULL,
    activa  BOOLEAN     NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_marca_nombre UNIQUE (nombre)
) ENGINE = InnoDB;

-- Unidad del CONTENIDO de la presentación (1 L, 500 g, 12 und).
-- Se vende por unidades enteras; vender a granel sería una extensión.
CREATE TABLE unidades_medida (
    id      INT AUTO_INCREMENT PRIMARY KEY,
    codigo  VARCHAR(10) NOT NULL,              -- 'g', 'kg', 'ml', 'L', 'und'
    nombre  VARCHAR(40) NOT NULL,
    CONSTRAINT uq_unidad_codigo UNIQUE (codigo)
) ENGINE = InnoDB;

-- En Colombia el IVA general es 19 %, con tarifas de 5 % y 0 %.
CREATE TABLE impuestos (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    nombre      VARCHAR(40)  NOT NULL,
    porcentaje  DECIMAL(5,2) NOT NULL,
    CONSTRAINT uq_impuesto_nombre UNIQUE (nombre),
    CONSTRAINT chk_impuesto_rango CHECK (porcentaje BETWEEN 0 AND 100)
) ENGINE = InnoDB;

-- El producto es el CONCEPTO del catálogo. No guarda stock ni vencimiento:
-- eso vive en los lotes.
CREATE TABLE productos (
    id                  INT AUTO_INCREMENT PRIMARY KEY,
    sku                 VARCHAR(20)   NOT NULL,          -- interno, autogenerado (LAC-0007)
    codigo_barras       VARCHAR(14)   NULL,              -- EAN-13 / UPC del fabricante
    nombre              VARCHAR(120)  NOT NULL,
    descripcion         TEXT          NULL,
    categoria_id        INT           NOT NULL,
    marca_id            INT           NULL,
    unidad_id           INT           NOT NULL,
    contenido           DECIMAL(10,3) NOT NULL,          -- 1.000 (L), 500.000 (g)
    impuesto_id         INT           NOT NULL,
    precio_venta_iva_incluido DECIMAL(12,2) NOT NULL,    -- precio de estantería (lo que paga el cliente)
    stock_minimo        INT           NOT NULL DEFAULT 0,
    maneja_vencimiento  BOOLEAN       NOT NULL,          -- reemplaza al ENUM tipo
    meses_garantia      SMALLINT      NULL,
    imagen_url          VARCHAR(500)  NULL,              -- ruta o URL de la imagen; nunca la imagen en la BD
    activo              BOOLEAN       NOT NULL DEFAULT TRUE,  -- se desactiva, no se borra
    creado_en           DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                      ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_producto_sku           UNIQUE (sku),
    CONSTRAINT uq_producto_codigo_barras UNIQUE (codigo_barras),   -- varios NULL permitidos
    CONSTRAINT fk_producto_categoria FOREIGN KEY (categoria_id) REFERENCES categorias (id),
    CONSTRAINT fk_producto_marca     FOREIGN KEY (marca_id)     REFERENCES marcas (id),
    CONSTRAINT fk_producto_unidad    FOREIGN KEY (unidad_id)    REFERENCES unidades_medida (id),
    CONSTRAINT fk_producto_impuesto  FOREIGN KEY (impuesto_id)  REFERENCES impuestos (id),
    CONSTRAINT chk_producto_precio      CHECK (precio_venta_iva_incluido >= 0),
    CONSTRAINT chk_producto_contenido   CHECK (contenido > 0),
    CONSTRAINT chk_producto_stock_min   CHECK (stock_minimo >= 0),
    CONSTRAINT chk_producto_garantia    CHECK (meses_garantia IS NULL OR meses_garantia > 0),
    -- un perecedero no tiene garantía (equivale al antiguo chk_tipo_consistente)
    CONSTRAINT chk_vencimiento_garantia CHECK (NOT (maneja_vencimiento AND meses_garantia IS NOT NULL)),
    INDEX idx_producto_nombre (nombre),                 -- búsquedas 'leche%'
    FULLTEXT INDEX ftx_producto_nombre (nombre, descripcion)  -- búsquedas por palabras
) ENGINE = InnoDB;

-- Auditoría de precios (lo llena el servicio al llamar cambiarPrecio).
CREATE TABLE historial_precios (
    id               BIGINT AUTO_INCREMENT PRIMARY KEY,
    producto_id      INT           NOT NULL,
    precio_anterior  DECIMAL(12,2) NOT NULL,          -- con IVA incluido
    precio_nuevo     DECIMAL(12,2) NOT NULL,          -- con IVA incluido
    usuario_id       INT           NOT NULL,
    cambiado_en      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_hist_producto FOREIGN KEY (producto_id) REFERENCES productos (id),
    INDEX idx_hist_producto_fecha (producto_id, cambiado_en)
    -- fk a usuarios se agrega abajo, cuando exista la tabla
) ENGINE = InnoDB;

-- =====================================================================
-- 2. SEGURIDAD
-- =====================================================================

CREATE TABLE roles (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    nombre       VARCHAR(30)  NOT NULL,         -- ADMIN, CAJERO, BODEGA
    descripcion  VARCHAR(150) NULL,
    CONSTRAINT uq_rol_nombre UNIQUE (nombre)
) ENGINE = InnoDB;

-- Catálogo de acciones que la app sabe proteger. El código Java pregunta
-- "¿este usuario tiene PRODUCTO_CAMBIAR_PRECIO?", nunca "¿es ADMIN?".
-- Así, crear un rol nuevo desde la web no exige tocar el código.
CREATE TABLE permisos (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    codigo       VARCHAR(50)  NOT NULL,         -- 'VENTA_REGISTRAR', 'PRODUCTO_CAMBIAR_PRECIO', ...
    descripcion  VARCHAR(150) NOT NULL,
    CONSTRAINT uq_permiso_codigo UNIQUE (codigo),
    CONSTRAINT chk_permiso_codigo CHECK (codigo = UPPER(codigo))
) ENGINE = InnoDB;

-- N:M: un rol tiene muchos permisos y un permiso está en muchos roles.
CREATE TABLE rol_permisos (
    rol_id      INT NOT NULL,
    permiso_id  INT NOT NULL,
    PRIMARY KEY (rol_id, permiso_id),
    CONSTRAINT fk_rp_rol     FOREIGN KEY (rol_id)     REFERENCES roles (id)    ON DELETE CASCADE,
    CONSTRAINT fk_rp_permiso FOREIGN KEY (permiso_id) REFERENCES permisos (id) ON DELETE CASCADE
) ENGINE = InnoDB;

-- Usuarios de la APLICACIÓN (no confundir con usuarios de MySQL).
-- Nunca se guarda la clave: solo su hash (bcrypt/argon2 desde Java).
CREATE TABLE usuarios (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    username         VARCHAR(40)  NOT NULL,
    password_hash    VARCHAR(255) NOT NULL,
    nombre_completo  VARCHAR(120) NOT NULL,
    rol_id           INT          NOT NULL,
    activo           BOOLEAN      NOT NULL DEFAULT TRUE,
    creado_en        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ultimo_acceso    DATETIME     NULL,
    CONSTRAINT uq_usuario_username UNIQUE (username),
    CONSTRAINT fk_usuario_rol FOREIGN KEY (rol_id) REFERENCES roles (id)
) ENGINE = InnoDB;

ALTER TABLE historial_precios
    ADD CONSTRAINT fk_hist_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id);

-- =====================================================================
-- 3. TERCEROS
-- =====================================================================

CREATE TABLE proveedores (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    nit           VARCHAR(20)  NOT NULL,
    razon_social  VARCHAR(150) NOT NULL,
    telefono      VARCHAR(20)  NULL,
    email         VARCHAR(120) NULL,
    direccion     VARCHAR(200) NULL,
    activo        BOOLEAN      NOT NULL DEFAULT TRUE,
    creado_en     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_proveedor_nit UNIQUE (nit)
) ENGINE = InnoDB;

-- Relación N:M: un producto lo pueden surtir varios proveedores y viceversa.
CREATE TABLE producto_proveedor (
    producto_id       INT           NOT NULL,
    proveedor_id      INT           NOT NULL,
    codigo_proveedor  VARCHAR(40)   NULL,       -- cómo lo llama el proveedor
    ultimo_costo      DECIMAL(12,2) NULL,
    PRIMARY KEY (producto_id, proveedor_id),
    CONSTRAINT fk_pp_producto  FOREIGN KEY (producto_id)  REFERENCES productos (id)   ON DELETE CASCADE,
    CONSTRAINT fk_pp_proveedor FOREIGN KEY (proveedor_id) REFERENCES proveedores (id) ON DELETE CASCADE
) ENGINE = InnoDB;

-- cliente_id NULL en ventas = "consumidor final".
-- cupo_fiado = cuánto puede deber como máximo (0 = no se le fía).
CREATE TABLE clientes (
    id                INT AUTO_INCREMENT PRIMARY KEY,
    tipo_documento    ENUM('CC','CE','NIT','PAS','TI') NOT NULL,
    numero_documento  VARCHAR(20)   NOT NULL,
    nombre            VARCHAR(150)  NOT NULL,
    email             VARCHAR(120)  NULL,
    telefono          VARCHAR(20)   NULL,
    cupo_fiado        DECIMAL(14,2) NOT NULL DEFAULT 0,
    activo            BOOLEAN       NOT NULL DEFAULT TRUE,
    creado_en         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_cliente_documento UNIQUE (tipo_documento, numero_documento),
    CONSTRAINT chk_cliente_cupo CHECK (cupo_fiado >= 0)
) ENGINE = InnoDB;

-- Pagos que hace el cliente para bajar lo que debe.
-- Lo que debe NO se guarda: se calcula (ver v_saldo_clientes).
--   deuda = pagos con metodo 'FIADO' de ventas no anuladas − abonos
CREATE TABLE abonos_clientes (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    cliente_id  INT           NOT NULL,
    monto       DECIMAL(14,2) NOT NULL,
    metodo      ENUM('EFECTIVO','TARJETA_DEBITO','TARJETA_CREDITO',
                     'TRANSFERENCIA','NEQUI','DAVIPLATA') NOT NULL,
    usuario_id  INT           NOT NULL,          -- quién recibió el abono
    nota        VARCHAR(255)  NULL,
    creado_en   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_abono_cliente FOREIGN KEY (cliente_id) REFERENCES clientes (id),
    CONSTRAINT fk_abono_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id),
    CONSTRAINT chk_abono_monto CHECK (monto > 0),
    INDEX idx_abono_cliente_fecha (cliente_id, creado_en)
) ENGINE = InnoDB;

-- =====================================================================
-- 4. COMPRAS (pedidos y entradas de mercancía)
-- =====================================================================

-- Ciclo de vida: BORRADOR (pedido hecho) → RECIBIDA (llegó, se crean lotes) → ANULADA.
-- Los lotes y movimientos SOLO se crean al pasar a RECIBIDA.
-- Los costos de compra se guardan SIN IVA (así vienen en la factura del proveedor).
CREATE TABLE compras (
    id                 INT AUTO_INCREMENT PRIMARY KEY,
    proveedor_id       INT           NOT NULL,
    numero_factura     VARCHAR(30)   NULL,       -- la del proveedor; no existe mientras es pedido
    fecha_pedido       DATE          NOT NULL,
    fecha_recepcion    DATETIME      NULL,       -- cuándo llegó la mercancía
    creado_por         INT           NOT NULL,   -- quién hizo el pedido
    recibido_por       INT           NULL,       -- quién recibió la mercancía
    estado             ENUM('BORRADOR','RECIBIDA','ANULADA') NOT NULL DEFAULT 'BORRADOR',
    forma_pago         ENUM('CONTADO','CREDITO') NOT NULL DEFAULT 'CONTADO',
    fecha_limite_pago  DATE          NULL,       -- solo si es a crédito ("a 30 días")
    subtotal           DECIMAL(14,2) NOT NULL DEFAULT 0,
    total_impuestos    DECIMAL(14,2) NOT NULL DEFAULT 0,
    total              DECIMAL(14,2) NOT NULL DEFAULT 0,
    notas              VARCHAR(255)  NULL,
    creado_en          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_compra_factura UNIQUE (proveedor_id, numero_factura),  -- no registrar dos veces la misma
    CONSTRAINT fk_compra_proveedor FOREIGN KEY (proveedor_id) REFERENCES proveedores (id),
    CONSTRAINT fk_compra_creador   FOREIGN KEY (creado_por)   REFERENCES usuarios (id),
    CONSTRAINT fk_compra_receptor  FOREIGN KEY (recibido_por) REFERENCES usuarios (id),
    CONSTRAINT chk_compra_totales  CHECK (subtotal >= 0 AND total_impuestos >= 0
                                          AND total = subtotal + total_impuestos),
    -- crédito ⇔ tiene fecha límite de pago
    CONSTRAINT chk_compra_credito  CHECK ((forma_pago = 'CREDITO') = (fecha_limite_pago IS NOT NULL)),
    -- un pedido aún no tiene recepción; una compra recibida sí, con factura y receptor
    CONSTRAINT chk_compra_estado   CHECK (
        (estado = 'BORRADOR' AND fecha_recepcion IS NULL AND recibido_por IS NULL)
     OR (estado = 'RECIBIDA' AND fecha_recepcion IS NOT NULL AND recibido_por IS NOT NULL
                             AND numero_factura IS NOT NULL)
     OR (estado = 'ANULADA')
    )
) ENGINE = InnoDB;

-- Se pide una cantidad y puede llegar otra ("pedí 20, llegaron 18").
CREATE TABLE compra_detalles (
    id                      INT AUTO_INCREMENT PRIMARY KEY,
    compra_id               INT           NOT NULL,
    producto_id             INT           NOT NULL,
    cantidad_pedida         INT           NOT NULL,
    cantidad_recibida       INT           NULL,      -- NULL mientras no llega
    costo_unitario_sin_iva  DECIMAL(12,2) NOT NULL,
    porcentaje_impuesto     DECIMAL(5,2)  NOT NULL,  -- copia del momento (snapshot)
    CONSTRAINT fk_cd_compra   FOREIGN KEY (compra_id)   REFERENCES compras (id) ON DELETE CASCADE,
    CONSTRAINT fk_cd_producto FOREIGN KEY (producto_id) REFERENCES productos (id),
    CONSTRAINT chk_cd_pedida   CHECK (cantidad_pedida > 0),
    CONSTRAINT chk_cd_recibida CHECK (cantidad_recibida IS NULL OR cantidad_recibida >= 0),
    CONSTRAINT chk_cd_costo    CHECK (costo_unitario_sin_iva >= 0)
) ENGINE = InnoDB;

-- Pagos a proveedores. Lo que se debe NO se guarda: total − pagos (ver v_cuentas_por_pagar).
-- Una compra de CONTADO también registra aquí su pago, para que la caja cuadre.
CREATE TABLE pagos_proveedores (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    compra_id   INT           NOT NULL,
    monto       DECIMAL(14,2) NOT NULL,
    metodo      ENUM('EFECTIVO','TARJETA_DEBITO','TARJETA_CREDITO',
                     'TRANSFERENCIA','NEQUI','DAVIPLATA') NOT NULL,
    referencia  VARCHAR(60)   NULL,              -- número de la transferencia, etc.
    usuario_id  INT           NOT NULL,
    pagado_en   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_pp_compra  FOREIGN KEY (compra_id)  REFERENCES compras (id),
    CONSTRAINT fk_pp_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id),
    CONSTRAINT chk_pp_monto CHECK (monto > 0)
) ENGINE = InnoDB;

-- =====================================================================
-- 5. INVENTARIO
-- =====================================================================

-- Aquí vive el vencimiento: la leche del 30-dic y la del 5-ene son dos lotes.
-- Una línea de compra puede generar VARIOS lotes (llegan 20 leches: 10 vencen
-- el 30-dic y 10 el 5-ene). El servicio valida que sumen cantidad_recibida.
-- cantidad_actual es un valor DERIVADO de los movimientos (caché a propósito):
-- permite el descuento atómico y la consulta FEFO sin sumar el kardex completo.
-- Cada lote guarda SU costo: así se sabe la ganancia exacta de cada venta.
CREATE TABLE lotes (
    id                      INT AUTO_INCREMENT PRIMARY KEY,
    producto_id             INT           NOT NULL,
    compra_detalle_id       INT           NULL,  -- NULL si el lote nace de un ajuste o de la migración
    codigo_lote             VARCHAR(40)   NULL,  -- el que trae impreso el empaque
    fecha_vencimiento       DATE          NULL,  -- obligatoria si el producto maneja vencimiento (lo valida el servicio)
    cantidad_inicial        INT           NOT NULL,
    cantidad_actual         INT           NOT NULL,
    costo_unitario_sin_iva  DECIMAL(12,2) NOT NULL,
    ingresado_en            DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_lote_producto       FOREIGN KEY (producto_id)       REFERENCES productos (id),
    CONSTRAINT fk_lote_compra_detalle FOREIGN KEY (compra_detalle_id) REFERENCES compra_detalles (id),
    CONSTRAINT chk_lote_inicial CHECK (cantidad_inicial > 0),
    CONSTRAINT chk_lote_actual  CHECK (cantidad_actual >= 0),
    CONSTRAINT chk_lote_costo   CHECK (costo_unitario_sin_iva >= 0),
    INDEX idx_lote_fefo (producto_id, fecha_vencimiento)   -- sirve a la consulta FEFO
) ENGINE = InnoDB;

-- Conteo físico: se cuenta la estantería y se compara con el sistema.
-- Al CERRAR el conteo, el servicio genera los AJUSTE_* que correspondan.
CREATE TABLE conteos_inventario (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    estado       ENUM('ABIERTO','CERRADO','CANCELADO') NOT NULL DEFAULT 'ABIERTO',
    usuario_id   INT          NOT NULL,          -- responsable del conteo
    iniciado_en  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    cerrado_en   DATETIME     NULL,
    notas        VARCHAR(255) NULL,
    CONSTRAINT fk_conteo_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id),
    CONSTRAINT chk_conteo_estado CHECK (
        (estado = 'ABIERTO' AND cerrado_en IS NULL) OR (estado <> 'ABIERTO' AND cerrado_en IS NOT NULL)
    )
) ENGINE = InnoDB;

-- Se cuenta por producto (en la estantería no se distinguen los lotes de algo sin fecha).
-- cantidad_sistema es una foto del stock en el momento de contar.
CREATE TABLE conteo_detalles (
    conteo_id         INT NOT NULL,
    producto_id       INT NOT NULL,
    cantidad_sistema  INT NOT NULL,
    cantidad_contada  INT NOT NULL,
    diferencia        INT GENERATED ALWAYS AS (cantidad_contada - cantidad_sistema) STORED,
    PRIMARY KEY (conteo_id, producto_id),
    CONSTRAINT fk_cdet_conteo   FOREIGN KEY (conteo_id)   REFERENCES conteos_inventario (id) ON DELETE CASCADE,
    CONSTRAINT fk_cdet_producto FOREIGN KEY (producto_id) REFERENCES productos (id),
    CONSTRAINT chk_cdet_cantidades CHECK (cantidad_sistema >= 0 AND cantidad_contada >= 0)
) ENGINE = InnoDB;

-- Kardex: registro INMUTABLE de todo lo que entra y sale (solo INSERT; nunca UPDATE ni DELETE).
-- La cantidad siempre es positiva; el sentido lo da el tipo.
-- Un error NO se borra: se registra un ajuste contrario que apunta al movimiento
-- equivocado con corrige_movimiento_id (como un banco que reversa una transferencia).
CREATE TABLE movimientos_inventario (
    id                     BIGINT AUTO_INCREMENT PRIMARY KEY,
    lote_id                INT          NOT NULL,
    tipo                   ENUM(
                               -- entradas (+)
                               'ENTRADA_COMPRA','AJUSTE_ENTRADA','DEVOLUCION_CLIENTE','ANULACION_VENTA',
                               -- salidas (−)
                               'SALIDA_VENTA','AJUSTE_SALIDA','BAJA_VENCIMIENTO','DEVOLUCION_PROVEEDOR'
                           ) NOT NULL,
    cantidad               INT          NOT NULL,
    compra_detalle_id      INT          NULL,
    venta_detalle_id       INT          NULL,
    conteo_id              INT          NULL,
    corrige_movimiento_id  BIGINT       NULL,
    usuario_id             INT          NOT NULL,
    motivo                 VARCHAR(255) NULL,
    creado_en              DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_mov_corrige  UNIQUE (corrige_movimiento_id),     -- un error se corrige una sola vez
    CONSTRAINT fk_mov_lote     FOREIGN KEY (lote_id)               REFERENCES lotes (id),
    CONSTRAINT fk_mov_compra   FOREIGN KEY (compra_detalle_id)     REFERENCES compra_detalles (id),
    CONSTRAINT fk_mov_conteo   FOREIGN KEY (conteo_id)             REFERENCES conteos_inventario (id),
    CONSTRAINT fk_mov_corrige  FOREIGN KEY (corrige_movimiento_id) REFERENCES movimientos_inventario (id),
    CONSTRAINT fk_mov_usuario  FOREIGN KEY (usuario_id)            REFERENCES usuarios (id),
    -- fk a venta_detalles se agrega abajo
    CONSTRAINT chk_mov_cantidad CHECK (cantidad > 0),
    -- cada tipo exige su documento de origen (y solo ese)
    CONSTRAINT chk_mov_referencias CHECK (
        (tipo = 'ENTRADA_COMPRA'
            AND compra_detalle_id IS NOT NULL AND venta_detalle_id IS NULL AND conteo_id IS NULL)
     OR (tipo = 'DEVOLUCION_PROVEEDOR'
            AND compra_detalle_id IS NOT NULL AND venta_detalle_id IS NULL AND conteo_id IS NULL
            AND motivo IS NOT NULL)
     OR (tipo IN ('SALIDA_VENTA','DEVOLUCION_CLIENTE','ANULACION_VENTA')
            AND venta_detalle_id IS NOT NULL AND compra_detalle_id IS NULL AND conteo_id IS NULL)
     OR (tipo IN ('AJUSTE_ENTRADA','AJUSTE_SALIDA')
            AND compra_detalle_id IS NULL AND venta_detalle_id IS NULL
            AND (motivo IS NOT NULL OR conteo_id IS NOT NULL))
     OR (tipo = 'BAJA_VENCIMIENTO'
            AND compra_detalle_id IS NULL AND venta_detalle_id IS NULL AND motivo IS NOT NULL)
    ),
    -- una corrección siempre es un ajuste y siempre explica por qué
    CONSTRAINT chk_mov_correccion CHECK (
        corrige_movimiento_id IS NULL
     OR (tipo IN ('AJUSTE_ENTRADA','AJUSTE_SALIDA') AND motivo IS NOT NULL)
    ),
    INDEX idx_mov_lote_fecha (lote_id, creado_en)
) ENGINE = InnoDB;

-- =====================================================================
-- 6. VENTAS
-- =====================================================================

CREATE TABLE ventas (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    numero_factura   VARCHAR(20)   NOT NULL,          -- de consecutivos 'FACTURA-VENTA'
    cliente_id       INT           NULL,              -- NULL = consumidor final
    usuario_id       INT           NOT NULL,          -- cajero
    fecha            DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado           ENUM('COMPLETADA','ANULADA') NOT NULL DEFAULT 'COMPLETADA',
    subtotal         DECIMAL(14,2) NOT NULL,
    total_impuestos  DECIMAL(14,2) NOT NULL,
    total            DECIMAL(14,2) NOT NULL,
    CONSTRAINT uq_venta_factura UNIQUE (numero_factura),
    CONSTRAINT fk_venta_cliente FOREIGN KEY (cliente_id) REFERENCES clientes (id),
    CONSTRAINT fk_venta_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id),
    CONSTRAINT chk_venta_totales CHECK (subtotal >= 0 AND total_impuestos >= 0
                                        AND total = subtotal + total_impuestos),
    INDEX idx_venta_fecha (fecha)
) ENGINE = InnoDB;

-- Precio e impuesto se COPIAN: si mañana sube la leche, la factura de hoy no cambia.
CREATE TABLE venta_detalles (
    id                   INT AUTO_INCREMENT PRIMARY KEY,
    venta_id             INT           NOT NULL,
    producto_id          INT           NOT NULL,
    cantidad             INT           NOT NULL,
    precio_unitario      DECIMAL(12,2) NOT NULL,     -- snapshot, sin IVA
    porcentaje_impuesto  DECIMAL(5,2)  NOT NULL,     -- snapshot
    descuento            DECIMAL(12,2) NOT NULL DEFAULT 0,
    subtotal_linea       DECIMAL(14,2) GENERATED ALWAYS AS
                         (cantidad * precio_unitario - descuento) STORED,
    CONSTRAINT fk_vd_venta    FOREIGN KEY (venta_id)    REFERENCES ventas (id),
    CONSTRAINT fk_vd_producto FOREIGN KEY (producto_id) REFERENCES productos (id),
    CONSTRAINT chk_vd_cantidad  CHECK (cantidad > 0),
    CONSTRAINT chk_vd_precio    CHECK (precio_unitario >= 0),
    CONSTRAINT chk_vd_descuento CHECK (descuento >= 0 AND descuento <= cantidad * precio_unitario)
) ENGINE = InnoDB;

ALTER TABLE movimientos_inventario
    ADD CONSTRAINT fk_mov_venta FOREIGN KEY (venta_detalle_id) REFERENCES venta_detalles (id);

-- Una venta puede pagarse con varios medios (parte efectivo, parte Nequi).
-- 'FIADO' = la parte que el cliente queda debiendo. El servicio Java valida que
-- la venta tenga cliente y que no supere su cupo (cruza tablas: no cabe en un CHECK).
CREATE TABLE venta_pagos (
    id        INT AUTO_INCREMENT PRIMARY KEY,
    venta_id  INT           NOT NULL,
    metodo    ENUM('EFECTIVO','TARJETA_DEBITO','TARJETA_CREDITO',
                   'TRANSFERENCIA','NEQUI','DAVIPLATA','FIADO') NOT NULL,
    monto     DECIMAL(14,2) NOT NULL,
    CONSTRAINT fk_pago_venta FOREIGN KEY (venta_id) REFERENCES ventas (id),
    CONSTRAINT chk_pago_monto CHECK (monto > 0)
) ENGINE = InnoDB;

-- =====================================================================
-- VISTAS (consultas frecuentes con nombre propio)
-- =====================================================================

-- Stock por producto. "vendible" excluye los lotes vencidos.
CREATE VIEW v_stock_producto AS
SELECT p.id,
       p.sku,
       p.nombre,
       p.stock_minimo,
       COALESCE(SUM(l.cantidad_actual), 0) AS stock_total,
       COALESCE(SUM(CASE WHEN l.fecha_vencimiento IS NULL
                           OR l.fecha_vencimiento >= CURRENT_DATE
                         THEN l.cantidad_actual END), 0) AS stock_vendible
FROM productos p
LEFT JOIN lotes l ON l.producto_id = p.id
WHERE p.activo
GROUP BY p.id, p.sku, p.nombre, p.stock_minimo;

-- Lotes con existencias que vencen en los próximos 15 días (o ya vencieron).
CREATE VIEW v_lotes_por_vencer AS
SELECT l.id AS lote_id,
       p.sku,
       p.nombre,
       l.fecha_vencimiento,
       DATEDIFF(l.fecha_vencimiento, CURRENT_DATE) AS dias_para_vencer,
       l.cantidad_actual
FROM lotes l
JOIN productos p ON p.id = l.producto_id
WHERE l.cantidad_actual > 0
  AND l.fecha_vencimiento IS NOT NULL
  AND l.fecha_vencimiento <= CURRENT_DATE + INTERVAL 15 DAY;

-- Kardex con el signo ya aplicado (+ entra, − sale).
CREATE VIEW v_kardex AS
SELECT m.id,
       m.creado_en,
       p.sku,
       m.lote_id,
       m.tipo,
       CASE WHEN m.tipo IN ('ENTRADA_COMPRA','AJUSTE_ENTRADA','DEVOLUCION_CLIENTE','ANULACION_VENTA')
            THEN m.cantidad ELSE -m.cantidad END AS cantidad_con_signo,
       u.username,
       m.motivo
FROM movimientos_inventario m
JOIN lotes     l ON l.id = m.lote_id
JOIN productos p ON p.id = l.producto_id
JOIN usuarios  u ON u.id = m.usuario_id;

-- Deuda de cada cliente con fiado y cuánto cupo le queda.
CREATE VIEW v_saldo_clientes AS
SELECT c.id,
       c.nombre,
       c.cupo_fiado,
       COALESCE(f.total_fiado, 0) - COALESCE(a.total_abonos, 0)                AS deuda,
       c.cupo_fiado - (COALESCE(f.total_fiado, 0) - COALESCE(a.total_abonos, 0)) AS cupo_disponible
FROM clientes c
LEFT JOIN (SELECT v.cliente_id, SUM(p.monto) AS total_fiado
           FROM ventas v JOIN venta_pagos p ON p.venta_id = v.id
           WHERE p.metodo = 'FIADO' AND v.estado <> 'ANULADA'
           GROUP BY v.cliente_id) f ON f.cliente_id = c.id
LEFT JOIN (SELECT cliente_id, SUM(monto) AS total_abonos
           FROM abonos_clientes GROUP BY cliente_id) a ON a.cliente_id = c.id
WHERE c.cupo_fiado > 0 OR f.total_fiado IS NOT NULL;

-- Permisos efectivos de cada usuario (lo que consulta el login).
CREATE VIEW v_permisos_usuario AS
SELECT u.id AS usuario_id, u.username, r.nombre AS rol, p.codigo AS permiso
FROM usuarios u
JOIN roles r         ON r.id = u.rol_id
JOIN rol_permisos rp ON rp.rol_id = r.id
JOIN permisos p      ON p.id = rp.permiso_id
WHERE u.activo;

-- Lo que se le debe a cada proveedor, factura por factura.
CREATE VIEW v_cuentas_por_pagar AS
SELECT c.id AS compra_id,
       pr.razon_social AS proveedor,
       c.numero_factura,
       c.forma_pago,
       c.fecha_limite_pago,
       c.total,
       COALESCE(SUM(pp.monto), 0)           AS pagado,
       c.total - COALESCE(SUM(pp.monto), 0) AS saldo,
       CASE WHEN c.fecha_limite_pago < CURRENT_DATE THEN 'VENCIDA' ELSE 'AL_DIA' END AS situacion
FROM compras c
JOIN proveedores pr ON pr.id = c.proveedor_id
LEFT JOIN pagos_proveedores pp ON pp.compra_id = c.id
WHERE c.estado = 'RECIBIDA'
GROUP BY c.id, pr.razon_social, c.numero_factura, c.forma_pago, c.fecha_limite_pago, c.total
HAVING saldo > 0;

-- Mermas: cuánto se pierde por producto (vencidos y faltantes), en unidades y al costo.
-- Se excluyen los movimientos que fueron reversados (los que alguien corrigió).
CREATE VIEW v_mermas AS
SELECT p.sku,
       p.nombre,
       SUM(CASE WHEN m.tipo = 'BAJA_VENCIMIENTO' THEN m.cantidad ELSE 0 END) AS unidades_vencidas,
       SUM(CASE WHEN m.tipo = 'AJUSTE_SALIDA'    THEN m.cantidad ELSE 0 END) AS unidades_faltantes,
       SUM(m.cantidad * l.costo_unitario_sin_iva)                           AS costo_perdido
FROM movimientos_inventario m
JOIN lotes l     ON l.id = m.lote_id
JOIN productos p ON p.id = l.producto_id
LEFT JOIN movimientos_inventario reversa ON reversa.corrige_movimiento_id = m.id
WHERE m.tipo IN ('BAJA_VENCIMIENTO', 'AJUSTE_SALIDA')
  AND m.corrige_movimiento_id IS NULL     -- no es una reversa
  AND reversa.id IS NULL                  -- y nadie lo reversó
GROUP BY p.sku, p.nombre;

-- Valor del inventario al costo (lo que costó) y al precio de venta (lo que vale).
CREATE VIEW v_valor_inventario AS
SELECT SUM(l.cantidad_actual * l.costo_unitario_sin_iva) AS valor_al_costo,
       SUM(l.cantidad_actual * p.precio_venta_iva_incluido) AS valor_a_precio_venta
FROM lotes l
JOIN productos p ON p.id = l.producto_id
WHERE l.fecha_vencimiento IS NULL OR l.fecha_vencimiento >= CURRENT_DATE;
