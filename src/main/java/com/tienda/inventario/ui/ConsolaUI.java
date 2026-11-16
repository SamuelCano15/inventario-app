package com.tienda.inventario.ui;

import com.tienda.inventario.exception.AccesoDatosException;
import com.tienda.inventario.exception.InventarioException;
import com.tienda.inventario.exception.StockInsuficienteException;
import com.tienda.inventario.interfaces.IInventarioService;
import com.tienda.inventario.model.Categoria;
import com.tienda.inventario.model.Producto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.List;
import java.util.Scanner;

/**
 * Interfaz de usuario por consola.
 * Responsabilidad: mostrar información y leer lo que escribe el usuario.
 * No contiene reglas de negocio: todo lo delega en IInventarioService.
 */
public class ConsolaUI {

    private final IInventarioService servicio;
    private final Scanner scanner;

    public ConsolaUI(IInventarioService servicio, Scanner scanner) {
        this.servicio = servicio;
        this.scanner = scanner;
    }

    // ============================================================
    // Ciclo principal
    // ============================================================

    /** Muestra el menú una y otra vez hasta que el usuario elija salir. */
    public void iniciar() {
        System.out.println("=== Inventario de la tienda ===");

        boolean continuar = true;
        while (continuar) {
            mostrarMenu();
            int opcion = leerEntero("Elige una opción: ");
            continuar = ejecutarOpcion(opcion);
        }
        System.out.println("¡Hasta luego!");
    }

    private void mostrarMenu() {
        System.out.println("""

                ------------------ MENÚ ------------------
                  1. Listar productos
                  2. Buscar producto
                  3. Registrar producto
                  4. Registrar entrada de mercancía
                  5. Registrar venta
                  6. Cambiar precio
                  7. Eliminar producto
                  8. Productos con stock bajo
                  9. Productos vencidos
                 10. Valor total del inventario
                  0. Salir
                ------------------------------------------""");
    }

    /**
     * Ejecuta la opción elegida dentro de un único manejo de errores.
     *
     * @return false si el usuario quiere salir
     */
    private boolean ejecutarOpcion(int opcion) {
        try {
            switch (opcion) {
                case 1 -> listarProductos();
                case 2 -> buscarProducto();
                case 3 -> registrarProducto();
                case 4 -> registrarEntrada();
                case 5 -> registrarVenta();
                case 6 -> cambiarPrecio();
                case 7 -> eliminarProducto();
                case 8 -> listarStockBajo();
                case 9 -> listarVencidos();
                case 10 -> mostrarValorInventario();
                case 0 -> {
                    return false;
                }
                default -> System.out.println("[!] Opción no válida.");
            }
        } catch (AccesoDatosException e) {
            // Error técnico: mensaje genérico para el usuario + detalle para quien depura
            System.out.println("[ERROR] No se pudo acceder a la base de datos. Intenta de nuevo.");
            if (e.getCause() != null) {
                System.out.println("        Detalle técnico: " + e.getCause().getMessage());
            }
        } catch (InventarioException e) {
            // Error de negocio: su mensaje ya está pensado para el usuario
            System.out.println("[ERROR] " + e.getMessage());
        } catch (IllegalArgumentException e) {
            // Dato que el modelo o el servicio rechazaron
            System.out.println("[DATO INVÁLIDO] " + e.getMessage());
        }
        return true;
    }

    // ============================================================
    // Opciones del menú
    // ============================================================

    private void listarProductos() {
        imprimirProductos(servicio.listarProductos());
    }

    private void buscarProducto() {
        String sku = leerTexto("SKU: ");
        imprimirDetalle(servicio.buscarProducto(sku));
    }

