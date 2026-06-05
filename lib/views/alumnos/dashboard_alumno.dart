import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/alumnos.dart';
import '../../viewmodels/dashboard_alumno.dart';
import '../../services/pdf_service.dart';

const Color kColorPrincipalAzul = Color(0xFF194395);
const Color kColorAcentoRojo = Color(0xFFAE0E0F);
const Color kColorTextoOscuro = Color(0xFF0D0E4A);
const Color kColorFondoGrisClaro = Color(0xFFF2F2F3);

class AlumnoHomePage extends StatefulWidget {
  final Alumno alumno;
  const AlumnoHomePage({super.key, required this.alumno});

  @override
  State<AlumnoHomePage> createState() => _AlumnoHomePageState();
}

class _AlumnoHomePageState extends State<AlumnoHomePage> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final vm = Provider.of<DashboardAlumnoViewModel>(context, listen: false);
      vm.setAlumno(widget.alumno);
      vm.cargarDatos();
    });
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return "Pendiente";
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? "PM" : "AM";
    return "${hour.toString().padLeft(2, '0')}:$min $ampm";
  }

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return dateStr;
      // retornar dd/mm/yyyy
      return "${parts[2]}/${parts[1]}/${parts[0]}";
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<DashboardAlumnoViewModel>(context);

    final List<Widget> tabs = [
      _buildInicio(vm),
      _buildHistorial(vm),
      _buildAvisos(vm),
      _buildPerfil(vm),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentIndex == 0
              ? "SICCE - Alumno"
              : _currentIndex == 1
                  ? "Historial de Asistencias"
                  : _currentIndex == 2
                      ? "Avisos Escolares"
                      : "Mi Perfil",
        ),
        automaticallyImplyLeading: false, // Quitar botón de retroceso automático
      ),
      body: vm.isLoading && vm.historial.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => vm.cargarDatos(),
              child: tabs[_currentIndex],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: kColorPrincipalAzul,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: "Inicio",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: "Historial",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications),
            label: "Avisos",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: "Perfil",
          ),
        ],
      ),
    );
  }

  Widget _buildInicio(DashboardAlumnoViewModel vm) {
    final today = vm.todayAsistencia;
    final hasEntrada = today?.entrada != null;
    final hasSalida = today?.salida != null;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Tarjeta superior: Perfil rápido
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kColorPrincipalAzul, Color(0xFF2C5EBA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: kColorPrincipalAzul.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: const Icon(
                    Icons.person,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.alumno.nombre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${widget.alumno.grado}° ${widget.alumno.grupo}  |  Matrícula: ${widget.alumno.matricula}",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. Tarjeta central: Asistencia de hoy
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Asistencia de Hoy",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kColorTextoOscuro,
                    ),
                  ),
                  const Divider(height: 24),
                  
                  // Estado de entrada
                  Row(
                    children: [
                      Icon(
                        hasEntrada ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: hasEntrada
                            ? (today?.estado == 'Retardo' ? Colors.orange : Colors.green)
                            : Colors.grey,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasEntrada
                                ? "Entrada Registrada (${today?.estado})"
                                : "Entrada Pendiente",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: hasEntrada ? kColorTextoOscuro : Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasEntrada
                                ? _formatTime(today?.entrada)
                                : "--:--",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Estado de salida
                  Row(
                    children: [
                      Icon(
                        hasSalida ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: hasSalida ? Colors.green : Colors.grey,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasSalida ? "Salida Registrada" : "Salida Pendiente",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: hasSalida ? kColorTextoOscuro : Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasSalida
                                ? _formatTime(today?.salida)
                                : "--:--",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Botón principal dinámico
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: vm.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : !hasEntrada
                            ? ElevatedButton.icon(
                                onPressed: () => vm.registrarEntrada(),
                                icon: const Icon(Icons.login, color: Colors.white),
                                label: const Text(
                                  "REGISTRAR ENTRADA",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[600],
                                  padding: EdgeInsets.zero,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              )
                            : !hasSalida
                                ? ElevatedButton.icon(
                                    onPressed: () => vm.registrarSalida(),
                                    icon: const Icon(Icons.logout, color: Colors.white),
                                    label: const Text(
                                      "REGISTRAR SALIDA",
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: kColorAcentoRojo,
                                      padding: EdgeInsets.zero,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  )
                                : OutlinedButton.icon(
                                    onPressed: null, // Deshabilitado
                                    icon: const Icon(Icons.check_circle_outline, color: Colors.grey),
                                    label: const Text(
                                      "JORNADA COMPLETADA",
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.grey),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 3. Tarjeta inferior: Resumen mensual
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Resumen del mes",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kColorTextoOscuro,
                    ),
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem("Asistencias", vm.asistenciasCount, Colors.green),
                      _buildStatItem("Retardos", vm.retardosCount, Colors.orange),
                      _buildStatItem("Faltas", vm.faltasCount, Colors.red),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            value.toString(),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildHistorial(DashboardAlumnoViewModel vm) {
    if (vm.historial.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "No hay registros de asistencia aún",
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Tus Registros",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: kColorTextoOscuro,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => PdfService.generarReportePdf(
                  alumno: widget.alumno,
                  historial: vm.historial,
                ),
                icon: const Icon(Icons.picture_as_pdf, size: 18, color: Colors.white),
                label: const Text(
                  "Exportar PDF",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kColorPrincipalAzul,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: vm.historial.length,
            itemBuilder: (context, index) {
              final registro = vm.historial[index];
              
              Color statusColor = Colors.green;
              IconData statusIcon = Icons.check_circle;
              if (registro.estado == 'Retardo') {
                statusColor = Colors.orange;
                statusIcon = Icons.access_time_filled;
              } else if (registro.estado == 'Falta') {
                statusColor = Colors.red;
                statusIcon = Icons.cancel;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Icon(statusIcon, color: statusColor, size: 36),
                  title: Text(
                    _formatDate(registro.fecha),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "Estado: ${registro.estado}",
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "E: ${_formatTime(registro.entrada)}",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "S: ${_formatTime(registro.salida)}",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAvisos(DashboardAlumnoViewModel vm) {
    // Lista de avisos estáticos institucionales pero muy realistas
    final List<Map<String, String>> avisosFijos = [
      {
        "titulo": "Suspensión de labores docentes",
        "cuerpo": "Se les informa que el día de mañana no habrá clases por motivo de la Junta de Consejo Técnico Escolar. Las clases se reanudarán en el horario habitual al día siguiente.",
        "fecha": "Hoy"
      },
      {
        "titulo": "Inicio de Evaluaciones del Segundo Parcial",
        "cuerpo": "Las evaluaciones correspondientes al segundo parcial darán inicio el próximo lunes. Les recomendamos presentarse puntualmente y con su uniforme y credencial escolar.",
        "fecha": "Ayer"
      },
      {
        "titulo": "Mantenimiento del Lector Biométrico",
        "cuerpo": "El lector de huellas digitales del pórtico principal estará en mantenimiento preventivo. Durante este periodo, favor de registrar su asistencia escaneando el código QR con el personal de guardia.",
        "fecha": "Hace 3 días"
      }
    ];

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      itemCount: avisosFijos.length,
      itemBuilder: (context, index) {
        final aviso = avisosFijos[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        aviso["titulo"]!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: kColorPrincipalAzul,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        aviso["fecha"]!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Text(
                  aviso["cuerpo"]!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPerfil(DashboardAlumnoViewModel vm) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          const SizedBox(height: 10),
          CircleAvatar(
            radius: 50,
            backgroundColor: kColorPrincipalAzul.withOpacity(0.1),
            child: const Icon(
              Icons.school,
              size: 56,
              color: kColorPrincipalAzul,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.alumno.nombre,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: kColorTextoOscuro,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Matrícula: ${widget.alumno.matricula}",
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  _buildProfileField(Icons.assignment_ind_outlined, "CURP", widget.alumno.curp),
                  const Divider(height: 1),
                  _buildProfileField(Icons.grade_outlined, "Grado", "${widget.alumno.grado}° Semestre"),
                  const Divider(height: 1),
                  _buildProfileField(Icons.group_outlined, "Grupo", widget.alumno.grupo),
                ],
              ),
            ),
          ),
          const SizedBox(height: 36),
          
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                // Cerrar sesión: remover la pantalla del stack de navegación y volver a la principal
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text(
                "Cerrar Sesión",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kColorAcentoRojo,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileField(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: kColorPrincipalAzul, size: 24),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  color: kColorTextoOscuro,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}