import os
import sys
import socket
import traceback
import time
from datetime import datetime

import psycopg2
import firebase_admin
from firebase_admin import credentials, firestore, messaging

_lock_socket = None


def evitar_multiples_instancias():
    global _lock_socket
    try:
        _lock_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        _lock_socket.bind(('127.0.0.1', 49999))
    except socket.error:
        print("Ya hay una instancia de puente.py ejecutándose en segundo plano. Saliendo de esta instancia repetida.")
        sys.exit(0)


# =========================
# CONFIGURACIÓN
# =========================

FIREBASE_KEY = r"D:\proyectohuellacobach\sicce\sicce-2026-firebase-adminsdk-fbsvc-6b52c7221c.json"

# ZKBioTime local
POSTGRES_HOST = "127.0.0.1"
POSTGRES_PORT = 7496
POSTGRES_DB = "biotime"
POSTGRES_USER = "postgres"
POSTGRES_PASSWORD = ""  # CAMBIA ESTO

LOG_FILE = "sync_zkbiotime.log"


# =========================
# FUNCIONES
# =========================

STATE_FILE = r"D:\proyectohuellacobach\sicce\puente_state.txt"


def obtener_ultimo_id():
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r", encoding="utf-8") as f:
                content = f.read().strip()
                if content:
                    return int(content)
        except Exception as e:
            escribir_log(f"Error al leer archivo de estado: {e}")
    return None


def guardar_ultimo_id(last_id):
    try:
        with open(STATE_FILE, "w", encoding="utf-8") as f:
            f.write(str(last_id))
    except Exception as e:
        escribir_log(f"Error al guardar último ID en archivo de estado: {e}")


def obtener_max_id_db():
    conexion = None
    try:
        conexion = psycopg2.connect(
            host=POSTGRES_HOST,
            port=POSTGRES_PORT,
            database=POSTGRES_DB,
            user=POSTGRES_USER,
            password=POSTGRES_PASSWORD
        )
        cursor = conexion.cursor()
        cursor.execute("SELECT MAX(id) FROM iclock_transaction")
        res = cursor.fetchone()
        if res and res[0] is not None:
            return int(res[0])
    except Exception as e:
        escribir_log(f"Error al obtener ID máximo de la base de datos: {e}")
    finally:
        if conexion:
            conexion.close()
    return 0


def escribir_log(mensaje):
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(f"[{datetime.now()}] {mensaje}\n")


def limpiar(valor):
    if valor is None:
        return ""
    return str(valor).strip()


def formatear_fecha_hora(valor):
    if valor is None:
        return ""

    if isinstance(valor, datetime):
        return valor.strftime("%Y-%m-%d %H:%M:%S")

    return str(valor).strip()


def separar_grado_grupo(valor):
    valor = limpiar(valor).upper()

    if not valor or valor.lower() == "department":
        return "", ""

    grado = ""
    grupo = ""

    for c in valor:
        if c.isdigit():
            grado += c
        else:
            grupo += c

    return grado, grupo


def convertir_sexo(valor):
    valor = limpiar(valor).lower()

    if valor in ["0", "m", "male", "masculino"]:
        return "M"
    elif valor in ["1", "f", "female", "femenino"]:
        return "F"
    else:
        return ""


def enviar_notificacion_padre(db, matricula, nombre, fecha, hora, tipo_registro):
    """
    Busca el fcmToken del padre vinculado al alumno y le envía
    una notificación push vía Firebase Cloud Messaging.
    """
    try:
        # 1. Obtener padreId del alumno
        alumno_doc = db.collection("zktime_empleados").document(matricula).get()
        if not alumno_doc.exists:
            return

        padre_id = alumno_doc.to_dict().get("padreId", "")
        if not padre_id:
            return  # Alumno sin tutor vinculado

        # 2. Obtener token FCM del padre
        padre_doc = db.collection("usuarios").document(padre_id).get()
        if not padre_doc.exists:
            return

        fcm_token = padre_doc.to_dict().get("fcmToken", "")
        if not fcm_token:
            return  # Padre sin token (nunca abrió la app)

        # 3. Construir y enviar la notificación
        nombre_corto = nombre.split()[0] if nombre else "Tu hijo/a"

        try:
            h, m, _ = hora.split(":")
            h12 = int(h)
            ampm = "AM" if h12 < 12 else "PM"
            h12 = h12 if h12 <= 12 else h12 - 12
            h12 = 12 if h12 == 0 else h12
            hora_fmt = f"{h12}:{m} {ampm}"
        except Exception:
            hora_fmt = hora

        tipo_texto = "entrada" if tipo_registro == "entrada" else "salida"
        emoji = "🟢" if tipo_registro == "entrada" else "🔴"

        mensaje = messaging.Message(
            notification=messaging.Notification(
                title=f"{emoji} Registro biométrico – {nombre}",
                body=f"{nombre_corto} registró su {tipo_texto} a las {hora_fmt}",
            ),
            data={
                "matricula": matricula,
                "fecha": fecha,
                "hora": hora,
                "tipo": tipo_registro,
            },
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id="asistencia_sicce",
                    sound="default",
                ),
            ),
            token=fcm_token,
        )

        messaging.send(mensaje)
        escribir_log(f"Notificación enviada al padre de {matricula} ({tipo_texto} {hora_fmt})")

    except Exception as e:
        escribir_log(f"Error al enviar notificación FCM para {matricula}: {e}")


