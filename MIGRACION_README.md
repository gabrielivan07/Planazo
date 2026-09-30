# 🚀 Planazo v3 — Migración a Backend Real (Supabase)

Este documento explica el diagnóstico, la arquitectura y los pasos exactos para poner en producción la migración de Planazo desde el Provider simulado hacia un backend real con Supabase.

---

## 1. Diagnóstico del estado actual

| Área | Estado en v2 (simulado) | Problema |
|---|---|---|
| Autenticación | `Future.delayed()` + validación de regex | No hay usuarios reales, cualquier email pasa |
| Persistencia | Listas en memoria (`List<Juntada>`) | Se pierde todo al cerrar la app |
| Tiempo real | `notifyListeners()` local | No sincroniza entre dispositivos |
| Seguridad | Ninguna | Cualquiera podría ver/editar todo si hubiera red |
| Geolocalización | Solo se muestra el punto, no se usa para nada | No ordena ni filtra por distancia |
| Verificación DNI | Campo `verificado` hardcodeado en `true` | No existe el flujo real |

**Conclusión:** la app es un prototipo funcional de UI, pero cero por ciento lista para usuarios reales. Esta migración resuelve los 4 primeros puntos (los críticos). Verificación de identidad e IA quedan diseñados pero no implementados en código (ver Riesgos).

---

## 2. Plan de migración por etapas

### Etapa 1 — CRÍTICA (este entregable)
1. Esquema completo de base de datos en PostgreSQL (`schema.sql`)
2. Políticas RLS de seguridad (`rls_policies.sql`)
3. Autenticación real con Supabase Auth
4. CRUD real de juntadas, participantes, chats, mensajes
5. Realtime en chat
6. Geolocalización real con ordenamiento y filtro por distancia

### Etapa 2 — Siguiente sprint
7. Verificación de DNI (Edge Function + Cloud Vision API)
8. Liveness detection (ML Kit)
9. Subida de fotos de perfil y de juntadas (Supabase Storage)

### Etapa 3 — Solo después de 1 y 2
10. Recomendaciones con Gemini API
11. Moderación automática de contenido

---

## 3. Estructura de base de datos (resumen)

```
usuarios           → extiende auth.users, 1:1
juntadas           → organizador_id → usuarios
participantes      → juntada_id + usuario_id (N:M)
chats              → juntada_id (nullable, para chats directos)
chat_participantes → chat_id + usuario_id (N:M)
mensajes           → chat_id + remitente_id
resenas            → autor_id + destinatario_id + juntada_id
historial_puntos   → auditoría del sistema de confianza
categorias         → catálogo editable sin deploy
```

Ver el archivo completo en `supabase/schema.sql`.

---

## 4. Cómo aplicar esta migración (paso a paso)

### 4.1 Crear el proyecto en Supabase
```bash
# 1. Ir a https://supabase.com y crear un proyecto nuevo
# 2. Copiar el Project URL y el anon key desde Settings > API
```

### 4.2 Ejecutar el esquema SQL
En **Supabase > SQL Editor**, ejecutar en este orden exacto:
```
1. supabase/schema.sql              ← Tablas, triggers, funciones base
2. supabase/rls_policies.sql        ← Seguridad por fila
3. supabase/funciones_auxiliares.sql ← Funciones RPC + Realtime config
4. supabase/production_migration_001.sql
5. supabase/chat_y_amistades_migration_002.sql ← Preferencias y acciones de chat
```

### 4.3 Configurar Storage (para fotos)
```
Supabase > Storage > Crear bucket "avatars" (público)
Supabase > Storage > Crear bucket "juntadas" (público)
```

### 4.4 Conectar Flutter
En `lib/main.dart`, reemplazar:
```dart
const String _supabaseUrl     = 'https://TU_PROYECTO.supabase.co';
const String _supabaseAnonKey = 'TU_ANON_KEY_AQUI';
```
con los valores reales de tu proyecto.

### 4.5 Instalar dependencias y correr
```bash
flutter pub get
flutter run
```

---

## 5. Archivos modificados / creados en esta etapa

| Archivo | Tipo de cambio |
|---|---|
| `pubspec.yaml` | Agregadas: supabase_flutter, permission_handler, flutter_secure_storage |
| `lib/models/models.dart` | Reescrito completo: fromJson/toJson + Haversine |
| `lib/services/supabase_service.dart` | **Nuevo** — Auth wrapper |
| `lib/services/juntadas_service.dart` | **Nuevo** — CRUD de juntadas |
| `lib/services/chat_service.dart` | **Nuevo** — Mensajería + Realtime |
| `lib/services/geolocacion_service.dart` | **Nuevo** — GPS + Haversine + ordenamiento |
| `lib/providers/app_provider.dart` | Reescrito: misma API pública, ahora async real |
| `lib/main.dart` | Agregado `Supabase.initialize()` antes de runApp |
| `lib/screens/auth/login_screen.dart` | Actualizado: maneja errores reales de Supabase |
| `lib/screens/map/mapa_screen.dart` | Actualizado: ordenar/filtrar por distancia real |
| `lib/screens/chat/chat_detalle_screen.dart` | Actualizado: Realtime + UI optimista |
| `android/.../AndroidManifest.xml` | Agregados permisos de cámara e internet |
| `supabase/schema.sql` | **Nuevo** |
| `supabase/rls_policies.sql` | **Nuevo** |
| `supabase/funciones_auxiliares.sql` | **Nuevo** |

**Compatibilidad:** todas las pantallas que no se mencionan arriba (`home_screen.dart`, `perfil_screen.dart`, `crear_juntada_screen.dart`, `juntada_card.dart`, `detalle_juntada_screen.dart`, `chats_screen.dart`, `registro_screen.dart`) **no necesitan cambios** porque consumen el Provider a través de la misma API pública (`provider.juntadas`, `provider.login()`, etc.), que se mantuvo idéntica a propósito.

---

## 6. Riesgos técnicos y cómo se resolvieron / quedan pendientes

| Riesgo | Resolución en este entregable |
|---|---|
| RLS mal configurado expone datos | Políticas explícitas por tabla, probadas contra los casos de uso de la app |
| Mensajes duplicados por reconexión Realtime | Filtro `remitenteId != usuarioId` en el callback (los propios se muestran optimistamente) |
| Pérdida de mensaje si falla el envío | Patrón optimista + rollback (`_BurbujaMensaje` con `pendiente: true`) |
| Coordenadas de juntada fake (creadas con jitter aleatorio) | **Pendiente real**: falta integrar Nominatim API para geocodificar la dirección de texto |
| Verificación de identidad | **No implementado en código** — diseño completo en la documentación técnica previa, requiere Edge Function de GCP |
| IA / Gemini | **No implementado a propósito** — la prioridad pedida fue backend, seguridad, realtime y geo primero |
| Costos de Supabase en producción | Capa gratuita: 500MB DB + 2GB bandwidth/mes. Suficiente para validar el proyecto, no para escala real |
| Falta de tests automatizados | **Pendiente**: no se incluyen tests en este entregable por alcance, ver recomendación abajo |

---

## 7. Qué falta para production-ready (siguiente entrega)

1. Edge Function de verificación de DNI con Cloud Vision API.
2. Geocodificación real de direcciones con Nominatim.
3. Tests unitarios de `AppProvider` y los Services.
4. Manejo de modo offline (cache local con Hive o sqflite).
5. Migrar las credenciales de Supabase a variables de entorno (`flutter_dotenv`), no constantes hardcodeadas.
6. Subida de imágenes de perfil y de juntadas (Storage ya configurado, falta la UI).
