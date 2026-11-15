package com.tienda.inventario.model;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;

public class ProductoPerecedero extends Producto {

    private final LocalDate fechaVencimiento;

    public ProductoPerecedero(Integer id, String sku, String nombre, BigDecimal precio,
                              int stock, Categoria categoria, LocalDate fechaVencimiento) {
        super(id, sku, nombre, precio, stock, categoria);   // parent validates its part
        if (fechaVencimiento == null) {
            throw new IllegalArgumentException(
                    "Un producto perecedero necesita fecha de vencimiento");
        }
        this.fechaVencimiento = fechaVencimiento;
    }

    public LocalDate getFechaVencimiento() {
        return fechaVencimiento;
    }

    public boolean estaVencido() {
        return LocalDate.now().isAfter(fechaVencimiento);
    }

    public long diasParaVencer() {
        return ChronoUnit.DAYS.between(LocalDate.now(), fechaVencimiento);
    }

    @Override
    public TipoProducto getTipo() {
        return TipoProducto.PERECEDERO;
    }

    // Adds a condition, keeps the parent's: respects the contract (Liskov)
    @Override
    public boolean estaDisponible() {
        return super.estaDisponible() && !estaVencido();
    }

    @Override
    protected String getDetalle() {
        if (estaVencido()) {
            return "VENCIDO desde " + fechaVencimiento;
        }
        return "Vence: %s (%d días)".formatted(fechaVencimiento, diasParaVencer());
    }
}