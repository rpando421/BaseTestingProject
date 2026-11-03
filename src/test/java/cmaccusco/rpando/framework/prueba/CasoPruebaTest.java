package cmaccusco.rpando.framework.prueba;

import cmaccusco.rpando.framework.reporte.ExtensionReporte;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** Prueba del propio framework (sin BD): verificación suave y verificarIgual. */
@ExtendWith(ExtensionReporte.class)
class CasoPruebaTest {

    @Test
    void verificacionSuave_reportaTodosLosFallos() {
        CasoPrueba caso = new CasoPrueba(getClass(), "VerificacionSuave", "Dos campos fallan, uno pasa") {
            @Override
            protected void act() { }

            @Override
            protected void assertar() {
                verificarIgual("Respuesta", "00", "80");
                verificarIgual("Cuenta", "106172321000400249", "106172321000400249");
                verificarIgual("Mensaje", "OK", "Saldo insuficiente");
            }
        };

        assertThatThrownBy(caso::ejecutar)
                .isInstanceOf(AssertionError.class)
                .hasMessageContaining("Respuesta:")
                .hasMessageContaining("Mensaje:")
                .message().doesNotContain("Cuenta:");
    }

    @Test
    void verificarIgual_omiteEsperadoVacioYComparaNumerosPorValor() {
        CasoPrueba caso = new CasoPrueba(getClass(), "VerificarIgual", "Esperado vacío y números") {
            @Override
            protected void act() { }

            @Override
            protected void assertar() {
                verificarIgual("Sin esperado", "", "cualquier cosa");
                verificarIgual("Sin esperado (null)", null, "cualquier cosa");
                verificarIgual("Monto", "20", new BigDecimal("20.00"));
                verificarIgual("Entero", 5, 5);
            }
        };

        assertThatCode(caso::ejecutar).doesNotThrowAnyException();
    }

    @Test
    void verificarIgual_codigosDeTextoNoSeComparanComoNumero() {
        CasoPrueba caso = new CasoPrueba(getClass(), "CodigosTexto", "\"00\" no es igual a \"0\"") {
            @Override
            protected void act() { }

            @Override
            protected void assertar() {
                verificarIgual("Respuesta", "00", "0");
            }
        };

        assertThatThrownBy(caso::ejecutar)
                .isInstanceOf(AssertionError.class)
                .hasMessageContaining("\"00\"");
    }
}
