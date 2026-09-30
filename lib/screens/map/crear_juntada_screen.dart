import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../services/geolocacion_service.dart';
import '../../theme/app_theme.dart';

class CrearJuntadaScreen extends StatefulWidget {
  const CrearJuntadaScreen({super.key});
  @override
  State<CrearJuntadaScreen> createState() => _CrearJuntadaScreenState();
}

class _CrearJuntadaScreenState extends State<CrearJuntadaScreen> {
  static const _barrios = [
    'Boedo',
    'Almagro',
    'Palermo',
    'Caballito',
    'Balvanera',
    'Belgrano',
    'Recoleta',
    'Villa Crespo',
    'Chacarita',
    'San Telmo',
    'Puerto Madero',
    'Núñez',
    'Flores',
    'Villa Devoto',
    'La Boca',
  ];
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _lugarCtrl = TextEditingController();
  DateTime _fecha = DateTime.now();
  TimeOfDay _hora = const TimeOfDay(hour: 19, minute: 0);
  String _categoria = CategoriaJuntada.todas.first.nombre;
  String? _barrio;
  double _capacidad = 10;
  bool _soloVerificados = false;
  bool _guardando = false;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _lugarCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
        context: context,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        initialDate: _fecha);
    if (elegida != null && mounted) setState(() => _fecha = elegida);
  }

  Future<void> _elegirHora() async {
    final elegida = await showTimePicker(
      context: context,
      initialTime: _hora,
      initialEntryMode: TimePickerEntryMode.dial,
    );
    if (elegida != null && mounted) setState(() => _hora = elegida);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<AppProvider>();
    final usuario = provider.usuario;
    if (usuario == null) return;
    final fecha = DateTime(
        _fecha.year, _fecha.month, _fecha.day, _hora.hour, _hora.minute);
    if (!fecha.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Elegí una fecha y hora futuras.'),
          backgroundColor: PlanazoColors.error));
      return;
    }
    setState(() => _guardando = true);
    final ubicacion =
        GeolocacionService.instance.latLng ?? const LatLng(-34.617, -58.420);
    final juntada = Juntada(
        id: const Uuid().v4(),
        titulo: _tituloCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim(),
        organizadorId: usuario.id,
        organizadorNombre: usuario.nombreCompleto,
        fecha: fecha,
        lugar: _lugarCtrl.text.trim(),
        coordenadas: ubicacion,
        barrio: _barrio!,
        capacidadMaxima: _capacidad.round(),
        categoria: _categoria,
        soloVerificados: _soloVerificados,
        creadoEn: DateTime.now());
    try {
      final nueva = await provider.crearJuntada(juntada);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('¡Juntada creada!'),
            backgroundColor: PlanazoColors.exito));
        context.go('/juntada/${nueva.id}');
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Supabase rechazó la juntada. Revisá el detalle.'),
            backgroundColor: PlanazoColors.error));
        _mostrarErrorTecnico(error);
      }
    } catch (error) {
      if (mounted) _mostrarErrorTecnico(error);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
          onPressed: () => context.pop()),
            title: const Text('Crear juntada',
                style: TextStyle(fontWeight: FontWeight.w800))),
        backgroundColor: PlanazoColors.negro,
        body: Theme(
          data: Theme.of(context).copyWith(
            scaffoldBackgroundColor: PlanazoColors.negro,
            inputDecorationTheme: Theme.of(context)
                .inputDecorationTheme
                .copyWith(
                  filled: true,
                  fillColor: PlanazoColors.negroSuave,
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIconColor: PlanazoColors.amarillo,
                  enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: const OutlineInputBorder(
                      borderSide:
                          BorderSide(color: PlanazoColors.amarillo, width: 2)),
                ),
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  surface: PlanazoColors.negroSuave,
                  onSurface: Colors.white,
                  primary: PlanazoColors.amarillo,
                ),
          ),
          child: Form(
            key: _formKey,
            child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  const Text('Armá un plan que den ganas de aceptar.',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text(
                      'Completá los datos principales y encontrá gente con tus mismos intereses.',
                      style: TextStyle(color: PlanazoColors.textoSecundario)),
                  const SizedBox(height: 24),
                  _field(_tituloCtrl, 'Título',
                      'Ej. Picnic y juegos en el parque', 3,
                      maxLength: 100),
                  _field(_descripcionCtrl, 'Descripción',
                      'Contá qué tienen pensado hacer', 10,
                      maxLength: 1000, maxLines: 4),
                  DropdownButtonFormField<String>(
                      initialValue: _categoria,
                      decoration: const InputDecoration(
                          labelText: 'Categoría',
                          prefixIcon: Icon(Icons.local_activity_outlined)),
                      items: CategoriaJuntada.todas
                          .map((cat) => DropdownMenuItem(
                              value: cat.nombre,
                              child: Text('${cat.emoji} ${cat.nombre}')))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _categoria = value!)),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                        child: _dateButton(
                            Icons.calendar_today_outlined,
                            '${_fecha.day}/${_fecha.month}/${_fecha.year}',
                            _elegirFecha)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _dateButton(Icons.schedule_outlined,
                            _hora.format(context), _elegirHora))
                  ]),
                  const SizedBox(height: 14),
                  _field(_lugarCtrl, 'Lugar', 'Ej. Plaza Armenia', 5),
                  DropdownButtonFormField<String>(
                      initialValue: _barrio,
                      decoration: const InputDecoration(
                          labelText: 'Barrio',
                          prefixIcon: Icon(Icons.location_city_outlined)),
                      dropdownColor: PlanazoColors.negroSuave,
                      style: const TextStyle(color: Colors.white),
                      items: _barrios
                          .map((barrio) => DropdownMenuItem(
                              value: barrio, child: Text(barrio)))
                          .toList(),
                      validator: (value) =>
                          value == null ? 'Elegí un barrio' : null,
                      onChanged: (value) => setState(() => _barrio = value)),
                  const SizedBox(height: 6),
                  Text('Capacidad: ${_capacidad.round()} personas',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Slider(
                      value: _capacidad,
                      min: 2,
                      max: 50,
                      divisions: 48,
                      activeColor: PlanazoColors.amarilloOscuro,
                      label: '${_capacidad.round()}',
                      onChanged: (value) => setState(() => _capacidad = value)),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Solo personas verificadas'),
                      subtitle: const Text('Sumá un filtro extra de confianza'),
                      value: _soloVerificados,
                      activeThumbColor: PlanazoColors.amarilloOscuro,
                      onChanged: (value) =>
                          setState(() => _soloVerificados = value)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                      onPressed: _guardando ? null : _guardar,
                      icon: _guardando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: PlanazoColors.negro))
                          : const Icon(Icons.rocket_launch_outlined),
                      label:
                          Text(_guardando ? 'Creando...' : 'Publicar juntada')),
                ]),
          ),
        ),
      );

  void _mostrarErrorTecnico(Object error) {
    final detalle = error is PostgrestException
        ? '${error.message} (código ${error.code ?? 'desconocido'})'
        : error.toString();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Detalle: $detalle'),
      backgroundColor: PlanazoColors.negroSuave,
      duration: const Duration(seconds: 8),
    ));
  }

  Widget _field(TextEditingController controller, String label, String hint,
          int minLength, {int? maxLength, int maxLines = 1}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextFormField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              maxLength: maxLength,
              maxLines: maxLines,
              decoration: InputDecoration(labelText: label, hintText: hint),
              validator: (value) =>
                  value == null || value.trim().length < minLength
                      ? '$label debe tener al menos $minLength caracteres'
                      : null));
  Widget _dateButton(IconData icon, String label, VoidCallback onPressed) =>
      OutlinedButton.icon(
          onPressed: onPressed, icon: Icon(icon, size: 18), label: Text(label));
}
