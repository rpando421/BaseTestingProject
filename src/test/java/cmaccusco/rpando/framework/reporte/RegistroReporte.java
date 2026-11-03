package cmaccusco.rpando.framework.reporte;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Acumula los {@link CasoReporte} de cada clase de prueba hasta que
 * {@link ExtensionReporte} los escribe al finalizar la clase.
 */
public final class RegistroReporte {

    private static final Map<Class<?>, List<CasoReporte>> CASOS = new ConcurrentHashMap<>();

    private RegistroReporte() { }

    public static void registrar(Class<?> clasePrueba, CasoReporte caso) {
        CASOS.computeIfAbsent(clasePrueba, k -> Collections.synchronizedList(new ArrayList<>())).add(caso);
    }

    /** Devuelve y elimina los casos registrados para la clase. */
    public static List<CasoReporte> extraer(Class<?> clasePrueba) {
        List<CasoReporte> casos = CASOS.remove(clasePrueba);
        return casos != null ? casos : List.of();
    }
}
