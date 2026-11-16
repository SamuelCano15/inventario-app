package com.tienda.inventario.service;

import com.tienda.inventario.exception.CategoriaNoEncontradaException;
import com.tienda.inventario.exception.ProductoNoEncontradoException;
import com.tienda.inventario.exception.ProductoVencidoException;
import com.tienda.inventario.exception.StockInsuficienteException;
import com.tienda.inventario.interfaces.ICategoriaRepository;
import com.tienda.inventario.interfaces.IInventarioService;
import com.tienda.inventario.interfaces.IProductoRepository;
import com.tienda.inventario.model.Categoria;
import com.tienda.inventario.model.Producto;
import com.tienda.inventario.model.ProductoNoPerecedero;
import com.tienda.inventario.model.ProductoPerecedero;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/**
 * Implementación de los casos de uso del inventario.
 * Orquesta el modelo y los repositorios, y aplica las reglas del negocio.
 * No conoce SQL ni MySQL: solo trabaja con las interfaces de los repositorios.
 */
public class InventarioService implements IInventarioService {

    private final IProductoRepository productoRepo;
    private final ICategoriaRepository categoriaRepo;

    // Recibe las interfaces (principio D): funciona con MySQL, con memoria o con lo que sea
    public InventarioService(IProductoRepository productoRepo,
                             ICategoriaRepository categoriaRepo) {
        this.productoRepo = productoRepo;
        this.categoriaRepo = categoriaRepo;
    }

    // ============================================================
    // Consultas
    // ============================================================

    @Override
    public List<Producto> listarProductos() {
        return productoRepo.listarTodos();
    }

    @Override
    public Producto buscarProducto(String sku) {
        String skuNormalizado = normalizarSku(sku);
        // El repositorio responde "puede no existir"; para el caso de uso es un error
        return productoRepo.buscarPorSku(skuNormalizado)
                .orElseThrow(() -> new ProductoNoEncontradoException(skuNormalizado));
    }

    @Override
    public List<Categoria> listarCategorias() {
        return categoriaRepo.listarTodas();
    }

    @Override
    public List<Producto> listarStockBajo(int umbral) {
        if (umbral < 0) {
            throw new IllegalArgumentException("El umbral no puede ser negativo");
        }
        return productoRepo.listarConStockBajo(umbral);
    }

    @Override
    public List<Producto> listarVencidos() {
        // Pattern matching dentro del filtro: solo los perecederos pueden vencerse
        return productoRepo.listarTodos().stream()
                .filter(p -> p instanceof ProductoPerecedero perecedero && perecedero.estaVencido())
                .toList();
    }

    @Override
    public BigDecimal calcularValorInventario() {
        // Para cada producto calcula precio × stock y luego suma todo, empezando en 0
        return productoRepo.listarTodos().stream()
                .map(p -> p.getPrecio().multiply(BigDecimal.valueOf(p.getStock())))
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    // ============================================================
    // Registro de productos
    // ============================================================

    @Override
    public Producto registrarPerecedero(String sku, String nombre, BigDecimal precio,
                                        int stockInicial, int categoriaId,
                                        LocalDate fechaVencimiento) {
        Categoria categoria = obtenerCategoria(categoriaId);

        // El constructor valida los datos (precio, stock, fecha no nula...)
        ProductoPerecedero producto = new ProductoPerecedero(
                null, normalizarSku(sku), nombre, precio, stockInicial, categoria, fechaVencimiento);

        // Regla de negocio: no se recibe mercancía que ya llegó vencida
        if (producto.estaVencido()) {
            throw new ProductoVencidoException(producto.getSku(), fechaVencimiento);
        }

        productoRepo.guardar(producto);   // aquí se le asigna el id
        return producto;
    }

    @Override
    public Producto registrarNoPerecedero(String sku, String nombre, BigDecimal precio,
                                          int stockInicial, int categoriaId,
                                          Integer mesesGarantia) {
        Categoria categoria = obtenerCategoria(categoriaId);

        ProductoNoPerecedero producto = new ProductoNoPerecedero(
                null, normalizarSku(sku), nombre, precio, stockInicial, categoria, mesesGarantia);

        productoRepo.guardar(producto);
        return producto;
    }

    // ============================================================
    // Movimientos de inventario
    // ============================================================

    @Override
    public Producto registrarEntrada(String sku, int cantidad) {
        validarCantidad(cantidad);
        String skuNormalizado = normalizarSku(sku);

        if (!productoRepo.aumentarStock(skuNormalizado, cantidad)) {
            throw new ProductoNoEncontradoException(skuNormalizado);
        }
        // Se vuelve a leer para devolver el stock REAL de la BD
        return buscarProducto(skuNormalizado);
    }

    @Override
    public Producto registrarVenta(String sku, int cantidad) {
        validarCantidad(cantidad);

        // 1. ¿Existe? (si no, buscarProducto lanza ProductoNoEncontradoException)
        Producto producto = buscarProducto(sku);

        // 2. Regla de negocio: no se vende un producto vencido
        if (producto instanceof ProductoPerecedero perecedero && perecedero.estaVencido()) {
            throw new ProductoVencidoException(producto.getSku(), perecedero.getFechaVencimiento());
        }

        // 3. Descuento atómico en la BD (seguro ante ventas simultáneas)
        if (!productoRepo.descontarStock(producto.getSku(), cantidad)) {
            // No alcanzó: se relee para informar el stock real en este momento
            Producto actual = buscarProducto(producto.getSku());
            throw new StockInsuficienteException(actual.getSku(), actual.getStock(), cantidad);
        }

        return buscarProducto(producto.getSku());
    }

    // ============================================================
    // Mantenimiento
    // ============================================================

    @Override
    public Producto cambiarPrecio(String sku, BigDecimal nuevoPrecio) {
        Producto producto = buscarProducto(sku);
        producto.setPrecio(nuevoPrecio);   // el modelo valida que no sea negativo
        productoRepo.actualizar(producto);   // solo toca nombre y precio, no el stock
        return producto;
    }

    @Override
    public void eliminarProducto(String sku) {
        String skuNormalizado = normalizarSku(sku);
        if (!productoRepo.eliminar(skuNormalizado)) {
            throw new ProductoNoEncontradoException(skuNormalizado);
        }
    }

    // ============================================================
    // Métodos auxiliares privados
    // ============================================================

    private Categoria obtenerCategoria(int categoriaId) {
        return categoriaRepo.buscarPorId(categoriaId)
                .orElseThrow(() -> new CategoriaNoEncontradaException(categoriaId));
    }

    private static void validarCantidad(int cantidad) {
        if (cantidad <= 0) {
            throw new IllegalArgumentException("La cantidad debe ser mayor que 0");
        }
    }

    /** Quita espacios y pasa a mayúsculas: " lac-001 " → "LAC-001". */
    private static String normalizarSku(String sku) {
        if (sku == null || sku.isBlank()) {
            throw new IllegalArgumentException("El SKU es obligatorio");
        }
        return sku.trim().toUpperCase();
    }
}