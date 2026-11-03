package cmaccusco.rpando.framework.reporte;

import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Resultado de un caso de prueba (una fila del CSV) tal como se muestra en el reporte.
 * <p>
 * Patrón GoF: <b>Builder</b> (creacional). Los datos se van agregando durante
 * ARRANGE/ACT/ASSERT y el objeto inmutable se construye al final con {@link Builder#construir()}.
 */
public final class CasoReporte {

    public enum Estado { PASSED, FAILED }

    /** Una comprobación individual del ASSERT: qué se esperaba y qué se obtuvo. */
    public record Verificacion(String nombre, String esperado, String real) { }

    private final String escenario;
    private final String descripcion;
    private final Map<String, String> parametros;
    private final List<Verificacion> verificaciones;
    private final Estado estado;
    private final String detalleError;

    private CasoReporte(Builder b) {
        this.escenario = b.escenario;
        this.descripcion = b.descripcion;
        this.parametros = Collections.unmodifiableMap(new LinkedHashMap<>(b.parametros));
        this.verificaciones = List.copyOf(b.verificaciones);
        this.estado = b.estado;
        this.detalleError = b.detalleError;
    }

    public static Builder builder(String escenario, String descripcion) {
        return new Builder(escenario, descripcion);
    }

    public String escenario() { return escenario; }
    public String descripcion() { return descripcion; }
    public Map<String, String> parametros() { return parametros; }
    public List<Verificacion> verificaciones() { return verificaciones; }
    public Estado estado() { return estado; }
    public String detalleError() { return detalleError; }

    public static final class Builder {
        private final String escenario;
        private final String descripcion;
        private final Map<String, String> parametros = new LinkedHashMap<>();
        private final List<Verificacion> verificaciones = new ArrayList<>();
        private Estado estado = Estado.FAILED;
        private String detalleError = "";

        private Builder(String escenario, String descripcion) {
            this.escenario = escenario;
            this.descripcion = descripcion;
        }

        public Builder parametro(String nombre, Object valor) {
            parametros.put(nombre, texto(valor));
            return this;
        }

        public Builder verificacion(String nombre, Object esperado, Object real) {
            verificaciones.add(new Verificacion(nombre, texto(esperado), texto(real)));
            return this;
        }

        public Builder exitoso() {
            this.estado = Estado.PASSED;
            this.detalleError = "";
            return this;
        }

        public Builder fallido(Throwable error) {
            this.estado = Estado.FAILED;
            this.detalleError = error.getMessage() != null ? error.getMessage() : error.getClass().getSimpleName();
            return this;
        }

        public CasoReporte construir() {
            return new CasoReporte(this);
        }

        private static String texto(Object valor) {
            return valor != null ? valor.toString() : "NULL";
        }
    }
}
