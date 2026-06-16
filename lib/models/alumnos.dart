class Alumno {
  final String matricula;
  final String nombre;
  final String apellidos;
  final String nombreCompleto;
  final String correo;
  final String gradoGrupo;
  final String grado;
  final String grupo;
  final String sexo;
  final String telefono;
  final String direccion;
  final String cumpleanos;
  final String estadoHuella;
  final String padreId;

  Alumno({
      required this.matricula,
    required this.nombre,
    required this.apellidos,
    required this.nombreCompleto,
    required this.correo,
    required this.gradoGrupo,
    required this.grado,
    required this.grupo,
    required this.sexo,
    required this.telefono,
    required this.direccion,
    required this.cumpleanos,
    required this.estadoHuella,
    required this.padreId,
  });

  factory Alumno.fromMap(Map<String, dynamic> data) {
    return Alumno(
      matricula: data['matricula']?.toString() ?? '',
      nombre: data['nombre']?.toString() ?? '',
      apellidos: data['apellidos']?.toString() ?? '',
      nombreCompleto: data['nombreCompleto']?.toString() ?? '',
      correo: data['correo']?.toString() ?? '',
      gradoGrupo: data['gradoGrupo']?.toString() ?? '',
      grado: data['grado']?.toString() ?? '',
      grupo: data['grupo']?.toString() ?? '',
      sexo: data['sexo']?.toString() ?? '',
      telefono: data['telefono']?.toString() ?? '',
      direccion: data['direccion']?.toString() ?? '',
      cumpleanos: data['cumpleanos']?.toString() ?? '',
      estadoHuella: data['estadoHuella']?.toString() ?? '',
      padreId: data['padreId']?.toString() ?? '',
    );
  }
}