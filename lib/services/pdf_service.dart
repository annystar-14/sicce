import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/alumnos.dart';
import '../models/asistencia.dart';

class PdfService {
  static Future<void> generarReportePdf({
    required Alumno alumno,
    required List<Asistencia> historial,
  }) async {
    final pdf = pw.Document();

    String formatearFecha(String fecha) {
      try {
        final p = fecha.split('-');
        if (p.length != 3) return fecha;
        return "${p[2]}/${p[1]}/${p[0]}";
      } catch (_) {
        return fecha;
      }
    }

    String valor(String value) {
      return value.trim().isEmpty ? "Pendiente" : value;
    }

    final nombreAlumno = alumno.nombreCompleto.isNotEmpty
        ? alumno.nombreCompleto
        : "${alumno.nombre} ${alumno.apellidos}";

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "COLEGIO DE BACHILLERES",
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex("#194395"),
                      ),
                    ),
                    pw.Text(
                      "Reporte de Asistencias - SICCE",
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  DateTime.now().toString().substring(0, 10),
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            ),

            pw.Divider(thickness: 2, color: PdfColor.fromHex("#194395")),
            pw.SizedBox(height: 15),

            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(
                  pw.Radius.circular(8),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Text(
                        "Alumno: ",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(nombreAlumno),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text(
                            "Matrícula: ",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(alumno.matricula),
                        ],
                      ),
                      pw.Row(
                        children: [
                          pw.Text(
                            "Grado/Grupo: ",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(alumno.gradoGrupo),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            pw.Text(
              "Historial de Asistencias",
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex("#0D0E4A"),
              ),
            ),

            pw.SizedBox(height: 8),

            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex("#194395"),
              ),
              rowDecoration: const pw.BoxDecoration(
                color: PdfColors.grey50,
              ),
              cellHeight: 25,
              cellAlignment: pw.Alignment.centerLeft,
              headers: [
                'Fecha',
                'Entrada',
                'Salida',
                'Estado',
              ],
              data: historial.map((reg) {
                return [
                  formatearFecha(reg.fecha),
                  valor(reg.entrada),
                  valor(reg.salida),
                  reg.estado,
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: "reporte_asistencias_${alumno.matricula}.pdf",
    );
  }
}