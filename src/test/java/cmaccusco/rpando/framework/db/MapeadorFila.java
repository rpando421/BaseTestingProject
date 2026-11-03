package cmaccusco.rpando.framework.db;

import java.sql.ResultSet;
import java.sql.SQLException;

/**
 * Convierte la fila actual de un {@link ResultSet} en un objeto.
 * <p>
 * Patrón GoF: <b>Strategy</b> (comportamiento). Cada repositorio aporta su propio
 * mapeador y {@link EjecutorSql} lo aplica sin conocer la tabla.
 */
@FunctionalInterface
public interface MapeadorFila<T> {
    T mapear(ResultSet rs) throws SQLException;
}
