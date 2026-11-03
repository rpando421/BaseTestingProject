package cmaccusco.rpando.framework.db;

import cmaccusco.rpando.framework.config.ConfiguracionBD;
import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;

import java.sql.Connection;
import java.sql.SQLException;

/**
 * Pool de conexiones compartido por todas las clases de prueba.
 * <p>
 * Patrón GoF: <b>Singleton</b> (creacional), con inicialización perezosa: el pool
 * solo se crea cuando una prueba pide una conexión, así las pruebas que no usan BD
 * no requieren configuración. Se cierra automáticamente al terminar la JVM.
 */
public final class FuenteDatos {

    private final HikariDataSource dataSource;

    private FuenteDatos() {
        ConfiguracionBD cfg = ConfiguracionBD.instancia();
        HikariConfig config = new HikariConfig();
        config.setJdbcUrl(cfg.url());
        config.setUsername(cfg.usuario());
        config.setPassword(cfg.clave());
        config.setAutoCommit(false);
        config.setMaximumPoolSize(cfg.tamanoPool());
        this.dataSource = new HikariDataSource(config);
        Runtime.getRuntime().addShutdownHook(new Thread(dataSource::close));
    }

    private static FuenteDatos instancia;

    /**
     * Inicialización perezosa sincronizada (no se usa el idiom "Holder": si la configuración
     * falla, el Holder deja la clase inutilizable y las siguientes pruebas verían
     * NoClassDefFoundError en lugar del mensaje real).
     */
    public static synchronized FuenteDatos instancia() {
        if (instancia == null) {
            instancia = new FuenteDatos();
        }
        return instancia;
    }

    /** Devuelve una conexión con autocommit desactivado (las pruebas siempre hacen rollback). */
    public Connection obtenerConexion() throws SQLException {
        Connection conn = dataSource.getConnection();
        conn.setAutoCommit(false);
        return conn;
    }
}
