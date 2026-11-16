package com.tienda.inventario.model;

import com.tienda.inventario.exception.StockInsuficienteException;

import java.math.BigDecimal;

/**
 * Base class for every product in the store.
 * Cannot be instantiated: a product is always perishable or non-perishable.
 */
public abstract class Producto {

    private Integer id;              // null until saved in the DB
    private final String sku;        // business code, never changes
    private String nombre;
    private BigDecimal precio;
    private int stock;
    private final Categoria categoria;

    // protected: only subclasses can call this constructor
    protected Producto(Integer id, String sku, String nombre,
                       BigDecimal precio, int stock, Categoria categoria) {
        if (stock < 0) {
            throw new IllegalArgumentException("El stock no puede ser negativo");
        }
        if (categoria == null) {
            throw new IllegalArgumentException("La categoría es obligatoria");
        }
        this.id = id;
        this.sku = requireText(sku, "SKU");
        setNombre(nombre);
        setPrecio(precio);
        this.stock = stock;
        this.categoria = categoria;
    }

    // ------------------------------------------------------------
    // Abstract methods: every subclass MUST implement them
    // ------------------------------------------------------------

    public abstract TipoProducto getTipo();

    /** Subclass-specific info (expiration date, warranty...). */
    protected abstract String getDetalle();

    // ------------------------------------------------------------
    // Behaviour
    // ------------------------------------------------------------

    /**
     * Contract: returns true if the product can be sold right now.
     * Subclasses may ADD conditions, but a product with no stock
     * must never be available.
     */
    public boolean estaDisponible() {
        return stock > 0;
    }

    public final void aumentarStock(int cantidad) {
        if (cantidad <= 0) {
            throw new IllegalArgumentException("La cantidad debe ser mayor que 0");
        }
        stock += cantidad;
    }

    public final void disminuirStock(int cantidad) {
        if (cantidad <= 0) {
            throw new IllegalArgumentException("La cantidad debe ser mayor que 0");
        }
        if (cantidad > stock) {
            throw new StockInsuficienteException(sku, stock, cantidad);
        }
        stock -= cantidad;
    }

    /** Called once by the repository after INSERT, with the id MySQL generated. */
    public final void asignarId(int id) {
        if (this.id != null) {
            throw new IllegalStateException("El producto ya tiene id: " + this.id);
        }
        this.id = id;
    }

    // ------------------------------------------------------------
    // Getters and validated setters
    // ------------------------------------------------------------

    public Integer getId()          { return id; }
    public String getSku()          { return sku; }
    public String getNombre()       { return nombre; }
    public BigDecimal getPrecio()   { return precio; }
    public int getStock()           { return stock; }
    public Categoria getCategoria() { return categoria; }

    public final void setNombre(String nombre) {
        this.nombre = requireText(nombre, "nombre");
    }

    public final void setPrecio(BigDecimal precio) {
        if (precio == null) {
            throw new IllegalArgumentException("El precio es obligatorio");
        }
        if (precio.signum() < 0) {
            throw new IllegalArgumentException("El precio no puede ser negativo");
        }
        this.precio = precio;
    }

    // Template Method: the structure is fixed here, the detail comes from the subclass
    @Override
    public String toString() {
        return "[%s] %-20s %-12s $%,12.2f  stock: %3d  | %s".formatted(
                sku, nombre, categoria.nombre(), precio, stock, getDetalle());
    }

    private static String requireText(String value, String campo) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("El campo " + campo + " es obligatorio");
        }
        return value.trim();
    }
}