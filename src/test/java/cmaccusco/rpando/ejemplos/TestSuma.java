package cmaccusco.rpando.ejemplos;

import cmaccusco.rpando.framework.prueba.CasoPrueba;
import cmaccusco.rpando.framework.reporte.ExtensionReporte;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvFileSource;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Ejemplo de referencia SIN base de datos: muestra el flujo
 * CSV → CasoPrueba (ARRANGE/ACT/ASSERT) → reporte Excel.
 */
@ExtendWith(ExtensionReporte.class)
class TestSuma {

    @ParameterizedTest(name = "[{index}] - {3}")
    @CsvFileSource(resources = "/matriz_pruebas/ejemplos/casos_prueba_suma.csv", numLinesToSkip = 1)
    void test_Suma(int numero1, int numero2, int sumaEsperada, String descripcion) throws Exception {
        new CasoPrueba(getClass(), "Suma", descripcion) {
            int resultado;

            @Override
            protected void act() {
                resultado = numero1 + numero2;
            }

            @Override
            protected void assertar() {
                verificar("Suma", sumaEsperada, resultado,
                        () -> assertThat(resultado).as(descripcion).isEqualTo(sumaEsperada));
            }
        }
                .parametro("Numero 1", numero1)
                .parametro("Numero 2", numero2)
                .ejecutar();
    }
}
