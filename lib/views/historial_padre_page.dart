import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/alumnos.dart';
import '../viewmodels/asistencia.dart';
import '../services/pdf_service.dart';

const Color kColorPrincipalAzul = Color(0xFF194395);
const Color kColorAcentoRojo = Color(0xFFAE0E0F);
const Color kColorTextoOscuro = Color(0xFF0D0E4A);

class HistorialPadrePage extends StatefulWidget {
  final Alumno alumno;
  const HistorialPadrePage({super.key, required this.alumno});

  @override
  State<HistorialPadrePage> createState() => _HistorialPadrePageState();
}

class _HistorialPadrePageState extends State<HistorialPadrePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AsistenciaViewModel>().cargarAsistenciasAlumno(widget.alumno.matricula);
      }
    });
  }

  String _formatFecha(String fecha) {
    try {
      final partes = fecha.split('-');
      if (partes.length != 3) return fecha;
      return "${partes[2]}/${partes[1]}/${partes[0]}";
    } catch (_) {
      return fecha;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AsistenciaViewModel>();
    final nombreAlumno = widget.alumno.nombreCompleto.isNotEmpty
        ? widget.alumno.nombreCompleto
        : "${widget.alumno.nombre} ${widget.alumno.apellidos}";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Historial de Asistencias"),
        actions: [
          if (!vm.isLoading && vm.asistencias.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: "Exportar PDF",
              onPressed: () {
                PdfService.generarReportePdf(
                  alumno: widget.alumno,
                  historial: vm.asistencias,
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Banner con información del alumno
          Container(
            width: double.infinity,
            color: kColorPrincipalAzul.withOpacity(0.05),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombreAlumno,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kColorTextoOscuro,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Matrícula: ${widget.alumno.matricula}",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      "Grupo: ${widget.alumno.gradoGrupo}",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Lista de asistencias
          Expanded(
            child: vm.isLoading
                ? const Center(child: CircularProgressIndicator())
                : vm.error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 60, color: kColorAcentoRojo),
                              const SizedBox(height: 12),
                              Text(
                                vm.error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: kColorAcentoRojo),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  context.read<AsistenciaViewModel>().cargarAsistenciasAlumno(widget.alumno.matricula);
                                },
                                child: const Text("Reintentar"),
                              ),
                            ],
                          ),
                        ),
                      )
                    : vm.asistencias.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.fingerprint, size: 72, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                const Text(
                                  "Sin Registros",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: kColorTextoOscuro,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "No se han encontrado registros biométricos del alumno.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => context.read<AsistenciaViewModel>().cargarAsistenciasAlumno(widget.alumno.matricula),
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              itemCount: vm.asistencias.length,
                              itemBuilder: (context, index) {
                                final registro = vm.asistencias[index];
                                final retardo = registro.estado == "Retardo";
                                final falta = registro.estado == "Falta";

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: CircleAvatar(
                                      backgroundColor: retardo
                                          ? Colors.orange.withOpacity(0.1)
                                          : (falta ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1)),
                                      child: Icon(
                                        Icons.fingerprint,
                                        color: retardo
                                            ? Colors.orange
                                            : (falta ? Colors.red : Colors.green),
                                        size: 28,
                                      ),
                                    ),
                                    title: Text(
                                      _formatFecha(registro.fecha),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: kColorTextoOscuro,
                                        fontSize: 15,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        "Entrada: ${registro.entrada.isEmpty ? '-' : registro.entrada}\nSalida: ${registro.salida.isEmpty ? 'Pendiente' : registro.salida}",
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 13,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: retardo
                                            ? Colors.orange.withOpacity(0.1)
                                            : (falta ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        registro.estado,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: retardo
                                              ? Colors.orange
                                              : (falta ? Colors.red : Colors.green),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
