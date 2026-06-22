import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/dashboard_padre.dart';
import 'notificaciones_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      context.read<DashboardPadreViewModel>().cargarAlumno();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DashboardPadreViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("SICCE - Padre de Familia"),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            tooltip: "Notificaciones",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificacionesPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : vm.alumno == null
              ? const Center(child: Text("No hay alumno vinculado"))
              : RefreshIndicator(
                  onRefresh: () => vm.cargarAlumno(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Alumno vinculado",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 20),

                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.school),
                                  ),
                                  title: Text(
                                    vm.alumno!.nombreCompleto.isNotEmpty
                                        ? vm.alumno!.nombreCompleto
                                        : "${vm.alumno!.nombre} ${vm.alumno!.apellidos}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  subtitle: Text(
                                    "Matrícula: ${vm.alumno!.matricula}",
                                  ),
                                ),

                                const Divider(),

                                _infoItem(
                                  Icons.grade_outlined,
                                  "Grado / Grupo",
                                  vm.alumno!.gradoGrupo,
                                ),
                                _infoItem(
                                  Icons.email_outlined,
                                  "Correo",
                                  vm.alumno!.correo,
                                ),
                                _infoItem(
                                  Icons.fingerprint,
                                  "Estado de huella",
                                  vm.alumno!.estadoHuella,
                                ),
                                _infoItem(
                                  Icons.phone_outlined,
                                  "Teléfono",
                                  vm.alumno!.telefono,
                                ),
                                _infoItem(
                                  Icons.home_outlined,
                                  "Dirección",
                                  vm.alumno!.direccion,
                                ),
                                _infoItem(
                                  Icons.cake_outlined,
                                  "Cumpleaños",
                                  vm.alumno!.cumpleanos,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.notifications_active),
                            title: const Text("Notificaciones"),
                            subtitle: const Text(
                              "Consulta las entradas y salidas registradas.",
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const NotificacionesPage(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _infoItem(IconData icon, String label, String value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(
        value.isEmpty ? "Sin información" : value,
      ),
    );
  }
}