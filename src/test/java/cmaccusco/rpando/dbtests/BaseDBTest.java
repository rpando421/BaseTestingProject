package cmaccusco.rpando.dbtests;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;

import java.io.FileOutputStream;
import java.io.IOException;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public abstract class BaseDBTest {
    private static HikariDataSource dataSource;
    protected Connection conn;

    protected static final List<CasoReporte> resultadosReporte = new ArrayList<>();

    protected static class CasoReporte {
        String descripcion;
        Map<String, String> parametros = new LinkedHashMap<>();
        double esperado;
        double actual;
        String estado;

        public CasoReporte(String descripcion, double esperado, double actual, String estado) {
            this.descripcion = descripcion;
            this.esperado = esperado;
            this.actual = actual;
            this.estado = estado;
        }

        public void agregarParametro(String nombre, Object valor) {
            this.parametros.put(nombre, valor != null ? valor.toString() : "NULL");
        }
    }

    @BeforeAll
    static void initDataSource() {
        HikariConfig config = new HikariConfig();
        config.setJdbcUrl("jdbc:sqlserver://svrdesasql01;databaseName=DBTarjeta;encrypt=false;trustServerCertificate=true;");
        config.setUsername("userUBA");
        config.setPassword("Ub@nc@us3r#2");
        config.setAutoCommit(false);
        config.setMaximumPoolSize(5);
        dataSource = new HikariDataSource(config);
    }

    @BeforeEach
    void openConnectionForEachTest() throws SQLException {
        this.conn = dataSource.getConnection();
        this.conn.setAutoCommit(false);
    }

    @AfterEach
    void rollbackAndCloseForEachTest() {
        if (this.conn != null) {
            try {
                this.conn.rollback();
            } catch (SQLException e) {
                System.err.println("Error rolling back: " + e.getMessage());
            } finally {
                try {
                    this.conn.close();
                } catch (SQLException e) {
                    System.err.println("Error closing connection: " + e.getMessage());
                }
            }
        }
    }

    @AfterAll
    static void generarReporteExcel() {
        System.out.println("Generando reporte plano por columnas en Excel...");
        String rutaArchivo = "target/Reporte_Cobertura_Tabular.xlsx";

        if (resultadosReporte.isEmpty()) return;

        try (Workbook workbook = new XSSFWorkbook();
             FileOutputStream fileOut = new FileOutputStream(rutaArchivo)) {

            Sheet sheet = workbook.createSheet("Resultados de Cobertura");

            // Estilos para encabezados
            CellStyle headerStyle = workbook.createCellStyle();
            Font fontHeader = workbook.createFont();
            fontHeader.setBold(true);
            headerStyle.setFont(fontHeader);
            headerStyle.setBorderBottom(BorderStyle.MEDIUM);

            // 1. Identificar dinámicamente los nombres de los parámetros del primer caso
            List<String> nombresParametros = new ArrayList<>(resultadosReporte.get(0).parametros.keySet());

            // 2. Construir la fila de encabezados dinámicamente
            Row headerRow = sheet.createRow(0);
            int colIndex = 0;

            headerRow.createCell(colIndex++).setCellValue("Descripción del Caso");

            // Crear una columna para cada parámetro detectado
            for (String nombreParam : nombresParametros) {
                headerRow.createCell(colIndex++).setCellValue("Param: " + nombreParam);
            }

            headerRow.createCell(colIndex++).setCellValue("Valor Esperado");
            headerRow.createCell(colIndex++).setCellValue("Valor Real");
            headerRow.createCell(colIndex++).setCellValue("Estado");

            // Aplicar estilo negrita a todos los encabezados creados
            for (int i = 0; i < colIndex; i++) {
                headerRow.getCell(i).setCellStyle(headerStyle);
            }

            // 3. Escribir los datos: Estrictamente una fila por caso ejecutado
            int rowNum = 1;
            for (CasoReporte caso : resultadosReporte) {
                Row row = sheet.createRow(rowNum++);
                int c = 0;

                // Columna Descripción
                row.createCell(c++).setCellValue(caso.descripcion);

                // Columnas de Parámetros Dinámicos
                for (String nombreParam : nombresParametros) {
                    String valor = caso.parametros.getOrDefault(nombreParam, "");
                    row.createCell(c++).setCellValue(valor);
                }

                // Columnas Finales de Resultados
                row.createCell(c++).setCellValue(caso.esperado);
                row.createCell(c++).setCellValue(caso.actual);
                row.createCell(c++).setCellValue(caso.estado);
            }

            // Autoajustar el ancho de todas las columnas utilizadas
            for (int i = 0; i < colIndex; i++) {
                sheet.autoSizeColumn(i);
            }

            workbook.write(fileOut);
            System.out.println("¡Reporte tabular generado con éxito en: " + rutaArchivo + "!");

        } catch (IOException e) {
            System.err.println("Error escribiendo el archivo Excel: " + e.getMessage());
        } finally {
            if (dataSource != null) {
                dataSource.close();
            }
        }
    }
}
