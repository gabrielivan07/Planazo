import 'dart:math';
import 'package:latlong2/latlong.dart';

// ─────────────────────────────────────────────
// USUARIO
// ─────────────────────────────────────────────
class Usuario {
  final String id;
  final String nombre;
  final String apellido;
  final String email;
  final String? telefono;
  final String? fotoPerfil;
  final int puntosConfianza;
  final List<String> intereses;
  final bool esPremium;
  final bool verificado;
  final DateTime? ultimaLat; // guardado como dummy — ver campo real
  final double? latitud;
  final double? longitud;
  final DateTime creadoEn;
  final List<Resena> resenas;

  const Usuario({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.email,
    this.telefono,
    this.fotoPerfil,
    this.puntosConfianza = 100,
    this.intereses = const [],
    this.esPremium = false,
    this.verificado = false,
    this.latitud,
    this.longitud,
    this.ultimaLat,
    required this.creadoEn,
    this.resenas = const [],
  });

  String get nombreCompleto => '$nombre $apellido';
  String get iniciales =>
      '${nombre[0]}${apellido.isNotEmpty ? apellido[0] : ''}'.toUpperCase();

  NivelConfianza get nivelConfianza {
    if (puntosConfianza >= 400) return NivelConfianza.estrella;
    if (puntosConfianza >= 250) return NivelConfianza.confiable;
    if (puntosConfianza >= 100) return NivelConfianza.nuevo;
    return NivelConfianza.enRiesgo;
  }

  double get promedioCalificacion {
    if (resenas.isEmpty) return 0.0;
    return resenas.map((r) => r.puntuacion).reduce((a, b) => a + b) /
        resenas.length;
  }

  // ─── Serialización desde Supabase ─────────────────────────
  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] as String,
      nombre: json['nombre'] as String? ?? '',
      apellido: json['apellido'] as String? ?? '',
      email: json['email'] as String? ?? '',
      telefono: json['telefono'] as String?,
      fotoPerfil: json['foto_perfil_url'] as String?,
      puntosConfianza: json['puntos_confianza'] as int? ?? 100,
      intereses: (json['intereses'] as List<dynamic>?)?.cast<String>() ?? [],
      esPremium: json['es_premium'] as bool? ?? false,
      verificado: json['verificado'] as bool? ?? false,
      latitud: json['ultima_lat'] as double?,
      longitud: json['ultima_lng'] as double?,
      creadoEn: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      resenas: (json['resenas'] as List<dynamic>?)
              ?.map((r) => Resena.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'apellido': apellido,
        'telefono': telefono,
        'foto_perfil_url': fotoPerfil,
        'intereses': intereses,
        'ultima_lat': latitud,
        'ultima_lng': longitud,
      };

  Usuario copyWith({
    String? nombre,
    String? apellido,
    String? email,
    String? telefono,
    String? fotoPerfil,
    int? puntosConfianza,
    List<String>? intereses,
    bool? esPremium,
    bool? verificado,
    double? latitud,
    double? longitud,
    List<Resena>? resenas,
  }) =>
      Usuario(
        id: id,
        creadoEn: creadoEn,
        nombre: nombre ?? this.nombre,
        apellido: apellido ?? this.apellido,
        email: email ?? this.email,
        telefono: telefono ?? this.telefono,
        fotoPerfil: fotoPerfil ?? this.fotoPerfil,
        puntosConfianza: puntosConfianza ?? this.puntosConfianza,
        intereses: intereses ?? this.intereses,
        esPremium: esPremium ?? this.esPremium,
        verificado: verificado ?? this.verificado,
        latitud: latitud ?? this.latitud,
        longitud: longitud ?? this.longitud,
        resenas: resenas ?? this.resenas,
      );
}

enum NivelConfianza {
  enRiesgo,
  nuevo,
  confiable,
  estrella;

