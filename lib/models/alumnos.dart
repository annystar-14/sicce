
class Alumno{
  final String matricula;
  final String nombre;
  final String curp;
  final String grado;
  final String grupo; 

  Alumno({
    required this.matricula,
    required this.nombre,
    required this.curp,
    required this.grado,
    required this.grupo,
  });

  //mapeo de las propiedades
  factory Alumno.fromMap(Map<String, dynamic> data) {
    return Alumno(
      matricula: data['matricula'] ?? '',
      nombre: data['nombre'] ?? '',
      curp: data['curp'] ?? '',
      grado: data['grado'] ?? 0,
      grupo: data['grupo'] ?? '',
    );
  }

}

