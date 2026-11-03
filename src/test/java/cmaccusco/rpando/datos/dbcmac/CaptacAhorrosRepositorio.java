package cmaccusco.rpando.datos.dbcmac;

import cmaccusco.rpando.framework.db.EjecutorSql;
import cmaccusco.rpando.framework.db.MapeadorFila;

import java.sql.SQLException;
import java.util.Optional;

/** Consultas sobre {@code DBCMAC..CaptacAhorros} reutilizables por cualquier prueba. */
public class CaptacAhorrosRepositorio {

    private static final String SQL_POR_CUENTA =
            "SELECT cCtaCod, nRetencion FROM DBCMAC..CaptacAhorros WITH(NOLOCK) WHERE cCtaCod = ?;";

    private static final MapeadorFila<CaptacAhorros> MAPEADOR = rs -> new CaptacAhorros(
            rs.getString("cCtaCod"),
            rs.getBigDecimal("nRetencion"));

    private final EjecutorSql sql;

    public CaptacAhorrosRepositorio(EjecutorSql sql) {
        this.sql = sql;
    }

    public Optional<CaptacAhorros> porCuenta(String ctaCod) throws SQLException {
        return sql.consultarUno(SQL_POR_CUENTA, MAPEADOR, ctaCod);
    }
}
