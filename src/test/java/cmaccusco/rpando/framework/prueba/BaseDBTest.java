package cmaccusco.rpando.framework.prueba;

import cmaccusco.rpando.framework.db.EjecutorSql;
import cmaccusco.rpando.framework.db.FuenteDatos;
import cmaccusco.rpando.framework.reporte.ExtensionReporte;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.extension.ExtendWith;

import java.sql.Connection;
import java.sql.SQLException;

/**
 * Base para pruebas que ejecutan SQL contra la BD configurada en {@code db.properties}.
 * <p>
 * Cada prueba recibe una conexión nueva sin autocommit y al finalizar se hace
 * <b>rollback</b>, de modo que ningún cambio del SP queda persistido.
 * El reporte Excel se genera automáticamente vía {@link ExtensionReporte}.
 */
@ExtendWith(ExtensionReporte.class)
public abstract class BaseDBTest {

    protected Connection conn;
    protected EjecutorSql sql;

    @BeforeEach
    void abrirConexion() throws SQLException {
        this.conn = FuenteDatos.instancia().obtenerConexion();
        this.sql = new EjecutorSql(conn);
    }

    @AfterEach
    void rollbackYCerrar() {
        if (conn == null) {
            return;
        }
        try {
            conn.rollback();
        } catch (SQLException e) {
            System.err.println("Error en rollback: " + e.getMessage());
        } finally {
            try {
                conn.close();
            } catch (SQLException e) {
                System.err.println("Error cerrando conexión: " + e.getMessage());
            }
        }
    }
}
