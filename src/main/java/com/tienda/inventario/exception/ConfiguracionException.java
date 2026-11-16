package com.tienda.inventario.exception;

/**
 * Error de configuración al arrancar: falta el .env, falta una variable
 * o alguna tiene un valor inválido.
 *
 * No hereda de InventarioException porque no es un error del negocio:
 * es un problema de instalación que impide que la aplicación arranque.
 */
public class ConfiguracionException extends RuntimeException {

    public ConfiguracionException(String message) {
        super(message);
    }

    public ConfiguracionException(String message, Throwable cause) {
        super(message, cause);
    }
}