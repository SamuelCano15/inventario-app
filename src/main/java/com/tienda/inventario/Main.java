package com.tienda.inventario;

import com.tienda.inventario.config.AppConfig;
import com.tienda.inventario.database.ConnectionFactory;
import com.tienda.inventario.interfaces.IConnectionProvider;
import com.tienda.inventario.interfaces.IInventarioService;
import com.tienda.inventario.repository.MySqlCategoriaRepository;
import com.tienda.inventario.repository.MySqlProductoRepository;
import com.tienda.inventario.service.InventarioService;
import com.tienda.inventario.ui.ConsolaUI;

import java.util.Scanner;

public class Main {
    public static void main(String[] args) {
        AppConfig config = AppConfig.fromEnv();
        IConnectionProvider provider = new ConnectionFactory(config);
        IInventarioService servicio = new InventarioService(
                new MySqlProductoRepository(provider),
                new MySqlCategoriaRepository(provider)
        );

        Scanner scanner = new Scanner(System.in);
        new ConsolaUI(servicio, scanner).iniciar();
    }
}