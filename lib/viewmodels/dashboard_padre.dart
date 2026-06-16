import 'package:flutter/material.dart';
import '../services/database.dart';
import '../models/alumnos.dart';

class DashboardPadreViewModel extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  Alumno? alumno;
  bool isLoading = false;
  String? error;

  Future<void> cargarAlumno() async {
    try {
      isLoading = true;
      error = null;
      alumno = null;
      notifyListeners();

      final data = await _db.obtenerAlumnoDelPadre();

      if (data != null) {
        alumno = Alumno.fromMap(data);
      } else {
        error = "No hay alumno vinculado";
      }
    } catch (e) {
      error = "Error al cargar alumno: $e";
    }

    isLoading = false;
    notifyListeners();
  }
}