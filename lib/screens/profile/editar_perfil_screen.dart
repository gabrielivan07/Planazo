import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';

class EditarPerfilScreen extends StatefulWidget {
  const EditarPerfilScreen({super.key});
  @override
  State<EditarPerfilScreen> createState() => _State();
}

class _State extends State<EditarPerfilScreen> {
  late final TextEditingController _nom;
  late final TextEditingController _ape;
  late final TextEditingController _tel;
  late final TextEditingController _em;

  @override
  void initState() {
    super.initState();
    final u = context.read<AppProvider>().usuario!;
    _nom = TextEditingController(text: u.nombre);
    _ape = TextEditingController(text: u.apellido);
    _tel = TextEditingController(text: u.telefono ?? '');
    _em = TextEditingController(text: u.email);
  }

  @override
  void dispose() {
    for (final c in [_nom, _ape, _tel, _em]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    await context.read<AppProvider>().actualizarPerfil(
          nombre: _nom.text.trim().isNotEmpty ? _nom.text.trim() : null,
          apellido: _ape.text.trim().isNotEmpty ? _ape.text.trim() : null,
          telefono: _tel.text.trim().isNotEmpty ? _tel.text.trim() : null,
          email: _em.text.trim().isNotEmpty ? _em.text.trim() : null,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Perfil actualizado ✓'),
          backgroundColor: PlanazoColors.exito),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AppProvider>().usuario!;
    return Scaffold(
      backgroundColor: PlanazoColors.fondoPrimario,
      appBar: AppBar(
        title: const Text('Editar perfil'),
        leading: IconButton(
            icon: const Icon(Icons.close), onPressed: () => context.pop()),
        actions: [
          TextButton(
            onPressed: _guardar,
            child: const Text('Guardar',
                style: TextStyle(
                    color: PlanazoColors.negro,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Stack(children: [
              CircleAvatar(
                radius: 46,
                backgroundColor: PlanazoColors.negro,
                child: Text(usuario.iniciales,
                    style: const TextStyle(
                        color: PlanazoColors.amarillo,
                        fontSize: 30,
                        fontWeight: FontWeight.w700)),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: const BoxDecoration(
                      color: PlanazoColors.amarillo, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt_outlined,
                      size: 16, color: PlanazoColors.negro),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 28),
          const Text('Información personal',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: PlanazoColors.negro)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _campo(_nom, 'Nombre')),
            const SizedBox(width: 12),
            Expanded(child: _campo(_ape, 'Apellido')),
          ]),
          const SizedBox(height: 12),
          _campo(_tel, 'Teléfono',
              hint: '+54 11 XXXX-XXXX', keyboard: TextInputType.phone),
          const SizedBox(height: 12),
          _campo(_em, 'Email', keyboard: TextInputType.emailAddress),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                onPressed: _guardar, child: const Text('Guardar cambios')),
          ),
        ]),
      ),
    );
  }

  Widget _campo(TextEditingController ctrl, String label,
          {String? hint, TextInputType keyboard = TextInputType.text}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: PlanazoColors.textoSecundario)),
        const SizedBox(height: 5),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboard,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: hint),
        ),
      ]);
}
