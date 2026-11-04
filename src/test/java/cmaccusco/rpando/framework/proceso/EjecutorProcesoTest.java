package cmaccusco.rpando.framework.proceso;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledOnOs;
import org.junit.jupiter.api.condition.OS;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.concurrent.TimeoutException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** Prueba del propio framework (sin BD): ejecución de procesos externos. */
@EnabledOnOs(OS.WINDOWS)
class EjecutorProcesoTest {

    @Test
    void capturaCodigoDeSalidaYSalida(@TempDir Path directorio) throws Exception {
        Path archivo = Files.writeString(directorio.resolve("datos.txt"), "linea uno\r\nlinea dos\r\n");

        ResultadoProceso r = new EjecutorProceso().ejecutar("findstr.exe", "dos", archivo.toString());

        assertThat(r.codigoSalida()).isZero();
        assertThat(r.salida()).contains("linea dos").doesNotContain("linea uno");
    }

    @Test
    void codigoDistintoDeCeroNoLanzaExcepcion(@TempDir Path directorio) throws Exception {
        Path archivo = Files.writeString(directorio.resolve("datos.txt"), "linea uno\r\n");

        ResultadoProceso r = new EjecutorProceso().ejecutar("findstr.exe", "ausente", archivo.toString());

        assertThat(r.codigoSalida()).isEqualTo(1);
        assertThat(r.salida()).isEmpty();
    }

    @Test
    void exeInexistenteLanzaIOException() {
        assertThatThrownBy(() -> new EjecutorProceso().ejecutar("exe_que_no_existe_xyz.exe", "a", "b"))
                .isInstanceOf(IOException.class);
    }

    @Test
    void timeoutLanzaExcepcion() {
        EjecutorProceso proceso = new EjecutorProceso(Duration.ofSeconds(1));

        assertThatThrownBy(() -> proceso.ejecutar("ping.exe", "-n", "6", "127.0.0.1"))
                .isInstanceOf(TimeoutException.class)
                .hasMessageContaining("ping.exe");
    }
}
