import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> guardarUsuario({
    required String uid,
    required String nombre,
    required String email,
    required String rol,
  }) async {
    await _db.collection('usuarios').doc(uid).set({
      'nombre': nombre,
      'email': email,
      'rol': rol,
    });
  }

  Future<String> vincularAlumno(String matricula) async {
    final doc = await _db
        .collection('zktime_empleados')
        .doc(matricula.trim())
        .get();

    if (!doc.exists) {
      return "Alumno no encontrado en el biométrico";
    }

    final data = doc.data()!;

    if (data.containsKey('padreId') &&
        data['padreId'] != null &&
        data['padreId'] != "") {
      return "Alumno ya vinculado";
    }

    return "ok";
  }

  Future<Map<String, dynamic>?> obtenerAlumnoDelPadre() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final query = await _db
        .collection('zktime_empleados')
        .where('padreId', isEqualTo: uid)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return null;
    }

    return query.docs.first.data();
  }

  Stream<List<Map<String, dynamic>>> obtenerAsistenciasAlumno(
    String matricula,
  ) {
    return _db
        .collection('asistencias')
        .where('matricula', isEqualTo: matricula.trim())
        .orderBy('fechaHora', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Stream<Map<String, dynamic>?> obtenerUltimaAsistenciaAlumno(
    String matricula,
  ) {
    return _db
        .collection('asistencias')
        .where('matricula', isEqualTo: matricula.trim())
        .orderBy('fechaHora', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return null;
      }

      return snapshot.docs.first.data();
    });
  }
}