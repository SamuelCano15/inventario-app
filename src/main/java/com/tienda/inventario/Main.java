package com.tienda.inventario;

import com.tienda.inventario.config.AppConfig;
import com.tienda.inventario.database.ConnectionFactory;
import com.tienda.inventario.interfaces.IConnectionProvider;

import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

public class Main {
    public static void main(String[] args) {
        AppConfig config = AppConfig.fromEnv();
        System.out.println(config);

        // Declared type = interface, actual object = concrete class
        IConnectionProvider provider = new ConnectionFactory(config);

        String sql = "SELECT CURRENT_USER(), DATABASE(), COUNT(*) FROM productos";

        // try-with-resources: closes rs, st and conn automatically, in reverse order
        try (Connection conn = provider.getConnection();
             Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery(sql)) {

            if (rs.next()) {
                System.out.println("Connected as : " + rs.getString(1));
                System.out.println("Database     : " + rs.getString(2));
                System.out.println("Products     : " + rs.getInt(3));
            }

        } catch (SQLException e) {
            System.err.println("DB error [" + e.getErrorCode() + "]: " + e.getMessage());
        }
    }
}