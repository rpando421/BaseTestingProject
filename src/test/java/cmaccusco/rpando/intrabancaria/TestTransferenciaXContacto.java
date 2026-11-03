package cmaccusco.rpando.intrabancaria;

import cmaccusco.rpando.datos.dbcmac.CaptacAhorros;
import cmaccusco.rpando.datos.dbcmac.CaptacAhorrosRepositorio;
import cmaccusco.rpando.datos.dbcmac.Producto;
import cmaccusco.rpando.datos.dbcmac.ProductoRepositorio;
import cmaccusco.rpando.framework.prueba.BaseDBTest;
import cmaccusco.rpando.framework.prueba.CasoPrueba;
import cmaccusco.rpando.intrabancaria.sp.RegistraTransferenciaContacto;
import cmaccusco.rpando.intrabancaria.sp.RespuestaTransferencia;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvFileSource;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Pruebas de {@code dbo.spu_App_RegistraTransferenciaContacto}.
 * Esta clase no contiene SQL: las consultas están en {@code datos.dbcmac.*Repositorio}
 * y la llamada al SP en {@link RegistraTransferenciaContacto}.
 */
class TestTransferenciaXContacto extends BaseDBTest {

    private static final String CSV = "/matriz_pruebas/intrabancaria/transferencia_x_contacto_regular.csv";
    private static final String CSV_RESPUESTA = "/matriz_pruebas/intrabancaria/transferencia_x_contacto_respuesta.csv";

    /**
     * Caso: el SP devuelve un SELECT y se validan varios de sus campos.
     * Los valores esperados vienen del CSV; una celda vacía significa "no validar".
     */
    @ParameterizedTest(name = "[{index}] - {8}")
    @CsvFileSource(resources = CSV_RESPUESTA, numLinesToSkip = 1)
    void test_RespuestaSp(String dniOrigen, String ctaCodOrigen, String dniDestino, String ctaCodDestino,
                          BigDecimal monto, String respuestaEsperada, String mensajeEsperado,
                          String entidadEsperada, String descripcion) throws Exception {
        new CasoPrueba(getClass(), "RespuestaSp", descripcion) {
            RespuestaTransferencia r;

            @Override
            protected void act() throws Exception {
                r = RegistraTransferenciaContacto
                        .de(dniOrigen, ctaCodOrigen, dniDestino, ctaCodDestino, monto)
                        .ejecutar(sql);
            }

            @Override
            protected void assertar() {
                verificarIgual("Respuesta", respuestaEsperada, r.cRespuesta());
                verificarIgual("Mensaje", mensajeEsperado, r.cMensaje());
                verificarIgual("Entidad", entidadEsperada, r.cNomEntidad());
                verificarIgual("Cuenta origen devuelta", ctaCodOrigen, r.cCtaCodOrigen());
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
    void test_NoOffHost(String dniOrigen, String ctaCodOrigen, String dniDestino, String ctaCodDestino,
                        BigDecimal monto, String descripcion) throws Exception {
        ProductoRepositorio productos = new ProductoRepositorio(sql);

        new CasoPrueba(getClass(), "NoOffHost", descripcion) {
            Producto destinoAntes;
            Producto destinoDespues;
            String respuesta;

            @Override
            protected void arrange() throws Exception {
                destinoAntes = productos.obtener(ctaCodDestino);
            }

            @Override
            protected void act() throws Exception {
                respuesta = RegistraTransferenciaContacto
                        .de(dniOrigen, ctaCodOrigen, dniDestino, ctaCodDestino, monto)
                        .ejecutar(sql)
                        .cRespuesta();
            }

            @Override
            protected void assertar() throws Exception {
                destinoDespues = productos.obtener(ctaCodDestino);

                // TODO revisar: se conserva la lógica original ("80" y saldo sin cambios)
                verificar("Respuesta SP", "80", respuesta,
                        () -> assertThat(respuesta).isEqualTo("80"));
                verificar("Saldo destino", destinoAntes.nSaldo(), destinoDespues.nSaldo(),
                        () -> assertThat(destinoAntes.nSaldo()).isEqualByComparingTo(destinoDespues.nSaldo()));
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
        ProductoRepositorio productos = new ProductoRepositorio(sql);
        CaptacAhorrosRepositorio ahorros = new CaptacAhorrosRepositorio(sql);

        new CasoPrueba(getClass(), "OffHost", descripcion) {
            BigDecimal saldo;
            BigDecimal retencion;
            String respuesta;

            @Override
            protected void act() throws Exception {
                respuesta = RegistraTransferenciaContacto
                        .de(dniOrigen, ctaCodOrigen, dniDestino, ctaCodDestino, monto)
                        .conOffHost()
                        .ejecutar(sql)
                        .cRespuesta();
            }

            @Override
            protected void assertar() throws Exception {
                saldo = productos.obtener(ctaCodDestino).nSaldo();
                retencion = ahorros.porCuenta(ctaCodDestino)
                        .map(CaptacAhorros::nRetencion)
                        .orElse(BigDecimal.ZERO);

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
}
