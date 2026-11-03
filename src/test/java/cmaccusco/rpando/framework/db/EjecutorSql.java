package cmaccusco.rpando.framework.db;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

/**
 * Punto único para ejecutar SQL desde las pruebas.
 * <p>
 * Patrón GoF: <b>Facade</b> (estructural). Oculta el manejo de
 * {@link PreparedStatement}, {@link CallableStatement} y {@link ResultSet}
 * para que ARRANGE/ASSERT (consultas SELECT) y ACT (llamada a SP) se lean en una línea.
 */
public class EjecutorSql {

    /** Asigna los parámetros de una llamada a procedimiento almacenado. */
    @FunctionalInterface
    public interface Parametros {
        void asignar(CallableStatement cstmt) throws SQLException;
    }

    private final Connection conn;

    public EjecutorSql(Connection conn) {
        this.conn = conn;
    }

    /**
     * Ejecuta un SELECT y devuelve el valor de {@code columna} en la primera fila,
     * o {@code valorPorDefecto} si no hay filas.
     */
    public <T> T consultarValor(String sql, String columna, Class<T> tipo, T valorPorDefecto, Object... params)
            throws SQLException {
        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            for (int i = 0; i < params.length; i++) {
                stmt.setObject(i + 1, params[i]);
            }
            try (ResultSet rs = stmt.executeQuery()) {
                return rs.next() ? rs.getObject(columna, tipo) : valorPorDefecto;
            }
        }
    }

    /**
     * Ejecuta un procedimiento almacenado y devuelve el valor de {@code columnaRespuesta}
     * en la primera fila del primer result set, o {@code null} si no devuelve filas.
     */
    public String ejecutarSp(String llamada, Parametros parametros, String columnaRespuesta) throws SQLException {
        try (CallableStatement cstmt = conn.prepareCall(llamada)) {
            parametros.asignar(cstmt);
            try (ResultSet rs = cstmt.executeQuery()) {
                return rs.next() ? rs.getString(columnaRespuesta) : null;
            }
        }
    }
}
