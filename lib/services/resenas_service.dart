import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class ResenasService {
  ResenasService._();
  static final instance = ResenasService._();

  SupabaseClient get _db => SupabaseService.instance.client;

  Future<List<Map<String, dynamic>>> fetchParticipantes(
      String juntadaId) async {
    final data = await _db.rpc(
      'obtener_participantes_para_resena',
      params: {'p_juntada_id': juntadaId},
    );
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchResenasJuntada(
      String juntadaId) async {
    final data = await _db.from('resenas_juntadas').select('''
          id, autor_id, puntuacion, comentario, created_at,
          usuarios:autor_id ( nombre, apellido, foto_perfil_url )
        ''').eq('juntada_id', juntadaId).order('created_at', ascending: false);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<void> crearResenaJuntada({
    required String juntadaId,
    required String autorId,
    required int puntuacion,
    required String comentario,
  }) async {
    await _db.from('resenas_juntadas').insert({
      'juntada_id': juntadaId,
      'autor_id': autorId,
      'puntuacion': puntuacion,
      'comentario': comentario,
    });
  }

  Future<void> crearResenaParticipante({
    required String juntadaId,
    required String autorId,
    required String destinatarioId,
    required int puntuacion,
    required String comentario,
  }) async {
    await _db.from('resenas').insert({
      'juntada_id': juntadaId,
      'autor_id': autorId,
      'destinatario_id': destinatarioId,
      'puntuacion': puntuacion,
      'comentario': comentario,
    });
  }
}
