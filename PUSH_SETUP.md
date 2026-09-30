# Push notifications con Supabase + FCM

Planazo mantiene Supabase como backend. Firebase Cloud Messaging se usa únicamente como canal de entrega push.

## Configuración necesaria

1. Crear una app Android en Firebase con el application id final de Planazo.
2. Descargar `google-services.json` y colocarlo en `android/app/`.
3. Crear una app iOS en Firebase con el bundle id final de Planazo.
4. Descargar `GoogleService-Info.plist` y agregarlo al target Runner desde Xcode.
5. Configurar una clave APNs en Firebase para la app iOS.
6. Agregar el plugin Google Services al proyecto Android según la versión actual de Flutter/Gradle:
   - declarar `com.google.gms.google-services` en `android/settings.gradle.kts`;
   - aplicarlo en `android/app/build.gradle.kts`.
7. Ejecutar `flutter pub get` y probar permisos en un dispositivo real.
8. Aplicar `supabase/production_migration_001.sql` en Supabase.
9. Enviar notificaciones desde una Edge Function o backend seguro usando la Firebase Admin SDK. Nunca incluir una server key en Flutter.

El servicio `PushNotificationService` no bloquea el arranque si esta configuración todavía no existe. Cuando Firebase queda configurado, registra y actualiza los tokens en `public.push_tokens` mediante el RPC `upsert_mi_push_token`.
