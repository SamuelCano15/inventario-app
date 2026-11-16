package com.tienda.inventario.exception;

import java.time.LocalDate;

/**
 * Se lanza al intentar vender o registrar un producto perecedero ya vencido.
 */
public class ProductoVencidoException extends InventarioException {

    private final String sku;
    private final LocalDate fechaVencimiento;

    public ProductoVencidoException(String sku, LocalDate fechaVencimiento) {
        super("El producto %s está vencido desde %s".formatted(sku, fechaVencimiento));
        this.sku = sku;
        this.fechaVencimiento = fechaVencimiento;
    }

    public String getSku()                  { return sku; }
    public LocalDate getFechaVencimiento()  { return fechaVencimiento; }
}