package com.tienda.inventario.exception;

/**
 * Base class for every business/application error in this app.
 * Lets the UI catch all of them with a single catch block.
 */
public abstract class InventarioException extends RuntimeException {

    protected InventarioException(String message) {
        super(message);
    }

    // Exception chaining: keeps the original cause (e.g. a SQLException)
    protected InventarioException(String message, Throwable cause) {
        super(message, cause);
    }
}