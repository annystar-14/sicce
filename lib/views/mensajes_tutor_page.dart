import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const Color kColorPrincipalAzul = Color(0xFF194395);
const Color kColorAcentoRojo = Color(0xFFAE0E0F);
const Color kColorTextoOscuro = Color(0xFF0D0E4A);
const Color kColorFondoGrisClaro = Color(0xFFF2F2F3);

class MensajesTutorPage extends StatelessWidget {
  const MensajesTutorPage({super.key});

  String _formatFecha(Timestamp? timestamp) {
    if (timestamp == null) return "Sin fecha";
    final dt = timestamp.toDate();
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? "PM" : "AM";
    return "$day/$month/$year $hour:$min $ampm";
  }

  void _abrirDetalleMensaje(BuildContext context, DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final mensaje = data['mensaje']?.toString() ?? '';
    final nombreAlumno = data['nombreAlumno']?.toString() ?? '';
    final fecha = data['fechaHora'] as Timestamp?;
    final leido = data['leido'] as bool? ?? false;

    // Si no está leído, marcarlo como leído en Firestore
    if (!leido) {
      FirebaseFirestore.instance
          .collection('mensajes_tutores')
          .doc(doc.id)
          .update({'leido': true});
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.mark_email_read_outlined, color: kColorPrincipalAzul),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Aviso sobre $nombreAlumno",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: kColorPrincipalAzul,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatFecha(fecha),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Text(
                  mensaje,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: kColorTextoOscuro,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.admin_panel_settings_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      "Enviado por: Dirección Escolar",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cerrar"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mensajes de Dirección"),
      ),
      body: uid == null
          ? const Center(child: Text("Inicie sesión para ver los mensajes"))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('mensajes_tutores')
                  .where('idTutor', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text("Error al cargar mensajes: ${snapshot.error}"));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.mail_outline, size: 72, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text(
                            "Buzón Vacío",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: kColorTextoOscuro,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "No has recibido mensajes del administrador escolar aún.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Ordenar en memoria por fechaHora descendente para evitar index compuesto
                final docs = snapshot.data!.docs;
                docs.sort((a, b) {
                  final tA = (a.data() as Map<String, dynamic>)['fechaHora'] as Timestamp?;
                  final tB = (b.data() as Map<String, dynamic>)['fechaHora'] as Timestamp?;
                  if (tA == null) return 1;
                  if (tB == null) return -1;
                  return tB.compareTo(tA);
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final mensaje = data['mensaje']?.toString() ?? '';
                    final nombreAlumno = data['nombreAlumno']?.toString() ?? '';
                    final fecha = data['fechaHora'] as Timestamp?;
                    final leido = data['leido'] as bool? ?? false;

                    return Card(
                      elevation: leido ? 1 : 3,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: leido
                            ? BorderSide(color: Colors.grey[200]!)
                            : const BorderSide(color: kColorPrincipalAzul, width: 1),
                      ),
                      color: leido ? Colors.white : const Color(0xFFF0F4FF),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: leido ? Colors.grey[200] : kColorPrincipalAzul.withOpacity(0.1),
                          child: Icon(
                            leido ? Icons.drafts_outlined : Icons.mark_email_unread_rounded,
                            color: leido ? Colors.grey[600] : kColorPrincipalAzul,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Aviso: $nombreAlumno",
                                style: TextStyle(
                                  fontWeight: leido ? FontWeight.normal : FontWeight.bold,
                                  color: kColorTextoOscuro,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (!leido)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: kColorAcentoRojo,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              mensaje,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatFecha(fecha),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _abrirDetalleMensaje(context, doc),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
