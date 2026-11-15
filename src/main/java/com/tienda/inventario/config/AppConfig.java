package com.tienda.inventario.config;

import io.github.cdimascio.dotenv.Dotenv;

/**
 * Configuración inmutable de la base de datos,
 * cargada desde el archivo .env.
 */
public record AppConfig(
        String host,
        int port,
        String dbName,
        String user,
        String password
) {

    /**
     * Metodo de fábrica: construye la configuración a partir del archivo .env.
     * Falla inmediatamente si alguna variable obligatoria no está definida.
     */
    public static AppConfig fromEnv() {
        Dotenv dotenv = Dotenv.load(); // Lanza DotenvException si no se encuentra el archivo .env

        return new AppConfig(
                required(dotenv, "DB_HOST"),
                Integer.parseInt(required(dotenv, "DB_PORT")),
                required(dotenv, "DB_NAME"),
                required(dotenv, "DB_USER"),
                required(dotenv, "DB_PASSWORD")
        );
    }

    /**
     * Obtiene una variable del archivo .env y comprueba que tenga un valor.
     * Lanza una excepción si la variable no existe o está vacía.
     */
    private static String required(Dotenv dotenv, String key) {
        String value = dotenv.get(key);
        if (value == null || value.isBlank()) {
            throw new IllegalStateException("Missing required variable in .env: " + key);
        }
        return value;
    }

    /**
     * Construye y devuelve la URL de conexión JDBC para MySQL.
     * Utiliza el servidor, puerto y nombre de la base de datos configurados.
     */
    public String jdbcUrl() {
        return "jdbc:mysql://%s:%d/%s?serverTimezone=America/Bogota"
                .formatted(host, port, dbName);
    }

    /**
     * Se sobrescribe para evitar que la contraseña aparezca en los registros
     * o en la salida de la consola.
     */
    @Override
    public String toString() {
        return "AppConfig[host=%s, port=%d, db=%s, user=%s, password=****]"
                .formatted(host, port, dbName, user);
    }
}