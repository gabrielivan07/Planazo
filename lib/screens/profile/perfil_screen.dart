import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';

class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final usuario = provider.usuario;
    if (usuario == null) return const SizedBox();

    return Scaffold(
      backgroundColor: PlanazoColors.fondoPrimario,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 180,
          pinned: true,
          backgroundColor: PlanazoColors.amarillo,
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: PlanazoColors.negro),
              onPressed: () => context.push('/editar-perfil'),
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: PlanazoColors.negro),
              onPressed: () => _confirmarLogout(context),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Padding(
              padding: const EdgeInsets.fromLTRB(18, 56, 18, 16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: PlanazoColors.negro,
                  child: Text(usuario.iniciales,
                      style: const TextStyle(
                          color: PlanazoColors.amarillo,
                          fontSize: 26,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(usuario.nombreCompleto,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: PlanazoColors.negro),
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (usuario.verificado) ...[
                          const SizedBox(width: 5),
                          const Icon(Icons.verified,
                              color: PlanazoColors.info, size: 18),
                        ],
                      ]),
                      Text(usuario.email,
                          style: const TextStyle(
                              fontSize: 12, color: PlanazoColors.negroSuave),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Stats
              Row(children: [
                _StatCard('📝', '${usuario.resenas.length}', 'Reseñas'),
                const SizedBox(width: 10),
                _StatCard('⭐', usuario.promedioCalificacion.toStringAsFixed(1),
                    'Rating'),
                const SizedBox(width: 10),
                _StatCard('🎯', '${usuario.puntosConfianza}', 'Puntos'),
              ]),
              const SizedBox(height: 16),

              // Confianza
              _TarjetaConfianza(usuario: usuario),
              const SizedBox(height: 14),

              // Plan
              _TarjetaPlan(esPremium: usuario.esPremium),
              const SizedBox(height: 18),

              // Intereses
              if (usuario.intereses.isNotEmpty) ...[
                const Text('Mis intereses',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: PlanazoColors.negro)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 7,
                  children: usuario.intereses.map((interes) {
                    final emoji = CategoriaJuntada.emojiPara(interes);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        color: PlanazoColors.amarilloClaro,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: PlanazoColors.amarilloOscuro
                                .withValues(alpha: .4)),
                      ),
                      child: Text('$emoji $interes',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: PlanazoColors.negro)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
              ],

              // Reseñas
              const Text('Reseñas recibidas',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: PlanazoColors.negro)),
              const SizedBox(height: 10),
              if (usuario.resenas.isEmpty)
                const Text('Todavía no tenés reseñas.',
                    style: TextStyle(
                        color: PlanazoColors.textoSecundario, fontSize: 13))
              else
                ...usuario.resenas.map((r) => _TarjetaResena(resena: r)),

              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: provider.cargando
                    ? null
                    : () => _confirmarEliminarCuenta(context),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Eliminar mi cuenta'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PlanazoColors.error,
                  side: const BorderSide(color: PlanazoColors.error),
                  minimumSize: const Size.fromHeight(46),
                ),
              ),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ]),
    );
  }

  void _confirmarLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro que querés cerrar sesión?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: PlanazoColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AppProvider>().cerrarSesion();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Cerrar sesión',
                style: TextStyle(color: PlanazoColors.blanco)),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminarCuenta(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text(
            'Esta acción es permanente. Se eliminarán tu perfil, tus juntadas y tus participaciones. ¿Querés continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: PlanazoColors.error),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await context.read<AppProvider>().eliminarCuenta();
                if (context.mounted) context.go('/login');
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('No se pudo eliminar la cuenta.'),
                    backgroundColor: PlanazoColors.error,
                  ));
                }
              }
            },
            child: const Text('Eliminar',
                style: TextStyle(color: PlanazoColors.blanco)),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String emoji, valor, label;
  const _StatCard(this.emoji, this.valor, this.label);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            color: PlanazoColors.blanco,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: PlanazoColors.borde),
          ),
          child: Column(children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 3),
            Text(valor,
                style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: PlanazoColors.negro)),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: PlanazoColors.textoTerciario)),
          ]),
        ),
      );
}

class _TarjetaConfianza extends StatelessWidget {
  final Usuario usuario;
  const _TarjetaConfianza({required this.usuario});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: PlanazoColors.negro,
            borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Text(usuario.nivelConfianza.emoji,
              style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Nivel de confianza',
                  style: TextStyle(fontSize: 11, color: Colors.white54)),
              Text(usuario.nivelConfianza.etiqueta,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: PlanazoColors.amarillo)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: PlanazoColors.amarillo,
                borderRadius: BorderRadius.circular(9)),
            child: Text('${usuario.puntosConfianza} pts',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: PlanazoColors.negro)),
          ),
        ]),
      );
}

class _TarjetaPlan extends StatelessWidget {
  final bool esPremium;
  const _TarjetaPlan({required this.esPremium});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: esPremium
              ? PlanazoColors.amarillo
              : PlanazoColors.fondoSecundario,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: esPremium
                  ? PlanazoColors.amarilloOscuro
                  : PlanazoColors.borde),
        ),
        child: Row(children: [
          Text(esPremium ? '👑' : '🌱', style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(esPremium ? 'Plan Premium' : 'Plan Gratuito',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: PlanazoColors.negro)),
              Text(
                  esPremium
                      ? 'Juntadas ilimitadas · Sin publicidad'
                      : '3 juntadas/mes · Hasta 10 personas',
                  style: const TextStyle(
                      fontSize: 11, color: PlanazoColors.textoSecundario)),
            ]),
          ),
          if (!esPremium)
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  textStyle: const TextStyle(fontSize: 12)),
              child: const Text('Premium'),
            ),
        ]),
      );
}

class _TarjetaResena extends StatelessWidget {
  final Resena resena;
  const _TarjetaResena({required this.resena});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: PlanazoColors.blanco,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: PlanazoColors.borde),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: PlanazoColors.fondoSecundario,
              child: Text(
                resena.autorNombre.isNotEmpty ? resena.autorNombre[0] : '?',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: PlanazoColors.negro),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(resena.autorNombre,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: PlanazoColors.negro)),
            ),
            Row(
              children: List.generate(
                  5,
                  (i) => Icon(
                      i < resena.puntuacion ? Icons.star : Icons.star_border,
                      size: 13,
                      color: PlanazoColors.amarilloOscuro)),
            ),
          ]),
          const SizedBox(height: 7),
          Text(resena.comentario,
              style: const TextStyle(
                  fontSize: 12,
                  color: PlanazoColors.textoSecundario,
                  height: 1.5)),
        ]),
      );
}
