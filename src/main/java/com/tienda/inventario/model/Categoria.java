package com.tienda.inventario.model;

/**
 * Product category. Immutable.
 * id may be null for a category that hasn't been saved yet.
 */
public record Categoria(Integer id, String nombre) {

    // Compact constructor: runs validation before fields are assigned
    public Categoria {
        if (nombre == null || nombre.isBlank()) {
            throw new IllegalArgumentException("El nombre de la categoría es obligatorio");
        }
        nombre = nombre.trim();
    }
}