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
  Map<String, Map<String, dynamic>> _calendarioEvents = {};

  Alumno? get alumno => _alumno;
  Asistencia? get todayAsistencia => _todayAsistencia;
  bool get isLoading => _isLoading;

  int get asistenciasCount => _asistenciasCount;
  int get retardosCount => _retardosCount;
  int get faltasCount => _faltasCount;

  List<Asistencia> get historial => _historial;
  Map<String, Map<String, dynamic>> get calendarioEvents => _calendarioEvents;

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

      // Cargar eventos del calendario escolar
      final calSnapshot = await FirebaseFirestore.instance
          .collection('calendario')
          .get();
      
      _calendarioEvents = {};
      for (var doc in calSnapshot.docs) {
        final data = doc.data();
        final fecha = data['fecha']?.toString();
        if (fecha != null) {
          _calendarioEvents[fecha] = data;
        }
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collection('asistencias_diarias')
          .where('matricula', isEqualTo: matricula)
          .get();

      _historial = [];
      _todayAsistencia = null;

      _asistenciasCount = 0;
      _retardosCount = 0;
      _faltasCount = 0;

      final list = querySnapshot.docs
          .map((doc) => Asistencia.fromMap(doc.data()))
          .toList();

      list.sort((a, b) => b.fecha.compareTo(a.fecha));
      _historial = list;

      for (var asistencia in _historial) {
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