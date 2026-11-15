package com.tienda.inventario.database;

import com.tienda.inventario.config.AppConfig;
import com.tienda.inventario.interfaces.IConnectionProvider;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

/**
 * Crea una nueva conexión JDBC en cada llamada utilizando DriverManager.
 */

public class ConnectionFactory implements IConnectionProvider {

    private final AppConfig config;

    public ConnectionFactory(AppConfig config) {
        this.config = config;
    }

    @Override
    public Connection getConnection() throws SQLException {
        return DriverManager.getConnection(
                config.jdbcUrl(),
                config.user(),
                config.password()
        );
    }
}