import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../services/chat_service.dart';
import '../../services/supabase_service.dart';
import '../../models/models.dart';

class ChatDetalleScreen extends StatefulWidget {
  final String chatId;
  const ChatDetalleScreen({super.key, required this.chatId});
  @override
  State<ChatDetalleScreen> createState() => _State();
}

class _State extends State<ChatDetalleScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  List<Mensaje> _mensajes = [];
  bool _cargando = true;
  bool _enviando = false;
  String? _miUid;
  StreamSubscription<Mensaje>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _miUid = SupabaseService.instance.currentUserId;
    _cargarYSuscribir();
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _cargarYSuscribir() async {
    try {
      final msgs = await ChatService.instance.fetchMensajes(widget.chatId);
      if (!mounted) return;
      setState(() {
        _mensajes = msgs;
        _cargando = false;
      });
      _scrollFinal();
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }

    // Suscripción Realtime
    _realtimeSub = ChatService.instance.suscribir(
      chatId: widget.chatId,
      usuarioId: _miUid ?? '',
      onNuevoMensaje: (msg) {
        if (!mounted) return;
        setState(() => _mensajes.add(msg));
        _scrollFinal(animado: true);
        if (_miUid != null) {
          ChatService.instance.marcarLeido(widget.chatId, _miUid!).ignore();
        }
      },
      onError: (_) {},
    );

    if (_miUid != null) {
      ChatService.instance.marcarLeido(widget.chatId, _miUid!).ignore();
    }
  }

  Future<void> _enviar() async {
    final txt = _ctrl.text.trim();
    if (txt.isEmpty || _enviando) return;
    setState(() => _enviando = true);
    _ctrl.clear();

    // Inserción optimista
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimista = Mensaje(
      id: tempId,
      chatId: widget.chatId,
      remitenteId: _miUid ?? '',
      remitenteNombre:
          context.read<AppProvider>().usuario?.nombreCompleto ?? '',
      contenido: txt,
      creadoEn: DateTime.now(),
    );
    setState(() => _mensajes.add(optimista));
    _scrollFinal(animado: true);

    try {
      final real =
          await context.read<AppProvider>().enviarMensaje(widget.chatId, txt);
      if (real != null && mounted) {
        setState(() {
          final idx = _mensajes.indexWhere((m) => m.id == tempId);
          if (idx != -1) _mensajes[idx] = real;
        });
      } else if (mounted) {
        setState(() => _mensajes.removeWhere((m) => m.id == tempId));
        _ctrl.text = txt;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo enviar. Intentá de nuevo.'),
          backgroundColor: PlanazoColors.error,
        ));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _mensajes.removeWhere((m) => m.id == tempId));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo enviar. Intentá de nuevo.'),
          backgroundColor: PlanazoColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _scrollFinal({bool animado = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      if (animado) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      } else {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chats = context.watch<AppProvider>().chats;
    final chat = chats
        .cast<Chat?>()
        .firstWhere((c) => c?.id == widget.chatId, orElse: () => null);
    final titulo = chat?.displayTitle ?? 'Chat';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis),
          if (chat?.esGrupal == true)
            const Text('Chat grupal',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400)),
        ]),
        actions: [
          if (chat?.esGrupal == true)
            IconButton(
              tooltip: 'Ver integrantes',
              icon: const Icon(Icons.people_outline),
              onPressed: _mostrarIntegrantes,
            ),
        ],
      ),
      body: Column(children: [
        // Lista de mensajes
        Expanded(
          child: _cargando
              ? const Center(
                  child:
                      CircularProgressIndicator(color: PlanazoColors.amarillo))
              : _mensajes.isEmpty
                  ? const Center(
                      child: Text(
                      'No hay mensajes todavía.\n¡Sé el primero en escribir!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: PlanazoColors.textoTerciario, fontSize: 14),
                    ))
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      itemCount: _mensajes.length,
                      itemBuilder: (ctx, i) {
                        final msg = _mensajes[i];
                        final esMio = msg.remitenteId == _miUid;
                        return _Burbuja(
                          mensaje: msg,
                          esMio: esMio,
                          esGrupal: chat?.esGrupal ?? false,
                          pendiente: msg.id.startsWith('temp_'),
                        );
                      },
                    ),
        ),

        // Input
        Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
          decoration: const BoxDecoration(
            color: PlanazoColors.blanco,
            border: Border(top: BorderSide(color: PlanazoColors.borde)),
          ),
          child: SafeArea(
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                  onSubmitted: (_) => _enviar(),
                  decoration: InputDecoration(
                    hintText: 'Escribí un mensaje...',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 11),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide:
                            const BorderSide(color: PlanazoColors.borde)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide:
                            const BorderSide(color: PlanazoColors.borde)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                            color: PlanazoColors.amarillo, width: 2)),
                    filled: true,
                    fillColor: PlanazoColors.fondoSecundario,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _enviar,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: PlanazoColors.amarillo,
                    shape: BoxShape.circle,
                  ),
                  child: _enviando
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: PlanazoColors.negro))
                      : const Icon(Icons.send_rounded,
                          color: PlanazoColors.negro, size: 20),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Future<void> _mostrarIntegrantes() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
                child: Row(children: [
                  const Expanded(
                    child: Text('Integrantes',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ]),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: ChatService.instance.fetchIntegrantes(widget.chatId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(
                          child:
                              Text('No se pudieron cargar los integrantes.'));
                    }
                    final integrantes = snapshot.data ?? [];
                    if (integrantes.isEmpty) {
                      return const Center(child: Text('No hay integrantes.'));
                    }
                    return ListView.separated(
                      itemCount: integrantes.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final integrante = integrantes[index];
                        final uid = integrante['usuario_id'] as String;
                        final nombre =
                            '${integrante['nombre'] ?? ''} ${integrante['apellido'] ?? ''}'
                                .trim();
                        final foto = integrante['foto_perfil_url'] as String?;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage:
                                foto != null ? NetworkImage(foto) : null,
                            child: foto == null
                                ? Text(nombre.isEmpty
                                    ? '?'
                                    : nombre[0].toUpperCase())
                                : null,
                          ),
                          title: Text(nombre.isEmpty ? 'Usuario' : nombre),
                          subtitle: uid == _miUid ? const Text('Vos') : null,
                          trailing: uid == _miUid
                              ? null
                              : PopupMenuButton<String>(
                                  tooltip: 'Acciones para $nombre',
                                  onSelected: (accion) async {
                                    Navigator.pop(sheetContext);
                                    if (accion == 'amigo') {
                                      await _agregarAmigo(uid, nombre);
                                    } else if (accion == 'mensaje') {
                                      await _iniciarChatDirecto(uid);
                                    } else if (accion == 'denunciar') {
                                      await _denunciarUsuario(uid, nombre);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'amigo',
                                      child: _AccionIntegrante(
                                          icon: Icons.person_add_alt_1,
                                          label: 'Agregar amigo'),
                                    ),
                                    PopupMenuItem(
                                      value: 'mensaje',
                                      child: _AccionIntegrante(
                                          icon: Icons.chat_bubble_outline,
                                          label: 'Enviar mensaje'),
                                    ),
                                    PopupMenuItem(
                                      value: 'denunciar',
                                      child: _AccionIntegrante(
                                          icon: Icons.flag_outlined,
                                          label: 'Denunciar'),
                                    ),
                                  ],
                                ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _agregarAmigo(String usuarioId, String nombre) async {
    try {
      final agregado =
          await context.read<AppProvider>().agregarAmigo(usuarioId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            agregado ? '$nombre se agregó a tus amigos.' : 'Ya es tu amigo.'),
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo agregar a este usuario.'),
        ));
      }
    }
  }

  Future<void> _iniciarChatDirecto(String usuarioId) async {
    final chat =
        await context.read<AppProvider>().iniciarChatDirecto(usuarioId);
    if (!mounted) return;
    if (chat == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No se pudo iniciar la conversación.'),
      ));
      return;
    }
    context.push('/chat/${chat.id}');
  }

  Future<void> _denunciarUsuario(String usuarioId, String nombre) async {
    final detalleController = TextEditingController();
    var motivo = 'Acoso';
    final reporte = await showDialog<(String, String?)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Denunciar a $nombre'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: motivo,
                decoration: const InputDecoration(labelText: 'Motivo'),
                items: const [
                  'Acoso',
                  'Contenido inapropiado',
                  'Suplantación',
                  'Otro',
                ]
                    .map((item) =>
                        DropdownMenuItem(value: item, child: Text(item)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => motivo = value);
                },
              ),
              TextField(
                controller: detalleController,
                maxLength: 1000,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Detalle (opcional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                (motivo, detalleController.text.trim()),
              ),
              child: const Text('Enviar denuncia'),
            ),
          ],
        ),
      ),
    );
    detalleController.dispose();
    if (reporte == null) return;
    if (!mounted) return;

    try {
      await context.read<AppProvider>().reportarUsuario(
            usuarioId: usuarioId,
            motivo: reporte.$1,
            detalle: reporte.$2?.isEmpty == true ? null : reporte.$2,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Denuncia enviada.'),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo enviar la denuncia.'),
        ));
      }
    }
  }
}

