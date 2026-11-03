package cmaccusco.rpando.framework.reporte;

import org.apache.poi.ss.usermodel.BorderStyle;
import org.apache.poi.ss.usermodel.CellStyle;
import org.apache.poi.ss.usermodel.FillPatternType;
import org.apache.poi.ss.usermodel.Font;
import org.apache.poi.ss.usermodel.IndexedColors;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.ss.util.WorkbookUtil;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;

import java.io.IOException;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Reporte Excel (.xlsx): una hoja por escenario y una fila por caso del CSV.
 * Columnas: Descripción | Param: ... | &lt;verificación&gt; Esperado / Real ... | Estado | Detalle.
 */
public class EscritorReporteExcel implements EscritorReporte {

    @Override
    public Path escribir(Path directorio, String nombre, List<CasoReporte> casos) throws IOException {
        Files.createDirectories(directorio);
        Path archivo = directorio.resolve(nombre + ".xlsx");

        Map<String, List<CasoReporte>> porEscenario = new LinkedHashMap<>();
        for (CasoReporte caso : casos) {
            porEscenario.computeIfAbsent(caso.escenario(), k -> new ArrayList<>()).add(caso);
        }

        try (Workbook wb = new XSSFWorkbook(); OutputStream out = Files.newOutputStream(archivo)) {
            Estilos estilos = new Estilos(wb);
            for (Map.Entry<String, List<CasoReporte>> e : porEscenario.entrySet()) {
                escribirHoja(wb.createSheet(WorkbookUtil.createSafeSheetName(e.getKey())), e.getValue(), estilos);
            }
            wb.write(out);
        }
        return archivo;
    }

    private void escribirHoja(Sheet sheet, List<CasoReporte> casos, Estilos estilos) {
        // Unión ordenada de parámetros y verificaciones de todos los casos
        Set<String> parametros = new LinkedHashSet<>();
        Set<String> verificaciones = new LinkedHashSet<>();
        for (CasoReporte caso : casos) {
            parametros.addAll(caso.parametros().keySet());
            caso.verificaciones().forEach(v -> verificaciones.add(v.nombre()));
        }

        Row header = sheet.createRow(0);
        int col = 0;
        col = encabezado(header, col, "Descripción del caso", estilos.encabezado);
        for (String p : parametros) {
            col = encabezado(header, col, "Param: " + p, estilos.encabezado);
        }
        for (String v : verificaciones) {
            col = encabezado(header, col, v + " - Esperado", estilos.encabezado);
            col = encabezado(header, col, v + " - Real", estilos.encabezado);
        }
        col = encabezado(header, col, "Estado", estilos.encabezado);
        col = encabezado(header, col, "Detalle", estilos.encabezado);
        int totalColumnas = col;

        int fila = 1;
        for (CasoReporte caso : casos) {
            Row row = sheet.createRow(fila++);
            int c = 0;
            row.createCell(c++).setCellValue(caso.descripcion());
            for (String p : parametros) {
                row.createCell(c++).setCellValue(caso.parametros().getOrDefault(p, ""));
            }
            Map<String, CasoReporte.Verificacion> vs = new LinkedHashMap<>();
            caso.verificaciones().forEach(v -> vs.put(v.nombre(), v));
            for (String v : verificaciones) {
                CasoReporte.Verificacion ver = vs.get(v);
                row.createCell(c++).setCellValue(ver != null ? ver.esperado() : "");
                row.createCell(c++).setCellValue(ver != null ? ver.real() : "");
            }
            var celdaEstado = row.createCell(c++);
            celdaEstado.setCellValue(caso.estado().name());
            celdaEstado.setCellStyle(caso.estado() == CasoReporte.Estado.PASSED ? estilos.ok : estilos.error);
            row.createCell(c).setCellValue(caso.detalleError());
        }

        sheet.createFreezePane(1, 1);
        for (int i = 0; i < totalColumnas; i++) {
            sheet.autoSizeColumn(i);
        }
    }

    private static int encabezado(Row row, int col, String texto, CellStyle estilo) {
        var cell = row.createCell(col);
        cell.setCellValue(texto);
        cell.setCellStyle(estilo);
        return col + 1;
    }

    private static final class Estilos {
        final CellStyle encabezado;
        final CellStyle ok;
        final CellStyle error;

        Estilos(Workbook wb) {
            Font negrita = wb.createFont();
            negrita.setBold(true);

            encabezado = wb.createCellStyle();
            encabezado.setFont(negrita);
            encabezado.setBorderBottom(BorderStyle.MEDIUM);
            encabezado.setFillForegroundColor(IndexedColors.GREY_25_PERCENT.getIndex());
            encabezado.setFillPattern(FillPatternType.SOLID_FOREGROUND);

            ok = wb.createCellStyle();
            ok.setFont(negrita);
            ok.setFillForegroundColor(IndexedColors.LIGHT_GREEN.getIndex());
            ok.setFillPattern(FillPatternType.SOLID_FOREGROUND);

            error = wb.createCellStyle();
            error.setFont(negrita);
            error.setFillForegroundColor(IndexedColors.ROSE.getIndex());
            error.setFillPattern(FillPatternType.SOLID_FOREGROUND);
        }
    }
}
