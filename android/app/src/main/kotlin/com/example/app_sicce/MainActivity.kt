package edu.cobach.app_sicce

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Crear el canal de notificación para las asistencias de SICCE
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "asistencia_sicce"
            val channelName = "Control de Asistencia"
            val channelDescription = "Notificaciones de entrada y salida de alumnos"
            val importance = NotificationManager.IMPORTANCE_HIGH
            
            val channel = NotificationChannel(channelId, channelName, importance).apply {
                description = channelDescription
                setShowBadge(true)
                enableVibration(true)
                // Se puede agregar sonido por defecto si se desea
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager?.createNotificationChannel(channel)
        }
    }
}
