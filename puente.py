import sqlite3
import firebase_admin
import os
from firebase_admin import credentials, firestore
from datetime import datetime
import traceback

# =========================
# CONFIGURACIÓN
# =========================

FIREBASE_KEY = r"C:\Users\laraa\proyectsAS\app_sicce\sicce-2026-firebase-adminsdk-fbsvc-6b52c7221c.json"
ZKTIME_DB = r"C:\Program Files (x86)\ZKTimeNet3.0\ZKTimeNet.db"
LOG_FILE = "sync.log"

# =========================
# FUNCIONES
# =========================

def escribir_log(mensaje):
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(f"[{datetime.now()}] {mensaje}\n")


def limpiar(valor):
    if valor is None:
        return ""
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
    valor = limpiar(valor)

    if valor == "0":
        return "M"
    elif valor == "1":
        return "F"
    elif valor == "-1" or valor == "":
        return ""
    else:
        return valor


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
                "origen": "ZKTime MB160",
                "fechaSincronizacion": firestore.SERVER_TIMESTAMP
            })
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
            else:
                if hora != entrada_actual and hora != salida_actual:
                    doc_ref.update({
                        "salida": hora,
                        "fechaSincronizacion": firestore.SERVER_TIMESTAMP
                    })

    except Exception as e:
        escribir_log(f"Error procesando asistencia diaria: {e}")


# =========================
# PROCESO PRINCIPAL
# =========================

conexion = None

try:
    print("===================================")
    print("INICIANDO SINCRONIZACIÓN")
    print("===================================")

    print("Firebase:", FIREBASE_KEY)
    print("DB:", ZKTIME_DB)

    if not os.path.exists(FIREBASE_KEY):
        raise FileNotFoundError(
            f"No existe el archivo Firebase: {FIREBASE_KEY}"
        )

    if not os.path.exists(ZKTIME_DB):
        raise FileNotFoundError(
            f"No existe la base de datos: {ZKTIME_DB}"
        )

    if not firebase_admin._apps:
        cred = credentials.Certificate(FIREBASE_KEY)
        firebase_admin.initialize_app(cred)

    db = firestore.client()

    conexion = sqlite3.connect(ZKTIME_DB)
    cursor = conexion.cursor()

    # =========================
    # EMPLEADOS / ALUMNOS
    # =========================

    cursor.execute("""
        SELECT
            e.id,
            e.emp_pin,
            e.emp_firstname,
            e.emp_lastname,
            e.emp_email,
            e.emp_gender,
            e.emp_phone,
            e.emp_address,
            e.emp_birthday,
            e.department_id,
            d.dept_name
        FROM hr_employee e
        LEFT JOIN hr_department d
            ON e.department_id = d.id
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
            "origen": "ZKTime MB160",
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

        escribir_log(
            f"Alumno sincronizado: {matricula} - {nombre_completo}"
        )

    # =========================
    # ASISTENCIAS DESDE ZKTIME DB
    # =========================

    cursor.execute("""
        SELECT
            a.id,
            a.employee_id,
            a.punch_time,
            e.emp_pin,
            e.emp_firstname,
            e.emp_lastname
        FROM att_punches a
        JOIN hr_employee e
            ON a.employee_id = e.id
        ORDER BY a.id ASC
    """)

    registros = cursor.fetchall()

    print(f"Asistencias encontradas: {len(registros)}")

    for r in registros:
        zk_id = limpiar(r[0])
        fecha_hora = limpiar(r[2])
        matricula = limpiar(r[3])
        nombre_asistencia = f"{limpiar(r[4])} {limpiar(r[5])}".strip()

        if not zk_id or not matricula:
            continue

        db.collection("asistencias").document(zk_id).set({
            "zk_id": zk_id,
            "matricula": matricula,
            "fechaHora": fecha_hora,
            "nombre": nombre_asistencia,
            "origen": "ZKTime MB160",
            "fechaSincronizacion": firestore.SERVER_TIMESTAMP
        }, merge=True)

        procesar_asistencia_diaria(
            db,
            matricula,
            nombre_asistencia,
            fecha_hora,
        )

        escribir_log(
            f"Asistencia sincronizada: {zk_id} | {matricula} | {fecha_hora}"
        )

    mensaje = (
        f"Sincronización exitosa. "
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