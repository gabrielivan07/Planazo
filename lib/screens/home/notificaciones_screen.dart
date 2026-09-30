import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  late final Timer _actualizador;

  @override
  void initState() {
    super.initState();
    _actualizador = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _actualizador.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recordatorios =
        context.watch<AppProvider>().juntadasConRecordatorio;

    return Scaffold(
      backgroundColor: PlanazoColors.fondoPrimario,
      appBar: AppBar(
        title: const Text('Notificaciones'),
      ),
      body: recordatorios.isEmpty
          ? const _SinNotificaciones()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: recordatorios.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _RecordatorioJuntada(
                juntada: recordatorios[index],
              ),
            ),
    );
  }
}

class _SinNotificaciones extends StatelessWidget {
  const _SinNotificaciones();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none,
                size: 56, color: PlanazoColors.amarilloOscuro),
            SizedBox(height: 16),
            Text(
              'No tienes notificaciones todavía',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: PlanazoColors.negro,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Aquí aparecerán los avisos de tus juntadas.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: PlanazoColors.textoSecundario,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordatorioJuntada extends StatelessWidget {
  final Juntada juntada;

  const _RecordatorioJuntada({required this.juntada});

  @override
  Widget build(BuildContext context) {
    final minutos = juntada.fecha.difference(DateTime.now()).inMinutes;
    final cuando = minutos < 1 ? 'menos de un minuto' : '$minutos minutos';

    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const CircleAvatar(
          backgroundColor: PlanazoColors.amarilloClaro,
          child: Icon(Icons.notifications_active_outlined,
              color: PlanazoColors.negro),
        ),
        title: const Text(
          'Tu juntada empieza pronto',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${juntada.titulo} empieza en $cuando.'),
        ),
      ),
    );
  }
}