def procesar_asistencia_diaria(db, matricula, nombre, fecha_hora):
    try:
        partes = fecha_hora.split(" ")

        if len(partes) < 2:
            return

        fecha = partes[0]
        hora = partes[1]

        doc_id = f"{matricula}_{fecha}"

        doc_ref = db.collection("asistencias_diarias").document(doc_id)
        doc = doc_ref.get()

        estado = "Asistencia"

        try:
            h, m, _ = hora.split(":")
            h = int(h)
            m = int(m)

            if h > 7 or (h == 7 and m > 15):
                estado = "Retardo"
        except:
            pass

        # Permite ±2 días de tolerancia por diferencias horarias o del reloj del biométrico
        es_reciente = False
        try:
            fecha_dt = datetime.strptime(fecha, "%Y-%m-%d").date()
            hoy_dt = datetime.now().date()
            es_reciente = abs((hoy_dt - fecha_dt).days) <= 2
        except Exception:
            pass

        if not doc.exists:
            doc_ref.set({
                "matricula": matricula,
                "nombre": nombre,
                "fecha": fecha,
                "entrada": hora,
                "salida": "",
                "estado": estado,
                "origen": "ZKBioTime MB160",
                "fechaSincronizacion": firestore.SERVER_TIMESTAMP
            })
            # Notificar al padre solo si es asistencia reciente
            if es_reciente:
                enviar_notificacion_padre(db, matricula, nombre, fecha, hora, "entrada")
        else:
            data = doc.to_dict()

            entrada_actual = data.get("entrada", "")
            salida_actual = data.get("salida", "")

            if entrada_actual == "":
                doc_ref.update({
                    "entrada": hora,
                    "estado": estado,
                    "fechaSincronizacion": firestore.SERVER_TIMESTAMP
                })
                if es_reciente:
                    enviar_notificacion_padre(db, matricula, nombre, fecha, hora, "entrada")
            else:
                if hora != entrada_actual and hora != salida_actual:
                    doc_ref.update({
                        "salida": hora,
                        "fechaSincronizacion": firestore.SERVER_TIMESTAMP
                    })
                    if es_reciente:
                        enviar_notificacion_padre(db, matricula, nombre, fecha, hora, "salida")

    except Exception as e:
        escribir_log(f"Error procesando asistencia diaria: {e}")


# =========================
# PROCESO PRINCIPAL
# =========================

