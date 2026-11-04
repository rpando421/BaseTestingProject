package cmaccusco.rpando.framework.proceso;

import java.io.IOException;
import java.nio.charset.Charset;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

/**
 * Ejecuta un programa externo (.exe) y devuelve su código de salida y su salida.
 * <p>
 * Patrón GoF: <b>Facade</b> (estructural). Oculta {@link ProcessBuilder}: lanzar un exe
 * es una línea, igual que un SP con {@code EjecutorSql}.
 * <p>
 * Los argumentos se pasan directamente al programa, sin shell, así que los valores del CSV
 * no se interpretan como comandos. Un código de salida distinto de 0 no es una excepción:
 * es un dato que la prueba valida en ASSERT.
 * <p>
 * El proceso no comparte la transacción de {@code BaseDBTest}: el rollback no deshace lo
 * que el exe escriba en la base de datos.
 */
public class EjecutorProceso {

    private static final Duration TIMEOUT_POR_DEFECTO = Duration.ofSeconds(30);
    private static final Charset CHARSET_SISTEMA = Charset.forName(System.getProperty("native.encoding"));

    private final Duration timeout;

    public EjecutorProceso() {
        this(TIMEOUT_POR_DEFECTO);
    }

    public EjecutorProceso(Duration timeout) {
        this.timeout = timeout;
    }

    /**
     * @throws IOException      si el exe no existe o no se puede iniciar
     * @throws TimeoutException si el proceso no termina dentro del tiempo límite
     */
    public ResultadoProceso ejecutar(String exe, String... argumentos)
            throws IOException, InterruptedException, TimeoutException {
        List<String> comando = new ArrayList<>();
        comando.add(exe);
        comando.addAll(List.of(argumentos));

        // A un archivo y no a un pipe: un pipe lleno bloquearía al proceso y anularía el timeout.
        Path archivoSalida = Files.createTempFile("proceso_", ".log");
        try {
            Process proceso = new ProcessBuilder(comando)
                    .redirectErrorStream(true)
                    .redirectOutput(archivoSalida.toFile())
                    .start();
            try {
                if (!proceso.waitFor(timeout.toMillis(), TimeUnit.MILLISECONDS)) {
                    throw new TimeoutException(
                            "El proceso no terminó en " + timeout.toSeconds() + " s: " + String.join(" ", comando));
                }
            } finally {
                if (proceso.isAlive()) {
                    proceso.destroyForcibly().waitFor();
                }
            }
            return new ResultadoProceso(proceso.exitValue(), Files.readString(archivoSalida, CHARSET_SISTEMA));
        } finally {
            Files.deleteIfExists(archivoSalida);
        }
    }
}
