import 'package:flutter/material.dart';


class AlumnoHomePage extends StatelessWidget {
  const AlumnoHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SICCE - Alumno"),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // BIENVENIDA
            const Text(
              "Hola, (nombre alumno) 👋",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              "Matricula: (matricula alumno)",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 25),

             // TARJETA DATOS ALUMNO
            _buildCard(
              title: "Datos del Alumno",
              icon: Icons.school,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("Grado: 4°"),
                  SizedBox(height: 5),
                  Text("Grupo: B"),
                ],
              ),
            ),

            // TARJETA ASISTENCIA
            _buildCard(
              title: "Tus asistencias",
              icon: Icons.access_time,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("Entrada: 7:01 AM"),
                  SizedBox(height: 5),
                  Text("Salida: Pendiente"),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // TARJETA NOTIFICACIONES
            _buildCard(
              title: "Notificaciones",
              icon: Icons.notifications,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("• Retardo registrado"),
                  SizedBox(height: 5),
                  Text("• Aviso escolar disponible"),
                ],
              ),
            ),

            const SizedBox(height: 20),

          ],
        ),
      ),
    );
  }

  // WIDGET TARJETA
  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),

                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            child,
          ],
        ),
      ),
    );
  }
}