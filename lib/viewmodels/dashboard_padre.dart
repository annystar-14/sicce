import 'package:flutter/material.dart';
import '../services/database.dart';
import '../models/alumnos.dart';

class DashboardPadreViewModel extends ChangeNotifier {

  final DatabaseService _db = DatabaseService();

  Alumno? alumno;

  bool isLoading = false;

  Future<void> cargarAlumno() async {

    isLoading = true;
    notifyListeners();

    final data = await _db.obtenerAlumnoDelPadre();

    if (data != null) {
      alumno = Alumno.fromMap(data);
    }

    isLoading = false;
    notifyListeners();
  }
}