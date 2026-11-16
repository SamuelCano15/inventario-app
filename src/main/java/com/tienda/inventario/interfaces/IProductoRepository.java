package com.tienda.inventario.interfaces;

import com.tienda.inventario.model.Producto;

import java.util.List;
import java.util.Optional;

/**
 * Contrato de persistencia para los productos.
 * Las implementaciones traducen los errores de bajo nivel a las excepciones
 * propias de la aplicación:
 * (AccesoDatosException, ProductoDuplicadoException, CategoriaNoEncontradaException).
 */
public interface IProductoRepository {

    // ---------------- Lectura ----------------

    /** Todos los productos ordenados por SKU. Nunca devuelve null (puede estar vacío). */
    List<Producto> listarTodos();

    /** El producto con ese SKU, o Optional.empty() si no existe. */
    Optional<Producto> buscarPorSku(String sku);

    /** Productos cuyo stock es menor o igual al umbral indicado. */
    List<Producto> listarConStockBajo(int umbral);

    // ---------------- Escritura ----------------

    /**
     * Inserta un producto NUEVO y le asigna el ID generado por la base de datos.
     *
     * @throws com.tienda.inventario.exception.ProductoDuplicadoException
     *         si el SKU ya existe.
     * @throws com.tienda.inventario.exception.CategoriaNoEncontradaException
     *         si la categoría no existe.
     */
    void guardar(Producto producto);

    /**
     * Actualiza el nombre y el precio de un producto EXISTENTE (lo busca por SKU).
     * NO modifica el stock: para eso usa aumentarStock / descontarStock.
     *
     * @throws com.tienda.inventario.exception.ProductoNoEncontradoException si el SKU no existe
     */
    void actualizar(Producto producto);

    /**
     * Elimina el producto que tiene ese SKU.
     *
     * @return true si fue eliminado, false si no existía.
     */
    boolean eliminar(String sku);

    // ---------------- Stock (operaciones atómicas) ----------------

    /**
     * Suma la cantidad al stock directamente en la BD (stock = stock + cantidad).
     *
     * @return true si se actualizó, false si el SKU no existe
     */
    boolean aumentarStock(String sku, int cantidad);

    /**
     * Resta la cantidad del stock solo si alcanza (stock = stock - cantidad).
     * Es atómica: segura aunque varias ventas ocurran al mismo tiempo.
     *
     * @return true si se descontó, false si el SKU no existe o el stock no alcanza
     */
    boolean descontarStock(String sku, int cantidad);
}