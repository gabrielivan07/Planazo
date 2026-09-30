import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../../widgets/juntada_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final usuario = provider.usuario;
    if (usuario == null) return const SizedBox();

    return Scaffold(
      backgroundColor: PlanazoColors.fondoPrimario,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 150,
          pinned: true,
          backgroundColor: PlanazoColors.amarillo,
          elevation: 0,
          flexibleSpace: FlexibleSpaceBar(
            background: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('¡Hola, ${usuario.nombre}! 👋',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: PlanazoColors.negro)),
                      const Text('¿Qué hacemos hoy?',
                          style: TextStyle(
                              fontSize: 13, color: PlanazoColors.negroSuave)),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Notificaciones',
                        icon: const Icon(Icons.notifications_none,
                            color: PlanazoColors.negro),
                        onPressed: () => context.push('/notificaciones'),
                      ),
                      GestureDetector(
                        onTap: () => context.go('/perfil'),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: PlanazoColors.negro,
                          child: Text(usuario.iniciales,
                              style: const TextStyle(
                                  color: PlanazoColors.amarillo,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _TarjetaConfianza(usuario: usuario),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: _AccionRapida(
                    emoji: '🗺️',
                    label: 'Explorar mapa',
                    dark: false,
                    onTap: () => context.go('/mapa'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AccionRapida(
                    emoji: '➕',
                    label: 'Crear juntada',
                    dark: true,
                    onTap: () => context.push('/crear-juntada'),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Próximas juntadas',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: PlanazoColors.negro)),
                  TextButton(
                    onPressed: () => context.go('/mapa'),
                    child: const Text('Ver todas',
                        style: TextStyle(
                            color: PlanazoColors.textoSecundario,
                            fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ]),
          ),
        ),
        provider.cargandoJuntadas
            ? const SliverToBoxAdapter(
                child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                    child: CircularProgressIndicator(
                        color: PlanazoColors.amarillo)),
              ))
            : SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final list = provider.juntadasProximas;
                      if (i >= list.length) return null;
                      return JuntadaCard(
                        juntada: list[i],
                        onTap: () => context.push('/juntada/${list[i].id}'),
                      );
                    },
                    childCount: provider.juntadasProximas.length,
                  ),
                ),
              ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ]),
    );
  }
}

// ── Tarjeta de confianza ─────────────────────────────────────
class _TarjetaConfianza extends StatelessWidget {
  final Usuario usuario;
  const _TarjetaConfianza({required this.usuario});

  @override
  Widget build(BuildContext context) {
    final nivel = usuario.nivelConfianza;
    final progreso = nivel.progreso(usuario.puntosConfianza);
    final siguienteNivel = nivel.siguiente;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: PlanazoColors.negro, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Tu nivel de confianza',
                style: TextStyle(fontSize: 11, color: Colors.white54)),
            const SizedBox(height: 3),
            Row(children: [
              Text(nivel.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(nivel.etiqueta,
                  style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: PlanazoColors.amarillo)),
            ]),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: PlanazoColors.amarillo,
                borderRadius: BorderRadius.circular(10)),
            child: Text('${usuario.puntosConfianza} pts',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: PlanazoColors.negro)),
          ),
        ]),
        const SizedBox(height: 14),
        LinearProgressIndicator(
          value: progreso,
          backgroundColor: Colors.white12,
          color: PlanazoColors.amarillo,
          borderRadius: BorderRadius.circular(4),
          minHeight: 5,
        ),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${nivel.puntosMinimos}',
              style: const TextStyle(fontSize: 9, color: Colors.white30)),
          Text(
            siguienteNivel == null
                ? 'Nivel máximo alcanzado'
                : '${(progreso * 100).toInt()}% hacia ${siguienteNivel.etiqueta}',
            style: const TextStyle(fontSize: 9, color: Colors.white38),
          ),
          Text('${siguienteNivel?.puntosMinimos ?? nivel.puntosMinimos}',
              style: const TextStyle(fontSize: 9, color: Colors.white30)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _StatChip('🎯', '${usuario.resenas.length}', 'reseñas'),
          const SizedBox(width: 8),
          if (usuario.verificado) const _StatChip('✓', '', 'Verificado'),
        ]),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String icon, value, label;
  const _StatChip(this.icon, this.value, this.label);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: Colors.white10, borderRadius: BorderRadius.circular(7)),
        child: Text('$icon $value $label',
            style: const TextStyle(fontSize: 10, color: Colors.white60)),
      );
}

class _AccionRapida extends StatelessWidget {
  final String emoji, label;
  final bool dark;
  final VoidCallback onTap;
  const _AccionRapida(
      {required this.emoji,
      required this.label,
      required this.dark,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: dark ? PlanazoColors.negro : PlanazoColors.amarilloClaro,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 9),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color:
                          dark ? PlanazoColors.blanco : PlanazoColors.negro)),
            ),
          ]),
        ),
      );
}
