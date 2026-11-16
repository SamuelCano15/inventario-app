package com.tienda.inventario.exception;

public class CategoriaNoEncontradaException extends InventarioException {

    public CategoriaNoEncontradaException(int categoriaId) {
        super("No existe una categoría con id: " + categoriaId);
    }
}