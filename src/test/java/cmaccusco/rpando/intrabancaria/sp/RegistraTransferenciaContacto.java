package cmaccusco.rpando.intrabancaria.sp;

import cmaccusco.rpando.framework.db.EjecutorSql;

import java.math.BigDecimal;
import java.sql.SQLException;

/**
 * Llamada a {@code dbo.spu_App_RegistraTransferenciaContacto}
 * (fuente: src/main/resources/sql/03_spu_App_RegistraTransferenciaContacto.sql).
 * <p>
 * Patrón GoF: <b>Command</b> (comportamiento). Encapsula el SP con sus parámetros; si la
 * firma del SP cambia, solo se modifica esta clase.
 */
public final class RegistraTransferenciaContacto {

    private static final String SP_SIN_OFFHOST =
            "{call spu_App_RegistraTransferenciaContacto(?,?,?,?,?,?,?,?,?,?)}";
    private static final String SP_CON_OFFHOST =
            "{call spu_App_RegistraTransferenciaContacto(?,?,?,?,?,?,?,?,?,?,?)}";

    private final String dniOrigen;
    private final String ctaCodOrigen;
    private final String dniDestino;
    private final String ctaCodDestino;
    private final BigDecimal monto;

    private int tipoIdOrigen = 1;
    private String canal = "91";
    private String usuario = "APP1";
    private int moneda = 1;
    private Boolean offHost = null; // null = no se envía @nOffHost (usa el valor por defecto del SP)

    private RegistraTransferenciaContacto(String dniOrigen, String ctaCodOrigen,
                                          String dniDestino, String ctaCodDestino, BigDecimal monto) {
        this.dniOrigen = dniOrigen;
        this.ctaCodOrigen = ctaCodOrigen;
        this.dniDestino = dniDestino;
        this.ctaCodDestino = ctaCodDestino;
        this.monto = monto;
    }

    public static RegistraTransferenciaContacto de(String dniOrigen, String ctaCodOrigen,
                                                   String dniDestino, String ctaCodDestino, BigDecimal monto) {
        return new RegistraTransferenciaContacto(dniOrigen, ctaCodOrigen, dniDestino, ctaCodDestino, monto);
    }

    public RegistraTransferenciaContacto conOffHost() {
        this.offHost = true;
        return this;
    }

    public RegistraTransferenciaContacto canal(String canal) {
        this.canal = canal;
        return this;
    }

    public RegistraTransferenciaContacto usuario(String usuario) {
        this.usuario = usuario;
        return this;
    }

    public RegistraTransferenciaContacto moneda(int moneda) {
        this.moneda = moneda;
        return this;
    }

    public RegistraTransferenciaContacto tipoIdOrigen(int tipoIdOrigen) {
        this.tipoIdOrigen = tipoIdOrigen;
        return this;
    }

    /** Ejecuta el SP y devuelve todos los campos de su SELECT final. */
    public RespuestaTransferencia ejecutar(EjecutorSql sql) throws SQLException {
        String llamada = offHost != null ? SP_CON_OFFHOST : SP_SIN_OFFHOST;
        return sql.ejecutarSp(llamada, cstmt -> {
            cstmt.setInt(1, tipoIdOrigen);
            cstmt.setString(2, dniOrigen);
            cstmt.setString(3, canal);
            cstmt.setDate(4, null);
            cstmt.setString(5, usuario);
            cstmt.setString(6, dniDestino);
            cstmt.setString(7, ctaCodDestino);
            cstmt.setString(8, ctaCodOrigen);
            cstmt.setInt(9, moneda);
            cstmt.setBigDecimal(10, monto);
            if (offHost != null) {
                cstmt.setBoolean(11, offHost);
            }
        }, RespuestaTransferencia.MAPEADOR).orElse(RespuestaTransferencia.VACIA);
    }
}
