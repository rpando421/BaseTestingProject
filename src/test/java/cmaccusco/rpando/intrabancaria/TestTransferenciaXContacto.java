package cmaccusco.rpando.intrabancaria;

import cmaccusco.rpando.framework.db.EjecutorSql;
import cmaccusco.rpando.framework.prueba.BaseDBTest;
import cmaccusco.rpando.framework.prueba.CasoPrueba;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvFileSource;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Pruebas de {@code dbo.spu_App_RegistraTransferenciaContacto}
 * (fuente: src/main/resources/sql/03_spu_App_RegistraTransferenciaContacto.sql).
 */
class TestTransferenciaXContacto extends BaseDBTest {

    private static final String CSV = "/matriz_pruebas/intrabancaria/transferencia_x_contacto_regular.csv";

    private static final String SQL_SALDO =
            "SELECT nSaldo FROM DBCMAC..Producto WITH(NOLOCK) WHERE cCtaCod = ?;";
    private static final String SQL_RETENCION =
            "SELECT nRetencion FROM DBCMAC..CaptacAhorros WITH(NOLOCK) WHERE cCtaCod = ?;";

    private static final String SP_SIN_OFFHOST =
            "{call spu_App_RegistraTransferenciaContacto(?,?,?,?,?,?,?,?,?,?)}";
    private static final String SP_CON_OFFHOST =
            "{call spu_App_RegistraTransferenciaContacto(?,?,?,?,?,?,?,?,?,?,?)}";

    @ParameterizedTest(name = "[{index}] - {5}")
    @CsvFileSource(resources = CSV, numLinesToSkip = 1)
    void test_NoOffHost(String dniOrigen, String ctaCodOrigen, String dniDestino, String ctaCodDestino,
                        BigDecimal monto, String descripcion) throws Exception {
        new CasoPrueba(getClass(), "NoOffHost", descripcion) {
            BigDecimal saldoAntes;
            BigDecimal saldoDespues;
            String respuesta;

            @Override
            protected void arrange() throws Exception {
                saldoAntes = saldo(sql, ctaCodDestino);
            }

            @Override
            protected void act() throws Exception {
                respuesta = sql.ejecutarSp(SP_SIN_OFFHOST, cstmt -> {
                    cstmt.setInt(1, 1);
                    cstmt.setString(2, dniOrigen);
                    cstmt.setString(3, "91");
                    cstmt.setDate(4, null);
                    cstmt.setString(5, "APP1");
                    cstmt.setString(6, dniDestino);
                    cstmt.setString(7, ctaCodDestino);
                    cstmt.setString(8, ctaCodOrigen);
                    cstmt.setInt(9, 1);
                    cstmt.setBigDecimal(10, monto);
                }, "cRespuesta");
            }

            @Override
            protected void assertar() throws Exception {
                saldoDespues = saldo(sql, ctaCodDestino);

                // TODO revisar: se conserva la lógica original ("80" y saldo sin cambios)
                verificar("Respuesta SP", "80", respuesta,
                        () -> assertThat(respuesta).isEqualTo("80"));
                verificar("Saldo destino", saldoAntes, saldoDespues,
                        () -> assertThat(saldoAntes).isEqualByComparingTo(saldoDespues));
                // TODO: validar retiro en cuenta origen
            }
        }
                .parametro("DNI origen", dniOrigen)
                .parametro("Cuenta origen", ctaCodOrigen)
                .parametro("DNI destino", dniDestino)
                .parametro("Cuenta destino", ctaCodDestino)
                .parametro("Monto", monto)
                .ejecutar();
    }

    @ParameterizedTest(name = "[{index}] - {5}")
    @CsvFileSource(resources = CSV, numLinesToSkip = 1)
    void test_OffHost(String dniOrigen, String ctaCodOrigen, String dniDestino, String ctaCodDestino,
                      BigDecimal monto, String descripcion) throws Exception {
        new CasoPrueba(getClass(), "OffHost", descripcion) {
            BigDecimal saldo;
            BigDecimal retencion;
            String respuesta;

            @Override
            protected void act() throws Exception {
                respuesta = sql.ejecutarSp(SP_CON_OFFHOST, cstmt -> {
                    cstmt.setInt(1, 1);
                    cstmt.setString(2, dniOrigen);
                    cstmt.setString(3, "91");
                    cstmt.setDate(4, null);
                    cstmt.setString(5, "APP1");
                    cstmt.setString(6, dniDestino);
                    cstmt.setString(7, ctaCodDestino);
                    cstmt.setString(8, ctaCodOrigen);
                    cstmt.setInt(9, 1);
                    cstmt.setBigDecimal(10, monto);
                    cstmt.setBoolean(11, true);
                }, "cRespuesta");
            }

            @Override
            protected void assertar() throws Exception {
                saldo = saldo(sql, ctaCodDestino);
                retencion = sql.consultarValor(SQL_RETENCION, "nRetencion", BigDecimal.class, BigDecimal.ZERO, ctaCodDestino);

                verificar("Respuesta SP", "00", respuesta,
                        () -> assertThat(respuesta).isEqualTo("00"));
                // TODO revisar: se conserva la lógica original (saldo - retención == saldo + monto)
                verificar("Saldo destino", saldo.add(monto), saldo.subtract(retencion),
                        () -> assertThat(saldo.subtract(retencion)).isEqualByComparingTo(saldo.add(monto)));
                // TODO: validar retiro en cuenta origen
            }
        }
                .parametro("DNI origen", dniOrigen)
                .parametro("Cuenta origen", ctaCodOrigen)
                .parametro("DNI destino", dniDestino)
                .parametro("Cuenta destino", ctaCodDestino)
                .parametro("Monto", monto)
                .ejecutar();
    }

    private static BigDecimal saldo(EjecutorSql sql, String ctaCod) throws Exception {
        return sql.consultarValor(SQL_SALDO, "nSaldo", BigDecimal.class, BigDecimal.ZERO, ctaCod);
    }
}
