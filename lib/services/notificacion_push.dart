import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificacionPushService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> inicializarLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(settings);
  }

  static Future<void> mostrarNotificacion(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'sicce_channel',
      'Notificaciones SICCE',
      channelDescription: 'Notificaciones de entrada y salida de alumnos',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      message.notification?.title ?? 'SICCE',
      message.notification?.body ?? 'Nueva notificación',
      details,
    );
  }

  Future<void> inicializarNotificaciones({
    required String usuarioId,
    required String tipoUsuario,
  }) async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await _messaging.getToken();

    if (token != null) {
      await _db.collection('usuarios').doc(usuarioId).set({
        'fcmToken': token,
        'tipoUsuario': tipoUsuario,
        'tokenActualizado': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    _messaging.onTokenRefresh.listen((nuevoToken) async {
      await _db.collection('usuarios').doc(usuarioId).set({
        'fcmToken': nuevoToken,
        'tokenActualizado': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      mostrarNotificacion(message);
    });
  }
}