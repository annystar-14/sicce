import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/alumnos.dart';
import 'dashboard_alumno.dart';

class AlumnoLoginPage extends StatefulWidget {
  const AlumnoLoginPage({super.key});

  @override
  State<AlumnoLoginPage> createState() => _AlumnoLoginPageState();
}

class _AlumnoLoginPageState extends State<AlumnoLoginPage> {
  final TextEditingController correoController = TextEditingController();
  final TextEditingController matriculaController = TextEditingController();

  bool isLoading = false;
  String? error;

  Future<void> loginAlumno() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final correoInput = correoController.text.trim().toLowerCase();
      final matriculaInput = matriculaController.text.trim();

      final query = await FirebaseFirestore.instance
          .collection('zktime_empleados')
          .where('correo', isEqualTo: correoInput)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setState(() {
          error = "Correo no encontrado";
        });
      } else {
        final data = query.docs.first.data();

        final matriculaDB = data['matricula']?.toString().trim() ?? '';

        if (matriculaDB == matriculaInput) {
          final alumno = Alumno.fromMap(data);

          if (!mounted) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AlumnoHomePage(alumno: alumno),
            ),
          );
        } else {
          setState(() {
            error = "Matrícula incorrecta";
          });
        }
      }
    } catch (e) {
      setState(() {
        error = "Error: $e";
      });
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    correoController.dispose();
    matriculaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Alumno - SICCE"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: correoController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Correo",
              ),
            ),
            TextField(
              controller: matriculaController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Matrícula",
              ),
            ),
            const SizedBox(height: 20),
            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: loginAlumno,
                    child: const Text("Entrar"),
                  ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}