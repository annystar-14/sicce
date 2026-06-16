import sqlite3

DB = r"C:\Program Files (x86)\ZKTimeNet3.0\ZKTimeNet.db"

conexion = sqlite3.connect(DB)
cursor = conexion.cursor()

cursor.execute("""
SELECT 
    a.id,
    e.emp_pin,
    e.emp_firstname,
    e.emp_lastname,
    a.punch_time
FROM att_punches a
JOIN hr_employee e
    ON a.employee_id = e.id
ORDER BY a.punch_time DESC
LIMIT 10
""")

for r in cursor.fetchall():
    print(r)

conexion.close()