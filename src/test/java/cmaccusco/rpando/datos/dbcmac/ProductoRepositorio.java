package cmaccusco.rpando.datos.dbcmac;

import cmaccusco.rpando.framework.db.EjecutorSql;
import cmaccusco.rpando.framework.db.MapeadorFila;

import java.sql.SQLException;
import java.util.Optional;

/** Consultas sobre {@code DBCMAC..Producto} reutilizables por cualquier prueba. */
public class ProductoRepositorio {

    private static final String SQL_POR_CUENTA =
            "SELECT cCtaCod, nSaldo FROM DBCMAC..Producto WITH(NOLOCK) WHERE cCtaCod = ?;";

    private static final MapeadorFila<Producto> MAPEADOR = rs -> new Producto(
            rs.getString("cCtaCod"),
            rs.getBigDecimal("nSaldo"));

    private final EjecutorSql sql;

    public ProductoRepositorio(EjecutorSql sql) {
        this.sql = sql;
    }

    public Optional<Producto> porCuenta(String ctaCod) throws SQLException {
        return sql.consultarUno(SQL_POR_CUENTA, MAPEADOR, ctaCod);
    }

    /** Igual que {@link #porCuenta} pero falla con mensaje claro si la cuenta no existe. */
    public Producto obtener(String ctaCod) throws SQLException {
        return porCuenta(ctaCod).orElseThrow(
                () -> new IllegalStateException("No existe la cuenta " + ctaCod + " en DBCMAC..Producto"));
    }
}
