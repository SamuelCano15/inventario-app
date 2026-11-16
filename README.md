# 🏪 Inventario de Tienda

Aplicación de consola en **Java** para gestionar el inventario de una tienda, conectada a una base de datos **MySQL**.

Proyecto académico para practicar programación orientada a objetos, principios **SOLID**, acceso a datos con **JDBC** y buenas prácticas de seguridad con bases de datos.

## ✨ Funcionalidades

- Listar, buscar, registrar y eliminar productos
- Productos **perecederos** (con fecha de vencimiento) y **no perecederos** (con garantía opcional)
- Registrar entradas de mercancía y ventas
- Ventas **seguras ante concurrencia** (sin pérdida de actualizaciones)
- Consultar productos con stock bajo y productos vencidos
- Calcular el valor total del inventario

## 🛠️ Tecnologías

| Herramienta | Versión |
|---|---|
| Java (JDK) | 21 o superior |
| Maven | Incluido (Maven Wrapper) |
| MySQL Server | 8.0.16 o superior |
| MySQL Connector/J | 9.x |
| dotenv-java | 3.x |

## 📁 Estructura

```
inventario-app/
├── sql/                         # Scripts de base de datos (ejecutar en orden)
├── src/main/java/com/tienda/inventario/
│   ├── Main.java                # Punto de entrada (raíz de composición)
│   ├── config/                  # Lectura del archivo .env
│   ├── database/                # Conexiones JDBC
│   ├── exception/               # Excepciones propias
│   ├── interfaces/              # Contratos (repositorios, servicio, conexión)
│   ├── model/                   # Entidades del dominio y herencia
│   ├── repository/              # Implementaciones con MySQL
│   ├── service/                 # Reglas de negocio
│   └── ui/                      # Menú de consola
├── .env.example                 # Plantilla de configuración
└── pom.xml
```

## 🚀 Instalación

### 1. Clonar el repositorio

```bash
git clone https://github.com/SamuelCano15/inventario-app.git
```

### 2. Crear la base de datos

Ejecuta los scripts de `sql/` **en orden** desde MySQL Workbench (u otro cliente):

| Script | Ejecutar como | Qué hace |
|---|---|---|
| `01_setup_usuario.sql` | `root` | Crea la base de datos y el usuario `app_inventario` con permisos mínimos |
| `02_schema.sql` | `root` | Crea las tablas `categorias` y `productos` |
| `03_seed_data.sql` | `app_inventario` | Inserta los datos de ejemplo |

> ⚠️ Antes de ejecutar `01_setup_usuario.sql`, reemplaza `CAMBIAR_ESTA_CLAVE` por una contraseña propia.

### 3. Configurar las credenciales

Copia la plantilla y completa tus datos:

```bash
cp .env.example .env
```

```properties
DB_HOST=localhost
DB_PORT=3306
DB_NAME=tienda_inventario
DB_USER=app_inventario
DB_PASSWORD=la_clave_que_pusiste_en_el_paso_2
```

> El archivo `.env` está en `.gitignore`: **nunca** se sube al repositorio.

### 4. Ejecutar

1. Abre el proyecto en **IntelliJ IDEA** (File → Open → carpeta `inventario-app`).
2. Espera a que Maven descargue las dependencias.
3. Ejecuta `Main.java`.

## 🏛️ Arquitectura

La aplicación está organizada en capas. Cada capa depende solo de **interfaces**, nunca de clases concretas:

```
ConsolaUI ──► IInventarioService ──► IProductoRepository / ICategoriaRepository ──► MySQL
  (UI)          (reglas de negocio)          (acceso a datos con JDBC)
```

`Main` es el único lugar que conoce las clases concretas y las conecta entre sí.

### Principios SOLID aplicados

| Principio | Aplicación |
|---|---|
| **S** — Responsabilidad única | Cada capa tiene una sola responsabilidad (mostrar, decidir, guardar) |
| **O** — Abierto/cerrado | Nuevas implementaciones (otra BD, pool de conexiones) sin modificar el código existente |
| **L** — Sustitución de Liskov | `ProductoPerecedero` amplía `estaDisponible()` sin romper el contrato de `Producto` |
| **I** — Segregación de interfaces | Repositorios separados para productos y categorías |
| **D** — Inversión de dependencias | Todas las clases reciben interfaces en su constructor |

### Decisiones de diseño

- **Herencia en BD — Single Table:** una sola tabla `productos` con la columna `tipo` como discriminador.
- **Dinero con `DECIMAL` / `BigDecimal`:** sin errores de redondeo de punto flotante.
- **Stock atómico:** `UPDATE ... SET stock = stock - ? WHERE stock >= ?` evita el problema de *lost update* con ventas simultáneas.
- **Excepciones propias:** jerarquía con `InventarioException` como base; los errores de JDBC nunca salen del repositorio.

## 🔒 Seguridad

- La aplicación **no usa `root`**: usa `app_inventario`, que solo tiene permisos `SELECT`, `INSERT`, `UPDATE` y `DELETE` sobre su base de datos (principio de mínimo privilegio).
- Las credenciales están en `.env`, fuera del código y del repositorio.
- Todas las consultas usan `PreparedStatement`, que protege contra **inyección SQL**.
- La contraseña nunca se imprime (`AppConfig.toString()` la oculta).

## 🩺 Solución de problemas

| Mensaje | Solución |
|---|---|
| `No se encontró el archivo .env` | Copia `.env.example` como `.env` en la raíz del proyecto |
| `Access denied for user 'app_inventario'` | Revisa `DB_PASSWORD` en el `.env` |
| `Communications link failure` | Inicia el servicio de MySQL |
| `Public Key Retrieval is not allowed` | Agrega `&allowPublicKeyRetrieval=true` a la URL en `AppConfig` (solo en local) |

## 🔮 Mejoras futuras

- Pruebas unitarias con JUnit usando repositorios en memoria
- Pool de conexiones (HikariCP)
- Tabla de movimientos de inventario con transacciones
- Empaquetar como `.jar` ejecutable

## 👤 Autor

Samuel Cano — Estudiante de Ingeniería en IA y Ciencia de Datos