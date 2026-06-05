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

  Future<void> cargarDatos() async {
    if (_alumno == null) return;
    final matricula = _alumno!.matricula;

    _isLoading = true;
    notifyListeners();

    try {
      final fechaHoy = _getFechaHoy();
      
      // 1. Cargar asistencia de hoy
      final docHoy = await FirebaseFirestore.instance
          .collection('asistencias')
          .doc('${matricula}_$fechaHoy')
          .get();

      if (docHoy.exists) {
        _todayAsistencia = Asistencia.fromMap(docHoy.data()!);
      } else {
        _todayAsistencia = null;
      }

      // 2. Cargar historial completo
      final querySnapshot = await FirebaseFirestore.instance
          .collection('asistencias')
          .where('matricula', isEqualTo: matricula)
          .get();

      final now = DateTime.now();
      final prefijoMes = "${now.year}-${now.month.toString().padLeft(2, '0')}";

      _asistenciasCount = 0;
      _retardosCount = 0;
      _faltasCount = 0;
      _historial = [];

      for (var doc in querySnapshot.docs) {
        final asistencia = Asistencia.fromMap(doc.data());
        _historial.add(asistencia);

        // Contar estadísticas si pertenece al mes actual
        if (asistencia.fecha.startsWith(prefijoMes)) {
          if (asistencia.estado == 'Asistencia') {
            _asistenciasCount++;
          } else if (asistencia.estado == 'Retardo') {
            _retardosCount++;
          } else if (asistencia.estado == 'Falta') {
            _faltasCount++;
          }
        }
      }

      // Ordenar historial por fecha descendente
      _historial.sort((a, b) => b.fecha.compareTo(a.fecha));

    } catch (e) {
      print("Error al cargar datos del alumno: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> registrarEntrada() async {
    if (_alumno == null) return;
    final matricula = _alumno!.matricula;
    final fechaHoy = _getFechaHoy();

    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      String estado = 'Asistencia';
      
      // Umbral: después de las 07:05 AM es Retardo
      if (now.hour > 7 || (now.hour == 7 && now.minute > 5)) {
        estado = 'Retardo';
      }

      final nuevaAsistencia = Asistencia(
        fecha: fechaHoy,
        entrada: now,
        salida: null,
        estado: estado,
      );

      final docRef = FirebaseFirestore.instance
          .collection('asistencias')
          .doc('${matricula}_$fechaHoy');

      await docRef.set({
        'matricula': matricula,
        ...nuevaAsistencia.toMap(),
      });

      // Recargar datos
      await cargarDatos();
    } catch (e) {
      print("Error al registrar entrada: $e");
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> registrarSalida() async {
    if (_alumno == null) return;
    final matricula = _alumno!.matricula;
    final fechaHoy = _getFechaHoy();

    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      final docRef = FirebaseFirestore.instance
          .collection('asistencias')
          .doc('${matricula}_$fechaHoy');

      await docRef.update({
        'salida': Timestamp.fromDate(now),
      });

      // Recargar datos
      await cargarDatos();
    } catch (e) {
      print("Error al registrar salida: $e");
      _isLoading = false;
      notifyListeners();
    }
  }
}
