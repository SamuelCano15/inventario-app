package com.tienda.inventario.exception;

public class ProductoDuplicadoException extends InventarioException {

    private final String sku;

    public ProductoDuplicadoException(String sku) {
        super("Ya existe un producto con SKU: " + sku);
        this.sku = sku;
    }

    public String getSku() {
        return sku;
    }
}