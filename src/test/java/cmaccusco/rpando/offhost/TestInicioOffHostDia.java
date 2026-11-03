package cmaccusco.rpando.offhost;

import cmaccusco.rpando.framework.prueba.BaseDBTest;
import cmaccusco.rpando.framework.prueba.CasoPrueba;
import cmaccusco.rpando.offhost.sp.InicioOffHostDia;
import cmaccusco.rpando.offhost.sp.ResultadoInicioOffHost;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvFileSource;

import java.time.LocalDate;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Pruebas de {@code dbo.InicioOFFHostDia}: caso en que el SP se valida por sus
 * parámetros OUTPUT. Celdas vacías en el CSV = no validar ese valor.
 */
class TestInicioOffHostDia extends BaseDBTest {

    private static final String CSV = "/matriz_pruebas/offhost/inicio_offhost_dia.csv";

    @ParameterizedTest(name = "[{index}] - {3}")
    @CsvFileSource(resources = CSV, numLinesToSkip = 1)
    void test_ParametrosSalida(LocalDate fecha, Integer nroOperacionesEsperado, Integer nroProcesadasEsperado,
                               String descripcion) throws Exception {
        new CasoPrueba(getClass(), "ParametrosSalida", descripcion) {
            ResultadoInicioOffHost r;

            @Override
            protected void act() throws Exception {
                r = InicioOffHostDia.de(fecha).ejecutar(sql);
            }

            @Override
            protected void assertar() {
                verificar("NroOperaciones informado", "no NULL", r.nroOperaciones(),
                        () -> assertThat(r.nroOperaciones()).as("@NroOperaciones").isNotNull());
                verificar("NroOperacionesProcesadas informado", "no NULL", r.nroOperacionesProcesadas(),
                        () -> assertThat(r.nroOperacionesProcesadas()).as("@NroOperacionesProcesadas").isNotNull());

                verificarIgual("NroOperaciones", nroOperacionesEsperado, r.nroOperaciones());
                verificarIgual("NroOperacionesProcesadas", nroProcesadasEsperado, r.nroOperacionesProcesadas());

                if (r.nroOperaciones() != null && r.nroOperacionesProcesadas() != null) {
                    verificar("Procesadas <= Operaciones", "<= " + r.nroOperaciones(), r.nroOperacionesProcesadas(),
                            () -> assertThat(r.nroOperacionesProcesadas()).isLessThanOrEqualTo(r.nroOperaciones()));
                }
            }
        }
                .parametro("Fecha", fecha)
                .ejecutar();
    }
}
