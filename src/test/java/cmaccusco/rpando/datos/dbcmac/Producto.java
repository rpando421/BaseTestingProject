package cmaccusco.rpando.datos.dbcmac;

import java.math.BigDecimal;

/**
 * Fila de {@code DBCMAC..Producto}. Para usar un campo nuevo en las pruebas, agréguelo
 * aquí y en {@link ProductoRepositorio} (SELECT + mapeador).
 */
public record Producto(String cCtaCod, BigDecimal nSaldo) { }
