-- 1. Create the database
CREATE DATABASE IF NOT EXISTS tienda_inventario
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- 2. Create the app user (only from this machine)
CREATE USER IF NOT EXISTS 'app_inventario'@'localhost'
  IDENTIFIED BY 'CAMBIAR_ESTA_CLAVE';

-- 3. Give it only read/write permissions on this database
GRANT SELECT, INSERT, UPDATE, DELETE
  ON tienda_inventario.*
  TO 'app_inventario'@'localhost';

-- 4. Check the result
SHOW GRANTS FOR 'app_inventario'@'localhost';