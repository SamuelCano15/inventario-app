package com.tienda.inventario.model;

import java.math.BigDecimal;
import java.util.Optional;

public class ProductoNoPerecedero extends Producto {

    private final Integer mesesGarantia;   // null = no warranty

    public ProductoNoPerecedero(Integer id, String sku, String nombre, BigDecimal precio,
                                int stock, Categoria categoria, Integer mesesGarantia) {
        super(id, sku, nombre, precio, stock, categoria);
        if (mesesGarantia != null && mesesGarantia <= 0) {
            throw new IllegalArgumentException("Los meses de garantía deben ser mayores que 0");
        }
        this.mesesGarantia = mesesGarantia;
    }

    /** Optional makes "may have no warranty" explicit in the method signature. */
    public Optional<Integer> getMesesGarantia() {
        return Optional.ofNullable(mesesGarantia);
    }

    @Override
    public TipoProducto getTipo() {
        return TipoProducto.NO_PERECEDERO;
    }

    @Override
    protected String getDetalle() {
        return mesesGarantia == null
                ? "Sin garantía"
                : "Garantía: %d meses".formatted(mesesGarantia);
    }
}