def sincronizar_once(db):
    conexion = None

    try:
        ultimo_id = obtener_ultimo_id()
        if ultimo_id is None:
            ultimo_id = obtener_max_id_db()
            guardar_ultimo_id(ultimo_id)
            print(f"Estado de sincronización inicializado en ID: {ultimo_id}")
            escribir_log(f"Estado de sincronización inicializado en ID: {ultimo_id}")

        conexion = psycopg2.connect(
            host=POSTGRES_HOST,
            port=POSTGRES_PORT,
            database=POSTGRES_DB,
            user=POSTGRES_USER,
            password=POSTGRES_PASSWORD
        )

        cursor = conexion.cursor()

        # =========================
        # EMPLEADOS / ALUMNOS
        # =========================

        cursor.execute("""
            SELECT
                e.id,
                e.emp_code,
                e.first_name,
                e.last_name,
                e.email,
                e.gender,
                e.mobile,
                e.address,
                e.birthday,
                e.department_id,
                d.dept_name
            FROM personnel_employee e
            LEFT JOIN personnel_department d
                ON e.department_id = d.id
            ORDER BY e.id ASC
        """)

        empleados = cursor.fetchall()

        print(f"Empleados encontrados: {len(empleados)}")

        for e in empleados:
            empleado_id = limpiar(e[0])
            matricula = limpiar(e[1])
            nombre = limpiar(e[2])
            apellidos = limpiar(e[3])
            correo = limpiar(e[4])
            sexo = convertir_sexo(e[5])
            telefono = limpiar(e[6])
            direccion = limpiar(e[7])
            cumpleanos = limpiar(e[8])
            departamento_id = limpiar(e[9])
            grado_grupo = limpiar(e[10])

            grado, grupo = separar_grado_grupo(grado_grupo)

            nombre_completo = f"{nombre} {apellidos}".strip()

            if not matricula:
                continue

            doc_ref = db.collection("zktime_empleados").document(matricula)
            doc = doc_ref.get()

            datos_empleado = {
                "zk_employee_id": empleado_id,
                "matricula": matricula,
                "nombre": nombre,
                "apellidos": apellidos,
                "nombreCompleto": nombre_completo,
                "correo": correo,
                "sexo": sexo,
                "telefono": telefono,
                "direccion": direccion,
                "cumpleanos": cumpleanos,
                "department_id": departamento_id,
                "gradoGrupo": grado_grupo,
                "grado": grado,
                "grupo": grupo,
                "estadoHuella": "registrada",
                "origen": "ZKBioTime MB160",
                "fechaSincronizacion": firestore.SERVER_TIMESTAMP
            }

            if doc.exists:
                datos_actuales = doc.to_dict()

                if "padreId" not in datos_actuales:
                    datos_empleado["padreId"] = ""

                doc_ref.set(datos_empleado, merge=True)
            else:
                datos_empleado["padreId"] = ""
                doc_ref.set(datos_empleado)

            escribir_log(f"Alumno sincronizado: {matricula} - {nombre_completo}")

        # =========================
        # ASISTENCIAS / MARCACIONES
        # =========================

        cursor.execute("""
            SELECT
                t.id,
                t.emp_id,
                t.punch_time,
                e.emp_code,
                e.first_name,
                e.last_name,
                d.dept_name
            FROM iclock_transaction t
            JOIN personnel_employee e
                ON t.emp_id = e.id
            LEFT JOIN personnel_department d
                ON e.department_id = d.id
            WHERE t.id > %s
            ORDER BY t.id ASC
        """, (ultimo_id,))

        registros = cursor.fetchall()

        print(f"Asistencias encontradas: {len(registros)}")

        max_id_procesado = ultimo_id
        for r in registros:
            zk_id = limpiar(r[0])
            try:
                zk_id_int = int(zk_id)
                if zk_id_int > max_id_procesado:
                    max_id_procesado = zk_id_int
            except:
                pass

            fecha_hora = formatear_fecha_hora(r[2])
            matricula = limpiar(r[3])
            nombre_asistencia = f"{limpiar(r[4])} {limpiar(r[5])}".strip()
            grado_grupo = limpiar(r[6])
            grado, grupo = separar_grado_grupo(grado_grupo)

            if not zk_id or not matricula:
                continue

            # Separar fecha y hora
            partes = fecha_hora.split(" ")
            fecha = partes[0] if len(partes) > 0 else ""
            hora = partes[1] if len(partes) > 1 else ""

            # Determinar tipoRegistro (entrada o salida)
            doc_diario_ref = db.collection("asistencias_diarias").document(f"{matricula}_{fecha}")
            doc_diario = doc_diario_ref.get()
            
            tipo_registro = "entrada"
            if doc_diario.exists:
                diario_data = doc_diario.to_dict()
                entrada_actual = diario_data.get("entrada", "")
                if entrada_actual and entrada_actual != hora:
                    tipo_registro = "salida"

            db.collection("asistencias").document(zk_id).set({
                "zk_id": zk_id,
                "matricula": matricula,
                "matriculaAlumno": matricula,
                "nombre": nombre_asistencia,
                "nombreAlumno": nombre_asistencia,
                "grado": grado,
                "grupo": grupo,
                "fecha": fecha,
                "hora": hora,
                "tipoRegistro": tipo_registro,
                "fechaHora": fecha_hora,
                "origen": "MB160",
                "fechaSincronizacion": firestore.SERVER_TIMESTAMP
            }, merge=True)

            procesar_asistencia_diaria(
                db,
                matricula,
                nombre_asistencia,
                fecha_hora
            )

            escribir_log(
                f"Asistencia sincronizada: {zk_id} | {matricula} | {fecha_hora}"
            )

        if max_id_procesado > ultimo_id:
            guardar_ultimo_id(max_id_procesado)
            escribir_log(f"Último ID sincronizado actualizado a: {max_id_procesado}")

        mensaje = (
            f"Sincronización exitosa ZKBioTime. "
            f"Empleados: {len(empleados)} | "
            f"Asistencias: {len(registros)}"
        )

        print(mensaje)
        escribir_log(mensaje)

    except Exception:
        error = traceback.format_exc()

        print("ERROR DURANTE LA SINCRONIZACIÓN")
        print(error)

        escribir_log("ERROR")
        escribir_log(error)

    finally:
        if conexion:
            conexion.close()


if __name__ == "__main__":
    evitar_multiples_instancias()
    print("==================================================")
    print("INICIANDO SERVICIO DE SINCRONIZACIÓN AUTOMÁTICA ZK")
    print("==================================================")
    print("Firebase:", FIREBASE_KEY)
    print("ZKBioTime DB:", POSTGRES_HOST, POSTGRES_PORT)

    if not os.path.exists(FIREBASE_KEY):
        raise FileNotFoundError(f"No existe el archivo Firebase: {FIREBASE_KEY}")

    if not firebase_admin._apps:
        cred = credentials.Certificate(FIREBASE_KEY)
        firebase_admin.initialize_app(cred)

    db = firestore.client()

    print("\nServicio activo. Sincronizando cada 30 segundos...")
    print("Presiona Ctrl+C para detener el servicio.\n")

    while True:
        try:
            print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Ejecutando sincronización...")
            sincronizar_once(db)
        except KeyboardInterrupt:
            print("\nServicio detenido por el usuario.")
            break
        except Exception as e:
            print(f"Error crítico en el bucle principal: {e}")
            escribir_log(f"CRITICAL LOOP ERROR: {e}")
        
        time.sleep(30)