package cmaccusco.rpando.ejemplos.exe;

import cmaccusco.rpando.framework.proceso.EjecutorProceso;
import cmaccusco.rpando.framework.proceso.ResultadoProceso;

import java.io.IOException;
import java.nio.file.Path;
import java.util.concurrent.TimeoutException;

/**
 * Llamada a {@code findstr.exe <texto> <archivo>}, incluido en Windows.
 * <p>
 * Patrón GoF: <b>Command</b> (comportamiento). Encapsula el exe y sus dos parámetros; si
 * cambia la línea de comandos solo se toca esta clase.
 * <p>
 * Código de salida: 0 si encuentra el texto, 1 si no. También devuelve 1 si el archivo no
 * existe, por eso la prueba lo comprueba antes de ejecutar.
 */
public final class BuscarTexto {

    private static final String EXE = "findstr.exe";

    private final String texto;
    private final Path archivo;

    private BuscarTexto(String texto, Path archivo) {
        this.texto = texto;
        this.archivo = archivo;
    }

    public static BuscarTexto de(String texto, Path archivo) {
        return new BuscarTexto(texto, archivo);
    }

    public ResultadoProceso ejecutar(EjecutorProceso proceso)
            throws IOException, InterruptedException, TimeoutException {
        return proceso.ejecutar(EXE, texto, archivo.toString());
    }
}
