import argparse
import os
import sys
import firebase_admin
from firebase_admin import credentials, auth, firestore

def main():
    parser = argparse.ArgumentParser(description="Registrar el administrador inicial en Firebase para SICCE.")
    parser.add_argument("--email", required=True, help="Correo electrónico del administrador")
    parser.add_argument("--password", required=True, help="Contraseña del administrador (min. 6 caracteres)")
    parser.add_argument("--nombre", required=True, help="Nombre del administrador")
    args = parser.parse_args()

    # Ruta del archivo de credenciales
    key_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "sicce-2026-firebase-adminsdk-fbsvc-6b52c7221c.json")

    print(f"Buscando archivo de credenciales en: {key_path}")
    if not os.path.exists(key_path):
        print(f"Error: No se encontró el archivo de credenciales de Firebase SDK en '{key_path}'")
        sys.exit(1)

    try:
        # Inicializar Firebase Admin
        cred = credentials.Certificate(key_path)
        firebase_admin.initialize_app(cred)
        db = firestore.client()

        print(f"Creando/Obteniendo usuario Auth para: {args.email}")
        try:
            # Intentar crear el usuario en Firebase Auth
            user = auth.create_user(
                email=args.email,
                password=args.password,
                display_name=args.nombre
            )
            uid = user.uid
            print(f"Usuario Auth creado exitosamente. UID: {uid}")
        except Exception as auth_error:
            # Si ya existe, intentar obtenerlo
            if "EMAIL_EXISTS" in str(auth_error) or "already in use" in str(auth_error).lower():
                print("El correo electrónico ya existe en Firebase Auth. Obteniendo UID existente...")
                user = auth.get_user_by_email(args.email)
                uid = user.uid
                print(f"Usuario Auth encontrado. UID: {uid}")
                # Actualizar contraseña si es necesario
                auth.update_user(uid, password=args.password)
                print("Contraseña del usuario actualizada.")
            else:
                raise auth_error

        # Crear o actualizar el perfil en la colección 'usuarios' en Firestore
        print(f"Guardando perfil de Administrador en la colección 'usuarios'...")
        user_ref = db.collection("usuarios").document(uid)
        user_ref.set({
            "nombre": args.nombre,
            "email": args.email,
            "rol": "admin",
            "createdAt": firestore.SERVER_TIMESTAMP
        }, merge=True)

        print("\n=======================================================")
        print("¡ADMINISTRADOR INICIAL CONFIGURADO CORRECTAMENTE!")
        print(f"Email: {args.email}")
        print(f"Contraseña: {args.password}")
        print(f"Nombre: {args.nombre}")
        print("=======================================================")

    except Exception as e:
        print(f"\nOcurrió un error al configurar el administrador: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
