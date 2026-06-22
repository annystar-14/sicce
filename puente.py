import os
import traceback
from datetime import datetime

import psycopg2
import firebase_admin
from firebase_admin import credentials, firestore, messaging


FIREBASE_KEY = r"C:\Users\laraa\proyectsAS\app_sicce\sicce-2026-firebase-adminsdk-fbsvc-6b52c7221c.json"

POSTGRES_HOST = "127.0.0.1"
POSTGRES_PORT = 7496
POSTGRES_DB = "biotime"
POSTGRES_USER = "postgres"
POSTGRES_PASSWORD = ""

LOG_FILE = "sync_zkbiotime.log"


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
            grupo += c.replace("-", "")

    return grado, grupo


def convertir_sexo(valor):
    valor = limpiar(valor).lower()

    if valor in ["0", "m", "male", "masculino"]:
        return "M"
    elif valor in ["1", "f", "female", "femenino"]:
        return "F"
    else:
        return ""


def enviar_notificacion_padre(db, matricula, nombre, fecha_hora, tipo):
    try:
        alumno_doc = db.collection("zktime_empleados").document(matricula).get()

        if not alumno_doc.exists:
            escribir_log(f"No existe alumno con matrícula {matricula}")
            return

        alumno = alumno_doc.to_dict()
        padre_id = alumno.get("padreId", "")

        if not padre_id:
            escribir_log(f"Alumno {matricula} no tiene padreId")
            return

        padre_doc = db.collection("usuarios").document(padre_id).get()

        if not padre_doc.exists:
            escribir_log(f"No existe padre {padre_id}")
            return

        padre = padre_doc.to_dict()
        token = padre.get("fcmToken", "")

        if not token:
            escribir_log(f"Padre {padre_id} no tiene fcmToken")
            return

        partes = fecha_hora.split(" ")
        hora = partes[1] if len(partes) > 1 else ""

        titulo = "📚 SICCE"

        if tipo == "entrada":
            cuerpo = f"Tu hijo {nombre} ingresó a la escuela a las {hora}."
        else:
            cuerpo = f"Tu hijo {nombre} salió de la escuela a las {hora}."

        mensaje = messaging.Message(
            notification=messaging.Notification(
                title=titulo,
                body=cuerpo,
            ),
            token=token,
        )

        messaging.send(mensaje)

        db.collection("usuarios").document(padre_id).collection("notificaciones").add({
            "titulo": titulo,
            "mensaje": cuerpo,
            "matricula": matricula,
            "nombreAlumno": nombre,
            "fechaHora": fecha_hora,
            "tipo": tipo,
            "leida": False,
            "createdAt": firestore.SERVER_TIMESTAMP,
        })

        escribir_log(f"Notificación enviada: {padre_id} | {cuerpo}")

    except Exception as e:
        escribir_log(f"Error enviando notificación: {e}")


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

            if h > 7 or (h == 7 and m > 5):
                estado = "Retardo"
        except:
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

            enviar_notificacion_padre(
                db,
                matricula,
                nombre,
                fecha_hora,
                "entrada"
            )

            escribir_log(f"Entrada registrada: {matricula} | {hora}")
            return

        data = doc.to_dict()

        entrada_actual = data.get("entrada", "")
        salida_actual = data.get("salida", "")

        if entrada_actual != "" and salida_actual == "":
            if hora != entrada_actual:
                doc_ref.update({
                    "salida": hora,
                    "fechaSincronizacion": firestore.SERVER_TIMESTAMP
                })

                enviar_notificacion_padre(
                    db,
                    matricula,
                    nombre,
                    fecha_hora,
                    "salida"
                )

                escribir_log(f"Salida registrada: {matricula} | {hora}")

        else:
            escribir_log(
                f"Registro ignorado, ya tiene entrada y salida: {matricula} | {hora}"
            )

    except Exception as e:
        escribir_log(f"Error procesando asistencia diaria: {e}")


conexion = None

try:
    print("===================================")
    print("INICIANDO SINCRONIZACIÓN ZKBIOTIME")
    print("===================================")

    if not os.path.exists(FIREBASE_KEY):
        raise FileNotFoundError(f"No existe el archivo Firebase: {FIREBASE_KEY}")

    if not firebase_admin._apps:
        cred = credentials.Certificate(FIREBASE_KEY)
        firebase_admin.initialize_app(cred)

    db = firestore.client()

    conexion = psycopg2.connect(
        host=POSTGRES_HOST,
        port=POSTGRES_PORT,
        database=POSTGRES_DB,
        user=POSTGRES_USER,
        password=POSTGRES_PASSWORD
    )

    cursor = conexion.cursor()

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

    cursor.execute("""
        SELECT
            t.id,
            t.emp_id,
            t.punch_time,
            e.emp_code,
            e.first_name,
            e.last_name
        FROM iclock_transaction t
        JOIN personnel_employee e
            ON t.emp_id = e.id
        ORDER BY t.id ASC
    """)

    registros = cursor.fetchall()
    print(f"Asistencias encontradas: {len(registros)}")

    for r in registros:
        zk_id = limpiar(r[0])
        fecha_hora = formatear_fecha_hora(r[2])
        matricula = limpiar(r[3])
        nombre_asistencia = f"{limpiar(r[4])} {limpiar(r[5])}".strip()

        if not zk_id or not matricula:
            continue

        asistencia_ref = db.collection("asistencias").document(zk_id)
        asistencia_doc = asistencia_ref.get()

        if asistencia_doc.exists:
            asistencia_data = asistencia_doc.to_dict()
            if asistencia_data.get("procesada", False):
                continue

        asistencia_ref.set({
            "zk_id": zk_id,
            "matricula": matricula,
            "fechaHora": fecha_hora,
            "nombre": nombre_asistencia,
            "origen": "ZKBioTime MB160",
            "procesada": True,
            "fechaSincronizacion": firestore.SERVER_TIMESTAMP
        }, merge=True)

        procesar_asistencia_diaria(
            db,
            matricula,
            nombre_asistencia,
            fecha_hora
        )

        escribir_log(f"Asistencia procesada: {zk_id} | {matricula} | {fecha_hora}")

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