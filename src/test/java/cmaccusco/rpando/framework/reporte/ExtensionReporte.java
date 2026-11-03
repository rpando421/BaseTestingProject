package cmaccusco.rpando.framework.reporte;

import org.junit.jupiter.api.extension.AfterAllCallback;
import org.junit.jupiter.api.extension.ExtensionContext;

import java.nio.file.Path;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;

/**
 * Extensión JUnit que genera el reporte al terminar cada clase de prueba.
 * <p>
 * Patrón GoF: <b>Observer</b> (comportamiento). Se suscribe al ciclo de vida de JUnit
 * y reacciona al evento "fin de clase" escribiendo
 * {@code target/reportes/<Clase>_<yyyyMMdd_HHmmss>.xlsx} con la estrategia configurada.
 */
public class ExtensionReporte implements AfterAllCallback {

    private static final Path DIRECTORIO = Path.of("target", "reportes");
    private static final DateTimeFormatter SELLO = DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss");

    private final EscritorReporte escritor;

    public ExtensionReporte() {
        this(new EscritorReporteExcel());
    }

    public ExtensionReporte(EscritorReporte escritor) {
        this.escritor = escritor;
    }

    @Override
    public void afterAll(ExtensionContext context) throws Exception {
        Class<?> clase = context.getRequiredTestClass();
        List<CasoReporte> casos = RegistroReporte.extraer(clase);
        if (casos.isEmpty()) {
            return;
        }
        String nombre = clase.getSimpleName() + "_" + LocalDateTime.now().format(SELLO);
        Path archivo = escritor.escribir(DIRECTORIO, nombre, casos);
        System.out.println("Reporte generado: " + archivo.toAbsolutePath());
    }
}
