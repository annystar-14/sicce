import sqlite3
import firebase_admin
from firebase_admin import credentials, firestore

FIREBASE_KEY = r"D:\proyecto huella\firebase-key.json"
ZKTIME_DB = r"D:\proyecto huella\zkt\ZKTimeNet3.0\ZKTimeNet.db"

cred = credentials.Certificate(FIREBASE_KEY)

if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)

db = firestore.client()

conexion = sqlite3.connect(ZKTIME_DB)
cursor = conexion.cursor()

# 1. SINCRONIZAR EMPLEADOS DE ZKTIME
cursor.execute("""
SELECT
    id,
    emp_pin,
    emp_firstname,
    emp_lastname
FROM hr_employee
""")

empleados = cursor.fetchall()

for e in empleados:
    empleado_id = str(e[0])
    matricula = str(e[1])
    nombre = f"{e[2]} {e[3]}".strip()

    # Guarda empleado de ZKTime en Firebase
    db.collection("zktime_empleados").document(matricula).set({
        "zk_employee_id": empleado_id,
        "matricula": matricula,
        "nombre": nombre,
        "estadoHuella": "registrada",
        "origen": "ZKTime MB160"
    })

    # Si ya existe en alumnos, actualiza estadoHuella
    alumnos = db.collection("alumnos") \
        .where("matricula", "==", matricula) \
        .limit(1) \
        .stream()

    for alumno in alumnos:
        alumno.reference.update({
            "estadoHuella": "registrada"
        })

# 2. SINCRONIZAR ASISTENCIAS
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

for r in registros:
    zk_id = str(r[0])
    fecha_hora = str(r[2])
    matricula = str(r[3])
    nombre = f"{r[4]} {r[5]}".strip()

    db.collection("asistencias").document(zk_id).set({
        "zk_id": zk_id,
        "matricula": matricula,
        "fechaHora": fecha_hora,
        "nombre": nombre,
        "origen": "ZKTime MB160"
    })

conexion.close()

print("Empleados y asistencias sincronizados correctamente")