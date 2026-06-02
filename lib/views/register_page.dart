import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth.dart';

class RegisterPage extends StatelessWidget {
  final nombreController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final matriculaController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<AuthViewModel>(context);

    return Scaffold(
      appBar: AppBar(title: Text("Registro SICCE")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: nombreController,
              decoration: InputDecoration(labelText: "Nombre"),
            ),
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: "Correo"),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: "Contraseña"),
            ),
            TextField(
              controller: matriculaController,
              decoration: InputDecoration(labelText: "Matrícula del alumno"),
            ),
            SizedBox(height: 20),

            vm.isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: () async {
                      bool success = await vm.registerCompleto(
                        nombreController.text.trim(),
                        emailController.text.trim(),
                        passwordController.text.trim(),
                        matriculaController.text.trim(),
                      );

                      if (success) {
                        Navigator.pop(context);
                      }
                    },
                    child: Text("Registrarse"),
                  ),

            if (vm.error != null)
              Text(vm.error!, style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}