  String get etiqueta => switch (this) {
        NivelConfianza.enRiesgo => 'En Riesgo',
        NivelConfianza.nuevo => 'Nuevo',
        NivelConfianza.confiable => 'Confiable',
        NivelConfianza.estrella => 'Estrella',
      };

  String get emoji => switch (this) {
        NivelConfianza.enRiesgo => '⚠️',
        NivelConfianza.nuevo => '🌱',
        NivelConfianza.confiable => '✅',
        NivelConfianza.estrella => '⭐',
      };
}

// ─────────────────────────────────────────────
// JUNTADA
// ─────────────────────────────────────────────
class Juntada {
  final String id;
  final String titulo;
  final String descripcion;
  final String organizadorId;
  final String organizadorNombre;
  final String? organizadorFoto;
  final bool organizadorVerificado;
  final DateTime fecha;
  final String lugar;
  final LatLng coordenadas;
  final String barrio;
  final int capacidadMaxima;
  final int participantesCount; // Viene del JOIN en la vista
  final String categoria;
  final List<String> etiquetas;
  final bool esPublica;
  final EstadoJuntada estado;
  final bool soloVerificados;
  final String? imagenUrl;
  final DateTime creadoEn;

  // Campo calculado al obtener la ubicación del usuario
  double? distanciaKm;

  Juntada({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.organizadorId,
    required this.organizadorNombre,
    this.organizadorFoto,
    this.organizadorVerificado = false,
    required this.fecha,
    required this.lugar,
    required this.coordenadas,
    required this.barrio,
    required this.capacidadMaxima,
    this.participantesCount = 0,
    required this.categoria,
    this.etiquetas = const [],
    this.esPublica = true,
    this.estado = EstadoJuntada.activa,
    this.soloVerificados = false,
    this.imagenUrl,
    required this.creadoEn,
    this.distanciaKm,
  });

  int get lugaresDisponibles =>
      (capacidadMaxima - participantesCount).clamp(0, capacidadMaxima);
  bool get estaLlena => lugaresDisponibles <= 0;
  bool get yaPaso => fecha.isBefore(DateTime.now());

  String get fechaFormateada {
    const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    const meses = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic'
    ];
    return '${dias[fecha.weekday - 1]} ${fecha.day} ${meses[fecha.month - 1]}';
  }

  String get horaFormateada =>
      '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';

  String get distanciaTexto {
    if (distanciaKm == null) return '';
    if (distanciaKm! < 1) return '${(distanciaKm! * 1000).round()} m';
    return '${distanciaKm!.toStringAsFixed(1)} km';
  }

  // ─── Fórmula de Haversine para distancia ──────────────────
  /// Calcula la distancia en km entre esta juntada y un punto dado.
  double calcularDistancia(double userLat, double userLng) {
    const double R = 6371; // Radio de la Tierra en km
    final dLat = _toRad(coordenadas.latitude - userLat);
    final dLng = _toRad(coordenadas.longitude - userLng);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(userLat)) *
            cos(_toRad(coordenadas.latitude)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRad(double deg) => deg * (pi / 180);

  // ─── Serialización desde Supabase ─────────────────────────
  factory Juntada.fromJson(Map<String, dynamic> json) {
    return Juntada(
      id: json['id'] as String,
      titulo: json['titulo'] as String,
      descripcion: json['descripcion'] as String,
      organizadorId: json['organizador_id'] as String,
      organizadorNombre:
          '${json['organizador_nombre'] ?? ''} ${json['organizador_apellido'] ?? ''}'
              .trim(),
      organizadorFoto: json['organizador_foto'] as String?,
      organizadorVerificado: json['organizador_verificado'] as bool? ?? false,
      fecha: DateTime.parse(json['fecha'] as String),
      lugar: json['lugar'] as String,
      coordenadas: LatLng(
        (json['lat'] as num).toDouble(),
        (json['lng'] as num).toDouble(),
      ),
      barrio: json['barrio'] as String? ?? '',
      capacidadMaxima: json['capacidad_maxima'] as int,
      participantesCount: json['participantes_count'] as int? ?? 0,
      categoria: json['categoria'] as String,
      etiquetas: (json['etiquetas'] as List<dynamic>?)?.cast<String>() ?? [],
      esPublica: json['es_publica'] as bool? ?? true,
      estado: EstadoJuntada.values.firstWhere(
        (e) => e.name == (json['estado'] as String? ?? 'activa'),
        orElse: () => EstadoJuntada.activa,
      ),
      soloVerificados: json['solo_verificados'] as bool? ?? false,
      imagenUrl: json['imagen_url'] as String?,
      creadoEn: DateTime.parse(json['created_at'] as String),
      distanciaKm: json['distancia_km'] as double?,
    );
  }

  Map<String, dynamic> toJson() => {
        'titulo': titulo,
        'descripcion': descripcion,
        'organizador_id': organizadorId,
        'fecha': fecha.toIso8601String(),
        'lugar': lugar,
        'lat': coordenadas.latitude,
        'lng': coordenadas.longitude,
        'barrio': barrio,
        'capacidad_maxima': capacidadMaxima,
        'categoria': categoria,
        'etiquetas': etiquetas,
        'es_publica': esPublica,
        'estado': estado.name,
        'solo_verificados': soloVerificados,
        'imagen_url': imagenUrl,
      };
}

