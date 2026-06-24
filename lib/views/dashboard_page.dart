import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../viewmodels/dashboard_padre.dart';
import '../main.dart';

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
            icon: const Icon(Icons.logout),
            tooltip: "Cerrar sesión",
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

              if (confirm == true) {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const VistaPrincipal()),
                    (route) => false,
                  );
                }
              }
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
                            leading: const Icon(Icons.history),
                            title: const Text("Asistencias"),
                            subtitle: const Text(
                              "Consulta los registros biométricos del alumno.",
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () {
                              // Después aquí abrimos historial de asistencias del padre
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