package cmaccusco.rpando.datos.dbcmac;

import java.math.BigDecimal;

/**
 * Fila de {@code DBCMAC..CaptacAhorros}. Para usar un campo nuevo en las pruebas, agréguelo
 * aquí y en {@link CaptacAhorrosRepositorio} (SELECT + mapeador).
 */
public record CaptacAhorros(String cCtaCod, BigDecimal nRetencion) { }