enum EstadoJuntada { activa, cancelada, finalizada, pendiente }

// ─────────────────────────────────────────────
// MENSAJE
// ─────────────────────────────────────────────
class Mensaje {
  final String id;
  final String chatId;
  final String remitenteId;
  final String remitenteNombre;
  final String? remitenteFoto;
  final String contenido;
  final TipoMensaje tipo;
  final String? imagenUrl;
  final List<String> leidoPor;
  final DateTime creadoEn;

  const Mensaje({
    required this.id,
    required this.chatId,
    required this.remitenteId,
    required this.remitenteNombre,
    this.remitenteFoto,
    required this.contenido,
    this.tipo = TipoMensaje.texto,
    this.imagenUrl,
    this.leidoPor = const [],
    required this.creadoEn,
  });

  bool esLeido(String userId) => leidoPor.contains(userId);

  factory Mensaje.fromJson(Map<String, dynamic> json) => Mensaje(
        id: json['id'] as String,
        chatId: json['chat_id'] as String,
        remitenteId: json['remitente_id'] as String,
        remitenteNombre: json['usuarios'] != null
            ? '${json['usuarios']['nombre']} ${json['usuarios']['apellido']}'
                .trim()
            : '',
        remitenteFoto: json['usuarios']?['foto_perfil_url'] as String?,
        contenido: json['contenido'] as String,
        tipo: TipoMensaje.values.firstWhere(
          (t) => t.name == (json['tipo'] as String? ?? 'texto'),
          orElse: () => TipoMensaje.texto,
        ),
        imagenUrl: json['imagen_url'] as String?,
        leidoPor: (json['leido_por'] as List<dynamic>?)?.cast<String>() ?? [],
        creadoEn: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'chat_id': chatId,
        'remitente_id': remitenteId,
        'contenido': contenido,
        'tipo': tipo.name,
        'imagen_url': imagenUrl,
      };
}

enum TipoMensaje { texto, imagen, sistema }

// ─────────────────────────────────────────────
// CHAT
// ─────────────────────────────────────────────
class Chat {
  final String id;
  final String? juntadaId;
  final String? titulo;
  final bool esGrupal;
  final bool silenciado;
  final bool archivado;
  final bool fijado;
  final bool eliminado;
  final List<Mensaje> mensajes;
  final DateTime creadoEn;

  const Chat({
    required this.id,
    this.juntadaId,
    this.titulo,
    required this.esGrupal,
    this.silenciado = false,
    this.archivado = false,
    this.fijado = false,
    this.eliminado = false,
    this.mensajes = const [],
    required this.creadoEn,
  });

