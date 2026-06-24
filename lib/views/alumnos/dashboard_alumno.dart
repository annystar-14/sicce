import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/alumnos.dart';
import '../../models/asistencia.dart';
import '../../viewmodels/dashboard_alumno.dart';
import '../../services/pdf_service.dart';

const Color kColorPrincipalAzul = Color(0xFF194395);
const Color kColorAcentoRojo = Color(0xFFAE0E0F);
const Color kColorTextoOscuro = Color(0xFF0D0E4A);
const Color kColorFondoGrisClaro = Color(0xFFF2F2F3);

class AlumnoHomePage extends StatefulWidget {
  final Alumno alumno;

  const AlumnoHomePage({
    super.key,
    required this.alumno,
  });

  @override
  State<AlumnoHomePage> createState() => _AlumnoHomePageState();
}

class _AlumnoHomePageState extends State<AlumnoHomePage> {
  int _currentIndex = 0;
  bool _verCalendario = false;
  DateTime _calendarMonth = DateTime.now();
  Map<String, dynamic>? _selectedDayEvent;
  String? _selectedDayAttendance;

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      final vm = Provider.of<DashboardAlumnoViewModel>(
        context,
        listen: false,
      );

      vm.setAlumno(widget.alumno);
      vm.cargarDatos();
    });
  }

  String _formatFecha(String fechaHora) {
    try {
      final fecha = fechaHora.split(' ')[0];
      final p = fecha.split('-');

      if (p.length != 3) return fechaHora;

      return "${p[2]}/${p[1]}/${p[0]}";
    } catch (_) {
      return fechaHora;
    }
  }

  String _formatHora(String fechaHora) {
    try {
      final partes = fechaHora.split(' ');
      if (partes.length < 2) return "Sin hora";

      final hora = partes[1].split(':');
      final hour24 = int.parse(hora[0]);
      final min = hora[1];

      final hour12 = hour24 == 0
          ? 12
          : (hour24 > 12 ? hour24 - 12 : hour24);

      final ampm = hour24 >= 12 ? "PM" : "AM";

      return "${hour12.toString().padLeft(2, '0')}:$min $ampm";
    } catch (_) {
      return fechaHora;
    }
  }

  bool _esRetardo(String fechaHora) {
    try {
      final partes = fechaHora.split(' ');
      if (partes.length < 2) return false;

      final hora = partes[1].split(':');
      final hour = int.parse(hora[0]);
      final min = int.parse(hora[1]);

      return hour > 7 || (hour == 7 && min > 5);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<DashboardAlumnoViewModel>(context);

    final tabs = [
      _buildInicio(vm),
      _buildHistorial(vm),
      _buildAvisos(),
      _buildPerfil(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentIndex == 0
              ? "SICCE - Alumno"
              : _currentIndex == 1
                  ? "Historial Biométrico"
                  : _currentIndex == 2
                      ? "Avisos Escolares"
                      : "Mi Perfil",
        ),
        automaticallyImplyLeading: false,
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
  final ultima = vm.todayAsistencia;

  return SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderAlumno(),
        const SizedBox(height: 24),

        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ultima == null
                ? const Text("No hay registro biométrico de hoy")
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Registro de hoy",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: kColorTextoOscuro,
                        ),
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Icon(
                            Icons.fingerprint,
                            size: 34,
                            color: ultima.estado == "Retardo"
                                ? Colors.orange
                                : Colors.green,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatFecha(ultima.fecha),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Text("Entrada: ${ultima.entrada}"),
                                Text(
                                  "Salida: ${ultima.salida.isEmpty ? "Pendiente" : ultima.salida}",
                                ),
                                Text(
                                  "Estado: ${ultima.estado}",
                                  style: TextStyle(
                                    color: ultima.estado == "Retardo"
                                        ? Colors.orange
                                        : Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  ultima.origen,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 24),

        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
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
                    _buildStatItem(
                      "Asistencias",
                      vm.asistenciasCount,
                      Colors.green,
                    ),
                    _buildStatItem(
                      "Retardos",
                      vm.retardosCount,
                      Colors.orange,
                    ),
                    _buildStatItem(
                      "Faltas",
                      vm.faltasCount,
                      Colors.red,
                    ),
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

 Widget _buildHeaderAlumno() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [
          kColorPrincipalAzul,
          Color(0xFF2C5EBA),
        ],
      ),
      borderRadius: BorderRadius.circular(16),
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
                widget.alumno.nombreCompleto.isNotEmpty
                    ? widget.alumno.nombreCompleto
                    : "${widget.alumno.nombre} ${widget.alumno.apellidos}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Matrícula: ${widget.alumno.matricula}",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
              ),
              Text(
                "Grado/Grupo: ${widget.alumno.gradoGrupo}",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
              ),
              Text(
                widget.alumno.correo,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildHistorial(DashboardAlumnoViewModel vm) {
  return Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  "Historial",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kColorTextoOscuro,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(_verCalendario ? Icons.list : Icons.calendar_month, color: kColorPrincipalAzul),
                  tooltip: _verCalendario ? "Ver en lista" : "Ver en calendario",
                  onPressed: () {
                    setState(() {
                      _verCalendario = !_verCalendario;
                      _selectedDayEvent = null;
                      _selectedDayAttendance = null;
                    });
                  },
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => PdfService.generarReportePdf(
                alumno: widget.alumno,
                historial: vm.historial,
              ),
              icon: const Icon(
                Icons.picture_as_pdf,
                size: 18,
                color: Colors.white,
              ),
              label: const Text(
                "PDF",
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kColorPrincipalAzul,
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: _verCalendario
            ? SingleChildScrollView(child: _buildCalendario(vm))
            : (vm.historial.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fingerprint, size: 60, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        const Text(
                          "No hay registros biométricos aún",
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => setState(() => _verCalendario = true),
                          icon: const Icon(Icons.calendar_month),
                          label: const Text("Ver calendario escolar"),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: vm.historial.length,
                    itemBuilder: (context, index) {
                      final registro = vm.historial[index];
                      final retardo = registro.estado == "Retardo";
                      final falta = registro.estado == "Falta";

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Icon(
                            Icons.fingerprint,
                            color: retardo
                                ? Colors.orange
                                : (falta ? Colors.red : Colors.green),
                            size: 36,
                          ),
                          title: Text(
                            _formatFecha(registro.fecha),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "Entrada: ${registro.entrada.isEmpty ? '-' : registro.entrada}\nSalida: ${registro.salida.isEmpty ? "Pendiente" : registro.salida}",
                            style: TextStyle(
                              color: retardo
                                  ? Colors.orange
                                  : (falta ? Colors.red : Colors.green),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: Text(
                            registro.estado,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  )),
      ),
    ],
  );
}

Widget _buildCalendario(DashboardAlumnoViewModel vm) {
  final weekDays = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"];
  final year = _calendarMonth.year;
  final month = _calendarMonth.month;

  final firstDayOfMonth = DateTime(year, month, 1);
  final totalDays = DateTime(year, month + 1, 0).day;
  final startWeekday = firstDayOfMonth.weekday;

  final paddingCells = startWeekday - 1;
  final totalCells = paddingCells + totalDays;

  final monthNames = [
    "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
    "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"
  ];

  return Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: kColorPrincipalAzul),
              onPressed: () {
                setState(() {
                  _calendarMonth = DateTime(year, month - 1, 1);
                  _selectedDayEvent = null;
                  _selectedDayAttendance = null;
                });
              },
            ),
            Text(
              "${monthNames[month - 1]} $year",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: kColorTextoOscuro,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: kColorPrincipalAzul),
              onPressed: () {
                setState(() {
                  _calendarMonth = DateTime(year, month + 1, 1);
                  _selectedDayEvent = null;
                  _selectedDayAttendance = null;
                });
              },
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekDays.map((day) => Expanded(
            child: Center(
              child: Text(
                day,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),
          )).toList(),
        ),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1,
          ),
          itemCount: totalCells,
          itemBuilder: (context, index) {
            if (index < paddingCells) {
              return const SizedBox.shrink();
            }

            final dayNum = index - paddingCells + 1;
            final cellDateStr = "$year-${month.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}";

            final asistenciasHoy = vm.historial.where((a) => a.fecha == cellDateStr).toList();
            final asistencia = asistenciasHoy.isNotEmpty ? asistenciasHoy.first : null;
            final event = vm.calendarioEvents[cellDateStr];

            Color cellBg = Colors.white;
            Color borderCol = Colors.grey[200]!;
            Color textCol = kColorTextoOscuro;
            IconData? cellIcon;
            Color iconCol = Colors.transparent;

            if (event != null) {
              if (event['tipo'] == 'suspension') {
                cellBg = const Color(0xFFF3E5F5);
                borderCol = Colors.purple[300]!;
                textCol = Colors.purple[900]!;
                cellIcon = Icons.event_busy;
                iconCol = Colors.purple;
              } else if (event['tipo'] == 'puente') {
                cellBg = const Color(0xFFE3F2FD);
                borderCol = Colors.blue[300]!;
                textCol = Colors.blue[900]!;
                cellIcon = Icons.alt_route;
                iconCol = Colors.blue;
              } else {
                cellBg = const Color(0xFFFFF8E1);
                borderCol = Colors.amber[300]!;
                textCol = Colors.amber[900]!;
                cellIcon = Icons.star;
                iconCol = Colors.amber[800]!;
              }
            } else if (asistencia != null) {
              if (asistencia.estado == "Asistencia") {
                cellBg = const Color(0xFFE8F5E9);
                borderCol = Colors.green[300]!;
                textCol = Colors.green[900]!;
                cellIcon = Icons.check;
                iconCol = Colors.green;
              } else if (asistencia.estado == "Retardo") {
                cellBg = const Color(0xFFFFF3E0);
                borderCol = Colors.orange[300]!;
                textCol = Colors.orange[900]!;
                cellIcon = Icons.access_time;
                iconCol = Colors.orange;
              } else if (asistencia.estado == "Falta") {
                cellBg = const Color(0xFFFFEBEE);
                borderCol = Colors.red[300]!;
                textCol = Colors.red[900]!;
                cellIcon = Icons.close;
                iconCol = Colors.red;
              }
            }

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDayEvent = event;
                  if (asistencia != null) {
                    _selectedDayAttendance =
                        "Entrada: ${asistencia.entrada.isNotEmpty ? asistencia.entrada : '-'}\nSalida: ${asistencia.salida.isNotEmpty ? asistencia.salida : 'Pendiente'}\nEstado: ${asistencia.estado}";
                  } else {
                    _selectedDayAttendance = null;
                  }
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: cellBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderCol, width: 1.5),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        dayNum.toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textCol,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (cellIcon != null)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Icon(
                          cellIcon,
                          size: 11,
                          color: iconCol,
                        ),
                      )
                  ],
                ),
              ),
            );
          },
        ),
      ),
      if (_selectedDayEvent != null || _selectedDayAttendance != null)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: Colors.white,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedDayEvent != null) ...[
                    Row(
                      children: [
                        Icon(
                          _selectedDayEvent!['tipo'] == 'suspension'
                              ? Icons.event_busy
                              : _selectedDayEvent!['tipo'] == 'puente'
                                  ? Icons.alt_route
                                  : Icons.star,
                          color: kColorPrincipalAzul,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _selectedDayEvent!['tipo'] == 'suspension'
                              ? "Suspensión de Clases"
                              : _selectedDayEvent!['tipo'] == 'puente'
                                  ? "Fin de Semana Largo / Puente"
                                  : "Día Festivo",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: kColorTextoOscuro,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedDayEvent!['descripcion'] ?? "Sin descripción",
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (_selectedDayAttendance != null)
                      const Divider(height: 20),
                  ],
                  if (_selectedDayAttendance != null) ...[
                    const Row(
                      children: [
                        Icon(Icons.fingerprint, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          "Registro Biométrico",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: kColorTextoOscuro,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedDayAttendance!,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ),
    ],
  );
}

  Widget _buildAvisos() {
    final avisos = [
      {
        "titulo": "Registro biométrico",
        "cuerpo":
            "Tus asistencias ahora se registran mediante lector de huella digital.",
        "fecha": "Hoy",
      },
      {
        "titulo": "Revisión de asistencias",
        "cuerpo":
            "Recuerda verificar tus registros dentro del historial de SICCE.",
        "fecha": "Reciente",
      },
    ];

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: avisos.length,
      itemBuilder: (context, index) {
        final aviso = avisos[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            title: Text(
              aviso["titulo"]!,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: kColorPrincipalAzul,
              ),
            ),
            subtitle: Text(aviso["cuerpo"]!),
            trailing: Text(aviso["fecha"]!),
          ),
        );
      },
    );
  }

 Widget _buildPerfil() {
  return SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(20),
    child: Column(
      children: [
        const CircleAvatar(
          radius: 50,
          child: Icon(Icons.school, size: 56),
        ),
        const SizedBox(height: 16),

        Text(
          widget.alumno.nombreCompleto.isNotEmpty
              ? widget.alumno.nombreCompleto
              : "${widget.alumno.nombre} ${widget.alumno.apellidos}",
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: kColorTextoOscuro,
          ),
        ),

        const SizedBox(height: 6),
        Text("Matrícula: ${widget.alumno.matricula}"),
        const SizedBox(height: 24),

        Card(
          child: Column(
            children: [
              _buildProfileField(
                Icons.email_outlined,
                "Correo",
                widget.alumno.correo,
              ),
              const Divider(height: 1),
              _buildProfileField(
                Icons.grade_outlined,
                "Grado",
                "${widget.alumno.grado}°",
              ),
              const Divider(height: 1),
              _buildProfileField(
                Icons.group_outlined,
                "Grupo",
                widget.alumno.grupo,
              ),
              const Divider(height: 1),
              _buildProfileField(
                Icons.fingerprint,
                "Estado de huella",
                widget.alumno.estadoHuella,
              ),
              const Divider(height: 1),
              _buildProfileField(
                Icons.phone_outlined,
                "Teléfono",
                widget.alumno.telefono,
              ),
              const Divider(height: 1),
              _buildProfileField(
                Icons.home_outlined,
                "Dirección",
                widget.alumno.direccion,
              ),
              const Divider(height: 1),
              _buildProfileField(
                Icons.cake_outlined,
                "Cumpleaños",
                widget.alumno.cumpleanos,
              ),
            ],
          ),
        ),

        const SizedBox(height: 30),

        ElevatedButton.icon(
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text("Cerrar Sesión"),
                content: const Text("¿Estás seguro de que deseas salir?"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Cancelar"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text("Salir"),
                  ),
                ],
              ),
            );

            if (confirm == true && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          icon: const Icon(Icons.logout, color: Colors.white),
          label: const Text(
            "Cerrar sesión",
            style: TextStyle(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: kColorAcentoRojo,
          ),
        ),
      ],
    ),
  );
}

  Widget _buildStatItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label),
      ],
    );
  }

  Widget _buildProfileField(
    IconData icon,
    String label,
    String value,
  ) {
    return ListTile(
      leading: Icon(icon, color: kColorPrincipalAzul),
      title: Text(label),
      subtitle: Text(value),
    );
  }
}