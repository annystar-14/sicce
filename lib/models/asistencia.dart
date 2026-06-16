class Asistencia {
  final String matricula;
  final String nombre;
  final String fecha;
  final String entrada;
  final String salida;
  final String estado;
  final String origen;

  Asistencia({
    required this.matricula,
    required this.nombre,
    required this.fecha,
    required this.entrada,
    required this.salida,
    required this.estado,
    required this.origen,
  });

  factory Asistencia.fromMap(Map<String, dynamic> data) {
    return Asistencia(
      matricula: data['matricula']?.toString() ?? '',
      nombre: data['nombre']?.toString() ?? '',
      fecha: data['fecha']?.toString() ?? '',
      entrada: data['entrada']?.toString() ?? '',
      salida: data['salida']?.toString() ?? '',
      estado: data['estado']?.toString() ?? 'Pendiente',
      origen: data['origen']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'matricula': matricula,
      'nombre': nombre,
      'fecha': fecha,
      'entrada': entrada,
      'salida': salida,
      'estado': estado,
      'origen': origen,
    };
  }
}