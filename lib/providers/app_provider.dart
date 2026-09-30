import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthState, AuthChangeEvent;
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/juntadas_service.dart';
import '../services/chat_service.dart';
import '../services/geolocacion_service.dart';
import '../services/push_notification_service.dart';
import '../services/reportes_service.dart';
import '../services/resenas_service.dart';

/// Estado global de la app.
///
/// La API pública (getters + métodos) es idéntica a la versión simulada,
/// así que ninguna pantalla necesita cambios para funcionar con Supabase.
///
/// Lo que cambió internamente:
///   - Todos los métodos ahora son async con llamadas reales a Supabase.
///   - Los datos se cargan desde la red, no desde DatosDemo.
///   - Los mensajes usan Realtime en lugar de mutation local.
class AppProvider extends ChangeNotifier {
  // ─── Servicios ───────────────────────────────────────────
  final _auth = SupabaseService.instance;
  final _juntSvc = JuntadasService.instance;
  final _chatSvc = ChatService.instance;
  final _geoSvc = GeolocacionService.instance;
  final _pushSvc = PushNotificationService.instance;
  final _reportesSvc = ReportesService.instance;
  final _resenasSvc = ResenasService.instance;

  // ─── Estado interno ──────────────────────────────────────
  Usuario? _usuario;
  bool _cargando = false;
  String? _error;
  bool _cargandoJuntadas = false;
  int _juntadasCreadasEsteMes = 0;

  List<Juntada> _juntadas = [];
  List<Chat> _chats = [];
  Set<String> _juntadasUnidas = {};

  // Suscripción al stream de auth de Supabase
  StreamSubscription<AuthState>? _authSub;
  Future<void>? _cargaInicialActiva;

  // ─── GETTERS PÚBLICOS ────────────────────────────────────
  Usuario? get usuario => _usuario;
  bool get cargando => _cargando;
  bool get cargandoJuntadas => _cargandoJuntadas;
  int get juntadasCreadasEsteMes => _juntadasCreadasEsteMes;
  String? get error => _error;
  bool get estaLogueado => _usuario != null;

  List<Juntada> get juntadas => List.unmodifiable(_juntadas);
  List<Chat> get chats => List.unmodifiable(_chats);
  Set<String> get juntadasUnidas => Set.unmodifiable(_juntadasUnidas);

  List<Juntada> get juntadasProximas => _juntadas
      .where((j) => !j.yaPaso && j.estado == EstadoJuntada.activa)
      .toList();

  List<Juntada> get juntadasConRecordatorio => _juntadas.where((j) {
        final tiempoRestante = j.fecha.difference(DateTime.now());
        return _juntadasUnidas.contains(j.id) &&
            j.estado == EstadoJuntada.activa &&
            tiempoRestante > Duration.zero &&
            tiempoRestante <= const Duration(hours: 1);
      }).toList();

  bool estaUnido(String juntadaId) => _juntadasUnidas.contains(juntadaId);

  // ─── INICIALIZACIÓN ──────────────────────────────────────
  AppProvider() {
    _listenAuth();
  }

  void _listenAuth() {
    _authSub = _auth.authStateChanges.listen((state) async {
      if (state.event == AuthChangeEvent.signedIn) {
        await _cargarDatosIniciales();
      } else if (state.event == AuthChangeEvent.signedOut) {
        _limpiarEstado();
      }
    });

    // Si la app arranca con sesión activa
    if (_auth.isLoggedIn) {
      _cargarDatosIniciales();
    }
  }

  Future<void> _cargarDatosIniciales() {
    return _cargaInicialActiva ??= _ejecutarCargaInicial().whenComplete(() {
      _cargaInicialActiva = null;
    });
  }

