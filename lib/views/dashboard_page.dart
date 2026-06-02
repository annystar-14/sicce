import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/dashboard_padre.dart';

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
      context.read<DashboardPadreViewModel>()
          .cargarAlumno();
    });
  }

  @override
  Widget build(BuildContext context) {

    final vm = context.watch<DashboardPadreViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("SICCE - padre de familia"),
      ),
      body: vm.isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : vm.alumno == null
              ? const Center(
                  child: Text(
                    "No hay alumno vinculado",
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [

                      Text(
                        "Alumno vinculado",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 20),

                      Card(
                        child: ListTile(
                          title: Text(
                            vm.alumno!.nombre,
                          ),
                          subtitle: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [

                              Text(
                                "Matrícula: ${vm.alumno!.matricula}",
                              ),

                              Text(
                                "Grado: ${vm.alumno!.grado}",
                              ),

                              Text(
                                "Grupo: ${vm.alumno!.grupo}",
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}