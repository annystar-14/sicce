import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/alumnos.dart';
import '../models/asistencia.dart';

class DashboardAlumnoViewModel extends ChangeNotifier {
  Alumno? _alumno;
  Asistencia? _todayAsistencia;
  bool _isLoading = false;

  int _asistenciasCount = 0;
  int _retardosCount = 0;
  int _faltasCount = 0;

  List<Asistencia> _historial = [];

  Alumno? get alumno => _alumno;
  Asistencia? get todayAsistencia => _todayAsistencia;
  bool get isLoading => _isLoading;

  int get asistenciasCount => _asistenciasCount;
  int get retardosCount => _retardosCount;
  int get faltasCount => _faltasCount;

  List<Asistencia> get historial => _historial;

  void setAlumno(Alumno al) {
    _alumno = al;
  }

  String _getFechaHoy() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  String _getMesActual() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}";
  }

  Future<void> cargarDatos() async {
    if (_alumno == null) return;

    final matricula = _alumno!.matricula;

    _isLoading = true;
    notifyListeners();

    try {
      final fechaHoy = _getFechaHoy();
      final mesActual = _getMesActual();

      final querySnapshot = await FirebaseFirestore.instance
          .collection('asistencias_diarias')
          .where('matricula', isEqualTo: matricula)
          .orderBy('fecha', descending: true)
          .get();

      _historial = [];
      _todayAsistencia = null;

      _asistenciasCount = 0;
      _retardosCount = 0;
      _faltasCount = 0;

      for (var doc in querySnapshot.docs) {
        final asistencia = Asistencia.fromMap(doc.data());

        _historial.add(asistencia);

        if (asistencia.fecha == fechaHoy) {
          _todayAsistencia = asistencia;
        }

        if (asistencia.fecha.startsWith(mesActual)) {
          if (asistencia.estado == "Retardo") {
            _retardosCount++;
          } else if (asistencia.estado == "Falta") {
            _faltasCount++;
          } else {
            _asistenciasCount++;
          }
        }
      }
    } catch (e) {
      print("Error al cargar datos del alumno: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  // SOLO PARA PRUEBAS MANUALES
  Future<void> registrarEntradaPrueba() async {
    if (_alumno == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();

      final fecha =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final hora =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

      final docId = "${_alumno!.matricula}_$fecha";

      await FirebaseFirestore.instance
          .collection('asistencias_diarias')
          .doc(docId)
          .set({
        'matricula': _alumno!.matricula,
        'nombre': _alumno!.nombreCompleto,
        'fecha': fecha,
        'entrada': hora,
        'salida': '',
        'estado': 'Asistencia',
        'origen': 'App SICCE prueba',
      }, SetOptions(merge: true));

      await cargarDatos();
    } catch (e) {
      print("Error al registrar entrada de prueba: $e");
      _isLoading = false;
      notifyListeners();
    }
  }
}