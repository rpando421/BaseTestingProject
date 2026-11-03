package cmaccusco.rpando.offhost.sp;

import cmaccusco.rpando.framework.db.EjecutorSql;

import java.sql.SQLException;
import java.sql.Timestamp;
import java.sql.Types;
import java.time.LocalDate;

/**
 * Llamada a {@code dbo.InicioOFFHostDia @pdFecha, @NroOperaciones OUTPUT, @NroOperacionesProcesadas OUTPUT}
 * (fuente: src/main/resources/sql/InicioOffHostDia.sql).
 * <p>
 * Patrón GoF: <b>Command</b> (comportamiento). Ejemplo de SP que se valida por sus
 * parámetros de salida en lugar de un SELECT.
 */
public final class InicioOffHostDia {

    private static final String SP = "{call InicioOFFHostDia(?, ?, ?)}";

    private final LocalDate fecha;

    private InicioOffHostDia(LocalDate fecha) {
        this.fecha = fecha;
    }

    public static InicioOffHostDia de(LocalDate fecha) {
        return new InicioOffHostDia(fecha);
    }

    public ResultadoInicioOffHost ejecutar(EjecutorSql sql) throws SQLException {
        return sql.ejecutarSpConSalida(SP,
                cstmt -> {
                    cstmt.setTimestamp(1, Timestamp.valueOf(fecha.atStartOfDay()));
                    cstmt.registerOutParameter(2, Types.INTEGER);
                    cstmt.registerOutParameter(3, Types.INTEGER);
                },
                cstmt -> new ResultadoInicioOffHost(
                        cstmt.getObject(2, Integer.class),
                        cstmt.getObject(3, Integer.class)));
    }
}
