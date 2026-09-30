import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';

class RegistroInteresesScreen extends StatefulWidget {
  const RegistroInteresesScreen({super.key});
  @override
  State<RegistroInteresesScreen> createState() => _State();
}

class _State extends State<RegistroInteresesScreen> {
  final Set<String> _sel = {};

  void _toggle(String n) =>
      setState(() => _sel.contains(n) ? _sel.remove(n) : _sel.add(n));

  Future<void> _continuar() async {
    // Persiste en Supabase a través del Provider
    await context.read<AppProvider>().actualizarIntereses(_sel.toList());
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: PlanazoColors.fondoPrimario,
        body: SafeArea(
          child: Column(children: [
            // Header amarillo — idéntico al v2
            Container(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 18),
              color: PlanazoColors.amarillo,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('¿Qué te gusta hacer?',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: PlanazoColors.negro)),
                    const SizedBox(height: 4),
                    Text(
                      'Elegí tus intereses para ver juntadas personalizadas.',
                      style: TextStyle(
                          fontSize: 13,
                          color: PlanazoColors.negro.withValues(alpha: .7)),
                    ),
                  ]),
            ),

            // Grid de categorías
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                ),
                itemCount: CategoriaJuntada.todas.length,
                itemBuilder: (ctx, i) {
                  final cat = CategoriaJuntada.todas[i];
                  final on = _sel.contains(cat.nombre);
                  return GestureDetector(
                    onTap: () => _toggle(cat.nombre),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color:
                            on ? PlanazoColors.amarillo : PlanazoColors.blanco,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: on
                              ? PlanazoColors.amarilloOscuro
                              : PlanazoColors.borde,
                          width: on ? 2 : 1,
                        ),
                        boxShadow: on
                            ? [
                                BoxShadow(
                                  color: PlanazoColors.amarillo
                                      .withValues(alpha: .35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            : [],
                      ),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(cat.emoji,
                                style: const TextStyle(fontSize: 30)),
                            const SizedBox(height: 6),
                            Text(cat.nombre,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: on
                                        ? PlanazoColors.negro
                                        : PlanazoColors.textoPrimario)),
                          ]),
                    ),
                  );
                },
              ),
            ),

            // Botones inferiores — idénticos al v2
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _sel.isNotEmpty ? _continuar : null,
                    child: Text(_sel.isEmpty
                        ? 'Elegí al menos uno'
                        : '¡Listo! (${_sel.length} elegidos)'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    final provider = context.read<AppProvider>();
                    await provider.actualizarIntereses([]);
                    if (!context.mounted) return;
                    context.go('/home');
                  },
                  child: const Text('Omitir por ahora',
                      style: TextStyle(color: PlanazoColors.textoSecundario)),
                ),
              ]),
            ),
          ]),
        ),
      );
}
