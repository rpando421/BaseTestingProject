package cmaccusco.rpando.dbtests.intrabancaria;


import java.math.BigDecimal;
import java.sql.CallableStatement;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvFileSource;

import static org.assertj.core.api.Assertions.assertThat;
import java.sql.SQLException;

import cmaccusco.rpando.dbtests.BaseDBTest;

public class TestTransferenciaXContacto extends BaseDBTest {
    @ParameterizedTest(name = "[{index}] - {5}")
    @CsvFileSource(resources = "/matriz_pruebas/transferencia_x_contacto_regular.csv", numLinesToSkip = 1)
    void test_NoOffHost(String dniOrigen, String ctaCodOrigen, String dniDestino, String ctaCodDestino, BigDecimal monto, String descripcion) throws SQLException {
        String estadoTest = "FAILED";
        String respuestaTransferencia = "";
        
        try {
            // ARRANGE
            BigDecimal saldoActual = BigDecimal.ZERO;
            BigDecimal saldoNuevo = BigDecimal.ZERO;
            String selectSql = "SELECT * FROM DBCMAC..Producto WITH(NOLOCK) WHERE cCtaCod = ?;";

            try (PreparedStatement stmt = conn.prepareStatement(selectSql)) {
                stmt.setString(1, ctaCodDestino);

                try (ResultSet rs = stmt.executeQuery()) {
                    if (rs.next()) {
                        saldoActual = rs.getBigDecimal("nSaldo");
                    }
                }
            }

            // ACT
            String spSql = "{call spu_App_RegistraTransferenciaContacto(?,?,?,?,?,?,?,?,?,?)}";
            try (CallableStatement cstmt = conn.prepareCall(spSql)) {
                cstmt.setInt(1, 1);
                cstmt.setString(2, dniOrigen);
                cstmt.setString(3, "91");
                cstmt.setDate(4, null);
                cstmt.setString(5, "APP1");
                cstmt.setString(6, dniDestino);
                cstmt.setString(7, ctaCodDestino);
                cstmt.setString(8, ctaCodOrigen);
                cstmt.setInt(9, 1);
                cstmt.setBigDecimal(10, monto);
                ResultSet rs = cstmt.executeQuery();

                if (rs.next()) {
                    respuestaTransferencia = rs.getString("cRespuesta");
                }
            }
            
            try (PreparedStatement stmt = conn.prepareStatement(selectSql)) {
                stmt.setString(1, ctaCodDestino);

                try (ResultSet rs = stmt.executeQuery()) {
                    if (rs.next()) {
                        saldoNuevo = rs.getBigDecimal("nSaldo");
                    }
                }
            }

            // ASSERT
            // - Transferencia exitosa
            assertThat(respuestaTransferencia).isEqualTo("80");
            // - Validar deposito en cuenta destino
            assertThat(saldoActual).isEqualByComparingTo(saldoNuevo);
            // - Validar retiro en cuenta origen
        } catch (Exception e) {
            estadoTest = "FAILED (" + e.getMessage() + ")";
            throw e;
        } finally {
            // AGREGAR REPORTE
        }
    }

    @ParameterizedTest(name = "[{index}] - {5}")
    @CsvFileSource(resources = "/matriz_pruebas/transferencia_x_contacto_regular.csv", numLinesToSkip = 1)
    void test_OffHost(String dniOrigen, String ctaCodOrigen, String dniDestino, String ctaCodDestino, BigDecimal monto, String descripcion) throws SQLException {
        String estadoTest = "FAILED";
        String respuestaTransferencia = "";
        
        try {
            // ARRANGE
            BigDecimal saldo = BigDecimal.ZERO;
            BigDecimal retencion = BigDecimal.ZERO;
            String selectSql = "SELECT * FROM DBCMAC..Producto WITH(NOLOCK) WHERE cCtaCod = ?;";
            String selectRetencionSql = "SELECT * FROM DBCMAC..CaptacAhorros WITH(NOLOCK) WHERE cCtaCod = ?;";

            // ACT
            String spSql = "{call spu_App_RegistraTransferenciaContacto(?,?,?,?,?,?,?,?,?,?,?)}";
            try (CallableStatement cstmt = conn.prepareCall(spSql)) {
                cstmt.setInt(1, 1);
                cstmt.setString(2, dniOrigen);
                cstmt.setString(3, "91");
                cstmt.setDate(4, null);
                cstmt.setString(5, "APP1");
                cstmt.setString(6, dniDestino);
                cstmt.setString(7, ctaCodDestino);
                cstmt.setString(8, ctaCodOrigen);
                cstmt.setInt(9, 1);
                cstmt.setBigDecimal(10, monto);
                cstmt.setBoolean(11, true);
                ResultSet rs = cstmt.executeQuery();

                if (rs.next()) {
                    respuestaTransferencia = rs.getString("cRespuesta");
                }
            }
            
            try (PreparedStatement stmt = conn.prepareStatement(selectSql)) {
                stmt.setString(1, ctaCodDestino);

                try (ResultSet rs = stmt.executeQuery()) {
                    if (rs.next()) {
                        saldo = rs.getBigDecimal("nSaldo");
                    }
                }
            }

            try (PreparedStatement stmt = conn.prepareStatement(selectRetencionSql)) {
                stmt.setString(1, ctaCodDestino);

                try (ResultSet rs = stmt.executeQuery()) {
                    if (rs.next()) {
                        retencion = rs.getBigDecimal("nRetencion");
                    }
                }
            }

            // ASSERT
            // - Transferencia exitosa
            assertThat(respuestaTransferencia).isEqualTo("00");
            // - Validar deposito en cuenta destino
            assertThat(saldo.subtract(retencion)).isEqualByComparingTo(saldo.add(monto));
            // - Validar retiro en cuenta origen
        } catch (Exception e) {
            estadoTest = "FAILED (" + e.getMessage() + ")";
            throw e;
        } finally {
            // AGREGAR REPORTE
        }
    }
}
