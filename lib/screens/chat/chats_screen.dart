import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mensajes'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Chats'),
              Tab(text: 'Archivados'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ListaChats(archivados: false),
            _ListaChats(archivados: true),
          ],
        ),
      ),
    );
  }
}

class _ListaChats extends StatelessWidget {
  final bool archivados;
  const _ListaChats({required this.archivados});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final miUid = provider.usuario?.id ?? '';
    final chats = provider.chats
        .where((chat) => !chat.eliminado && chat.archivado == archivados)
        .toList();

    if (chats.isEmpty) {
      return Center(
        child: Text(
          archivados ? 'No hay chats archivados' : 'Todavía no hay chats',
          style: const TextStyle(color: PlanazoColors.textoSecundario),
        ),
      );
    }

    return ListView.separated(
      itemCount: chats.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (ctx, i) => _ChatTile(
        chat: chats[i],
        miUid: miUid,
        onTap: () => context.push('/chat/${chats[i].id}'),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final Chat chat;
  final String miUid;
  final VoidCallback onTap;
  const _ChatTile(
      {required this.chat, required this.miUid, required this.onTap});

  String _formatTiempo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inHours < 1) return 'Hace ${diff.inMinutes}m';
    if (diff.inDays < 1) return 'Hace ${diff.inHours}h';
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    final titulo = chat.displayTitle;
    final ultimo = chat.ultimoMensaje;
    final noLeidos = ultimo != null && !ultimo.esLeido(miUid) ? 1 : 0;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 24,
        backgroundImage: !chat.esGrupal && chat.contactoFoto != null
            ? NetworkImage(chat.contactoFoto!)
            : null,
        backgroundColor: chat.esGrupal
            ? PlanazoColors.amarillo
            : PlanazoColors.fondoSecundario,
        child: chat.contactoFoto != null && !chat.esGrupal
            ? null
            : chat.esGrupal
                ? const Text('👥', style: TextStyle(fontSize: 20))
                : Text(titulo.isNotEmpty ? titulo[0].toUpperCase() : '?',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: PlanazoColors.negro)),
      ),
      title: Row(children: [
        Expanded(
          child: Text(titulo,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: noLeidos > 0 ? FontWeight.w700 : FontWeight.w500,
                  color: PlanazoColors.negro),
              overflow: TextOverflow.ellipsis),
        ),
        if (chat.silenciado)
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(Icons.notifications_off_outlined,
                size: 15, color: PlanazoColors.textoTerciario),
          ),
        if (chat.fijado)
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(Icons.push_pin_outlined,
                size: 15, color: PlanazoColors.textoTerciario),
          ),
        if (ultimo != null)
          Text(_formatTiempo(ultimo.creadoEn),
              style: TextStyle(
                  fontSize: 11,
                  color: noLeidos > 0
                      ? PlanazoColors.negro
                      : PlanazoColors.textoTerciario,
                  fontWeight:
                      noLeidos > 0 ? FontWeight.w600 : FontWeight.w400)),
      ]),
      subtitle: Row(children: [
        Expanded(
          child: Text(
            ultimo?.contenido ?? 'Sin mensajes',
            style: TextStyle(
                fontSize: 12,
                color: noLeidos > 0
                    ? PlanazoColors.textoPrimario
                    : PlanazoColors.textoTerciario),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (noLeidos > 0)
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
                color: PlanazoColors.negro,
                borderRadius: BorderRadius.circular(10)),
            child: Text('$noLeidos',
                style: const TextStyle(
                    fontSize: 10,
                    color: PlanazoColors.amarillo,
                    fontWeight: FontWeight.w700)),
          ),
      ]),
      trailing: PopupMenuButton<String>(
        tooltip: 'Opciones del chat',
        onSelected: (accion) => _accionChat(context, accion),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'silenciar',
            child: _OpcionMenu(
              icon: chat.silenciado
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              texto: chat.silenciado ? 'Activar notificaciones' : 'Silenciar',
            ),
          ),
          PopupMenuItem(
            value: 'fijar',
            child: _OpcionMenu(
              icon: chat.fijado ? Icons.push_pin : Icons.push_pin_outlined,
              texto: chat.fijado ? 'Desfijar' : 'Fijar arriba',
            ),
          ),
          PopupMenuItem(
            value: 'archivar',
            child: _OpcionMenu(
              icon: chat.archivado
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined,
              texto: chat.archivado ? 'Desarchivar' : 'Archivar',
            ),
          ),
          const PopupMenuItem(
            value: 'eliminar',
            child: _OpcionMenu(
              icon: Icons.delete_outline,
              texto: 'Borrar chat',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _accionChat(BuildContext context, String accion) async {
    final provider = context.read<AppProvider>();
    var confirmado = true;
    if (accion == 'eliminar') {
      confirmado = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Borrar chat'),
              content: const Text('Se ocultará de tu lista de chats.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Borrar'),
                ),
              ],
            ),
          ) ??
          false;
    }
    if (!confirmado || !context.mounted) return;

    try {
      switch (accion) {
        case 'silenciar':
          await provider.actualizarPreferenciasChat(
            chat.id,
            silenciado: !chat.silenciado,
          );
        case 'fijar':
          await provider.actualizarPreferenciasChat(chat.id,
              fijado: !chat.fijado);
        case 'archivar':
          await provider.actualizarPreferenciasChat(
            chat.id,
            archivado: !chat.archivado,
          );
        case 'eliminar':
          await provider.actualizarPreferenciasChat(chat.id, eliminado: true);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo actualizar el chat.'),
        ));
      }
    }
  }
}

class _OpcionMenu extends StatelessWidget {
  final IconData icon;
  final String texto;
  const _OpcionMenu({required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Text(texto),
      ]);
}
