package com.tienda.inventario.repository;

import com.tienda.inventario.exception.AccesoDatosException;
import com.tienda.inventario.interfaces.ICategoriaRepository;
import com.tienda.inventario.interfaces.IConnectionProvider;
import com.tienda.inventario.model.Categoria;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * Implementación de ICategoriaRepository usando MySQL y JDBC.
 * Es la única clase que conoce el SQL de la tabla categorias.
 */
public class MySqlCategoriaRepository implements ICategoriaRepository {

    // Consultas SQL como constantes: se escriben una vez y se reconocen fácilmente
    private static final String SQL_LISTAR_TODAS =
            "SELECT id, nombre FROM categorias ORDER BY nombre";

    private static final String SQL_BUSCAR_POR_ID =
            "SELECT id, nombre FROM categorias WHERE id = ?";

    private final IConnectionProvider connectionProvider;

    // Depende de la interfaz, no de ConnectionFactory (principio D)
    public MySqlCategoriaRepository(IConnectionProvider connectionProvider) {
        this.connectionProvider = connectionProvider;
    }

    @Override
    public List<Categoria> listarTodas() {
        List<Categoria> categorias = new ArrayList<>();

        try (Connection conn = connectionProvider.getConnection();
             PreparedStatement ps = conn.prepareStatement(SQL_LISTAR_TODAS);
             ResultSet rs = ps.executeQuery()) {

            // Recorre fila por fila y convierte cada una en un objeto
            while (rs.next()) {
                categorias.add(mapear(rs));
            }
            return categorias;

        } catch (SQLException e) {
            // Traduce el error de JDBC a una excepción propia (sin perder la causa)
            throw new AccesoDatosException("Error al listar las categorías", e);
        }
    }

    @Override
    public Optional<Categoria> buscarPorId(int id) {
        try (Connection conn = connectionProvider.getConnection();
             PreparedStatement ps = conn.prepareStatement(SQL_BUSCAR_POR_ID)) {

            // Reemplaza el primer "?" por el id, de forma segura
            ps.setInt(1, id);

            // try anidado: el ResultSet solo existe después de asignar los parámetros
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next()
                        ? Optional.of(mapear(rs))
                        : Optional.empty();
            }

        } catch (SQLException e) {
            throw new AccesoDatosException("Error al buscar la categoría con id " + id, e);
        }
    }

    /**
     * Convierte la fila actual del ResultSet en un objeto Categoria.
     * No avanza el cursor: eso lo hace quien la llama con rs.next().
     */
    private Categoria mapear(ResultSet rs) throws SQLException {
        return new Categoria(
                rs.getInt("id"),
                rs.getString("nombre")
        );
    }
}