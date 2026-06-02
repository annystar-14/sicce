import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_alumno.dart';

class AlumnoLoginPage extends StatefulWidget {
  const AlumnoLoginPage({super.key});

  @override
  State<AlumnoLoginPage> createState() => _AlumnoLoginPageState();
}

class _AlumnoLoginPageState extends State<AlumnoLoginPage> {
  final TextEditingController curpController = TextEditingController();
  final TextEditingController matriculaController = TextEditingController();

  bool isLoading = false;
  String? error;

Future<void> loginAlumno() async {
  setState(() {
    isLoading = true;
    error = null;
  });

  try {
    final doc = await FirebaseFirestore.instance
        .collection('alumnos')
        .doc(matriculaController.text.trim())
        .get();
    print(doc.exists);   //
    print(doc.data());   ///
    if (!doc.exists) {
      setState(() {
        error = "Alumno no encontrado";
      });
    } else {
      final data = doc.data()!;

      print(data);       
print(data.keys);

      final curpDB = data['curp'].toString().trim().toUpperCase();
      final curpInput = curpController.text.trim().toUpperCase();

      print("DB: $curpDB");
      print("INPUT: $curpInput");

      if (curpDB == curpInput) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AlumnoHomePage(),
          ),
        );
      } else {
        setState(() {
          error = "CURP incorrecta";
        });
      }
    }
  } catch (e) {
    setState(() {
      error = "Error: $e";
    });
  }

  setState(() {
    isLoading = false;
  });
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
              controller: curpController,
              decoration: const InputDecoration(labelText: "CURP"),
            ),
            TextField(
              controller: matriculaController,
              decoration: const InputDecoration(labelText: "Matrícula"),
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