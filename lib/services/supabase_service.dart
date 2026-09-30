import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

/// Wrapper central de Supabase.
/// Provee el cliente, la sesión actual y las operaciones de Auth.
/// NUNCA llames a Supabase.instance.client directamente en la UI —
/// siempre usá este servicio.
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  // Acceso al cliente raw (solo para los otros services)
  SupabaseClient get client => Supabase.instance.client;

  // ─── Sesión ───────────────────────────────────────────────
  User? get currentUser => client.auth.currentUser;
  Session? get currentSession => client.auth.currentSession;
  bool get isLoggedIn => currentUser != null;
  String? get currentUserId => currentUser?.id;

  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  // ─── REGISTRO ─────────────────────────────────────────────
  /// Registra un nuevo usuario.
  /// El trigger en Supabase crea automáticamente el perfil en public.usuarios.
  Future<AuthResponse> registrar({
    required String email,
    required String password,
    required String nombre,
    required String apellido,
  }) async {
    final res = await client.auth.signUp(
      email: email,
      password: password,
      data: {
        'nombre': nombre,
        'apellido': apellido,
      },
    );

    if (res.user == null) {
      throw const AuthException('El registro falló. Intentá de nuevo.');
    }

    // El trigger handle_new_user() ya creó el row en public.usuarios.
    // Actualizamos campos adicionales por si el trigger tardó.
    await _ensureProfile(
      userId: res.user!.id,
      nombre: nombre,
      apellido: apellido,
    );

    return res;
  }

  Future<void> _ensureProfile({
    required String userId,
    required String nombre,
    required String apellido,
  }) async {
    try {
      await client.from('usuarios').upsert({
        'id': userId,
        'nombre': nombre,
        'apellido': apellido,
      });
    } catch (_) {
      // Si el trigger ya lo creó, el upsert simplemente confirma los datos.
    }
  }

  // ─── LOGIN ────────────────────────────────────────────────
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final res = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (res.user == null) {
      throw const AuthException('Email o contraseña incorrectos.');
    }
    return res;
  }

  // ─── LOGOUT ───────────────────────────────────────────────
  Future<void> logout() => client.auth.signOut();

  Future<void> eliminarCuenta() async {
    await client.rpc('eliminar_mi_cuenta');
    await client.auth.signOut();
  }

  // ─── RESET PASSWORD ───────────────────────────────────────
  Future<void> resetPassword(String email) =>
      client.auth.resetPasswordForEmail(email);

  // ─── OBTENER PERFIL PROPIO ────────────────────────────────
  Future<Usuario> fetchPerfil(String userId) async {
    final data = await client.from('usuarios').select('''
          *,
          resenas:resenas!destinatario_id (
            id, autor_id, puntuacion, comentario, created_at,
            usuarios:autor_id ( nombre, apellido, foto_perfil_url )
          )
        ''').eq('id', userId).single();

    return Usuario.fromJson({
      ...data,
      'email': currentUser?.email ?? '',
    });
  }

  // ─── ACTUALIZAR PERFIL ────────────────────────────────────
  Future<void> actualizarPerfil({
    required String userId,
    String? nombre,
    String? apellido,
    String? telefono,
    String? fotoPerfil,
    List<String>? intereses,
    double? latitud,
    double? longitud,
  }) async {
    final updates = <String, dynamic>{};
    if (nombre != null) updates['nombre'] = nombre;
    if (apellido != null) updates['apellido'] = apellido;
    if (telefono != null) updates['telefono'] = telefono;
    if (fotoPerfil != null) updates['foto_perfil_url'] = fotoPerfil;
    if (intereses != null) updates['intereses'] = intereses;
    if (latitud != null) updates['ultima_lat'] = latitud;
    if (longitud != null) updates['ultima_lng'] = longitud;

    if (updates.isEmpty) return;

    await client.from('usuarios').update(updates).eq('id', userId);
  }

  // ─── VERIFICAR USUARIO ────────────────────────────────────
  /// Solo se llama desde una Cloud Function autenticada.
  /// Flutter no puede marcar verificado = true directamente (RLS lo impide).
  Future<void> marcarVerificado(String userId) async {
    await client.from('usuarios').update({
      'verificado': true,
      'puntos_confianza': client.from('usuarios')
      // Se usa RPC para sumar atomicamente
    }).eq('id', userId);
    // En la práctica esto viene de una Edge Function,
    // así que aquí solo actualizamos el estado local.
  }

  // ─── SUBIR FOTO DE PERFIL ─────────────────────────────────
  Future<String> subirFotoPerfil({
    required String userId,
    required List<int> bytes,
    required String extension,
  }) async {
    final path = 'perfiles/$userId.$extension';
    await client.storage.from('avatars').uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(
            contentType: 'image/$extension',
            upsert: true,
          ),
        );
    return client.storage.from('avatars').getPublicUrl(path);
  }
}
