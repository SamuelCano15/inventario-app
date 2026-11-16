package com.tienda.inventario;

import com.tienda.inventario.config.AppConfig;
import com.tienda.inventario.database.ConnectionFactory;
import com.tienda.inventario.exception.InventarioException;
import com.tienda.inventario.interfaces.ICategoriaRepository;
import com.tienda.inventario.interfaces.IConnectionProvider;
import com.tienda.inventario.interfaces.IProductoRepository;
import com.tienda.inventario.model.Categoria;
import com.tienda.inventario.model.Producto;
import com.tienda.inventario.model.ProductoNoPerecedero;
import com.tienda.inventario.model.ProductoPerecedero;
import com.tienda.inventario.repository.MySqlCategoriaRepository;
import com.tienda.inventario.repository.MySqlProductoRepository;

import java.math.BigDecimal;
import java.time.LocalDate;

public class Main {
    public static void main(String[] args) {
        // Armar las piezas
        AppConfig config = AppConfig.fromEnv();
        IConnectionProvider provider = new ConnectionFactory(config);
        ICategoriaRepository categoriaRepo = new MySqlCategoriaRepository(provider);
        IProductoRepository productoRepo = new MySqlProductoRepository(provider);

        // La categoría se LEE de la BD, no se inventa (su id es real)
        Categoria lacteos = categoriaRepo.listarTodas().stream()
                .filter(c -> c.nombre().equals("Lácteos"))
                .findFirst()
                .orElseThrow();

        // 1. Guardar
        System.out.println("=== 1. Guardar ===");
        Producto yogur = new ProductoPerecedero(null, "LAC-002", "Yogur de fresa",
                new BigDecimal("3200"), 12, lacteos, LocalDate.of(2026, 12, 20));
        System.out.println("Antes de guardar  → id: " + yogur.getId());
        productoRepo.guardar(yogur);
        System.out.println("Después de guardar → id: " + yogur.getId());

        // 2. Leerlo de vuelta desde la BD
        System.out.println("\n=== 2. Leer desde la BD ===");
        productoRepo.buscarPorSku("LAC-002").ifPresent(System.out::println);

        // 3. Errores esperados
        System.out.println("\n=== 3. Errores esperados ===");
        intentar(() -> productoRepo.guardar(
                new ProductoPerecedero(null, "LAC-002", "Yogur repetido",
                        new BigDecimal("1000"), 1, lacteos, LocalDate.of(2026, 12, 31))));
        intentar(() -> productoRepo.guardar(
                new ProductoNoPerecedero(null, "TEST-999", "Categoría fantasma",
                        new BigDecimal("1000"), 1, new Categoria(999, "Fantasma"), null)));
        intentar(() -> productoRepo.actualizar(
                new ProductoNoPerecedero(null, "FANTASMA-01", "No existe",
                        new BigDecimal("1000"), 1, lacteos, null)));

        // 4. Actualizar: se cambia el objeto en memoria y luego se guarda
        System.out.println("\n=== 4. Actualizar ===");
        yogur.setPrecio(new BigDecimal("3800"));
        yogur.aumentarStock(10);
        productoRepo.actualizar(yogur);
        productoRepo.buscarPorSku("LAC-002").ifPresent(p ->
                System.out.println("En BD → precio: " + p.getPrecio() + ", stock: " + p.getStock()));

        // 5. Eliminar (deja la BD como estaba)
        System.out.println("\n=== 5. Eliminar ===");
        System.out.println("Primera vez: " + productoRepo.eliminar("LAC-002"));
        System.out.println("Segunda vez: " + productoRepo.eliminar("LAC-002"));
    }

    /** Ejecuta una acción que DEBE fallar y muestra qué excepción lanzó. */
    private static void intentar(Runnable accion) {
        try {
            accion.run();
            System.out.println("⚠️ No falló, ¡y debería haber fallado!");
        } catch (InventarioException e) {
            System.out.println(e.getClass().getSimpleName() + ": " + e.getMessage());
        }
    }
}