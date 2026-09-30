import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    _scale = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.5, 1.0)));
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2000), _navegar);
  }

  void _navegar() {
    if (!mounted) return;
    final loggedIn = context.read<AppProvider>().estaLogueado;
    context.go(loggedIn ? '/home' : '/login');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: PlanazoColors.loginFondo,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: PlanazoColors.amarillo,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Center(
                      child: Text('🎉', style: TextStyle(fontSize: 52))),
                ),
              ),
              const SizedBox(height: 28),
              FadeTransition(
                opacity: _fade,
                child: const Column(children: [
                  Text('Planazo',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: PlanazoColors.amarillo,
                        letterSpacing: -1,
                      )),
                  SizedBox(height: 8),
                  Text('Juntate con gente real',
                      style:
                          TextStyle(fontSize: 16, color: Colors.white54)),
                ]),
              ),
            ],
          ),
        ),
      );
}
