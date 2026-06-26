import 'package:flutter/material.dart';
import 'viewmodels/auth.dart';
import 'views/login_page.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'views/alumnos/alumno_login_page.dart';
import 'viewmodels/dashboard_padre.dart';
import 'viewmodels/dashboard_alumno.dart';
import 'services/notificacion_push.dart';
import 'viewmodels/asistencia.dart';

//PALETA DE COLORES DE TOMADO DE CANVA
//https://www.canva.com/design/DAHByoEiWdQ/KIicJ_nqgwmEGCFJ0YqEdw/edit
const Color kColorPrincipalAzul = Color(0xFF194395);
const Color kColorAcentoRojo = Color(0xFFAE0E0F);
const Color kColorTextoOscuro = Color(0xFF0D0E4A);
const Color kColorFondoGrisClaro = Color(0xFFF2F2F3);

/// Handler para mensajes FCM recibidos en BACKGROUND/TERMINADO
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // El sistema Android muestra la notificación automáticamente
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Registrar handler de mensajes en background
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificacionPushService.inicializarLocalNotifications();

  // Solicitar permisos de notificación (iOS + Android 13+)
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Mostrar notificaciones en PRIMER PLANO (cuando la app está abierta)
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider( providers: [
      ChangeNotifierProvider(create: (_) => AuthViewModel()),
      ChangeNotifierProvider(create: (_) => DashboardPadreViewModel()),
      ChangeNotifierProvider(create: (_) => DashboardAlumnoViewModel()),
      ChangeNotifierProvider(create: (_) => AsistenciaViewModel()),
    ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SICCE COBACH',
        // --- CONFIGURACIÓN DE TEMA INSTITUCIONAL ---
        theme: ThemeData(
          useMaterial3: true,
          //Definicion de la paleta de colores global
          colorScheme: ColorScheme.fromSeed(
            seedColor: kColorPrincipalAzul,
            primary: kColorPrincipalAzul,
            secondary: kColorAcentoRojo,
            background: kColorFondoGrisClaro,
          ),
          scaffoldBackgroundColor: kColorFondoGrisClaro,
          fontFamily: 'Poppins', 
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: kColorTextoOscuro),
            bodyMedium: TextStyle(color: kColorTextoOscuro),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: kColorPrincipalAzul,
            foregroundColor: Colors.white,
            centerTitle: true,
            elevation: 0,
            titleTextStyle: TextStyle(
              fontFamily: 'Poppins', 
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 3,
            ),
          ),
        ),
        home: const VistaPrincipal(), //mi clase de la primera vista
      ),
    );
 
  }
}

class VistaPrincipal extends StatelessWidget {
  const VistaPrincipal({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SICCE COBACH"),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.1, 
              child: Image.asset(
                // logo
                'assets/images/logo_cobach.png',
                fit: BoxFit.cover,
                repeat: ImageRepeat.repeat,
              ),
            ),
          ),
          // --- CONTENIDO PRINCIPAL ---
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo/Icono de la Institución con el color principal
                  const Icon(Icons.school_outlined, size: 90, color: kColorPrincipalAzul),
                  const SizedBox(height: 15),
                  const Text(
                    "Bienvenido",
                    style: TextStyle(
                      color: kColorPrincipalAzul,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    "Selecciona tu perfil de usuario",
                    style: TextStyle(
                      color: kColorTextoOscuro,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 60),

                  // BOTÓN ALUMNO
                  _buildPerfilButton(
                    context: context,
                    label: "SOY ALUMNO",
                    icon: Icons.person_outline_rounded,
                    isPrimary: true, 
                    onPressed: () {                   
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AlumnoLoginPage()),
                      );

                    },
                  ),

                  const SizedBox(height: 25),

                  // BOTÓN PADRE DE FAMILIA
                  _buildPerfilButton(
                    context: context,
                    label: "SOY PADRE DE FAMILIA",
                    icon: Icons.family_restroom_outlined,
                    isPrimary: false,
                    onPressed: () {
                      // MANTENEMOS LA LÓGICA DE NAVEGACIÓN ORIGINAL
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => LoginPage()),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 50),
                  // Pie de página institucional
                  const Text(
                    "DEP. TECNOLOGÍAS EDUCATIVAS Y PROCESOS DIGITALES",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: kColorPrincipalAzul,
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget para crear botones de perfil
  Widget _buildPerfilButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
   
    final buttonColor = isPrimary ? kColorPrincipalAzul : kColorAcentoRojo;
    final textColor = Colors.white;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 26, color: textColor),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 17, 
            fontWeight: FontWeight.w600, 
            color: textColor,
            letterSpacing: 1.0,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          elevation: isPrimary ? 4 : 2, 
        ),
      ),
    );
  }
}

