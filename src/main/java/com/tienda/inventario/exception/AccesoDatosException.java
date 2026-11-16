package com.tienda.inventario.exception;

/**
 * Wraps any low-level persistence error (e.g. SQLException)
 * so upper layers never depend on java.sql.
 */
public class AccesoDatosException extends InventarioException {

    public AccesoDatosException(String message, Throwable cause) {
        super(message, cause);
    }
}