package cmaccusco.rpando.dbtests;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvFileSource;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.sql.SQLException;

public class TestSuma extends BaseDBTest {
    @ParameterizedTest(name = "[{index}] - {3}")
    @CsvFileSource(resources = "/casos_prueba_suma.csv", numLinesToSkip = 1)
    void test_TestSencillo(int numero1, int numero2, int suma, String descripcionCaso) throws SQLException {
        String estadoTest = "FAILED";
        int valorCalculado = 0;

        try {
            valorCalculado = numero1 + numero2;
            assertEquals(suma, valorCalculado, "Fallo en el caso: " + descripcionCaso);

            estadoTest = "PASSED";
        } catch (Exception e) {
            estadoTest = "FAILED (" + e.getMessage() + ")";
            throw e;
        } finally {
            CasoReporte caso = new CasoReporte(descripcionCaso,suma,valorCalculado,estadoTest);
            caso.agregarParametro("Numero 1", numero1);
            caso.agregarParametro("Numeor 2", numero2);
            resultadosReporte.add(caso);
        }
    }
}
