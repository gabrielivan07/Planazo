import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';

class DetalleJuntadaScreen extends StatefulWidget {
  final String juntadaId;
  const DetalleJuntadaScreen({super.key, required this.juntadaId});
  @override
  State<DetalleJuntadaScreen> createState() => _DetalleJuntadaScreenState();
}

class _DetalleJuntadaScreenState extends State<DetalleJuntadaScreen> {
  Juntada? _juntada;
  bool _cargando = true;
  bool _uniendose = false;
  bool _abriendoChat = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final juntada = await context
          .read<AppProvider>()
          .obtenerDetalleJuntada(widget.juntadaId);
      if (mounted) {
        setState(() {
          _juntada = juntada;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _error = 'No pudimos cargar esta juntada.';
        });
      }
    }
  }

  Future<void> _unirse() async {
    final juntada = _juntada;
    if (juntada == null) {
      return;
    }
    setState(() => _uniendose = true);
    try {
      final ok = await context.read<AppProvider>().unirseAJuntada(juntada.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ok
                ? '¡Ya estás adentro!'
                : 'No pudiste unirte. Puede que no haya cupos.'),
            backgroundColor: ok ? PlanazoColors.exito : PlanazoColors.error));
        if (ok) {
          setState(() => _juntada = Juntada(
              id: juntada.id,
              titulo: juntada.titulo,
              descripcion: juntada.descripcion,
              organizadorId: juntada.organizadorId,
              organizadorNombre: juntada.organizadorNombre,
              organizadorFoto: juntada.organizadorFoto,
              organizadorVerificado: juntada.organizadorVerificado,
              fecha: juntada.fecha,
              lugar: juntada.lugar,
              coordenadas: juntada.coordenadas,
              barrio: juntada.barrio,
              capacidadMaxima: juntada.capacidadMaxima,
              participantesCount: juntada.participantesCount + 1,
              categoria: juntada.categoria,
              etiquetas: juntada.etiquetas,
              esPublica: juntada.esPublica,
              estado: juntada.estado,
              soloVerificados: juntada.soloVerificados,
              imagenUrl: juntada.imagenUrl,
              creadoEn: juntada.creadoEn,
              distanciaKm: juntada.distanciaKm));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No pudimos completar la inscripción.'),
            backgroundColor: PlanazoColors.error));
      }
    } finally {
      if (mounted) setState(() => _uniendose = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_juntada == null) {
      return Scaffold(
          appBar: AppBar(),
          body: Center(child: Text(_error ?? 'Juntada no encontrada')));
    }
    final juntada = _juntada!;
    final provider = context.watch<AppProvider>();
    final esOrganizador = provider.usuario?.id == juntada.organizadorId;
    final unido = provider.estaUnido(juntada.id) || esOrganizador;
    final llena = juntada.estaLlena && !unido;
    return Scaffold(
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Volver',
              onPressed: () => context.go('/home')),
          title: const Text('Detalle',
              style: TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            IconButton(
              tooltip: 'Reportar juntada',
              icon: const Icon(Icons.flag_outlined),
              onPressed: () => _reportarJuntada(context, juntada),
            ),
          ]),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Container(
                height: 150,
                decoration: BoxDecoration(
                    color: PlanazoColors.negro,
                    borderRadius: BorderRadius.circular(20)),
                child: Center(
                    child: Text(CategoriaJuntada.emojiPara(juntada.categoria),
                        style: const TextStyle(fontSize: 64)))),
            const SizedBox(height: 20),
            Text(juntada.titulo,
                style:
                    const TextStyle(fontSize: 27, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              _tag(Icons.category_outlined, juntada.categoria),
              _tag(Icons.people_outline,
                  '${juntada.participantesCount}/${juntada.capacidadMaxima}'),
              if (juntada.estaLlena) _tag(Icons.lock_outline, 'Completa')
            ]),
            const SizedBox(height: 20),
            _info(Icons.calendar_month_outlined,
                '${juntada.fechaFormateada} a las ${juntada.horaFormateada}'),
            _info(Icons.location_on_outlined,
                '${juntada.lugar} · ${juntada.barrio}'),
            _info(
                Icons.person_outline, 'Organiza ${juntada.organizadorNombre}'),
            const Divider(height: 32),
            const Text('Sobre el plan',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(juntada.descripcion,
                style: const TextStyle(
                    height: 1.45, color: PlanazoColors.textoSecundario)),
            const SizedBox(height: 24),
            if (esOrganizador)
              const Text(
                  'Esta es tu juntada. Compartila para sumar participantes.',
                  style: TextStyle(color: PlanazoColors.textoSecundario))
            else
              ElevatedButton.icon(
                  onPressed: unido || llena || _uniendose ? null : _unirse,
                  icon: _uniendose
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: PlanazoColors.negro))
                      : Icon(unido ? Icons.check : Icons.group_add_outlined),
                  label: Text(unido
                      ? 'Ya estás unido'
                      : llena
                          ? 'Juntada completa'
                          : 'Unirme a la juntada')),
            if (unido) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                  onPressed:
                      _abriendoChat ? null : () => _abrirChat(juntada.id),
                  icon: _abriendoChat
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chat_bubble_outline),
                  label: const Text('Abrir chat de la juntada'))
            ],
            if (unido && juntada.yaPaso) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () => _resenarJuntada(juntada),
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('Reseñar la juntada'),
              ),
              OutlinedButton.icon(
                onPressed: () => _calificarParticipantes(juntada),
                icon: const Icon(Icons.people_outline),
                label: const Text('Calificar participantes'),
              ),
            ],
            if (esOrganizador && juntada.yaPaso) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _gestionarAsistencia(juntada),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Marcar asistencia'),
              ),
            ],
          ]),
    );
  }

  Widget _tag(IconData icon, String text) => Chip(
      avatar: Icon(icon, size: 16, color: PlanazoColors.negro),
      label: Text(text),
      backgroundColor: PlanazoColors.amarilloClaro);
  Widget _info(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(icon, color: PlanazoColors.amarilloOscuro),
        const SizedBox(width: 10),
        Expanded(
            child:
                Text(text, style: const TextStyle(fontWeight: FontWeight.w600)))
      ]));

  Future<void> _abrirChat(String juntadaId) async {
    setState(() => _abriendoChat = true);
    try {
      final chat =
          await context.read<AppProvider>().obtenerChatJuntada(juntadaId);
      if (!mounted) return;
      if (chat == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Supabase no devolvió un chat para esta juntada. Revisá que estén instalados los triggers de chats.'),
          backgroundColor: PlanazoColors.error,
        ));
        return;
      }
      context.push('/chat/${chat.id}');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Supabase no pudo abrir el chat: $error'),
          backgroundColor: PlanazoColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _abriendoChat = false);
    }
  }

  Future<void> _resenarJuntada(Juntada juntada) async {
    final provider = context.read<AppProvider>();
    final resena = await _pedirResena('esta juntada');
    if (resena == null || !mounted) return;
    try {
      await provider.enviarResenaJuntada(
        juntadaId: juntada.id,
        puntuacion: resena.$1,
        comentario: resena.$2,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Reseña enviada. Gracias por compartir tu experiencia.'),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No se pudo enviar. Quizás ya reseñaste esta juntada.'),
        backgroundColor: PlanazoColors.error,
      ));
    }
  }

  Future<(int, String)?> _pedirResena(String destino) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var puntuacion = 5.0;
    final resultado = await showDialog<(int, String)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Reseña de $destino'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RatingBar.builder(
                  initialRating: puntuacion,
                  minRating: 1,
                  allowHalfRating: false,
                  itemCount: 5,
                  itemSize: 32,
                  itemBuilder: (_, __) => const Icon(
                    Icons.star_rounded,
                    color: PlanazoColors.amarilloOscuro,
                  ),
                  onRatingUpdate: (value) =>
                      setDialogState(() => puntuacion = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: controller,
                  minLines: 3,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Contá cómo fue (mínimo 5 caracteres)',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => value == null || value.trim().length < 5
                      ? 'Escribí al menos 5 caracteres'
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(
                  dialogContext,
                  (puntuacion.round(), controller.text.trim()),
                );
              },
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return resultado;
  }

  Future<void> _calificarParticipantes(Juntada juntada) async {
    final provider = context.read<AppProvider>();
    try {
      final participantes = await provider.participantesParaResena(juntada.id);
      if (!mounted) return;
      if (participantes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Todavía no hay otros participantes para calificar.'),
        ));
        return;
      }

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.65,
            child: Column(children: [
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text('Calificar participantes',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: participantes.length,
                  itemBuilder: (context, index) {
                    final participante = participantes[index];
                    final id = participante['usuario_id'] as String;
                    final nombre =
                        '${participante['nombre'] ?? ''} ${participante['apellido'] ?? ''}'
                            .trim();
                    final foto = participante['foto_perfil_url'] as String?;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            foto == null ? null : NetworkImage(foto),
                        child: foto == null
                            ? Text(
                                nombre.isEmpty ? '?' : nombre[0].toUpperCase())
                            : null,
                      ),
                      title: Text(nombre.isEmpty ? 'Participante' : nombre),
                      trailing: const Icon(Icons.rate_review_outlined),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _resenarParticipante(juntada, id, nombre);
                      },
                    );
                  },
                ),
              ),
            ]),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudieron cargar los participantes.'),
          backgroundColor: PlanazoColors.error,
        ));
      }
    }
  }

  Future<void> _resenarParticipante(
      Juntada juntada, String participanteId, String nombre) async {
    final provider = context.read<AppProvider>();
    final resena = await _pedirResena(nombre.isEmpty ? 'participante' : nombre);
    if (resena == null || !mounted) return;
    try {
      await provider.enviarResenaParticipante(
        juntadaId: juntada.id,
        participanteId: participanteId,
        puntuacion: resena.$1,
        comentario: resena.$2,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Calificación enviada.'),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('No se pudo calificar. Quizás ya calificaste a esta persona.'),
        backgroundColor: PlanazoColors.error,
      ));
    }
  }

  Future<void> _gestionarAsistencia(Juntada juntada) async {
    final provider = context.read<AppProvider>();
    try {
      final participantes = await provider.obtenerAsistenciaJuntada(juntada.id);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * 0.65,
              child: Column(children: [
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('Asistencia',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: participantes.length,
                    itemBuilder: (context, index) {
                      final participante = participantes[index];
                      final id = participante['usuario_id'] as String;
                      final nombre =
                          '${participante['nombre'] ?? ''} ${participante['apellido'] ?? ''}'
                              .trim();
                      final asistencia =
                          participante['asistencia'] as String? ?? 'pendiente';
                      return ListTile(
                        title: Text(nombre.isEmpty ? 'Participante' : nombre),
                        subtitle: Text(_etiquetaAsistencia(asistencia)),
                        trailing: asistencia != 'pendiente'
                            ? const Icon(Icons.check_circle_outline)
                            : PopupMenuButton<String>(
                                tooltip: 'Marcar asistencia',
                                onSelected: (estado) async {
                                  try {
                                    await provider.marcarAsistencia(
                                      juntadaId: juntada.id,
                                      usuarioId: id,
                                      asistencia: estado,
                                    );
                                    if (mounted) {
                                      setSheetState(() =>
                                          participante['asistencia'] = estado);
                                    }
                                  } catch (_) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                        content: Text(
                                            'No se pudo guardar la asistencia.'),
                                      ));
                                    }
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'puntual',
                                      child: Text('Llegó puntual')),
                                  PopupMenuItem(
                                      value: 'tarde',
                                      child: Text('Llegó tarde')),
                                  PopupMenuItem(
                                      value: 'ausente', child: Text('Ausente')),
                                ],
                              ),
                      );
                    },
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo cargar la asistencia.'),
          backgroundColor: PlanazoColors.error,
        ));
      }
    }
  }

  String _etiquetaAsistencia(String asistencia) => switch (asistencia) {
        'puntual' => 'Llegó puntual',
        'tarde' => 'Llegó tarde',
        'ausente' => 'Ausente',
        _ => 'Sin marcar',
      };

  Future<void> _reportarJuntada(BuildContext context, Juntada juntada) async {
    const motivos = [
      'Contenido inapropiado',
      'Actividad falsa o engañosa',
      'Acoso o comportamiento inseguro',
      'Otro',
    ];
    final motivo = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            const ListTile(
              title: Text('¿Por qué querés reportar esta juntada?',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            ...motivos.map((item) => ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(item),
                  onTap: () => Navigator.pop(sheetContext, item),
                )),
          ],
        ),
      ),
    );
    if (motivo == null || !context.mounted) return;
    try {
      await context.read<AppProvider>().reportarJuntada(
            juntadaId: juntada.id,
            motivo: motivo,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gracias. Revisaremos el reporte.')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo enviar el reporte.'),
          backgroundColor: PlanazoColors.error));
    }
  }
}