  Chat copyWith({
    bool? silenciado,
    bool? archivado,
    bool? fijado,
    bool? eliminado,
    List<Mensaje>? mensajes,
  }) =>
      Chat(
        id: id,
        juntadaId: juntadaId,
        titulo: titulo,
        esGrupal: esGrupal,
        silenciado: silenciado ?? this.silenciado,
        archivado: archivado ?? this.archivado,
        fijado: fijado ?? this.fijado,
        eliminado: eliminado ?? this.eliminado,
        mensajes: mensajes ?? this.mensajes,
        creadoEn: creadoEn,
      );

  Mensaje? get ultimoMensaje => mensajes.isNotEmpty ? mensajes.last : null;
  int get mensajesNoLeidos => 0; // Se calcula con el userId en pantalla

  factory Chat.fromJson(Map<String, dynamic> json) {
    final rawConfig = json['mi_configuracion'];
    final config = rawConfig is List && rawConfig.isNotEmpty
        ? rawConfig.first as Map<String, dynamic>
        : rawConfig is Map<String, dynamic>
            ? rawConfig
            : <String, dynamic>{};

    return Chat(
      id: json['id'] as String,
      juntadaId: json['juntada_id'] as String?,
      titulo: json['titulo'] as String?,
      esGrupal: json['es_grupal'] as bool? ?? true,
      silenciado: config['silenciado'] as bool? ?? false,
      archivado: config['archivado'] as bool? ?? false,
      fijado: config['fijado'] as bool? ?? false,
      eliminado: config['eliminado'] as bool? ?? false,
      creadoEn: DateTime.parse(json['created_at'] as String),
      mensajes: (json['mensajes'] as List<dynamic>?)
              ?.map((m) => Mensaje.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

// ─────────────────────────────────────────────
// RESEÑA
// ─────────────────────────────────────────────
class Resena {
  final String id;
  final String autorId;
  final String autorNombre;
  final String? autorFoto;
  final double puntuacion;
  final String comentario;
  final DateTime creadoEn;

  const Resena({
    required this.id,
    required this.autorId,
    required this.autorNombre,
    this.autorFoto,
    required this.puntuacion,
    required this.comentario,
    required this.creadoEn,
  });

  factory Resena.fromJson(Map<String, dynamic> json) => Resena(
        id: json['id'] as String,
        autorId: json['autor_id'] as String,
        autorNombre: json['usuarios']?['nombre'] as String? ?? '',
        autorFoto: json['usuarios']?['foto_perfil_url'] as String?,
        puntuacion: (json['puntuacion'] as num).toDouble(),
        comentario: json['comentario'] as String,
        creadoEn: DateTime.parse(json['created_at'] as String),
      );
}

// ─────────────────────────────────────────────
// CATEGORÍAS (inmutables, sin DB)
// ─────────────────────────────────────────────
class CategoriaJuntada {
  final String nombre;
  final String emoji;
  const CategoriaJuntada({required this.nombre, required this.emoji});

  static const List<CategoriaJuntada> todas = [
    CategoriaJuntada(nombre: 'Deportes', emoji: '⚽'),
    CategoriaJuntada(nombre: 'Gastronomía', emoji: '🍕'),
    CategoriaJuntada(nombre: 'Cultura', emoji: '🎭'),
    CategoriaJuntada(nombre: 'Música', emoji: '🎵'),
    CategoriaJuntada(nombre: 'Naturaleza', emoji: '🌿'),
    CategoriaJuntada(nombre: 'Juegos', emoji: '🎲'),
    CategoriaJuntada(nombre: 'Social', emoji: '🤝'),
    CategoriaJuntada(nombre: 'Viajes', emoji: '✈️'),
  ];

  static String emojiPara(String nombre) => todas
      .firstWhere((c) => c.nombre == nombre,
          orElse: () => const CategoriaJuntada(nombre: '', emoji: '📍'))
      .emoji;
}
