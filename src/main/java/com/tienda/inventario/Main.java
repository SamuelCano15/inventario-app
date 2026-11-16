package com.tienda.inventario;

import com.tienda.inventario.config.AppConfig;
import com.tienda.inventario.database.ConnectionFactory;
import com.tienda.inventario.exception.AccesoDatosException;
import com.tienda.inventario.exception.ConfiguracionException;
import com.tienda.inventario.interfaces.ICategoriaRepository;
import com.tienda.inventario.interfaces.IConnectionProvider;
import com.tienda.inventario.interfaces.IInventarioService;
import com.tienda.inventario.interfaces.IProductoRepository;
import com.tienda.inventario.repository.MySqlCategoriaRepository;
import com.tienda.inventario.repository.MySqlProductoRepository;
import com.tienda.inventario.service.InventarioService;
import com.tienda.inventario.ui.ConsolaUI;

import java.util.Scanner;

/**
 * Punto de entrada de la aplicación.
 * Es la "raíz de composición": el único lugar que conoce las clases concretas.
 */
public class Main {

    // Códigos de salida: 0 = todo bien; otro número = qué tipo de error ocurrió
    private static final int SALIDA_ERROR_CONFIGURACION = 1;
    private static final int SALIDA_ERROR_BASE_DATOS = 2;
    private static final int SALIDA_ERROR_INESPERADO = 99;

    public static void main(String[] args) {
        try (Scanner scanner = new Scanner(System.in)) {

            IInventarioService servicio = construirServicio();
            new ConsolaUI(servicio, scanner).iniciar();

        } catch (ConfiguracionException e) {
            System.err.println("[CONFIGURACIÓN] " + e.getMessage());
            System.exit(SALIDA_ERROR_CONFIGURACION);

        } catch (AccesoDatosException e) {
            System.err.println("[BASE DE DATOS] " + e.getMessage());
            if (e.getCause() != null) {
                System.err.println("  Causa: " + e.getCause().getMessage());
            }
            System.err.println("  Verifica que el servicio MySQL esté iniciado y que");
            System.err.println("  DB_USER y DB_PASSWORD del archivo .env sean correctos.");
            System.exit(SALIDA_ERROR_BASE_DATOS);

        } catch (RuntimeException e) {
            // Red de seguridad: un error que no esperábamos es un bug, se muestra completo
            System.err.println("[ERROR INESPERADO] " + e.getMessage());
            e.printStackTrace();
            System.exit(SALIDA_ERROR_INESPERADO);
        }
    }

    /**
     * Crea todas las piezas concretas y las conecta entre sí.
     * Para cambiar de base de datos (o usar datos de prueba), solo se cambia este método.
     */
    private static IInventarioService construirServicio() {
        AppConfig config = AppConfig.fromEnv();

        IConnectionProvider provider = new ConnectionFactory(config);
        provider.verificarConexion();   // fail fast: mejor saberlo antes de mostrar el menú

        IProductoRepository productoRepo = new MySqlProductoRepository(provider);
        ICategoriaRepository categoriaRepo = new MySqlCategoriaRepository(provider);

        return new InventarioService(productoRepo, categoriaRepo);
    }
}