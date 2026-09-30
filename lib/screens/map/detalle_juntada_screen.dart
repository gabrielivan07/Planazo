import 'package:flutter/material.dart';
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
