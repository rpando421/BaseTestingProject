package cmaccusco.rpando.offhost.sp;

/**
 * Parámetros OUTPUT de {@code InicioOFFHostDia}. Se usan {@link Integer} (no {@code int})
 * para conservar NULL si el SP no los asigna.
 */
public record ResultadoInicioOffHost(Integer nroOperaciones, Integer nroOperacionesProcesadas) { }
