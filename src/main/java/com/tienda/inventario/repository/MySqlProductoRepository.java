package com.tienda.inventario.repository;

import com.tienda.inventario.exception.AccesoDatosException;
import com.tienda.inventario.exception.CategoriaNoEncontradaException;
import com.tienda.inventario.exception.InventarioException;
import com.tienda.inventario.exception.ProductoDuplicadoException;
import com.tienda.inventario.exception.ProductoNoEncontradoException;
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
import java.sql.Statement;
import java.sql.Types;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * Implementación de IProductoRepository usando MySQL y JDBC.
 * Convierte filas en objetos (lectura) y objetos en filas (escritura),
 * y traduce los errores de MySQL a las excepciones propias de la aplicación.
 */
public class MySqlProductoRepository implements IProductoRepository {

    // ------------------------------------------------------------
    // SQL de lectura
    // ------------------------------------------------------------

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

    // ------------------------------------------------------------
    // SQL de escritura
    // ------------------------------------------------------------

    private static final String SQL_INSERT = """
            INSERT INTO productos
                (sku, nombre, precio, stock, categoria_id, tipo, fecha_vencimiento, meses_garantia)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """;

    // Solo se actualiza lo que el modelo permite cambiar:
    // sku, categoría, tipo, fecha y garantía son final en Java
    private static final String SQL_UPDATE = """
            UPDATE productos
            SET nombre = ?, precio = ?, stock = ?
            WHERE sku = ?
            """;

    private static final String SQL_DELETE =
            "DELETE FROM productos WHERE sku = ?";

    // ------------------------------------------------------------
    // Códigos de error de MySQL que sabemos interpretar
    // ------------------------------------------------------------

    private static final int MYSQL_ENTRADA_DUPLICADA = 1062;  // viola un UNIQUE
    private static final int MYSQL_FK_FALLIDA = 1452;         // la FK apunta a algo que no existe

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
    // Escritura
    // ============================================================

    @Override
    public void guardar(Producto producto) {
        // Validaciones previas: evitan ir a la BD con algo que de seguro va a fallar
        if (producto.getId() != null) {
            throw new IllegalStateException(
                    "El producto " + producto.getSku() + " ya está guardado (id "
                            + producto.getId() + "). Usa actualizar().");
        }
        Integer categoriaId = producto.getCategoria().id();
        if (categoriaId == null) {
            throw new IllegalArgumentException(
                    "La categoría del producto debe existir en la BD (tiene id nulo)");
        }

        try (Connection conn = connectionProvider.getConnection();
             PreparedStatement ps = conn.prepareStatement(SQL_INSERT, Statement.RETURN_GENERATED_KEYS)) {

            // Campos comunes (el orden coincide con los "?" del INSERT)
            ps.setString(1, producto.getSku());
            ps.setString(2, producto.getNombre());
            ps.setBigDecimal(3, producto.getPrecio());
            ps.setInt(4, producto.getStock());
            ps.setInt(5, categoriaId);
            ps.setString(6, producto.getTipo().name());   // "PERECEDERO" o "NO_PERECEDERO"

            // Campos propios de cada subclase (posiciones 7 y 8)
            asignarCamposDeSubclase(ps, producto);

            ps.executeUpdate();

            // Recupera el id que generó AUTO_INCREMENT y se lo asigna al objeto
            try (ResultSet claves = ps.getGeneratedKeys()) {
                if (!claves.next()) {
                    throw new SQLException("MySQL no devolvió el id generado");
                }
                producto.asignarId(claves.getInt(1));
            }

        } catch (SQLException e) {
            throw traducirErrorAlGuardar(e, producto);
        }
    }

    @Override
    public void actualizar(Producto producto) {
        try (Connection conn = connectionProvider.getConnection();
             PreparedStatement ps = conn.prepareStatement(SQL_UPDATE)) {

            ps.setString(1, producto.getNombre());
            ps.setBigDecimal(2, producto.getPrecio());
            ps.setInt(3, producto.getStock());
            ps.setString(4, producto.getSku());

            // executeUpdate devuelve cuántas filas cumplieron el WHERE
            int filas = ps.executeUpdate();
            if (filas == 0) {
                throw new ProductoNoEncontradoException(producto.getSku());
            }

        } catch (SQLException e) {
            throw new AccesoDatosException("Error al actualizar el producto " + producto.getSku(), e);
        }
    }

    @Override
    public boolean eliminar(String sku) {
        try (Connection conn = connectionProvider.getConnection();
             PreparedStatement ps = conn.prepareStatement(SQL_DELETE)) {

            ps.setString(1, sku);
            return ps.executeUpdate() > 0;   // true si borró al menos una fila

        } catch (SQLException e) {
            throw new AccesoDatosException("Error al eliminar el producto " + sku, e);
        }
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
     * Es el único lugar del programa que conoce el discriminador "tipo" al leer.
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

    /**
     * Llena las posiciones 7 y 8 del INSERT según la subclase real del producto.
     * Es el único lugar que conoce las subclases al escribir.
     */
    private void asignarCamposDeSubclase(PreparedStatement ps, Producto producto) throws SQLException {
        LocalDate fechaVencimiento = null;
        Integer mesesGarantia = null;

        if (producto instanceof ProductoPerecedero perecedero) {
            fechaVencimiento = perecedero.getFechaVencimiento();
        } else if (producto instanceof ProductoNoPerecedero noPerecedero) {
            mesesGarantia = noPerecedero.getMesesGarantia().orElse(null);
        } else {
            throw new IllegalArgumentException(
                    "Tipo de producto no soportado: " + producto.getClass().getSimpleName());
        }

        asignarNulable(ps, 7, fechaVencimiento, Types.DATE);
        asignarNulable(ps, 8, mesesGarantia, Types.INTEGER);
    }

    /**
     * Asigna un valor que puede ser null. Con null se usa setNull indicando
     * el tipo SQL, que es la forma correcta y portable de enviar un NULL.
     */
    private static void asignarNulable(PreparedStatement ps, int indice,
                                       Object valor, int tipoSql) throws SQLException {
        if (valor == null) {
            ps.setNull(indice, tipoSql);
        } else {
            ps.setObject(indice, valor);
        }
    }

    /**
     * Traduce los códigos de error de MySQL a excepciones del negocio.
     * Devuelve la excepción en lugar de lanzarla, para que quien llama
     * escriba "throw traducir...(...)" y el compilador sepa que ahí termina el método.
     */
    private InventarioException traducirErrorAlGuardar(SQLException e, Producto producto) {
        return switch (e.getErrorCode()) {
            case MYSQL_ENTRADA_DUPLICADA -> new ProductoDuplicadoException(producto.getSku());
            case MYSQL_FK_FALLIDA -> new CategoriaNoEncontradaException(producto.getCategoria().id());
            default -> new AccesoDatosException("Error al guardar el producto " + producto.getSku(), e);
        };
    }
}