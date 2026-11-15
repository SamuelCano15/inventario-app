package com.tienda.inventario.interfaces;

import java.sql.Connection;
import java.sql.SQLException;

/**
 * Contrato para cualquier elemento que pueda proporcionar una conexión JDBC.
 * El código que solicita la conexión es responsable de cerrar la conexión devuelta.
 */
public interface IConnectionProvider {

    Connection getConnection() throws SQLException;
}