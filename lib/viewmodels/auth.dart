import 'package:flutter/material.dart';
import '../services/auth.dart';
import '../services/database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService _auth = AuthService();
  final DatabaseService _db = DatabaseService();

  bool isLoading = false;
  String? error;

  // LOGIN
  Future<bool> login(String email, String password) async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();

      final user = await _auth.login(email, password);

      if (user != null) {
        await asegurarUsuarioFirestore();
      }

      isLoading = false;
      notifyListeners();

      return user != null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-credential') {
        error = "Correo o contraseña incorrectos";
      } else if (e.code == 'user-not-found') {
        error = "Usuario no encontrado";
      } else if (e.code == 'wrong-password') {
        error = "Contraseña incorrecta";
      } else if (e.code == 'invalid-email') {
        error = "Correo inválido";
      } else {
        error = "Error de autenticación";
      }

      isLoading = false;
      notifyListeners();

      return false;
    } catch (e) {
      error = "Ocurrió un error inesperado";

      isLoading = false;
      notifyListeners();

      return false;
    }
  }

  // función para crear un usuario en Firestore cuando no está registrado
  Future<void> asegurarUsuarioFirestore() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid);

    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({
        "nombre": "",
        "email": user.email,
        "rol": "padre",
        "createdAt": FieldValue.serverTimestamp(),
      });
    }
  }

  // REGISTRO
  Future<bool> registerCompleto(
    String nombre,
    String email,
    String password,
    String matricula,
  ) async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();

      final validacion = await _db.vincularAlumno(matricula);

      if (validacion != "ok") {
        error = validacion;

        isLoading = false;
        notifyListeners();

        return false;
      }

      final user = await _auth.register(email, password);

      if (user == null) {
        error = "No se puede crear el usuario";
        isLoading = false;
        notifyListeners();

        return false;
      }

      await _db.guardarUsuario(
        uid: user.uid,
        nombre: nombre,
        email: email,
        rol: "padre",
      );

      final alumnoQuery = await FirebaseFirestore.instance
          .collection('alumnos')
          .where('matricula', isEqualTo: matricula.trim())
          .limit(1)
          .get();

      if (alumnoQuery.docs.isNotEmpty) {
        await alumnoQuery.docs.first.reference.update({
          'padreId': user.uid,
          'estadoHuella': 'pendiente',
        });
      }

      isLoading = false;
      notifyListeners();

      return true;
    } catch (e) {
      error = e.toString();

      isLoading = false;
      notifyListeners();

      return false;
    }
  }
}