package cmaccusco.rpando.framework.proceso;

/**
 * Resultado de un proceso externo.
 *
 * @param codigoSalida código con el que terminó el proceso
 * @param salida       stdout y stderr combinados
 */
public record ResultadoProceso(int codigoSalida, String salida) { }
