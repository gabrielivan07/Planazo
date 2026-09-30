import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../services/geolocacion_service.dart';
import '../../models/models.dart';
import '../../widgets/juntada_card.dart';

class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});
  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  static const LatLng _centro = LatLng(-34.617, -58.420);
  final MapController _mapCtrl = MapController();
  final _geoSvc = GeolocacionService.instance;

  String _categoriaFiltro = 'Todas';
  String _busqueda = '';
  bool _modoMapa = true;
  bool _porDistancia = false;
  bool _refrescoInicialSolicitado = false;
  Juntada? _seleccionada;

  @override
  void initState() {
    super.initState();
    _initGeo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_refrescoInicialSolicitado) return;
    _refrescoInicialSolicitado = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _actualizarJuntadas();
    });
  }

  Future<void> _actualizarJuntadas({bool mostrarError = false}) async {
    try {
      await context.read<AppProvider>().recargarJuntadas();
    } catch (_) {
      if (mostrarError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudieron actualizar las juntadas.'),
        ));
      }
    }
  }

  Future<void> _initGeo() async {
    await _geoSvc.obtenerPosicion();
    if (mounted) setState(() {});
    final ll = _geoSvc.latLng;
    if (ll != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapCtrl.move(ll, 14.0);
      });
    }
  }

  List<Juntada> _filtradas(List<Juntada> todas) {
    var lista = todas.where((j) {
      final mc = _categoriaFiltro == 'Todas' || j.categoria == _categoriaFiltro;
      final mb = _busqueda.isEmpty ||
          j.titulo.toLowerCase().contains(_busqueda.toLowerCase()) ||
          j.lugar.toLowerCase().contains(_busqueda.toLowerCase()) ||
          j.barrio.toLowerCase().contains(_busqueda.toLowerCase());
      return mc && mb;
    }).toList();

    if (_porDistancia && _geoSvc.posicion != null) {
      lista = _geoSvc.ordenarPorDistancia(lista);
    }
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final juntadas = _filtradas(provider.juntadasProximas);
    final categorias = [
      'Todas',
      ...CategoriaJuntada.todas.map((c) => c.nombre)
    ];
    final tieneGeo = _geoSvc.posicion != null;

    return Scaffold(
      backgroundColor: PlanazoColors.fondoPrimario,
      appBar: AppBar(
        title: const Text('Explorar'),
        actions: [
          IconButton(
            tooltip: 'Actualizar juntadas',
            icon: const Icon(Icons.refresh),
            onPressed: () => _actualizarJuntadas(mostrarError: true),
          ),
          // Toggle mapa / lista
          IconButton(
            tooltip: _modoMapa ? 'Ver lista' : 'Ver mapa',
            icon: Icon(_modoMapa ? Icons.list : Icons.map_outlined),
            onPressed: () => setState(() {
              _modoMapa = !_modoMapa;
              _seleccionada = null;
            }),
          ),
          // Ordenar por distancia (solo si hay GPS)
          if (tieneGeo)
            IconButton(
              tooltip:
                  _porDistancia ? 'Ordenar por fecha' : 'Ordenar por cercanía',
              icon: Icon(
                Icons.near_me,
                color: _porDistancia ? PlanazoColors.negro : Colors.black38,
              ),
              onPressed: () => setState(() => _porDistancia = !_porDistancia),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/crear-juntada'),
        backgroundColor: PlanazoColors.negro,
        foregroundColor: PlanazoColors.amarillo,
        icon: const Icon(Icons.add),
        label: const Text('Crear juntada',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(children: [
        // Buscador
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: TextField(
            onChanged: (v) => setState(() => _busqueda = v),
            decoration: InputDecoration(
              hintText: 'Buscar en Boedo, Almagro, Caballito...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _busqueda.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _busqueda = ''),
                    )
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ),

        // Chips de categorías
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: categorias.length,
            itemBuilder: (ctx, i) {
              final cat = categorias[i];
              final on = cat == _categoriaFiltro;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(cat),
                  selected: on,
                  onSelected: (_) => setState(() {
                    _categoriaFiltro = cat;
                    _seleccionada = null;
                  }),
                  selectedColor: PlanazoColors.amarillo,
                  backgroundColor: PlanazoColors.blanco,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                    color: PlanazoColors.negro,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                        color: on
                            ? PlanazoColors.amarilloOscuro
                            : PlanazoColors.borde),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              );
            },
          ),
        ),

        // Indicador de carga
        if (provider.cargandoJuntadas)
          const LinearProgressIndicator(
            color: PlanazoColors.amarillo,
            backgroundColor: PlanazoColors.amarilloClaro,
            minHeight: 2,
          ),

        const SizedBox(height: 4),

        // Mapa o lista
        Expanded(
          child: _modoMapa
              ? _buildMapa(juntadas, tieneGeo)
              : _buildLista(juntadas),
        ),
      ]),
    );
  }

  // ── MAPA ─────────────────────────────────────────────────
  Widget _buildMapa(List<Juntada> juntadas, bool tieneGeo) => Stack(children: [
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: _centro,
            initialZoom: 14.0,
            onTap: (_, __) => setState(() => _seleccionada = null),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.planazo.app',
            ),

            // Punto azul de ubicación del usuario
            if (_geoSvc.latLng != null)
              MarkerLayer(markers: [
                Marker(
                  point: _geoSvc.latLng!,
                  width: 40,
                  height: 40,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: PlanazoColors.info,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                            color: PlanazoColors.info.withValues(alpha: .4),
                            blurRadius: 8)
                      ],
                    ),
                  ),
                ),
              ]),

            // Pines de juntadas
            MarkerLayer(
              markers: juntadas.map((j) {
                final cat = CategoriaJuntada.todas.firstWhere(
                  (c) => c.nombre == j.categoria,
                  orElse: () => const CategoriaJuntada(nombre: '', emoji: '📍'),
                );
                final selec = _seleccionada?.id == j.id;
                return Marker(
                  point: j.coordenadas,
                  width: 50,
                  height: 58,
                  child: GestureDetector(
                    onTap: () => setState(() => _seleccionada = j),
                    child: AnimatedScale(
                      scale: selec ? 1.15 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Column(children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: j.estaLlena
                                ? PlanazoColors.error
                                : selec
                                    ? PlanazoColors.negro
                                    : PlanazoColors.amarillo,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 6,
                                  offset: Offset(0, 3))
                            ],
                          ),
                          child: Text(cat.emoji,
                              style: const TextStyle(fontSize: 18)),
                        ),
                        CustomPaint(
                          painter: _PinTail(
                            color: j.estaLlena
                                ? PlanazoColors.error
                                : selec
                                    ? PlanazoColors.negro
                                    : PlanazoColors.amarillo,
                          ),
                          size: const Size(12, 7),
                        ),
                      ]),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        // Botón mi ubicación
        if (tieneGeo)
          Positioned(
            top: 10,
            right: 10,
            child: FloatingActionButton.small(
              heroTag: 'loc',
              backgroundColor: PlanazoColors.blanco,
              onPressed: () {
                final ll = _geoSvc.latLng;
                if (ll != null) _mapCtrl.move(ll, 15);
              },
              child: const Icon(Icons.my_location,
                  color: PlanazoColors.info, size: 20),
            ),
          ),

        // Label barrios
        Positioned(
          top: 10,
          left: 0,
          right: 60,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: PlanazoColors.negro.withValues(alpha: .75),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '📍 Boedo · Almagro · Caballito · Balvanera',
                style: TextStyle(
                    color: PlanazoColors.blanco,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),

        // Card de juntada seleccionada
        if (_seleccionada != null)
          Positioned(
            bottom: 90,
            left: 14,
            right: 14,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              child: JuntadaCard(
                juntada: _seleccionada!,
                onTap: () => context.push('/juntada/${_seleccionada!.id}'),
                compact: true,
              ),
            ),
          ),
      ]);

  // ── LISTA ─────────────────────────────────────────────────
  Widget _buildLista(List<Juntada> juntadas) {
    if (juntadas.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('😕', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 12),
          Text('Sin juntadas',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('Probá con otra categoría.',
              style: TextStyle(
                  color: PlanazoColors.textoSecundario, fontSize: 13)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
      itemCount: juntadas.length,
      itemBuilder: (ctx, i) => JuntadaCard(
        juntada: juntadas[i],
        onTap: () => context.push('/juntada/${juntadas[i].id}'),
      ),
    );
  }
}

class _PinTail extends CustomPainter {
  final Color color;
  const _PinTail({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      ui.Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_) => true;
}
