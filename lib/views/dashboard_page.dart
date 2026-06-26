import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../viewmodels/dashboard_padre.dart';
import '../main.dart';
import 'mensajes_tutor_page.dart';
import 'historial_padre_page.dart';

const Color kColorPrincipalAzul = Color(0xFF194395);
const Color kColorAcentoRojo = Color(0xFFAE0E0F);
const Color kColorTextoOscuro = Color(0xFF0D0E4A);

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

    // Guardar token FCM del dispositivo para recibir notificaciones
    _registrarTokenFCM();

    // Actualizar token si Firebase lo rota
    FirebaseMessaging.instance.onTokenRefresh.listen(_guardarTokenEnFirestore);
  }

  Future<void> _registrarTokenFCM() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _guardarTokenEnFirestore(token);
      }
    } catch (e) {
      // Silencioso — no crítico
    }
  }

  Future<void> _guardarTokenEnFirestore(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('usuarios').doc(uid).set(
      {'fcmToken': token},
      SetOptions(merge: true),
    );
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
                                  builder: (_) => HistorialPadrePage(
                                    alumno: vm.alumno!,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 16),

                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('mensajes_tutores')
                              .where('idTutor', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                              .where('leido', isEqualTo: false)
                              .snapshots(),
                          builder: (context, snapshot) {
                            int unreadCount = 0;
                            if (snapshot.hasData) {
                              unreadCount = snapshot.data!.docs.length;
                            }

                            return Card(
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: kColorPrincipalAzul,
                                  child: Icon(Icons.mail_outline, color: Colors.white),
                                ),
                                title: const Text(
                                  "Mensajes de Dirección",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: kColorTextoOscuro,
                                  ),
                                ),
                                subtitle: const Text(
                                  "Consulta los avisos enviados sobre tu hijo.",
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (unreadCount > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: kColorAcentoRojo,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          "$unreadCount",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_forward_ios),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const MensajesTutorPage(),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
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