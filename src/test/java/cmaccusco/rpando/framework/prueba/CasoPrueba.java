package cmaccusco.rpando.framework.prueba;

import cmaccusco.rpando.framework.reporte.CasoReporte;
import cmaccusco.rpando.framework.reporte.RegistroReporte;

/**
 * Esqueleto de un caso de prueba (una fila del CSV).
 * <p>
 * Patrón GoF: <b>Template Method</b> (comportamiento). {@link #ejecutar()} fija el orden
 * ARRANGE → ACT → ASSERT y siempre registra el resultado para el reporte; cada prueba
 * solo implementa los tres pasos.
 *
 * <pre>{@code
 * new CasoPrueba(getClass(), "Escenario", descripcion) {
 *     BigDecimal saldoAntes;
 *     protected void arrange() throws Exception { saldoAntes = sql.consultarValor(...); }
 *     protected void act()     throws Exception { respuesta = sql.ejecutarSp(...); }
 *     protected void assertar() throws Exception {
 *         verificar("Respuesta", "00", respuesta, () -> assertThat(respuesta).isEqualTo("00"));
 *     }
 * }.parametro("Monto", monto).ejecutar();
 * }</pre>
 */
public abstract class CasoPrueba {

    private final Class<?> clasePrueba;
    private final CasoReporte.Builder reporte;

    protected CasoPrueba(Class<?> clasePrueba, String escenario, String descripcion) {
        this.clasePrueba = clasePrueba;
        this.reporte = CasoReporte.builder(escenario, descripcion);
    }

    /** ARRANGE: preparar y leer el estado inicial (normalmente consultas SELECT). */
    protected void arrange() throws Exception { }

    /** ACT: ejecutar la acción bajo prueba (normalmente un procedimiento almacenado). */
    protected abstract void act() throws Exception;

    /** ASSERT: leer el estado final (SELECT) y comprobar resultados con {@link #verificar}. */
    protected abstract void assertar() throws Exception;

    /** Registra un dato de entrada del CSV para que aparezca en el reporte. */
    public final CasoPrueba parametro(String nombre, Object valor) {
        reporte.parametro(nombre, valor);
        return this;
    }

    /**
     * Anota en el reporte lo esperado vs. lo obtenido y ejecuta la aserción.
     * Si la aserción falla, el caso queda FAILED con el mensaje de error.
     */
    protected final void verificar(String nombre, Object esperado, Object real, Runnable asercion) {
        reporte.verificacion(nombre, esperado, real);
        asercion.run();
    }

    /** Método plantilla: no se sobrescribe. */
    public final void ejecutar() throws Exception {
        try {
            arrange();
            act();
            assertar();
            reporte.exitoso();
        } catch (Exception | AssertionError e) {
            reporte.fallido(e);
            throw e;
        } finally {
            RegistroReporte.registrar(clasePrueba, reporte.construir());
        }
    }
}
