import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/asistencia.dart';

class AsistenciaViewModel extends ChangeNotifier {
  bool isLoading = false;
  String? error;

  List<Asistencia> asistencias = [];

  Future<void> cargarAsistenciasAlumno(String matricula) async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();

      final query = await FirebaseFirestore.instance
          .collection('asistencias_diarias')
          .where('matricula', isEqualTo: matricula)
          .orderBy('fecha', descending: true)
          .get();

      asistencias = query.docs
          .map((doc) => Asistencia.fromMap(doc.data()))
          .toList();

      isLoading = false;
      notifyListeners();
    } catch (e) {
      error = "Error al cargar asistencias: $e";
      isLoading = false;
      notifyListeners();
    }
  }
}