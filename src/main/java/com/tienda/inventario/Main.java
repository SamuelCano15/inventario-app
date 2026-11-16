package com.tienda.inventario;

import com.tienda.inventario.config.AppConfig;
import com.tienda.inventario.database.ConnectionFactory;
import com.tienda.inventario.interfaces.ICategoriaRepository;
import com.tienda.inventario.interfaces.IConnectionProvider;
import com.tienda.inventario.model.Categoria;
import com.tienda.inventario.repository.MySqlCategoriaRepository;

public class Main {
    public static void main(String[] args) {
        // 1. Armar las piezas (inyección de dependencias manual)
        AppConfig config = AppConfig.fromEnv();
        IConnectionProvider provider = new ConnectionFactory(config);
        ICategoriaRepository categoriaRepo = new MySqlCategoriaRepository(provider);

        // 2. Listar todas
        System.out.println("=== Categorías ===");
        for (Categoria c : categoriaRepo.listarTodas()) {
            System.out.println(c.id() + " - " + c.nombre());
        }

        // 3. Buscar una que existe y una que no
        System.out.println("\n=== Búsquedas ===");
        buscarYMostrar(categoriaRepo, 2);
        buscarYMostrar(categoriaRepo, 99);
    }

    private static void buscarYMostrar(ICategoriaRepository repo, int id) {
        repo.buscarPorId(id).ifPresentOrElse(
                c -> System.out.println("id " + id + " → encontrada: " + c.nombre()),
                () -> System.out.println("id " + id + " → no existe")
        );
    }
}