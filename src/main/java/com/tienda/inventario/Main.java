package com.tienda.inventario;

import com.tienda.inventario.config.AppConfig;
import com.tienda.inventario.database.ConnectionFactory;
import com.tienda.inventario.exception.InventarioException;
import com.tienda.inventario.interfaces.IConnectionProvider;
import com.tienda.inventario.interfaces.IInventarioService;
import com.tienda.inventario.repository.MySqlCategoriaRepository;
import com.tienda.inventario.repository.MySqlProductoRepository;
import com.tienda.inventario.service.InventarioService;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.stream.IntStream;

public class Main {
    public static void main(String[] args) {
        // Armar las piezas: Main es el único que conoce las clases concretas
        AppConfig config = AppConfig.fromEnv();
        IConnectionProvider provider = new ConnectionFactory(config);
        IInventarioService servicio = new InventarioService(
                new MySqlProductoRepository(provider),
                new MySqlCategoriaRepository(provider)
        );

        // 1. Consultas
        System.out.println("=== 1. Consultas ===");
        System.out.printf("Valor del inventario: $%,.2f%n", servicio.calcularValorInventario());
        servicio.listarVencidos().forEach(p -> System.out.println("Vencido: " + p.getSku()));
        System.out.println("Buscar ' lac-001 ' → " + servicio.buscarProducto(" lac-001 ").getNombre());

        // 2. Ventas
        System.out.println("\n=== 2. Ventas ===");
        System.out.println("Venta OK → stock: " + servicio.registrarVenta("LAC-001", 5).getStock());
        intentar(() -> servicio.registrarVenta("LAC-001", 1000));
        intentar(() -> servicio.registrarVenta("LAC-099", 1));
        intentar(() -> servicio.registrarVenta("NO-EXISTE", 1));

        // 3. Ventas simultáneas: 10 hilos venden 1 unidad cada uno, AL MISMO TIEMPO
        System.out.println("\n=== 3. Ventas simultáneas ===");
        int antes = servicio.buscarProducto("LAC-001").getStock();
        IntStream.range(0, 10).parallel()
                .forEach(i -> servicio.registrarVenta("LAC-001", 1));
        int despues = servicio.buscarProducto("LAC-001").getStock();
        System.out.println("Antes: " + antes + " → después de 10 ventas paralelas: " + despues);

        // Restaurar el stock original (5 + 10 vendidas)
        System.out.println("Entrada de 15 → stock: " + servicio.registrarEntrada("LAC-001", 15).getStock());

        // 4. Registro con errores
        System.out.println("\n=== 4. Registro ===");
        intentar(() -> servicio.registrarPerecedero("LAC-050", "Queso viejo",
                new BigDecimal("8000"), 3, 1, LocalDate.of(2025, 1, 1)));
        intentar(() -> servicio.registrarNoPerecedero("ASE-050", "Escoba",
                new BigDecimal("9000"), 3, 999, null));

        // 5. Cambio de precio (y vuelta al original)
        System.out.println("\n=== 5. Precio ===");
        System.out.println("GRA-001 → $" + servicio.cambiarPrecio("GRA-001", new BigDecimal("3300")).getPrecio());
        System.out.println("GRA-001 → $" + servicio.cambiarPrecio("GRA-001", new BigDecimal("3200")).getPrecio());

        // 6. Limpieza: eliminar el vencido de prueba
        System.out.println("\n=== 6. Eliminar ===");
        servicio.eliminarProducto("LAC-099");
        System.out.println("LAC-099 eliminado");
        intentar(() -> servicio.eliminarProducto("LAC-099"));
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