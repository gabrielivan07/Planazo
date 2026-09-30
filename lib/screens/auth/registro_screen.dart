import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});
  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  bool _verPass = false;
  bool _terminos = false;
  String? _errorMsg;

  @override
  void dispose() {
    for (final c in [
      _nombreCtrl,
      _apellidoCtrl,
      _emailCtrl,
      _passCtrl,
      _pass2Ctrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _registrar() async {
    setState(() => _errorMsg = null);
    if (!_formKey.currentState!.validate()) return;
    if (!_terminos) {
      setState(() => _errorMsg = 'Aceptá los términos para continuar.');
      return;
    }

    final ok = await context.read<AppProvider>().registrar(
          nombre: _nombreCtrl.text.trim(),
          apellido: _apellidoCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );

    if (!mounted) return;
    if (ok) {
      // Si Supabase requiere confirmación de email el usuario no estará logueado.
      final loggedIn = context.read<AppProvider>().estaLogueado;
      context.go(loggedIn ? '/registro/intereses' : '/login');
    } else {
      setState(() => _errorMsg =
          context.read<AppProvider>().error ?? 'Error al registrarse.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cargando = context.watch<AppProvider>().cargando;

    return Scaffold(
      backgroundColor: PlanazoColors.loginFondo,
      appBar: AppBar(
        backgroundColor: PlanazoColors.loginFondo,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: PlanazoColors.amarillo),
          onPressed: () => context.go('/login'),
        ),
        title: const Text('Crear cuenta',
            style: TextStyle(
                color: PlanazoColors.blanco,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Form(
            key: _formKey,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_errorMsg != null) ...[
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A0000),
                    border: Border.all(
                        color: PlanazoColors.error.withValues(alpha: .4)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_errorMsg!,
                      style: const TextStyle(
                          color: Color(0xFFFF6B6B), fontSize: 12)),
                ),
                const SizedBox(height: 12),
              ],
              Row(children: [
                Expanded(
                    child: _buildField(_nombreCtrl, 'Nombre', hint: 'Carlos')),
                const SizedBox(width: 12),
                Expanded(
                    child:
                        _buildField(_apellidoCtrl, 'Apellido', hint: 'Méndez')),
              ]),
              const SizedBox(height: 12),
              _buildField(_emailCtrl, 'Email',
                  hint: 'tu@email.com',
                  keyboard: TextInputType.emailAddress, validator: (v) {
                if (v == null || !v.contains('@')) {
                  return 'Email inválido';
                }
                return null;
              }),
              const SizedBox(height: 12),
              _buildField(_passCtrl, 'Contraseña',
                  hint: 'Mínimo 6 caracteres',
                  obscure: !_verPass,
                  suffix: IconButton(
                    icon: Icon(
                      _verPass
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.white38,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _verPass = !_verPass),
                  ), validator: (v) {
                if (v == null || v.length < 6) {
                  return 'Mínimo 6 caracteres';
                }
                return null;
              }),
              const SizedBox(height: 12),
              _buildField(_pass2Ctrl, 'Confirmar contraseña',
                  hint: 'Repetí la contraseña', obscure: true, validator: (v) {
                if (v != _passCtrl.text) {
                  return 'Las contraseñas no coinciden';
                }
                return null;
              }),
              const SizedBox(height: 16),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Checkbox(
                  value: _terminos,
                  activeColor: PlanazoColors.amarillo,
                  checkColor: PlanazoColors.negro,
                  side: const BorderSide(color: Colors.white30),
                  onChanged: (v) => setState(() => _terminos = v ?? false),
                ),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text.rich(TextSpan(
                      style: TextStyle(fontSize: 12, color: Colors.white38),
                      children: [
                        TextSpan(text: 'Acepto los '),
                        TextSpan(
                            text: 'Términos y Condiciones',
                            style: TextStyle(
                                decoration: TextDecoration.underline,
                                color: PlanazoColors.amarillo)),
                        TextSpan(text: ' y la '),
                        TextSpan(
                            text: 'Política de Privacidad',
                            style: TextStyle(
                                decoration: TextDecoration.underline,
                                color: PlanazoColors.amarillo)),
                      ],
                    )),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: cargando ? null : _registrar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PlanazoColors.amarillo,
                    foregroundColor: PlanazoColors.negro,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: cargando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: PlanazoColors.negro))
                      : const Text('Crear cuenta',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('¿Ya tenés cuenta? Iniciá sesión',
                      style: TextStyle(
                          color: PlanazoColors.amarillo, fontSize: 13)),
                ),
              ),
              const SizedBox(height: 30),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label, {
    String? hint,
    bool obscure = false,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
    Widget? suffix,
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white60)),
        const SizedBox(height: 5),
        TextFormField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: keyboard,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          validator: validator ??
              (v) => (v == null || v.isEmpty) ? 'Campo requerido' : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
            suffixIcon: suffix,
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2A2A2A))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF2A2A2A), width: 1.5)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: PlanazoColors.amarillo, width: 2)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: PlanazoColors.error)),
            errorStyle: const TextStyle(color: Color(0xFFFF6B6B)),
          ),
        ),
      ]);
}
