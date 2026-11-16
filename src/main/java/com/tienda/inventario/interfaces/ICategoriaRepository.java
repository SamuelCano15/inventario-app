package com.tienda.inventario.interfaces;

import com.tienda.inventario.model.Categoria;

import java.util.List;
import java.util.Optional;

/**
 * Acceso de solo lectura a las categorías de productos.
 * Las implementaciones lanzan AccesoDatosException cuando ocurren
 * errores durante las operaciones de persistencia.
 */
public interface ICategoriaRepository {

    /** Returns all categories ordered by name. Never null (may be empty). */
    List<Categoria> listarTodas();

    /** Returns the category with that id, or Optional.empty() if it doesn't exist. */
    Optional<Categoria> buscarPorId(int id);
}