class _AccionIntegrante extends StatelessWidget {
  final IconData icon;
  final String label;
  const _AccionIntegrante({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Text(label),
      ]);
}

// ── Burbuja de mensaje ───────────────────────────────────────
class _Burbuja extends StatelessWidget {
  final Mensaje mensaje;
  final bool esMio;
  final bool esGrupal;
  final bool pendiente;

  const _Burbuja({
    required this.mensaje,
    required this.esMio,
    required this.esGrupal,
    this.pendiente = false,
  });

  @override
  Widget build(BuildContext context) {
    final hora =
        '${mensaje.creadoEn.hour.toString().padLeft(2, '0')}:${mensaje.creadoEn.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment:
            esMio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!esMio && esGrupal)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 3),
              child: Text(mensaje.remitenteNombre,
                  style: const TextStyle(
                      fontSize: 11,
                      color: PlanazoColors.textoTerciario,
                      fontWeight: FontWeight.w500)),
            ),
          Row(
            mainAxisAlignment:
                esMio ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!esMio) ...[
                CircleAvatar(
                  radius: 15,
                  backgroundColor: PlanazoColors.fondoSecundario,
                  child: Text(
                    mensaje.remitenteNombre.isNotEmpty
                        ? mensaje.remitenteNombre[0]
                        : '?',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: PlanazoColors.negro),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Opacity(
                  opacity: pendiente ? 0.65 : 1.0,
                  child: Container(
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.72),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: esMio ? PlanazoColors.negro : PlanazoColors.blanco,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(esMio ? 18 : 4),
                        bottomRight: Radius.circular(esMio ? 4 : 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(mensaje.contenido,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: esMio
                                      ? PlanazoColors.blanco
                                      : PlanazoColors.textoPrimario)),
                          const SizedBox(height: 3),
                          Text(
                            pendiente ? 'Enviando...' : hora,
                            style: TextStyle(
                                fontSize: 9,
                                color: esMio
                                    ? Colors.white38
                                    : PlanazoColors.textoTerciario),
                          ),
                        ]),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
