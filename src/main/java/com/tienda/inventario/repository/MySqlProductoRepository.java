package com.tienda.inventario.repository;

import com.tienda.inventario.exception.AccesoDatosException;
import com.tienda.inventario.interfaces.IConnectionProvider;
import com.tienda.inventario.interfaces.IProductoRepository;
import com.tienda.inventario.model.Categoria;
import com.tienda.inventario.model.Producto;
import com.tienda.inventario.model.ProductoNoPerecedero;
import com.tienda.inventario.model.ProductoPerecedero;
import com.tienda.inventario.model.TipoProducto;

import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * Implementación de IProductoRepository usando MySQL y JDBC.
 * Convierte cada fila de la tabla productos en la subclase correcta
 * según la columna discriminadora "tipo".
 */
public class MySqlProductoRepository implements IProductoRepository {

    // SELECT común a todas las lecturas: productos + su categoría.
    // Los alias (AS) evitan la ambigüedad, porque ambas tablas tienen "id" y "nombre".
    private static final String SQL_SELECT_BASE = """
            SELECT p.id, p.sku, p.nombre, p.precio, p.stock, p.tipo,
                   p.fecha_vencimiento, p.meses_garantia,
                   c.id     AS categoria_id,
                   c.nombre AS categoria_nombre
            FROM productos p
            JOIN categorias c ON c.id = p.categoria_id
            """;

    private static final String SQL_LISTAR_TODOS =
            SQL_SELECT_BASE + "ORDER BY p.sku";

    private static final String SQL_BUSCAR_POR_SKU =
            SQL_SELECT_BASE + "WHERE p.sku = ?";

    private static final String SQL_STOCK_BAJO =
            SQL_SELECT_BASE + "WHERE p.stock <= ? ORDER BY p.stock, p.sku";

    private final IConnectionProvider connectionProvider;

    public MySqlProductoRepository(IConnectionProvider connectionProvider) {
        this.connectionProvider = connectionProvider;
    }

    // ============================================================
    // Lectura
    // ============================================================

    @Override
    public List<Producto> listarTodos() {
        return consultar(SQL_LISTAR_TODOS);
    }

    @Override
    public Optional<Producto> buscarPorSku(String sku) {
        // El SKU es UNIQUE en la BD: habrá cero o un resultado
        return consultar(SQL_BUSCAR_POR_SKU, sku).stream().findFirst();
    }

    @Override
    public List<Producto> listarConStockBajo(int umbral) {
        return consultar(SQL_STOCK_BAJO, umbral);
    }

    // ============================================================
    // Escritura (pendiente: paso 2.14)
    // ============================================================

    @Override
    public void guardar(Producto producto) {
        throw new UnsupportedOperationException("Se implementa en el paso 2.14");
    }

    @Override
    public void actualizar(Producto producto) {
        throw new UnsupportedOperationException("Se implementa en el paso 2.14");
    }

    @Override
    public boolean eliminar(String sku) {
        throw new UnsupportedOperationException("Se implementa en el paso 2.14");
    }

    // ============================================================
    // Métodos auxiliares privados
    // ============================================================

    /**
     * Ejecuta un SELECT con parámetros opcionales y mapea cada fila a un Producto.
     * Todas las lecturas pasan por aquí, así el manejo de conexión y errores
     * se escribe una sola vez.
     */
    private List<Producto> consultar(String sql, Object... parametros) {
        try (Connection conn = connectionProvider.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {

            // Asigna cada parámetro a su "?" correspondiente (empiezan en 1)
            for (int i = 0; i < parametros.length; i++) {
                ps.setObject(i + 1, parametros[i]);
            }

            try (ResultSet rs = ps.executeQuery()) {
                List<Producto> productos = new ArrayList<>();
                while (rs.next()) {
                    productos.add(mapear(rs));
                }
                return productos;
            }

        } catch (SQLException e) {
            throw new AccesoDatosException("Error al consultar los productos", e);
        }
    }

    /**
     * Convierte la fila actual en la subclase de Producto que corresponda.
     * Es el único lugar del programa que conoce el discriminador "tipo".
     */
    private Producto mapear(ResultSet rs) throws SQLException {
        // Campos comunes a todos los productos
        Categoria categoria = new Categoria(
                rs.getInt("categoria_id"),
                rs.getString("categoria_nombre")
        );
        int id = rs.getInt("id");
        String sku = rs.getString("sku");
        String nombre = rs.getString("nombre");
        BigDecimal precio = rs.getBigDecimal("precio");
        int stock = rs.getInt("stock");

        // El discriminador decide qué subclase construir
        TipoProducto tipo = TipoProducto.valueOf(rs.getString("tipo"));

        return switch (tipo) {
            case PERECEDERO -> new ProductoPerecedero(
                    id, sku, nombre, precio, stock, categoria,
                    rs.getObject("fecha_vencimiento", LocalDate.class)
            );
            case NO_PERECEDERO -> new ProductoNoPerecedero(
                    id, sku, nombre, precio, stock, categoria,
                    rs.getObject("meses_garantia", Integer.class)   // puede ser null
            );
        };
    }
}