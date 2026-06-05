import 'package:cloud_firestore/cloud_firestore.dart';

class Asistencia {
  final String fecha; // Formato: yyyy-MM-dd
  final DateTime? entrada;
  final DateTime? salida;
  final String estado; // 'Asistencia', 'Retardo', 'Falta', 'Pendiente'

  Asistencia({
    required this.fecha,
    this.entrada,
    this.salida,
    required this.estado,
  });

  factory Asistencia.fromMap(Map<String, dynamic> data) {
    return Asistencia(
      fecha: data['fecha'] ?? '',
      entrada: data['entrada'] != null ? (data['entrada'] as Timestamp).toDate() : null,
      salida: data['salida'] != null ? (data['salida'] as Timestamp).toDate() : null,
      estado: data['estado'] ?? 'Pendiente',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fecha': fecha,
      'entrada': entrada != null ? Timestamp.fromDate(entrada!) : null,
      'salida': salida != null ? Timestamp.fromDate(salida!) : null,
      'estado': estado,
    };
  }
}
