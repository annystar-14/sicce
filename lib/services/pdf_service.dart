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

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Encabezado institucional
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

            // Información del alumno
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
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
                      pw.Text(alumno.nombre),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text(
                            "Matricula: ",
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(alumno.matricula),
                        ],
                      ),
                      pw.Row(
                        children: [
                          pw.Text(
                            "Grado/Grupo: ",
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text("${alumno.grado}° ${alumno.grupo}"),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Titulo de la tabla
            pw.Text(
              "Historial de Registros",
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex("#0D0E4A"),
              ),
            ),
            pw.SizedBox(height: 8),

            // Tabla de asistencia
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
              headers: ['Fecha', 'Entrada', 'Salida', 'Estado'],
              data: historial.map((reg) {
                String formatTime(DateTime? dt) {
                  if (dt == null) return "Pendiente";
                  final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
                  final min = dt.minute.toString().padLeft(2, '0');
                  final ampm = dt.hour >= 12 ? "PM" : "AM";
                  return "${hour.toString().padLeft(2, '0')}:$min $ampm";
                }

                String formatDate(String dateStr) {
                  try {
                    final parts = dateStr.split('-');
                    if (parts.length != 3) return dateStr;
                    return "${parts[2]}/${parts[1]}/${parts[0]}";
                  } catch (_) {
                    return dateStr;
                  }
                }

                return [
                  formatDate(reg.fecha),
                  formatTime(reg.entrada),
                  formatTime(reg.salida),
                  reg.estado,
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    // Mostrar vista de impresion/guardado nativo
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: "reporte_asistencias_${alumno.matricula}.pdf",
    );
  }
}
