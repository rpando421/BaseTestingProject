package cmaccusco.rpando.intrabancaria.sp;

import cmaccusco.rpando.framework.db.MapeadorFila;

/**
 * SELECT final de {@code spu_App_RegistraTransferenciaContacto}:
 * {@code cRespuesta, cMensaje, nIdAutoriza, cNomEntidad, cNombreAp, cCtaCodOrigen}.
 * Para validar un campo nuevo, agréguelo aquí y en {@link #MAPEADOR}.
 */
public record RespuestaTransferencia(
        String cRespuesta,
        String cMensaje,
        String nIdAutoriza,
        String cNomEntidad,
        String cNombreAp,
        String cCtaCodOrigen) {

    public static final MapeadorFila<RespuestaTransferencia> MAPEADOR = rs -> new RespuestaTransferencia(
            rs.getString("cRespuesta"),
            rs.getString("cMensaje"),
            rs.getString("nIdAutoriza"),
            rs.getString("cNomEntidad"),
            rs.getString("cNombreAp"),
            rs.getString("cCtaCodOrigen"));

    /** Respuesta usada cuando el SP no devuelve filas. */
    public static final RespuestaTransferencia VACIA = new RespuestaTransferencia(null, null, null, null, null, null);
}
