package com.tienda.inventario.model;

/**
 * Product type. Names match EXACTLY the MySQL ENUM values,
 * so TipoProducto.valueOf(rs.getString("tipo")) works directly.
 */
public enum TipoProducto {
    PERECEDERO,
    NO_PERECEDERO
}