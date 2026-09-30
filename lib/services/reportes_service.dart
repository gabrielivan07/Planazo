import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class ReportesService {
  ReportesService._();
  static final instance = ReportesService._();

  SupabaseClient get _db => SupabaseService.instance.client;

  Future<void> reportarJuntada({
    required String juntadaId,
    required String motivo,
    String? detalle,
  }) async {
    final reportanteId = SupabaseService.instance.currentUserId;
    if (reportanteId == null) throw StateError('No hay una sesión activa.');

    await _db.from('reportes').insert({
      'reportante_id': reportanteId,
      'juntada_id': juntadaId,
      'motivo': motivo,
      'detalle': detalle,
    });
  }

  Future<void> reportarUsuario({
    required String usuarioId,
    required String motivo,
    String? detalle,
  }) async {
    final reportanteId = SupabaseService.instance.currentUserId;
    if (reportanteId == null) throw StateError('No hay una sesión activa.');
    if (reportanteId == usuarioId) {
      throw ArgumentError('No podés reportarte a vos mismo.');
    }

    await _db.from('reportes').insert({
      'reportante_id': reportanteId,
      'usuario_id': usuarioId,
      'motivo': motivo,
      'detalle': detalle,
    });
  }
}
