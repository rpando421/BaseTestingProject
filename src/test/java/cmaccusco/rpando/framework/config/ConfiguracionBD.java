package cmaccusco.rpando.framework.config;

import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

/**
 * Configuración de conexión a la base de datos.
 * <p>
 * Patrón GoF: <b>Singleton</b> (creacional). Se carga una sola vez desde
 * {@code db.properties} (classpath de test) y cada valor puede sobrescribirse
 * con variables de entorno: {@code DB_URL}, {@code DB_USER}, {@code DB_PASSWORD},
 * {@code DB_POOL_SIZE}.
 * <p>
 * Las credenciales nunca deben escribirse en el código fuente.
 */
public final class ConfiguracionBD {

    private static final String ARCHIVO = "db.properties";

    private final String url;
    private final String usuario;
    private final String clave;
    private final int tamanoPool;

    private ConfiguracionBD() {
        Properties props = cargarArchivo();
        this.url = valor(props, "DB_URL", "db.url");
        this.usuario = valor(props, "DB_USER", "db.user");
        this.clave = valor(props, "DB_PASSWORD", "db.password");
        String pool = valor(props, "DB_POOL_SIZE", "db.pool.size");
        this.tamanoPool = pool != null ? Integer.parseInt(pool) : 5;

        if (url == null || usuario == null || clave == null) {
            throw new IllegalStateException(
                    "Configuración de BD incompleta. Copie src/test/resources/db.properties.example a "
                            + "src/test/resources/db.properties o defina las variables DB_URL, DB_USER y DB_PASSWORD.");
        }
    }

    private static final class Holder {
        private static final ConfiguracionBD INSTANCIA = new ConfiguracionBD();
    }

    public static ConfiguracionBD instancia() {
        return Holder.INSTANCIA;
    }

    private static Properties cargarArchivo() {
        Properties props = new Properties();
        try (InputStream in = ConfiguracionBD.class.getClassLoader().getResourceAsStream(ARCHIVO)) {
            if (in != null) {
                props.load(in);
            }
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo leer " + ARCHIVO, e);
        }
        return props;
    }

    private static String valor(Properties props, String variableEntorno, String clavePropiedad) {
        String env = System.getenv(variableEntorno);
        if (env != null && !env.isBlank()) {
            return env;
        }
        String prop = props.getProperty(clavePropiedad);
        return (prop != null && !prop.isBlank()) ? prop : null;
    }

    public String url() { return url; }
    public String usuario() { return usuario; }
    public String clave() { return clave; }
    public int tamanoPool() { return tamanoPool; }
}
