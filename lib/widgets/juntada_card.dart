import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class JuntadaCard extends StatelessWidget {
  final Juntada juntada;
  final VoidCallback? onTap;
  final bool compact;

  const JuntadaCard({
    super.key,
    required this.juntada,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      color: PlanazoColors.blanco,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: PlanazoColors.amarilloClaro,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        CategoriaJuntada.emojiPara(juntada.categoria),
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          juntada.titulo,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${juntada.fechaFormateada} · ${juntada.horaFormateada}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: PlanazoColors.textoTerciario),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                juntada.descripcion,
                maxLines: compact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, color: PlanazoColors.textoPrimario),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 16, color: PlanazoColors.textoTerciario),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${juntada.lugar} · ${juntada.barrio}',
                      style: const TextStyle(
                          fontSize: 12, color: PlanazoColors.textoTerciario),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.people_alt_outlined,
                      size: 16, color: PlanazoColors.textoTerciario),
                  const SizedBox(width: 4),
                  Text(
                    '${juntada.participantesCount}/${juntada.capacidadMaxima} participantes',
                    style: const TextStyle(
                        fontSize: 12, color: PlanazoColors.textoTerciario),
                  ),
                  const Spacer(),
                  if (juntada.distanciaTexto.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: PlanazoColors.fondoSecundario,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        juntada.distanciaTexto,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return card;
  }
}
