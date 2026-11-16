package com.tienda.inventario.exception;

public class ProductoNoEncontradoException extends InventarioException {

    private final String sku;

    public ProductoNoEncontradoException(String sku) {
        super("No existe un producto con SKU: " + sku);
        this.sku = sku;
    }

    public String getSku() {
        return sku;
    }
}