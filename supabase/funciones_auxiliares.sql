-- ============================================================
-- PLANAZO — FUNCIONES AUXILIARES Y DATOS INICIALES
-- Ejecutar después de schema.sql y rls_policies.sql
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- FUNCIÓN: marcar_mensajes_leidos
-- Llamada desde ChatService.marcarLeido()
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.marcar_mensajes_leidos(
  p_chat_id    UUID,
  p_usuario_id UUID
) RETURNS VOID AS $$
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> p_usuario_id THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.chat_participantes
    WHERE chat_id = p_chat_id AND usuario_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

  UPDATE public.mensajes
  SET leido_por = array_append(leido_por, p_usuario_id)
  WHERE
    chat_id  = p_chat_id
    AND NOT (leido_por @> ARRAY[p_usuario_id]);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ────────────────────────────────────────────────────────────
-- FUNCIÓN: sumar_puntos_confianza
-- Llamada desde triggers y edge functions
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.sumar_puntos(
  p_usuario_id UUID,
  p_puntos     INT,
  p_motivo     TEXT,
  p_juntada_id UUID DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
  UPDATE public.usuarios
  SET puntos_confianza = GREATEST(0, puntos_confianza + p_puntos)
  WHERE id = p_usuario_id;

  INSERT INTO public.historial_puntos (usuario_id, cambio, motivo, juntada_id)
  VALUES (p_usuario_id, p_puntos, p_motivo, p_juntada_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ────────────────────────────────────────────────────────────
-- FUNCIÓN: obtener_mis_chats
-- Retorna los chats del usuario autenticado con el último mensaje
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.obtener_mis_chats()
RETURNS TABLE (
  id           UUID,
  juntada_id   UUID,
  titulo       TEXT,
  es_grupal    BOOLEAN,
  ultimo_msg   TEXT,
  ultimo_ts    TIMESTAMPTZ,
  no_leidos    BIGINT,
  created_at   TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id,
    c.juntada_id,
    COALESCE(c.titulo, j.titulo) AS titulo,
    c.es_grupal,
    (
      SELECT m.contenido FROM public.mensajes m
      WHERE m.chat_id = c.id
      ORDER BY m.created_at DESC LIMIT 1
    ) AS ultimo_msg,
    (
      SELECT m.created_at FROM public.mensajes m
      WHERE m.chat_id = c.id
      ORDER BY m.created_at DESC LIMIT 1
    ) AS ultimo_ts,
    (
      SELECT COUNT(*) FROM public.mensajes m
      WHERE m.chat_id = c.id
        AND NOT (m.leido_por @> ARRAY[auth.uid()])
        AND m.remitente_id != auth.uid()
    ) AS no_leidos,
    c.created_at
  FROM public.chats c
  LEFT JOIN public.juntadas j ON j.id = c.juntada_id
  INNER JOIN public.chat_participantes cp
    ON cp.chat_id = c.id AND cp.usuario_id = auth.uid()
  ORDER BY ultimo_ts DESC NULLS LAST;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ────────────────────────────────────────────────────────────
-- FUNCIÓN: penalizar_ausencia
-- Cron job: ejecutar diariamente para restar puntos por inasistencia
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.penalizar_ausencias()
RETURNS VOID AS $$
DECLARE
  rec RECORD;
BEGIN
  -- Buscar participantes de juntadas que ya pasaron hace más de 2 horas
  -- y no fueron marcados como asistentes
  FOR rec IN
    SELECT p.usuario_id, p.juntada_id
    FROM public.participantes p
    INNER JOIN public.juntadas j ON j.id = p.juntada_id
    WHERE
      p.estado = 'confirmado'
      AND j.fecha < NOW() - INTERVAL '2 hours'
      AND j.estado = 'activa'
      -- Solo penalizar una vez: verificar que no hay historial de esta juntada
      AND NOT EXISTS (
        SELECT 1 FROM public.historial_puntos hp
        WHERE hp.usuario_id = p.usuario_id
          AND hp.juntada_id = p.juntada_id
          AND hp.motivo LIKE 'Ausente%'
      )
  LOOP
    PERFORM public.sumar_puntos(
      rec.usuario_id,
      -30,
      'Ausente en juntada sin cancelar',
      rec.juntada_id
    );

    -- Marcar la juntada como finalizada si corresponde
    UPDATE public.juntadas
    SET estado = 'finalizada'
    WHERE id = rec.juntada_id AND estado = 'activa';
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Solo triggers/funciones internas pueden modificar puntos o ejecutar el cron.
REVOKE EXECUTE ON FUNCTION public.sumar_puntos(UUID, INT, TEXT, UUID)
  FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.penalizar_ausencias()
  FROM anon, authenticated;

-- ────────────────────────────────────────────────────────────
-- DATOS INICIALES: Categorías (almacenadas para referencia futura)
-- No es estrictamente necesario, las categorías están hardcodeadas en Flutter,
-- pero tener esta tabla permite agregar/quitar sin deploy.
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.categorias (
  nombre       TEXT PRIMARY KEY,
  emoji        TEXT NOT NULL,
  descripcion  TEXT,
  activa       BOOLEAN DEFAULT TRUE,
  orden        INT DEFAULT 99
);

INSERT INTO public.categorias (nombre, emoji, descripcion, orden) VALUES
  ('Deportes',    '⚽', 'Fútbol, tenis, running y más',    1),
  ('Gastronomía', '🍕', 'Cenas, asados, bares',            2),
  ('Cultura',     '🎭', 'Teatro, museos, arte',            3),
  ('Música',      '🎵', 'Recitales, peñas, covers',        4),
  ('Naturaleza',  '🌿', 'Senderismo, parques, bici',       5),
  ('Juegos',      '🎲', 'Board games, videojuegos',        6),
  ('Social',      '🤝', 'Networking, charlas, meetups',    7),
  ('Viajes',      '✈️', 'Excursiones y escapadas',         8)
ON CONFLICT DO NOTHING;

-- ────────────────────────────────────────────────────────────
-- DATOS DE DEMO: Juntadas en Boedo/Almagro/Caballito/Balvanera
-- IMPORTANTE: reemplazar organizador_id con el UUID real
-- de un usuario existente en tu proyecto de Supabase.
-- ────────────────────────────────────────────────────────────
-- DO $$
-- DECLARE
--   org_id UUID := 'UUID-DE-UN-USUARIO-REAL';
-- BEGIN
--   INSERT INTO public.juntadas
--     (titulo, descripcion, organizador_id, fecha, lugar, lat, lng, barrio, capacidad_maxima, categoria, etiquetas)
--   VALUES
--     ('Fútbol 5 en Parque Rivadavia',
--      'Partidito amistoso. Todos los niveles bienvenidos.',
--      org_id,
--      NOW() + INTERVAL '2 days 3 hours',
--      'Parque Rivadavia, Av. Rivadavia 4900, Caballito',
--      -34.6231, -58.4393, 'Caballito', 10, 'Deportes',
--      ARRAY['fútbol', 'deporte', 'aire libre']),
--
--     ('Asado en Boedo',
--      'Gran asado dominical con buena música.',
--      org_id,
--      NOW() + INTERVAL '4 days 12 hours',
--      'Boedo 760 entre Independencia y San Juan',
--      -34.6260, -58.4180, 'Boedo', 15, 'Gastronomía',
--      ARRAY['asado', 'domingo']),
--
--     ('Teatro en el Camarín de las Musas',
--      'Obra de teatro independiente en Almagro.',
--      org_id,
--      NOW() + INTERVAL '3 days 19 hours',
--      'Mario Bravo 960, Almagro',
--      -34.6068, -58.4221, 'Almagro', 20, 'Cultura',
--      ARRAY['teatro', 'cultura']),
--
--     ('Board Games en Almagro',
--      'Tarde de juegos de mesa. Más de 50 juegos disponibles.',
--      org_id,
--      NOW() + INTERVAL '1 day 15 hours',
--      'Av. Corrientes 3247, Almagro',
--      -34.6050, -58.4280, 'Almagro', 12, 'Juegos',
--      ARRAY['juegos', 'tarde']),
--
--     ('Running Parque Centenario',
--      'Trote matutino de 5k. Ritmo moderado.',
--      org_id,
--      NOW() + INTERVAL '18 hours',
--      'Parque Centenario, Av. Díaz Vélez 4698, Caballito',
--      -34.6111, -58.4358, 'Caballito', 15, 'Deportes',
--      ARRAY['running', 'mañana']),
--
--     ('Peña folclórica en Balvanera',
--      'Noche de folklore. Entrada libre.',
--      org_id,
--      NOW() + INTERVAL '5 days 20 hours',
--      'Av. Corrientes 2100, Balvanera',
--      -34.6090, -58.4080, 'Balvanera', 30, 'Música',
--      ARRAY['folklore', 'música']);
-- END $$;

-- ────────────────────────────────────────────────────────────
-- CONFIGURACIÓN DE REALTIME
-- Habilitar para las tablas que necesitan tiempo real
-- ────────────────────────────────────────────────────────────
-- Ejecutar en Supabase > Database > Replication:
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.mensajes;
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.participantes;
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.juntadas;

-- O via SQL:
BEGIN;
  ALTER PUBLICATION supabase_realtime ADD TABLE public.mensajes;
  ALTER PUBLICATION supabase_realtime ADD TABLE public.participantes;
COMMIT;
