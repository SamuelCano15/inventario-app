package com.tienda.inventario.config;

import com.tienda.inventario.exception.ConfiguracionException;
import io.github.cdimascio.dotenv.Dotenv;
import io.github.cdimascio.dotenv.DotenvException;

/**
 * Configuración inmutable de la base de datos, leída del archivo .env.
 */
public record AppConfig(
        String host,
        int port,
        String dbName,
        String user,
        String password
) {

    /**
     * Construye la configuración a partir del archivo .env.
     * Falla rápido y con un mensaje claro si falta el archivo o alguna variable.
     */
    public static AppConfig fromEnv() {
        Dotenv dotenv;
        try {
            dotenv = Dotenv.load();
        } catch (DotenvException e) {
            // Se traduce el error de la librería a uno propio y entendible
            throw new ConfiguracionException(
                    "No se encontró el archivo .env en la carpeta del proyecto. "
                            + "Copia .env.example como .env y completa tus datos.", e);
        }

        return new AppConfig(
                requerida(dotenv, "DB_HOST"),
                leerPuerto(dotenv),
                requerida(dotenv, "DB_NAME"),
                requerida(dotenv, "DB_USER"),
                requerida(dotenv, "DB_PASSWORD")
        );
    }

    private static String requerida(Dotenv dotenv, String clave) {
        String valor = dotenv.get(clave);
        if (valor == null || valor.isBlank()) {
            throw new ConfiguracionException(
                    "Falta la variable " + clave + " en el archivo .env (revisa .env.example)");
        }
        return valor;
    }

    private static int leerPuerto(Dotenv dotenv) {
        String valor = requerida(dotenv, "DB_PORT");
        try {
            return Integer.parseInt(valor);
        } catch (NumberFormatException e) {
            throw new ConfiguracionException(
                    "DB_PORT debe ser un número (ej. 3306), pero vale: " + valor, e);
        }
    }

    public String jdbcUrl() {
        return "jdbc:mysql://%s:%d/%s?serverTimezone=America/Bogota"
                .formatted(host, port, dbName);
    }

    /**
     * Se sobrescribe para que la contraseña nunca aparezca en la consola ni en los logs.
     */
    @Override
    public String toString() {
        return "AppConfig[host=%s, port=%d, db=%s, user=%s, password=****]"
                .formatted(host, port, dbName, user);
    }
}