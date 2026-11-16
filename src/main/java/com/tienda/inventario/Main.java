package com.tienda.inventario;

import com.tienda.inventario.config.AppConfig;
import com.tienda.inventario.database.ConnectionFactory;
import com.tienda.inventario.interfaces.IConnectionProvider;
import com.tienda.inventario.interfaces.IProductoRepository;
import com.tienda.inventario.model.Producto;
import com.tienda.inventario.repository.MySqlProductoRepository;

public class Main {
    public static void main(String[] args) {
        // Armar las piezas
        AppConfig config = AppConfig.fromEnv();
        IConnectionProvider provider = new ConnectionFactory(config);
        IProductoRepository productoRepo = new MySqlProductoRepository(provider);

        // 1. Listar todos: cada fila se convierte en la subclase correcta
        System.out.println("=== Todos los productos ===");
        for (Producto p : productoRepo.listarTodos()) {
            System.out.println(p);
            System.out.println("    → clase Java: " + p.getClass().getSimpleName());
        }

        // 2. Buscar por SKU: uno que existe, uno que no, y un intento de inyección SQL
        System.out.println("\n=== Búsquedas por SKU ===");
        buscarYMostrar(productoRepo, "LAC-001");
        buscarYMostrar(productoRepo, "NO-EXISTE");
        buscarYMostrar(productoRepo, "' OR '1'='1");

        // 3. Stock bajo
        System.out.println("\n=== Stock <= 35 ===");
        productoRepo.listarConStockBajo(35)
                .forEach(p -> System.out.println(p.getSku() + " → stock " + p.getStock()));
    }

    private static void buscarYMostrar(IProductoRepository repo, String sku) {
        repo.buscarPorSku(sku).ifPresentOrElse(
                p -> System.out.println("'" + sku + "' → " + p.getNombre()),
                () -> System.out.println("'" + sku + "' → no existe")
        );
    }
}