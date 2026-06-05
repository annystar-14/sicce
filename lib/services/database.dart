import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

//no utilice librerias de auth y core por la logica

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
    final query = await FirebaseFirestore.instance
        .collection('alumnos')
        .where('matricula', isEqualTo: matricula.trim())
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return "Alumno no encontrado";
    }

    final data = query.docs.first.data();

    if (data.containsKey('padreId') &&
        data['padreId'] != null &&
        data['padreId'] != "") {
      return "Alumno ya vinculado";
    }

    return "ok";
  }

  //consulta

  Future<Map<String, dynamic>?> obtenerAlumnoDelPadre() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final query = await FirebaseFirestore.instance
        .collection('alumnos')
        .where('padreId', isEqualTo: uid)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return null;
    }

    return query.docs.first.data();
  }
}