    private void registrarProducto() {
        System.out.println("Tipo de producto:  1. Perecedero   2. No perecedero");
        int tipo = leerEnteroEnRango("Elige el tipo: ", 1, 2);

        String sku = leerTexto("SKU (ej. LAC-002): ");
        String nombre = leerTexto("Nombre: ");
        BigDecimal precio = leerDecimal("Precio (ej. 4500 o 4500,50): ");
        int stock = leerEnteroEnRango("Stock inicial: ", 0, Integer.MAX_VALUE);
        int categoriaId = elegirCategoria();

        Producto creado;
        if (tipo == 1) {
            LocalDate vence = leerFecha("Fecha de vencimiento (AAAA-MM-DD): ");
            creado = servicio.registrarPerecedero(sku, nombre, precio, stock, categoriaId, vence);
        } else {
            Integer garantia = leerGarantiaOpcional();
            creado = servicio.registrarNoPerecedero(sku, nombre, precio, stock, categoriaId, garantia);
        }

        System.out.println("[OK] Producto registrado con id " + creado.getId() + ":");
        System.out.println(creado);
    }

    private void registrarEntrada() {
        String sku = leerTexto("SKU: ");
        int cantidad = leerEnteroEnRango("Cantidad que llegó: ", 1, Integer.MAX_VALUE);

        Producto actualizado = servicio.registrarEntrada(sku, cantidad);
        System.out.println("[OK] Nuevo stock de " + actualizado.getSku() + ": " + actualizado.getStock());
    }

    private void registrarVenta() {
        String sku = leerTexto("SKU: ");
        int cantidad = leerEnteroEnRango("Cantidad a vender: ", 1, Integer.MAX_VALUE);

        try {
            Producto actualizado = servicio.registrarVenta(sku, cantidad);
            System.out.println("[OK] Venta registrada. Stock restante: " + actualizado.getStock());

        } catch (StockInsuficienteException e) {
            // Aquí se ve el valor de guardar datos en la excepción: usamos getDisponible()
            System.out.println("[ERROR] " + e.getMessage());
            int disponible = e.getDisponible();
            if (disponible > 0 && leerSiNo("¿Vender las " + disponible + " unidades disponibles? (s/n): ")) {
                Producto actualizado = servicio.registrarVenta(sku, disponible);
                System.out.println("[OK] Venta registrada. Stock restante: " + actualizado.getStock());
            }
        }
    }

    private void cambiarPrecio() {
        String sku = leerTexto("SKU: ");
        Producto producto = servicio.buscarProducto(sku);
        System.out.printf("Precio actual: $%,.2f%n", producto.getPrecio());

        BigDecimal nuevoPrecio = leerDecimal("Nuevo precio: ");
        Producto actualizado = servicio.cambiarPrecio(sku, nuevoPrecio);
        System.out.printf("[OK] Nuevo precio de %s: $%,.2f%n", actualizado.getSku(), actualizado.getPrecio());
    }

    private void eliminarProducto() {
        String sku = leerTexto("SKU: ");
        Producto producto = servicio.buscarProducto(sku);   // falla si no existe
        System.out.println(producto);

        // Borrar no se puede deshacer: siempre se pide confirmación
        if (leerSiNo("¿Seguro que quieres eliminarlo? (s/n): ")) {
            servicio.eliminarProducto(sku);
            System.out.println("[OK] Producto eliminado.");
        } else {
            System.out.println("Operación cancelada.");
        }
    }

    private void listarStockBajo() {
        int umbral = leerEnteroEnRango("Mostrar productos con stock menor o igual a: ", 0, Integer.MAX_VALUE);
        imprimirProductos(servicio.listarStockBajo(umbral));
    }

    private void listarVencidos() {
        imprimirProductos(servicio.listarVencidos());
    }

    private void mostrarValorInventario() {
        System.out.printf("Valor total del inventario: $%,.2f%n", servicio.calcularValorInventario());
    }

    /** Muestra las categorías y pide el id de una. Que exista lo valida el servicio. */
    private int elegirCategoria() {
        System.out.println("Categorías disponibles:");
        for (Categoria c : servicio.listarCategorias()) {
            System.out.printf("  %d. %s%n", c.id(), c.nombre());
        }
        return leerEntero("Id de la categoría: ");
    }

