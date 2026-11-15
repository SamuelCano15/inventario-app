package com.tienda.inventario;

import com.tienda.inventario.model.Categoria;
import com.tienda.inventario.model.Producto;
import com.tienda.inventario.model.ProductoNoPerecedero;
import com.tienda.inventario.model.ProductoPerecedero;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public class Main {
    public static void main(String[] args) {
        Categoria lacteos = new Categoria(1, "Lácteos");
        Categoria electronica = new Categoria(3, "Electrónica");

        // Polymorphism: a List<Producto> holds both subclasses
        List<Producto> productos = List.of(
                new ProductoPerecedero(null, "LAC-001", "Leche entera 1L",
                        new BigDecimal("4500"), 30, lacteos, LocalDate.of(2026, 12, 1)),
                new ProductoPerecedero(null, "LAC-002", "Yogur",
                        new BigDecimal("3000"), 5, lacteos, LocalDate.of(2026, 1, 10)),
                new ProductoNoPerecedero(null, "ELE-001", "Audífonos básicos",
                        new BigDecimal("35000"), 10, electronica, 6)
        );

        System.out.println("=== Productos ===");
        for (Producto p : productos) {
            // Same call, different behaviour depending on the real class
            System.out.println(p + "  | disponible: " + p.estaDisponible());
        }

        System.out.println("\n=== Validaciones ===");

        // 1) Perishable without expiration date
        try {
            new ProductoPerecedero(null, "LAC-003", "Kumis",
                    new BigDecimal("2500"), 5, lacteos, null);
        } catch (IllegalArgumentException e) {
            System.out.println("Rechazado: " + e.getMessage());
        }

        // 2) Negative price
        try {
            new ProductoNoPerecedero(null, "ASE-002", "Shampoo",
                    new BigDecimal("-100"), 5, electronica, null);
        } catch (IllegalArgumentException e) {
            System.out.println("Rechazado: " + e.getMessage());
        }

        // 3) Selling more than available
        Producto leche = productos.get(0);
        try {
            leche.disminuirStock(100);
        } catch (IllegalStateException e) {
            System.out.println("Rechazado: " + e.getMessage());
        }

        // 4) Valid sale
        leche.disminuirStock(5);
        System.out.println("Venta OK → stock de leche ahora: " + leche.getStock());

        // 5) Uncomment to see it: abstract class can't be instantiated (won't compile)
        // Producto p = new Producto(null, "X", "X", BigDecimal.ONE, 1, lacteos);
    }
}