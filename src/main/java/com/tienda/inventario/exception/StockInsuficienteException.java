package com.tienda.inventario.exception;

public class StockInsuficienteException extends InventarioException {

    private final String sku;
    private final int disponible;
    private final int solicitado;

    public StockInsuficienteException(String sku, int disponible, int solicitado) {
        super("Stock insuficiente para %s: hay %d, se pidieron %d"
                .formatted(sku, disponible, solicitado));
        this.sku = sku;
        this.disponible = disponible;
        this.solicitado = solicitado;
    }

    public String getSku()      { return sku; }
    public int getDisponible()  { return disponible; }
    public int getSolicitado()  { return solicitado; }
}