    // ============================================================
    // Impresión
    // ============================================================

    private void imprimirProductos(List<Producto> productos) {
        if (productos.isEmpty()) {
            System.out.println("(No hay productos para mostrar)");
            return;
        }
        productos.forEach(System.out::println);
        System.out.println("Total: " + productos.size() + " producto(s)");
    }

    private void imprimirDetalle(Producto producto) {
        System.out.println(producto);
        System.out.println("  Tipo: " + producto.getTipo()
                + " | Disponible para venta: " + (producto.estaDisponible() ? "Sí" : "No"));
    }

    // ============================================================
    // Lectura de datos: convierten texto en tipos y repiten hasta que sea válido
    // ============================================================

    /** Lee un texto no vacío. */
    private String leerTexto(String mensaje) {
        while (true) {
            System.out.print(mensaje);
            String texto = scanner.nextLine().trim();
            if (!texto.isEmpty()) {
                return texto;
            }
            System.out.println("  [!] Este campo es obligatorio.");
        }
    }

    /** Lee un número entero. Si el usuario escribe "abc", vuelve a preguntar. */
    private int leerEntero(String mensaje) {
        while (true) {
            String texto = leerTexto(mensaje);
            try {
                return Integer.parseInt(texto);
            } catch (NumberFormatException e) {
                System.out.println("  [!] Escribe un número entero (ej. 5).");
            }
        }
    }

    private int leerEnteroEnRango(String mensaje, int minimo, int maximo) {
        while (true) {
            int numero = leerEntero(mensaje);
            if (numero >= minimo && numero <= maximo) {
                return numero;
            }
            System.out.printf("  [!] Debe estar entre %d y %d.%n", minimo, maximo);
        }
    }

    /**
     * Lee un valor con decimales al estilo colombiano: coma para decimales y sin
     * separador de miles. Se rechaza el punto porque "4.500" es ambiguo:
     * para Java sería 4,5 y no cuatro mil quinientos.
     */
    private BigDecimal leerDecimal(String mensaje) {
        while (true) {
            String texto = leerTexto(mensaje);
            if (texto.contains(".")) {
                System.out.println("  [!] No uses puntos. Escribe 4500 o, con decimales, 4500,50.");
                continue;
            }
            try {
                BigDecimal valor = new BigDecimal(texto.replace(",", "."));
                if (valor.signum() >= 0) {
                    return valor;
                }
                System.out.println("  [!] No puede ser negativo.");
            } catch (NumberFormatException e) {
                System.out.println("  [!] Escribe un número válido (ej. 4500 o 4500,50).");
            }
        }
    }

    /** Lee una fecha en formato ISO (AAAA-MM-DD). */
    private LocalDate leerFecha(String mensaje) {
        while (true) {
            String texto = leerTexto(mensaje);
            try {
                return LocalDate.parse(texto);
            } catch (DateTimeParseException e) {
                System.out.println("  [!] Usa el formato AAAA-MM-DD (ej. 2026-12-31).");
            }
        }
    }

    /** Lee los meses de garantía. Enter vacío significa "sin garantía" (null). */
    private Integer leerGarantiaOpcional() {
        while (true) {
            System.out.print("Meses de garantía (Enter si no tiene): ");
            String texto = scanner.nextLine().trim();
            if (texto.isEmpty()) {
                return null;
            }
            try {
                int meses = Integer.parseInt(texto);
                if (meses > 0) {
                    return meses;
                }
                System.out.println("  [!] Debe ser mayor que 0.");
            } catch (NumberFormatException e) {
                System.out.println("  [!] Escribe un número entero o deja vacío.");
            }
        }
    }

    private boolean leerSiNo(String mensaje) {
        while (true) {
            String respuesta = leerTexto(mensaje).toLowerCase();
            switch (respuesta) {
                case "s", "si", "sí" -> { return true; }
                case "n", "no" -> { return false; }
                default -> System.out.println("  [!] Responde s o n.");
            }
        }
    }
}