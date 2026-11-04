package cmaccusco.rpando.ejemplos;

import cmaccusco.rpando.ejemplos.exe.BuscarTexto;
import cmaccusco.rpando.framework.prueba.CasoPrueba;
import cmaccusco.rpando.framework.proceso.EjecutorProceso;
import cmaccusco.rpando.framework.proceso.ResultadoProceso;
import cmaccusco.rpando.framework.reporte.ExtensionReporte;
import org.junit.jupiter.api.condition.EnabledOnOs;
import org.junit.jupiter.api.condition.OS;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvFileSource;

import java.net.URL;
import java.nio.file.Path;

/**
 * Ejemplo de referencia SIN base de datos: el paso ACT ejecuta un .exe con dos parámetros
 * y ASSERT valida su código de salida y su salida. Celda vacía en el CSV = no validar.
 */
@EnabledOnOs(OS.WINDOWS)
@ExtendWith(ExtensionReporte.class)
class TestBuscarTexto {

    private static final String DIRECTORIO = "/matriz_pruebas/ejemplos/";
    private static final String CSV = DIRECTORIO + "casos_prueba_exe.csv";

    private final EjecutorProceso proceso = new EjecutorProceso();

    @ParameterizedTest(name = "[{index}] - {4}")
    @CsvFileSource(resources = CSV, numLinesToSkip = 1)
    void test_BuscarTexto(String texto, String archivo, Integer codigoSalidaEsperado, String salidaEsperada,
                          String descripcion) throws Exception {
        new CasoPrueba(getClass(), "BuscarTexto", descripcion) {
            Path ruta;
            ResultadoProceso r;

            @Override
            protected void arrange() throws Exception {
                // findstr devuelve 1 tanto si no halla el texto como si no existe el archivo.
                URL recurso = TestBuscarTexto.class.getResource(DIRECTORIO + archivo);
                if (recurso == null) {
                    throw new IllegalStateException("No existe el archivo de datos: " + archivo);
                }
                ruta = Path.of(recurso.toURI());
            }

            @Override
            protected void act() throws Exception {
                r = BuscarTexto.de(texto, ruta).ejecutar(proceso);
            }

            @Override
            protected void assertar() {
                verificarIgual("Codigo de salida", codigoSalidaEsperado, r.codigoSalida());
                verificarIgual("Salida", salidaEsperada, r.salida());
            }
        }
                .parametro("Texto", texto)
                .parametro("Archivo", archivo)
                .ejecutar();
    }
}
