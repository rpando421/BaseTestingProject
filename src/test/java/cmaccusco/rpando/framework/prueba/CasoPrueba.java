package cmaccusco.rpando.framework.prueba;

import cmaccusco.rpando.framework.reporte.CasoReporte;
import cmaccusco.rpando.framework.reporte.RegistroReporte;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

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
    private final List<String> fallos = new ArrayList<>();

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
     * <p>
     * Verificación <b>suave</b>: si la aserción falla se guarda el error y se continúa con
     * las siguientes, así el reporte muestra todos los campos. Al terminar ASSERT, si hubo
     * fallos, el caso queda FAILED con todos los mensajes.
     */
    protected final void verificar(String nombre, Object esperado, Object real, Runnable asercion) {
        reporte.verificacion(nombre, esperado, real);
        try {
            asercion.run();
        } catch (AssertionError e) {
            String mensaje = e.getMessage() != null ? e.getMessage().replaceAll("\\s+", " ").trim() : "falló";
            fallos.add(nombre + ": " + mensaje);
        }
    }

    /**
     * Compara {@code esperado} con {@code real}. Si {@code esperado} es null o vacío
     * (celda vacía en el CSV) la verificación se omite.
     * Si alguno es numérico se compara por valor ({@code "20"} == {@code 20.00});
     * si ambos son texto se comparan como texto ({@code "00"} != {@code "0"}).
     */
    protected final void verificarIgual(String nombre, Object esperado, Object real) {
        if (esperado == null || esperado.toString().isBlank()) {
            return;
        }
        verificar(nombre, esperado, real, () -> {
            // Solo se compara como número si uno de los dos ya es numérico (p.ej. saldo BigDecimal).
            // Dos textos se comparan como texto: el código "00" no es igual a "0".
            boolean hayNumero = esperado instanceof Number || real instanceof Number;
            BigDecimal esperadoNum = hayNumero ? comoNumero(esperado) : null;
            BigDecimal realNum = hayNumero ? comoNumero(real) : null;
            if (esperadoNum != null && realNum != null) {
                assertThat(realNum).as(nombre).isEqualByComparingTo(esperadoNum);
            } else {
                assertThat(real != null ? real.toString().trim() : null).as(nombre)
                        .isEqualTo(esperado.toString().trim());
            }
        });
    }

    private static BigDecimal comoNumero(Object valor) {
        if (valor == null) {
            return null;
        }
        try {
            return new BigDecimal(valor.toString().trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    /** Método plantilla: no se sobrescribe. */
    public final void ejecutar() throws Exception {
        try {
            arrange();
            act();
            assertar();
            if (!fallos.isEmpty()) {
                throw new AssertionError(String.join(" | ", fallos));
            }
            reporte.exitoso();
        } catch (Exception | AssertionError e) {
            reporte.fallido(e);
            throw e;
        } finally {
            RegistroReporte.registrar(clasePrueba, reporte.construir());
        }
    }
}
