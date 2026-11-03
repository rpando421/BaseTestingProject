package cmaccusco.rpando.framework.reporte;

import java.io.IOException;
import java.nio.file.Path;
import java.util.List;

/**
 * Formato de salida del reporte de pruebas.
 * <p>
 * Patrón GoF: <b>Strategy</b> (comportamiento). Hoy existe {@link EscritorReporteExcel};
 * otro formato (CSV, HTML) solo requiere una nueva implementación.
 */
public interface EscritorReporte {

    /**
     * Escribe el reporte en {@code directorio} y devuelve la ruta del archivo generado.
     */
    Path escribir(Path directorio, String nombre, List<CasoReporte> casos) throws IOException;
}
