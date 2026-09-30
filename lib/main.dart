import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme/app_theme.dart';
import 'providers/app_provider.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/registro_screen.dart';
import 'screens/auth/registro_intereses_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/notificaciones_screen.dart';
import 'screens/map/mapa_screen.dart';
import 'screens/map/crear_juntada_screen.dart';
import 'screens/map/detalle_juntada_screen.dart';
import 'screens/chat/chats_screen.dart';
import 'screens/chat/chat_detalle_screen.dart';
import 'screens/profile/perfil_screen.dart';
import 'screens/profile/editar_perfil_screen.dart';
import 'services/push_notification_service.dart';

// ─────────────────────────────────────────────────────────────
// CREDENCIALES DE SUPABASE
// Reemplazar con las claves reales del proyecto en Supabase:
// Supabase > Settings > API > Project URL y anon key
// ─────────────────────────────────────────────────────────────
const String _supabaseUrl = 'https://ybzrxidpsgxoeldjnueg.supabase.co';
const String _supabaseAnonKey =
    'sb_publishable_ZpAK3SKTZqLfbjcItEoPyQ_IPgQsrqd';
//
// En producción, mover estas constantes a un archivo .env
// y leerlas con flutter_dotenv:
//   await dotenv.load(fileName: '.env');
//   final url = dotenv.env['SUPABASE_URL']!;
//   final key = dotenv.env['SUPABASE_ANON_KEY']!;
// ─────────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // La app necesita una instancia de Supabase aunque no haya credenciales reales.
  // Esto evita crashes del singleton y permite arrancar la UI de prueba.
  await Supabase.initialize(
    url: _supabaseUrl.contains('TU_PROYECTO')
        ? 'https://example.supabase.co'
        : _supabaseUrl,
    publishableKey: _supabaseAnonKey.contains('TU_ANON_KEY')
        ? 'fake_anon_key'
        : _supabaseAnonKey,
    debug: false,
  );
  await PushNotificationService.instance.initialize();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const PlanazoApp(),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// APP ROOT
// ─────────────────────────────────────────────────────────────
class PlanazoApp extends StatelessWidget {
  const PlanazoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Planazo',
      debugShowCheckedModeBanner: false,
      theme: PlanazoTheme.lightTheme,
      routerConfig: _buildRouter(context),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ROUTER
// ─────────────────────────────────────────────────────────────
GoRouter _buildRouter(BuildContext context) => GoRouter(
      initialLocation: '/splash',

      // ── Guardia global de autenticación ──────────────────────
      redirect: (ctx, state) {
        final loggedIn = ctx.read<AppProvider>().estaLogueado;
        final authPaths = [
          '/splash',
          '/login',
          '/registro',
          '/registro/intereses'
        ];
        final isAuth =
            authPaths.any((p) => state.matchedLocation.startsWith(p));

        if (!loggedIn && !isAuth) return '/login';
        // No redirigir de auth → app acá: lo hace el SplashScreen
        return null;
      },

      routes: [
        // ── Flujo de autenticación ───────────────────────────
        GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
        GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
        GoRoute(
          path: '/registro',
          builder: (c, s) => const RegistroScreen(),
          routes: [
            GoRoute(
                path: 'intereses',
                builder: (c, s) => const RegistroInteresesScreen()),
          ],
        ),

        // ── App principal (con BottomNav) ────────────────────
        ShellRoute(
          builder: (ctx, state, child) => MainShell(child: child),
          routes: [
            GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
            GoRoute(path: '/mapa', builder: (c, s) => const MapaScreen()),
            GoRoute(path: '/chats', builder: (c, s) => const ChatsScreen()),
            GoRoute(path: '/perfil', builder: (c, s) => const PerfilScreen()),
          ],
        ),

        // ── Pantallas sin BottomNav ──────────────────────────
        GoRoute(
          path: '/juntada/:id',
          builder: (c, s) =>
              DetalleJuntadaScreen(juntadaId: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/notificaciones',
          builder: (c, s) => const NotificacionesScreen(),
        ),
        GoRoute(
            path: '/crear-juntada',
            builder: (c, s) => const CrearJuntadaScreen()),
        GoRoute(
          path: '/chat/:id',
          builder: (c, s) => ChatDetalleScreen(chatId: s.pathParameters['id']!),
        ),
        GoRoute(
            path: '/editar-perfil',
            builder: (c, s) => const EditarPerfilScreen()),
      ],
    );

// ─────────────────────────────────────────────────────────────
// BOTTOM NAV SHELL
// ─────────────────────────────────────────────────────────────
class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _idx = 0;
  final _rutas = ['/home', '/mapa', '/chats', '/perfil'];

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).matchedLocation;
    final selectedIndex =
        _rutas.indexWhere((ruta) => currentPath.startsWith(ruta));

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: PlanazoColors.borde)),
        ),
        child: BottomNavigationBar(
          currentIndex: selectedIndex == -1 ? _idx : selectedIndex,
          onTap: (i) {
            setState(() => _idx = i);
            context.go(_rutas[i]);
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Inicio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map),
              label: 'Explorar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Chats',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}
