import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import 'supabase_service.dart';

/// Todas las operaciones de lectura y escritura sobre juntadas.
/// Usa la vista juntadas_con_participantes para traer el count de participantes
/// y los datos del organizador en una sola query.
class JuntadasService {
  JuntadasService._();
  static final JuntadasService instance = JuntadasService._();

  SupabaseClient get _db => SupabaseService.instance.client;

  static const String _vista = 'juntadas_con_participantes';

  // ─── SELECT base ──────────────────────────────────────────
  static const String _selectCampos = '''
    id, titulo, descripcion, organizador_id,
    organizador_nombre, organizador_apellido,
    organizador_foto, organizador_verificado,
    fecha, lugar, lat, lng, barrio,
    capacidad_maxima, participantes_count,
    categoria, etiquetas, es_publica, estado,
    solo_verificados, imagen_url, created_at
  ''';

  // ─── LISTAR PROXIMAS ──────────────────────────────────────
  /// Devuelve juntadas activas y futuras, paginadas.
  Future<List<Juntada>> fetchProximas({
    String? categoria,
    String? busqueda,
    int pagina = 0,
    int tamano = 30,
  }) async {
    final data = await _db
        .from(_vista)
        .select(_selectCampos)
        .order('fecha', ascending: true);
    final now = DateTime.now();

    final lista = (data as List)
        .where((j) => (j['estado'] as String? ?? 'activa') == 'activa')
        .where((j) {
          final fecha = DateTime.tryParse(j['fecha'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return fecha.isAfter(now);
        })
        .map((j) => Juntada.fromJson(j))
        .toList();

    final filtrada = lista.where((j) {
      if (categoria != null &&
          categoria != 'Todas' &&
          j.categoria != categoria) {
        return false;
      }
      if (busqueda != null && busqueda.isNotEmpty) {
        final q = busqueda.toLowerCase();
        final hayCoincidencia = j.titulo.toLowerCase().contains(q) ||
            j.lugar.toLowerCase().contains(q) ||
            j.barrio.toLowerCase().contains(q);
        if (!hayCoincidencia) return false;
      }
      return true;
    }).toList();

    final start = pagina * tamano;
    final end = start + tamano;
    if (start >= filtrada.length) return <Juntada>[];
    return filtrada.sublist(
        start, end < filtrada.length ? end : filtrada.length);
  }

  // ─── LISTAR POR CERCANÍA (server-side) ───────────────────
  /// Llama a la función SQL juntadas_cercanas() que usa PostGIS.
  Future<List<Juntada>> fetchCercanas({
    required double lat,
    required double lng,
    double radioKm = 10,
    int limite = 50,
  }) async {
    final data = await _db.rpc('juntadas_cercanas', params: {
      'lat_usuario': lat,
      'lng_usuario': lng,
      'radio_km': radioKm,
      'limite': limite,
    });

    // La función retorna solo id, titulo, distancia_km.
    // Hacemos un IN query para traer los datos completos.
    final ids = (data as List).map((r) => r['id'] as String).toList();
    final distancias = {
      for (final r in data)
        r['id'] as String: (r['distancia_km'] as num).toDouble()
    };

    if (ids.isEmpty) return [];

    final detalle =
        await _db.from(_vista).select(_selectCampos).inFilter('id', ids);

    return (detalle as List).map((j) {
      final juntada = Juntada.fromJson(j);
      juntada.distanciaKm = distancias[juntada.id];
      return juntada;
    }).toList()
      ..sort((a, b) => (a.distanciaKm ?? 999).compareTo(b.distanciaKm ?? 999));
  }

  // ─── DETALLE ──────────────────────────────────────────────
  Future<Juntada> fetchDetalle(String juntadaId) async {
    final data = await _db
        .from(_vista)
        .select(_selectCampos)
        .eq('id', juntadaId)
        .single();
    return Juntada.fromJson(data);
  }

  // ─── CREAR ────────────────────────────────────────────────
  Future<Juntada> crear(Juntada juntada) async {
    // 1. Insertar en juntadas (el trigger crea el chat automáticamente)
    final data =
        await _db.from('juntadas').insert(juntada.toJson()).select().single();

    // 2. Insertar al organizador como participante confirmado
    await _db.from('participantes').insert({
      'juntada_id': data['id'],
      'usuario_id': juntada.organizadorId,
      'estado': 'confirmado',
    });

    return fetchDetalle(data['id'] as String);
  }

  // ─── UNIRSE ───────────────────────────────────────────────
  /// Devuelve true si la operación fue exitosa.
  Future<bool> unirse({
    required String juntadaId,
    required String usuarioId,
  }) async {
    try {
      await _db.from('participantes').insert({
        'juntada_id': juntadaId,
        'usuario_id': usuarioId,
        'estado': 'confirmado',
      });
      return true;
    } on PostgrestException catch (e) {
      // Código 23505 = violación de unique constraint (ya estaba anotado)
      // Código 42501 = violó RLS (juntada llena o no autorizado)
      if (e.code == '23505') return false; // Ya anotado
      if (e.code == '42501') return false; // RLS bloqueó
      rethrow;
    }
  }

  // ─── CANCELAR PARTICIPACIÓN ───────────────────────────────
  Future<void> cancelarParticipacion({
    required String juntadaId,
    required String usuarioId,
  }) async {
    await _db
        .from('participantes')
        .update({'estado': 'cancelado'})
        .eq('juntada_id', juntadaId)
        .eq('usuario_id', usuarioId);
  }

  // ─── CANCELAR JUNTADA (solo organizador) ──────────────────
  Future<void> cancelar(String juntadaId) async {
    await _db
        .from('juntadas')
        .update({'estado': 'cancelada'}).eq('id', juntadaId);
  }

  // ─── ACTUALIZAR ───────────────────────────────────────────
  Future<void> actualizar({
    required String juntadaId,
    String? titulo,
    String? descripcion,
    DateTime? fecha,
    String? lugar,
    int? capacidadMaxima,
  }) async {
    final updates = <String, dynamic>{};
    if (titulo != null) updates['titulo'] = titulo;
    if (descripcion != null) updates['descripcion'] = descripcion;
    if (fecha != null) updates['fecha'] = fecha.toIso8601String();
    if (lugar != null) updates['lugar'] = lugar;
    if (capacidadMaxima != null) updates['capacidad_maxima'] = capacidadMaxima;
    if (updates.isEmpty) return;
    await _db.from('juntadas').update(updates).eq('id', juntadaId);
  }

  // ─── IDs DONDE EL USUARIO ES PARTICIPANTE ─────────────────
  Future<Set<String>> fetchIdsUnidas(String usuarioId) async {
    final data = await _db
        .from('participantes')
        .select('juntada_id')
        .eq('usuario_id', usuarioId)
        .eq('estado', 'confirmado');
    return {for (final r in data as List) r['juntada_id'] as String};
  }

  // ─── JUNTADAS ORGANIZADAS POR EL USUARIO ──────────────────
  Future<List<Juntada>> fetchOrganizadas(String usuarioId) async {
    final data = await _db
        .from(_vista)
        .select(_selectCampos)
        .eq('organizador_id', usuarioId)
        .order('fecha', ascending: false);
    return (data as List).map((j) => Juntada.fromJson(j)).toList();
  }
}
