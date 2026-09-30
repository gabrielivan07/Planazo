import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _verPass = false;
  String? _errorMsg;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _errorMsg = null);

    final ok = await context.read<AppProvider>().login(
          _emailCtrl.text.trim(),
          _passCtrl.text,
        );

    if (!mounted) return;
    if (ok) {
      context.go('/home');
    } else {
      setState(() => _errorMsg =
          context.read<AppProvider>().error ?? 'Error al iniciar sesión.');
    }
  }

  Future<void> _recuperarContrasena() async {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    final formKey = GlobalKey<FormState>();
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Recuperar contraseña'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: emailCtrl,
            autofocus: emailCtrl.text.isEmpty,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: (value) {
              if (value == null || !value.contains('@')) {
                return 'Ingresá un email válido';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, emailCtrl.text.trim());
              }
            },
            child: const Text('Enviar email'),
          ),
        ],
      ),
    );
    emailCtrl.dispose();
    if (email == null || !mounted) return;

    final ok = await context.read<AppProvider>().recuperarContrasena(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Revisá tu email para restablecer la contraseña.'
            : context.read<AppProvider>().error ??
                'No se pudo enviar el email.'),
        backgroundColor: ok ? null : PlanazoColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cargando = context.watch<AppProvider>().cargando;

    return Scaffold(
      backgroundColor: PlanazoColors.loginFondo,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                        color: PlanazoColors.amarillo,
                        borderRadius: BorderRadius.circular(20)),
                    child: const Center(
                        child: Text('🎉', style: TextStyle(fontSize: 34))),
                  ),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text('Planazo',
                      style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: PlanazoColors.amarillo,
                          letterSpacing: -0.5)),
                ),
                const SizedBox(height: 6),
                const Center(
                  child: Text('Iniciá sesión para continuar',
                      style: TextStyle(fontSize: 14, color: Colors.white54)),
                ),
                const SizedBox(height: 36),

                // Error
                if (_errorMsg != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A0000),
                      border: Border.all(
                          color: PlanazoColors.error.withValues(alpha: .4)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_errorMsg!,
                        style: const TextStyle(
                            color: Color(0xFFFF6B6B), fontSize: 13)),
                  ),
                  const SizedBox(height: 14),
                ],

                _label('Email'),
                const SizedBox(height: 6),
                _darkField(
                  controller: _emailCtrl,
                  hint: 'tu@email.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || !v.contains('@')) {
                      return 'Email inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                _label('Contraseña'),
                const SizedBox(height: 6),
                _darkField(
                  controller: _passCtrl,
                  hint: '••••••••',
                  obscure: !_verPass,
                  validator: (v) {
                    if (v == null || v.length < 6) {
                      return 'Mínimo 6 caracteres';
                    }
                    return null;
                  },
                  suffix: IconButton(
                    icon: Icon(
                      _verPass
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.white38,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _verPass = !_verPass),
                  ),
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: cargando ? null : _recuperarContrasena,
                    child: const Text('¿Olvidaste la contraseña?',
                        style: TextStyle(
                            color: PlanazoColors.amarillo, fontSize: 13)),
                  ),
                ),
                const SizedBox(height: 6),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: cargando ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PlanazoColors.amarillo,
                      foregroundColor: PlanazoColors.negro,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: cargando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: PlanazoColors.negro))
                        : const Text('Iniciar sesión',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 20),

                const Row(children: [
                  Expanded(child: Divider(color: Colors.white12)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Text('o',
                        style: TextStyle(color: Colors.white30, fontSize: 13)),
                  ),
                  Expanded(child: Divider(color: Colors.white12)),
                ]),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.go('/registro'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PlanazoColors.blanco,
                      side: const BorderSide(
                          color: Color(0xFF333333), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Crear cuenta nueva',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF2A2A2A)),
                  ),
                  child: const Row(children: [
                    Text('💡', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(TextSpan(
                        style: TextStyle(fontSize: 12, color: Colors.white38),
                        children: [
                          TextSpan(
                              text: 'Demo: ',
                              style: TextStyle(
                                  color: PlanazoColors.amarillo,
                                  fontWeight: FontWeight.w700)),
                          TextSpan(
                              text:
                                  'Registrate con tu email real. Tu sesión se guarda automáticamente.'),
                        ],
                      )),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white60));

  Widget _darkField({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    Widget? suffix,
  }) =>
      TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
          suffixIcon: suffix,
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
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
      );
}
