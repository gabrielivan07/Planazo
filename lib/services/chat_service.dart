import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import 'supabase_service.dart';

class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  SupabaseClient get _db => SupabaseService.instance.client;

  Future<List<Chat>> fetchChats(String usuarioId) async {
    dynamic data;
    try {
      data = await _db.from('chats').select('''
          id, juntada_id, titulo, es_grupal, created_at,
          mi_configuracion:chat_participantes!inner(
            usuario_id, silenciado, archivado, fijado, eliminado
          ),
          mensajes:mensajes (
            id, chat_id, remitente_id, contenido, tipo,
            leido_por, created_at,
            usuarios:remitente_id ( nombre, apellido, foto_perfil_url )
          )
        ''').eq('mi_configuracion.usuario_id', usuarioId);
    } on PostgrestException catch (error) {
      if (error.code != '42703') rethrow;
      data = await _db.from('chats').select('''
            id, juntada_id, titulo, es_grupal, created_at,
            mensajes:mensajes (
              id, chat_id, remitente_id, contenido, tipo,
              leido_por, created_at,
              usuarios:remitente_id ( nombre, apellido, foto_perfil_url )
            )
          ''');
    }

    final chats = (data as List).map((c) => Chat.fromJson(c)).toList();
    chats.sort((a, b) {
      if (a.fijado != b.fijado) return a.fijado ? -1 : 1;
      final ta = a.ultimoMensaje?.creadoEn ?? a.creadoEn;
      final tb = b.ultimoMensaje?.creadoEn ?? b.creadoEn;
      return tb.compareTo(ta);
    });
    return chats;
  }

  Future<Chat?> fetchChatJuntada(String juntadaId) async {
    final data = await _db
        .from('chats')
        .select('id, juntada_id, titulo, es_grupal, created_at')
        .eq('juntada_id', juntadaId)
        .eq('es_grupal', true)
        .order('created_at')
        .limit(1)
        .maybeSingle();
    return data == null ? null : Chat.fromJson(data);
  }

  Future<List<Mensaje>> fetchMensajes(
    String chatId, {
    int pagina = 0,
    int tamano = 50,
  }) async {
    final start = pagina * tamano;
    final data = await _db
        .from('mensajes')
        .select('''
          id, chat_id, remitente_id, contenido, tipo,
          imagen_url, leido_por, created_at,
          usuarios:remitente_id ( nombre, apellido, foto_perfil_url )
        ''')
        .eq('chat_id', chatId)
        .order('created_at')
        .range(start, start + tamano - 1);

    return (data as List).map((m) => Mensaje.fromJson(m)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchIntegrantes(String chatId) async {
    final data = await _db.rpc(
      'obtener_participantes_chat',
      params: {'p_chat_id': chatId},
    );
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<void> actualizarPreferencias(
    String chatId,
    String usuarioId,
    Map<String, bool> cambios,
  ) async {
    await _db
        .from('chat_participantes')
        .update(cambios)
        .eq('chat_id', chatId)
        .eq('usuario_id', usuarioId);
  }

  Future<bool> agregarAmigo(String usuarioId, String amigoId) async {
    return await _db.rpc(
      'agregar_amigo',
      params: {'p_amigo_id': amigoId},
    ) as bool;
  }

  Future<Mensaje> enviar({
    required String chatId,
    required String remitenteId,
    required String contenido,
    String? imagenUrl,
  }) async {
    final data = await _db.from('mensajes').insert({
      'chat_id': chatId,
      'remitente_id': remitenteId,
      'contenido': contenido,
      'tipo': imagenUrl != null ? 'imagen' : 'texto',
      'imagen_url': imagenUrl,
      'leido_por': [remitenteId],
    }).select('''
      id, chat_id, remitente_id, contenido, tipo,
      imagen_url, leido_por, created_at,
      usuarios:remitente_id ( nombre, apellido, foto_perfil_url )
    ''').single();

    return Mensaje.fromJson(data);
  }

  Future<void> marcarLeido(String chatId, String usuarioId) async {
    await _db.rpc('marcar_mensajes_leidos', params: {
      'p_chat_id': chatId,
      'p_usuario_id': usuarioId,
    });
  }

  StreamSubscription<Mensaje> suscribir({
    required String chatId,
    required String usuarioId,
    required void Function(Mensaje mensaje) onNuevoMensaje,
    required void Function(String error) onError,
  }) {
    final controller = StreamController<Mensaje>.broadcast();
    final sub = controller.stream.listen(onNuevoMensaje);

    final channel = _db
        .channel('mensajes:$chatId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'mensajes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (payload) async {
            final record = payload.newRecord;
            if (record['remitente_id'] == usuarioId) return;
            try {
              final data = await _db.from('mensajes').select('''
                    id, chat_id, remitente_id, contenido, tipo,
                    imagen_url, leido_por, created_at,
                    usuarios:remitente_id ( nombre, apellido, foto_perfil_url )
                  ''').eq('id', record['id'] as String).single();
              controller.add(Mensaje.fromJson(data));
            } catch (error) {
              onError(error.toString());
            }
          },
        )
        .subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut) {
        onError(error?.toString() ?? 'No se pudo conectar al chat.');
      }
    });

    controller.onCancel = () => _db.removeChannel(channel);

    return sub;
  }

  void cancelarTodas() {}

  Future<Chat> obtenerOCrearChatDirecto({
    required String usuarioA,
    required String usuarioB,
  }) async {
    final chatId = await _db.rpc(
      'obtener_o_crear_chat_directo',
      params: {'p_otro_usuario_id': usuarioB},
    ) as String;
    final chats = await fetchChats(usuarioA);
    return chats.firstWhere((chat) => chat.id == chatId);
  }
}
