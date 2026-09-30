# Planazo - Guía rápida de instalación y prueba

Este documento explica cómo instalar y ejecutar la app en computadoras del colegio de forma simple, junto con la creación de un usuario de prueba en Supabase para poder iniciar sesión.

## 1) Requisitos previos

Necesitás tener instalado lo siguiente en la PC:

- Git
- Flutter SDK
- Android Studio (para emulador Android o dispositivos físicos)
- Java JDK (si el proyecto lo pide según tu versión de Flutter)
- VS Code o Android Studio

### Verificar que Flutter esté instalado

Abrí una terminal y ejecutá:

```bash
flutter --version
```

Si no está instalado, descargalo desde:

https://docs.flutter.dev/get-started/install

Luego agregá Flutter al PATH del sistema y verificá:

```bash
flutter doctor
```

Si aparecieran errores de Android, instalá Android Studio y aceptá los componentes del SDK.

Para aceptar licencias de Android:

```bash
flutter doctor --android-licenses
```

---

## 2) Clonar el proyecto

Abrí la terminal y ejecutá:

```bash
git clone <URL_DEL_REPO>
cd planazo_v3
```

Si el proyecto ya está descargado en la carpeta local, sólo entrás:

```bash
cd planazo_v3
```

---

## 3) Instalar dependencias

En la raíz del proyecto ejecutá:

```bash
flutter pub get
```

Si la terminal muestra errores de dependencias o de Flutter, revisá con:

```bash
flutter doctor
```

---

## 4) Ejecutar la app

### Opción A: Android emulador

1. Abrí Android Studio
2. Creá o levantá un emulador Android
3. En la terminal del proyecto ejecutá:

```bash
flutter run
```

Si querés forzar un dispositivo específico:

```bash
flutter devices
flutter run -d emulator-5554
```

### Opción B: Windows

Si la computadora es Windows y el proyecto está configurado para correr en escritorio:

```bash
flutter run -d windows
```

### Opción C: Chrome (si querés probar más fácil en una laptop)

```bash
flutter run -d chrome
```

> En una máquina del colegio, suele ser más simple probarlo con Chrome o con un emulador Android bien configurado.

---

## 5) ¿Qué pasa con Supabase?

Este proyecto ya viene conectado a un proyecto de Supabase y usa la URL y la anon key en:

```dart
lib/main.dart
```

Las variables actuales son:

```dart
const String _supabaseUrl = 'https://ybzrxidpsgxoeldjnueg.supabase.co';
const String _supabaseAnonKey = 'sb_publishable_ZpAK3SKTZqLfbjcItEoPyQ_IPgQsrqd';
```

Esto significa que la app apunta a ese proyecto de Supabase y no necesita cambiarse para probar en una PC del colegio, siempre que usen ese mismo proyecto.

Si en algún momento cambian de proyecto de Supabase, deberán actualizar esos valores en `lib/main.dart`.

### Reparar error `chat_participantes`

Si al crear una juntada aparece `relation public.chat_participantes does not exist`,
abrí el SQL Editor de Supabase y ejecutá el archivo `supabase/fix_chat_participantes.sql`.
Después de ejecutarlo, volvé a iniciar la app y probá crear la juntada nuevamente.

---

## 6) Crear un usuario de prueba en Supabase

Para poder iniciar sesión en la app, hace falta crear un usuario real en Supabase Auth.

### Paso a paso

1. Entrá a tu proyecto de Supabase.
2. En el menú izquierdo, hacé click en Authentication.
3. Entrá en Users.
4. Hacé click en Add user.
5. Cargá un email y una contraseña de prueba.

Ejemplo:

```text
email: test@planazo.com
password: Test1234
```

6. Guardá el usuario.
7. Si el proyecto tiene email confirmation activo, desactivá esa opción temporalmente para pruebas.

### Configuración recomendada para pruebas

En Supabase:

- Authentication
- Providers
- Email
- Activá Email provider
- Si querés evitar confirmación por email para testing, dejá la confirmación desactivada o configurá el proyecto como prueba.

Esto permite que el inicio de sesión funcione directamente desde la app.

---

## 7) Cómo iniciar sesión en la app

Una vez creado el usuario en Supabase:

1. Abrí la app.
2. En la pantalla de login, ingresá:
   - Email: `test@planazo.com`
   - Contraseña: `Test1234`
3. Presioná Iniciar sesión.

Si las credenciales existen en Supabase Auth, la app entra correctamente a la pantalla principal.

> La pantalla de registro en la app todavía es provisional, por eso la forma más simple de probar la app es creando el usuario manualmente desde Supabase.

---

## 8) Si la app no deja entrar a nadie

Revisá estos puntos:

### Verificá que la app esté connectada al proyecto correcto

Mirá si `lib/main.dart` tiene la URL y anon key correctas.

### Verificá que el usuario exista en Supabase

- Authentication > Users
- Debe aparecer el email creado.

### Verificá si la contraseña es correcta

Debe coincidir exactamente con la que creaste en Supabase.

### Verificá que Flutter tenga dependencias bien instaladas

```bash
flutter pub get
flutter doctor
```

### Si falla la ejecución por Android

```bash
flutter devices
flutter emulators
```

Y levantá un emulador o usá Chrome.

---

## 9) Comandos resumidos

Estos son los más importantes para usar en la terminal:

```bash
cd planazo_v3
flutter pub get
flutter doctor
flutter run
```

Para Windows:

```bash
flutter run -d windows
```

Para Chrome:

```bash
flutter run -d chrome
```

---

## 10) Sugerencia para el colegio

Para que puedan probarlo sin complicarse:

- Dejar una cuenta de prueba creada en Supabase con email y contraseña simples.
- Documentar esas credenciales en una nota interna del curso.
- Hacer la prueba siempre con ese mismo usuario.
- Si alguien necesita crear otro usuario, hacerlo desde Supabase Dashboard.

---

## 11) Resumen rápido

1. Instalar Flutter y Android Studio.
2. Clonar el proyecto.
3. Ejecutar `flutter pub get`.
4. Ejecutar `flutter run`.
5. Crear usuario en Supabase Authentication → Users.
6. Iniciar sesión con ese usuario desde la app.

Si necesitás, puedo dejarte también una versión del README adaptada para Windows 11 o para uso en laboratorio con Android Studio y emulador.
