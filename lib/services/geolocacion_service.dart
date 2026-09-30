import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';
import 'supabase_service.dart';

class GeolocacionService {
  GeolocacionService._();
  static final GeolocacionService instance = GeolocacionService._();

  Position? _ultimaPosicion;
  DateTime? _ultimaActualizacion;

  Position? get posicion => _ultimaPosicion;
  LatLng? get latLng => _ultimaPosicion == null
      ? null
      : LatLng(_ultimaPosicion!.latitude, _ultimaPosicion!.longitude);

  Future<Position?> obtenerPosicion({bool forzar = false}) async {
    if (!forzar && _ultimaActualizacion != null) {
      final diff = DateTime.now().difference(_ultimaActualizacion!);
      if (diff.inSeconds < 60 && _ultimaPosicion != null) {
        return _ultimaPosicion;
      }
    }
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return null;
      }
      if (perm == LocationPermission.deniedForever) return null;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      _ultimaPosicion = pos;
      _ultimaActualizacion = DateTime.now();
      _persistirUbicacion(pos).ignore();
      return pos;
    } catch (_) {
      return _ultimaPosicion;
    }
  }

  Future<void> _persistirUbicacion(Position pos) async {
    final uid = SupabaseService.instance.currentUserId;
    if (uid == null) return;
    try {
      await SupabaseService.instance.actualizarPerfil(
        userId: uid,
        latitud: pos.latitude,
        longitud: pos.longitude,
      );
    } catch (_) {}
  }

  /// Fórmula de Haversine pura.
  double distancia(LatLng a, LatLng b) {
    const R = 6371.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final h = pow(sin(dLat / 2), 2) +
        cos(_rad(a.latitude)) * cos(_rad(b.latitude)) * pow(sin(dLng / 2), 2);
    return R * 2 * atan2(sqrt(h), sqrt(1 - h));
  }

  double _rad(double d) => d * pi / 180;

  List<Juntada> agregarDistancias(List<Juntada> juntadas) {
    final p = _ultimaPosicion;
    if (p == null) return juntadas;
    for (final j in juntadas) {
      j.distanciaKm = j.calcularDistancia(p.latitude, p.longitude);
    }
    return juntadas;
  }

  List<Juntada> ordenarPorDistancia(List<Juntada> juntadas) {
    final list = agregarDistancias(List.of(juntadas));
    list.sort((a, b) => (a.distanciaKm ?? 999).compareTo(b.distanciaKm ?? 999));
    return list;
  }

  List<Juntada> filtrarPorRadio(List<Juntada> juntadas, double radioKm) {
    return agregarDistancias(List.of(juntadas))
        .where((j) => (j.distanciaKm ?? 999) <= radioKm)
        .toList();
  }

  Future<EstadoPermiso> estadoPermiso() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return EstadoPermiso.servicioApagado;
    final perm = await Geolocator.checkPermission();
    return switch (perm) {
      LocationPermission.always => EstadoPermiso.concedido,
      LocationPermission.whileInUse => EstadoPermiso.concedido,
      LocationPermission.denied => EstadoPermiso.denegado,
      LocationPermission.deniedForever => EstadoPermiso.denegadoPermanente,
      LocationPermission.unableToDetermine => EstadoPermiso.desconocido,
    };
  }

  Stream<Position> streamPosicion() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 20,
        ),
      );
}

enum EstadoPermiso {
  concedido,
  denegado,
  denegadoPermanente,
  servicioApagado,
  desconocido
}
