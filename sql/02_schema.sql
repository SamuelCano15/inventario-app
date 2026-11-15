USE tienda_inventario;

CREATE TABLE IF NOT EXISTS categorias (
    id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre  VARCHAR(60) NOT NULL,
    CONSTRAINT uq_categorias_nombre UNIQUE (nombre)
) ENGINE = InnoDB;

-- Productos
CREATE TABLE IF NOT EXISTS productos (
    id                 INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    sku                VARCHAR(20)   NOT NULL,
    nombre             VARCHAR(100)  NOT NULL,
    precio             DECIMAL(10,2) NOT NULL,
    stock              INT           NOT NULL DEFAULT 0,
    categoria_id       INT UNSIGNED  NOT NULL,

    -- Discriminator: tells Java which subclass to build
    tipo               ENUM('PERECEDERO', 'NO_PERECEDERO') NOT NULL,

    -- Subclass-specific columns (nullable)
    fecha_vencimiento  DATE NULL,   -- only PERECEDERO
    meses_garantia     INT  NULL,   -- only NO_PERECEDERO

    creado_en          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                                  ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_productos_sku UNIQUE (sku),
    CONSTRAINT fk_productos_categoria
        FOREIGN KEY (categoria_id) REFERENCES categorias(id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_precio_positivo CHECK (precio >= 0),
    CONSTRAINT chk_stock_positivo  CHECK (stock >= 0),
    CONSTRAINT chk_tipo_consistente CHECK (
        (tipo = 'PERECEDERO'    AND fecha_vencimiento IS NOT NULL AND meses_garantia IS NULL)
     OR (tipo = 'NO_PERECEDERO' AND fecha_vencimiento IS NULL)
    )
) ENGINE = InnoDB;


