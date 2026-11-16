package com.tienda.inventario.interfaces;

import com.tienda.inventario.exception.AccesoDatosException;

import java.sql.Connection;
import java.sql.SQLException;

/**
 * Contrato para cualquier cosa que pueda entregar una conexión JDBC.
 * Quien recibe la conexión es responsable de cerrarla.
 */
public interface IConnectionProvider {

    Connection getConnection() throws SQLException;

    /**
     * Abre una conexión de prueba y la cierra de inmediato.
     * Sirve para fallar rápido al arrancar si MySQL no está disponible.
     *
     * Es un método "default": tiene código dentro de la interfaz, y todas las
     * implementaciones lo heredan sin tener que escribirlo.
     *
     * @throws AccesoDatosException si no se puede conectar
     */
    default void verificarConexion() {
        try (Connection conn = getConnection()) {
            // isValid hace un "ping" real a MySQL, esperando máximo 2 segundos
            if (!conn.isValid(2)) {
                throw new SQLException("La conexión se abrió pero no responde");
            }
        } catch (SQLException e) {
            throw new AccesoDatosException("No se pudo conectar a la base de datos", e);
        }
    }
}