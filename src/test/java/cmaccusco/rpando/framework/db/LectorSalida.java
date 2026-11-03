package cmaccusco.rpando.framework.db;

import java.sql.CallableStatement;
import java.sql.SQLException;

/**
 * Lee los parámetros OUTPUT de un procedimiento almacenado ya ejecutado.
 * <p>
 * Patrón GoF: <b>Strategy</b> (comportamiento), análogo a {@link MapeadorFila}.
 */
@FunctionalInterface
public interface LectorSalida<T> {
    T leer(CallableStatement cs) throws SQLException;
}