  Future<void> _ejecutarCargaInicial() async {
    _setLoading(true);
    try {
      await Future.wait([
        _cargarPerfil(),
        _cargarJuntadas(),
        _cargarChats(),
        _cargarGeolocacion(),
        _cargarCupoMensual(),
      ]);
      await _pushSvc.registerCurrentUser();
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _cargarPerfil() async {
    final uid = _auth.currentUserId!;
    _usuario = await _auth.fetchPerfil(uid);
    notifyListeners();
  }

  Future<void> _cargarJuntadas() async {
    _cargandoJuntadas = true;
    notifyListeners();
    try {
      _juntadas = await _juntSvc.fetchProximas();
      // Calcular distancias si tenemos ubicación
      _juntadas = _geoSvc.agregarDistancias(_juntadas);
      // Cargar qué juntadas tiene el usuario
      final uid = _auth.currentUserId;
      if (uid != null) {
        _juntadasUnidas = await _juntSvc.fetchIdsUnidas(uid);
      }
    } finally {
      _cargandoJuntadas = false;
      notifyListeners();
    }
  }

  Future<void> _cargarChats() async {
    final uid = _auth.currentUserId;
    if (uid == null) return;
    _chats = await _chatSvc.fetchChats(uid);
    notifyListeners();
  }

  Future<void> _cargarGeolocacion() async {
    await _geoSvc.obtenerPosicion();
    // Si obtuvimos ubicación, re-calcular distancias
    if (_geoSvc.posicion != null) {
      _juntadas = _geoSvc.agregarDistancias(_juntadas);
      notifyListeners();
    }
  }

  Future<void> _cargarCupoMensual() async {
    final uid = _auth.currentUserId;
    if (uid == null) return;
    try {
      _juntadasCreadasEsteMes = await _juntSvc.contarCreadasEsteMes(uid);
      notifyListeners();
    } catch (_) {}
  }

  void _limpiarEstado() {
    _usuario = null;
    _juntadas = [];
    _chats = [];
    _juntadasUnidas = {};
    _juntadasCreadasEsteMes = 0;
    _chatSvc.cancelarTodas();
    notifyListeners();
  }

  // ─── AUTH ────────────────────────────────────────────────
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _error = null;
    try {
      await _auth.login(email: email, password: password);
      await _cargarDatosIniciales();
      if (_usuario == null) {
        throw StateError(_error ?? 'No se pudo cargar el perfil.');
      }
      return true;
    } catch (e) {
      _error ??= _mensajeError(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> registrar({
    required String nombre,
    required String apellido,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      await _auth.registrar(
        email: email,
        password: password,
        nombre: nombre,
        apellido: apellido,
      );
      return true;
    } catch (e) {
      _error = _mensajeError(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> recuperarContrasena(String email) async {
    _setLoading(true);
    _error = null;
    try {
      await _auth.resetPassword(email);
      return true;
    } catch (e) {
      _error = _mensajeError(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> cerrarSesion() async {
    await _auth.logout();
    // _listenAuth() detecta signedOut y limpia el estado
  }

  Future<void> eliminarCuenta() async {
    _setLoading(true);
    _error = null;
    try {
      await _auth.eliminarCuenta();
      _limpiarEstado();
    } catch (e) {
      _error = _mensajeError(e);
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> reportarJuntada({
    required String juntadaId,
    required String motivo,
    String? detalle,
  }) {
    return _reportesSvc.reportarJuntada(
      juntadaId: juntadaId,
      motivo: motivo,
      detalle: detalle,
    );
  }

  // ─── JUNTADAS ────────────────────────────────────────────
  Future<Juntada> crearJuntada(Juntada juntada) async {
    final usuario = _usuario;
    if (usuario == null) throw StateError('Iniciá sesión para crear juntadas.');
    if (!usuario.esPremium && _juntadasCreadasEsteMes >= 3) {
      throw StateError('El plan gratuito permite crear 3 juntadas por mes.');
    }
    if (!usuario.esPremium && juntada.capacidadMaxima > 10) {
      throw StateError(
          'El plan gratuito admite hasta 10 personas por juntada.');
    }

    _setLoading(true);
    try {
      final nueva = await _juntSvc.crear(juntada);
      _juntadas.insert(0, nueva);
      _juntadasUnidas.add(nueva.id);
      _juntadasCreadasEsteMes++;
      try {
        await _cargarChats();
      } catch (_) {}
      notifyListeners();
      return nueva;
    } finally {
      _setLoading(false);
    }
  }

  Future<Juntada> obtenerDetalleJuntada(String juntadaId) async {
    return _juntSvc.fetchDetalle(juntadaId);
  }

  Future<bool> unirseAJuntada(String juntadaId) async {
    final uid = _auth.currentUserId;
    if (uid == null) return false;
    if (_juntadasUnidas.contains(juntadaId)) return false;

    final ok = await _juntSvc.unirse(juntadaId: juntadaId, usuarioId: uid);
    if (ok) {
      _juntadasUnidas.add(juntadaId);
      // Actualizar el count local sin re-fetch completo
      final idx = _juntadas.indexWhere((j) => j.id == juntadaId);
      if (idx != -1) {
        final j = _juntadas[idx];
        _juntadas[idx] = Juntada(
          id: j.id,
          titulo: j.titulo,
          descripcion: j.descripcion,
          organizadorId: j.organizadorId,
          organizadorNombre: j.organizadorNombre,
          organizadorFoto: j.organizadorFoto,
          organizadorVerificado: j.organizadorVerificado,
          fecha: j.fecha,
          lugar: j.lugar,
          coordenadas: j.coordenadas,
          barrio: j.barrio,
          capacidadMaxima: j.capacidadMaxima,
          participantesCount: j.participantesCount + 1,
          categoria: j.categoria,
          etiquetas: j.etiquetas,
          esPublica: j.esPublica,
          estado: j.estado,
          soloVerificados: j.soloVerificados,
          imagenUrl: j.imagenUrl,
          creadoEn: j.creadoEn,
          distanciaKm: j.distanciaKm,
        );
      }
      try {
        await _cargarChats();
      } catch (_) {}
      notifyListeners();
    }
    return ok;
  }

  Future<void> recargarJuntadas({String? categoria, String? busqueda}) async {
    _cargandoJuntadas = true;
    notifyListeners();
    try {
      _juntadas = await _juntSvc.fetchProximas(
        categoria: categoria,
        busqueda: busqueda,
      );
      _juntadas = _geoSvc.agregarDistancias(_juntadas);
    } finally {
      _cargandoJuntadas = false;
      notifyListeners();
    }
  }

  Future<void> recargarJuntadasCercanas(double radioKm) async {
    final pos = await _geoSvc.obtenerPosicion();
    if (pos == null) return;
    _cargandoJuntadas = true;
    notifyListeners();
    try {
      _juntadas = await _juntSvc.fetchCercanas(
        lat: pos.latitude,
        lng: pos.longitude,
        radioKm: radioKm,
      );
    } finally {
      _cargandoJuntadas = false;
      notifyListeners();
    }
  }

  Future<Chat?> obtenerChatJuntada(String juntadaId) async {
    final chat = await _chatSvc.fetchChatJuntada(juntadaId);
    if (chat == null) return null;

    final index = _chats.indexWhere((item) => item.id == chat.id);
    if (index == -1) {
      _chats.add(chat);
      notifyListeners();
      return chat;
    }
    return _chats[index];
  }

  // ─── CHAT ────────────────────────────────────────────────
  Future<List<Mensaje>> cargarMensajes(String chatId) async {
    return _chatSvc.fetchMensajes(chatId);
  }

  Future<Mensaje?> enviarMensaje(String chatId, String contenido) async {
    final uid = _auth.currentUserId;
    if (uid == null) return null;
    try {
      final m = await _chatSvc.enviar(
        chatId: chatId,
        remitenteId: uid,
        contenido: contenido,
      );
      // Actualizar preview del chat en la lista
      final idx = _chats.indexWhere((c) => c.id == chatId);
      if (idx != -1) {
        final c = _chats[idx];
        _chats[idx] = c.copyWith(mensajes: [...c.mensajes, m]);
        notifyListeners();
      }
      return m;
    } catch (_) {
      return null;
    }
  }

  Future<void> actualizarPreferenciasChat(
    String chatId, {
    bool? silenciado,
    bool? archivado,
    bool? fijado,
    bool? eliminado,
  }) async {
    final uid = _auth.currentUserId;
    final index = _chats.indexWhere((chat) => chat.id == chatId);
    if (uid == null || index == -1) return;

    final cambios = <String, bool>{};
    if (silenciado != null) cambios['silenciado'] = silenciado;
    if (archivado != null) cambios['archivado'] = archivado;
    if (fijado != null) cambios['fijado'] = fijado;
    if (eliminado != null) cambios['eliminado'] = eliminado;
    if (cambios.isEmpty) return;

    await _chatSvc.actualizarPreferencias(chatId, uid, cambios);
    _chats[index] = _chats[index].copyWith(
      silenciado: silenciado,
      archivado: archivado,
      fijado: fijado,
      eliminado: eliminado,
    );
    notifyListeners();
  }

  Future<bool> agregarAmigo(String amigoId) async {
    final uid = _auth.currentUserId;
    if (uid == null || uid == amigoId) return false;
    return _chatSvc.agregarAmigo(uid, amigoId);
  }

  Future<Chat?> iniciarChatDirecto(String otroUsuarioId) async {
    final uid = _auth.currentUserId;
    if (uid == null || uid == otroUsuarioId) return null;
    try {
      final chat = await _chatSvc.obtenerOCrearChatDirecto(
        usuarioA: uid,
        usuarioB: otroUsuarioId,
      );
      await _cargarChats();
      return _chats.firstWhere((item) => item.id == chat.id);
    } catch (_) {
      return null;
    }
  }

  Future<void> reportarUsuario({
    required String usuarioId,
    required String motivo,
    String? detalle,
  }) =>
      _reportesSvc.reportarUsuario(
        usuarioId: usuarioId,
        motivo: motivo,
        detalle: detalle,
      );

  Future<List<Map<String, dynamic>>> obtenerAsistenciaJuntada(
          String juntadaId) =>
      _juntSvc.fetchAsistencia(juntadaId);

  Future<void> marcarAsistencia({
    required String juntadaId,
    required String usuarioId,
    required String asistencia,
  }) async {
    await _juntSvc.marcarAsistencia(
      juntadaId: juntadaId,
      usuarioId: usuarioId,
      asistencia: asistencia,
    );
    await _cargarPerfil();
  }

  Future<List<Map<String, dynamic>>> participantesParaResena(
          String juntadaId) =>
      _resenasSvc.fetchParticipantes(juntadaId);

  Future<List<Map<String, dynamic>>> resenasDeJuntada(String juntadaId) =>
      _resenasSvc.fetchResenasJuntada(juntadaId);

  Future<void> enviarResenaJuntada({
    required String juntadaId,
    required int puntuacion,
    required String comentario,
  }) async {
    final uid = _auth.currentUserId;
    if (uid == null) throw StateError('Iniciá sesión para enviar una reseña.');
    await _resenasSvc.crearResenaJuntada(
      juntadaId: juntadaId,
      autorId: uid,
      puntuacion: puntuacion,
      comentario: comentario,
    );
  }

  Future<void> enviarResenaParticipante({
    required String juntadaId,
    required String participanteId,
    required int puntuacion,
    required String comentario,
  }) async {
    final uid = _auth.currentUserId;
    if (uid == null) throw StateError('Iniciá sesión para enviar una reseña.');
    await _resenasSvc.crearResenaParticipante(
      juntadaId: juntadaId,
      autorId: uid,
      destinatarioId: participanteId,
      puntuacion: puntuacion,
      comentario: comentario,
    );
  }

  // ─── PERFIL ──────────────────────────────────────────────
  Future<void> actualizarIntereses(List<String> intereses) async {
    if (_usuario == null) return;
    _usuario = _usuario!.copyWith(intereses: intereses);
    notifyListeners();
    await _auth.actualizarPerfil(
      userId: _usuario!.id,
      intereses: intereses,
    );
  }

  Future<void> actualizarPerfil({
    String? nombre,
    String? apellido,
    String? telefono,
    String? email,
  }) async {
    if (_usuario == null) return;
    await _auth.actualizarPerfil(
      userId: _usuario!.id,
      nombre: nombre,
      apellido: apellido,
      telefono: telefono,
    );
    await _cargarPerfil();
  }

  // ─── GEO ─────────────────────────────────────────────────
  Future<void> actualizarUbicacion() async {
    await _geoSvc.obtenerPosicion(forzar: true);
    _juntadas = _geoSvc.agregarDistancias(_juntadas);
    notifyListeners();
  }

  List<Juntada> juntadasOrdenadas({bool porDistancia = false}) {
    if (!porDistancia || _geoSvc.posicion == null) return juntadasProximas;
    return _geoSvc.ordenarPorDistancia(juntadasProximas);
  }

  // ─── HELPERS ─────────────────────────────────────────────
  void _setLoading(bool v) {
    _cargando = v;
    notifyListeners();
  }

  String _mensajeError(dynamic e) {
    if (e.toString().contains('Invalid login credentials')) {
      return 'Email o contraseña incorrectos.';
    }
    if (e.toString().contains('Email already registered')) {
      return 'Este email ya está registrado.';
    }
    if (e.toString().contains('Password should be at least')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    return 'Ocurrió un error. Intentá de nuevo.';
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _chatSvc.cancelarTodas();
    super.dispose();
  }
}
