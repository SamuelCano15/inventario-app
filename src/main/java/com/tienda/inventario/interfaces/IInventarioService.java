package com.tienda.inventario.interfaces;

import com.tienda.inventario.model.Categoria;
import com.tienda.inventario.model.Producto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/**
 * Casos de uso del inventario de la tienda.
 * Es la única puerta de entrada que usa la interfaz de usuario:
 * la UI nunca habla directamente con los repositorios.
 *
 * Todos los errores de negocio se reportan con subclases de InventarioException.
 */
public interface IInventarioService {

    // ============================================================
    // Consultas
    // ============================================================

    /** Todos los productos, ordenados por SKU. */
    List<Producto> listarProductos();

    /**
     * Busca un producto por su SKU.
     *
     * @throws com.tienda.inventario.exception.ProductoNoEncontradoException si no existe
     */
    Producto buscarProducto(String sku);

    /** Todas las categorías disponibles, ordenadas por nombre. */
    List<Categoria> listarCategorias();

    /** Productos cuyo stock es menor o igual al umbral (para saber qué reabastecer). */
    List<Producto> listarStockBajo(int umbral);

    /** Productos perecederos cuya fecha de vencimiento ya pasó. */
    List<Producto> listarVencidos();

    /** Suma de (precio × stock) de todos los productos. */
    BigDecimal calcularValorInventario();

    // ============================================================
    // Registro de productos
    // ============================================================

    /**
     * Registra un producto perecedero nuevo.
     *
     * @return el producto creado, ya con el id asignado por la BD
     * @throws com.tienda.inventario.exception.CategoriaNoEncontradaException si la categoría no existe
     * @throws com.tienda.inventario.exception.ProductoDuplicadoException     si el SKU ya existe
     */
    Producto registrarPerecedero(String sku, String nombre, BigDecimal precio,
                                 int stockInicial, int categoriaId,
                                 LocalDate fechaVencimiento);

    /**
     * Registra un producto no perecedero nuevo.
     *
     * @param mesesGarantia puede ser null si el producto no tiene garantía
     * @return el producto creado, ya con el id asignado por la BD
     * @throws com.tienda.inventario.exception.CategoriaNoEncontradaException si la categoría no existe
     * @throws com.tienda.inventario.exception.ProductoDuplicadoException     si el SKU ya existe
     */
    Producto registrarNoPerecedero(String sku, String nombre, BigDecimal precio,
                                   int stockInicial, int categoriaId,
                                   Integer mesesGarantia);

    // ============================================================
    // Movimientos de inventario
    // ============================================================

    /**
     * Registra la llegada de mercancía (aumenta el stock).
     *
     * @return el producto con el stock actualizado
     * @throws com.tienda.inventario.exception.ProductoNoEncontradoException si no existe
     */
    Producto registrarEntrada(String sku, int cantidad);

    /**
     * Registra una venta (disminuye el stock). Es segura ante ventas simultáneas.
     *
     * @return el producto con el stock actualizado
     * @throws com.tienda.inventario.exception.ProductoNoEncontradoException si no existe
     * @throws com.tienda.inventario.exception.StockInsuficienteException    si no hay suficiente
     */
    Producto registrarVenta(String sku, int cantidad);

    // ============================================================
    // Mantenimiento
    // ============================================================

    /**
     * Cambia el precio de un producto.
     *
     * @throws com.tienda.inventario.exception.ProductoNoEncontradoException si no existe
     */
    Producto cambiarPrecio(String sku, BigDecimal nuevoPrecio);

    /**
     * Elimina un producto.
     *
     * @throws com.tienda.inventario.exception.ProductoNoEncontradoException si no existe
     */
    void eliminarProducto(String sku);
}