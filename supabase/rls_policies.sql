-- ============================================================
-- PLANAZO — POLÍTICAS DE SEGURIDAD (Row Level Security)
-- Ejecutar DESPUÉS de schema.sql
-- ============================================================

-- Habilitar RLS en todas las tablas
ALTER TABLE public.usuarios          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.juntadas          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.participantes     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chats             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_participantes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mensajes          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.resenas           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.historial_puntos  ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- POLÍTICAS: usuarios
-- ============================================================

-- Cualquiera puede ver perfiles públicos
CREATE POLICY "usuarios_select_publico"
  ON public.usuarios FOR SELECT
  USING (auth.uid() = id);

-- Solo el propio usuario puede actualizar su perfil
CREATE POLICY "usuarios_update_propio"
  ON public.usuarios FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Insert lo hace el trigger automáticamente (SECURITY DEFINER)
-- No necesita política

-- Un usuario no puede eliminarse a sí mismo directamente (lógica de negocio)
CREATE POLICY "usuarios_no_delete"
  ON public.usuarios FOR DELETE
  USING (FALSE);

-- ============================================================
-- POLÍTICAS: juntadas
-- ============================================================

-- Cualquier usuario autenticado puede ver juntadas públicas activas
CREATE POLICY "juntadas_select_publicas"
  ON public.juntadas FOR SELECT
  USING (
    auth.role() = 'authenticated'
    AND es_publica = TRUE
    AND estado IN ('activa', 'finalizada')
  );

-- El organizador puede ver todas sus juntadas (incluyendo borradores)
CREATE POLICY "juntadas_select_propias"
  ON public.juntadas FOR SELECT
  USING (auth.uid() = organizador_id);

-- Solo usuarios autenticados pueden crear juntadas
CREATE POLICY "juntadas_insert"
  ON public.juntadas FOR INSERT
  WITH CHECK (
    auth.role() = 'authenticated'
    AND auth.uid() = organizador_id
  );

-- Solo el organizador puede modificar su juntada
CREATE POLICY "juntadas_update_propio"
  ON public.juntadas FOR UPDATE
  USING (auth.uid() = organizador_id)
  WITH CHECK (auth.uid() = organizador_id);

-- Solo el organizador puede cancelar (no eliminar) su juntada
-- (se hace mediante UPDATE de estado, no DELETE)
CREATE POLICY "juntadas_no_delete"
  ON public.juntadas FOR DELETE
  USING (FALSE);

-- ============================================================
-- POLÍTICAS: participantes
-- ============================================================

-- Ver participantes: el organizador o los propios participantes
CREATE POLICY "participantes_select"
  ON public.participantes FOR SELECT
  USING (
    auth.uid() = usuario_id
    OR EXISTS (
      SELECT 1 FROM public.juntadas j
      WHERE j.id = juntada_id
      AND j.organizador_id = auth.uid()
    )
  );

-- Unirse a una juntada: solo uno mismo
CREATE POLICY "participantes_insert"
  ON public.participantes FOR INSERT
  WITH CHECK (
    auth.uid() = usuario_id
    AND EXISTS (
      -- Solo se puede confirmar una juntada activa y futura.
      SELECT 1 FROM public.juntadas j
      WHERE j.id = juntada_id
        AND j.estado = 'activa'
        AND j.fecha > NOW()
        AND (
          j.organizador_id = auth.uid()
          OR NOT j.solo_verificados
          OR EXISTS (
            SELECT 1 FROM public.usuarios u
            WHERE u.id = auth.uid() AND u.verificado = TRUE
          )
        )
        AND (
          SELECT COUNT(*) FROM public.participantes p2
          WHERE p2.juntada_id = j.id
            AND p2.estado = 'confirmado'
        ) < j.capacidad_maxima
    )
  );

-- Solo el participante puede cancelar su propia participación
CREATE POLICY "participantes_update"
  ON public.participantes FOR UPDATE
  USING (auth.uid() = usuario_id)
  WITH CHECK (auth.uid() = usuario_id AND estado = 'cancelado');

-- ============================================================
-- POLÍTICAS: participantes de chats
-- ============================================================

-- Cada usuario solo puede ver su propia pertenencia a un chat.
-- Las inserciones las realizan los triggers SECURITY DEFINER.
CREATE POLICY "chat_participantes_select_propio"
  ON public.chat_participantes FOR SELECT
  USING (auth.uid() = usuario_id);

CREATE POLICY "chat_participantes_no_insert_direct"
  ON public.chat_participantes FOR INSERT
  WITH CHECK (FALSE);

CREATE POLICY "chat_participantes_no_update"
  ON public.chat_participantes FOR UPDATE
  USING (FALSE);

CREATE POLICY "chat_participantes_no_delete"
  ON public.chat_participantes FOR DELETE
  USING (FALSE);

-- ============================================================
-- POLÍTICAS: mensajes
-- ============================================================

-- Solo los participantes del chat pueden ver los mensajes
CREATE POLICY "mensajes_select"
  ON public.mensajes FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.chat_participantes cp
      WHERE cp.chat_id = mensajes.chat_id
      AND cp.usuario_id = auth.uid()
    )
  );

-- Solo los participantes del chat pueden enviar mensajes
CREATE POLICY "mensajes_insert"
  ON public.mensajes FOR INSERT
  WITH CHECK (
    auth.uid() = remitente_id
    AND EXISTS (
      SELECT 1 FROM public.chat_participantes cp
      WHERE cp.chat_id = mensajes.chat_id
      AND cp.usuario_id = auth.uid()
    )
  );

-- No se pueden editar ni eliminar mensajes (por ahora)
CREATE POLICY "mensajes_no_update"
  ON public.mensajes FOR UPDATE
  USING (FALSE);

CREATE POLICY "mensajes_no_delete"
  ON public.mensajes FOR DELETE
  USING (FALSE);

-- ============================================================
-- POLÍTICAS: chats
-- ============================================================

-- Solo los participantes ven el chat
CREATE POLICY "chats_select"
  ON public.chats FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.chat_participantes cp
      WHERE cp.chat_id = id
      AND cp.usuario_id = auth.uid()
    )
  );

-- Los chats se crean con triggers (SECURITY DEFINER), no directamente
CREATE POLICY "chats_no_insert_direct"
  ON public.chats FOR INSERT
  WITH CHECK (FALSE);

-- ============================================================
-- POLÍTICAS: reseñas
-- ============================================================

-- Cualquiera puede ver reseñas
CREATE POLICY "resenas_select"
  ON public.resenas FOR SELECT
  USING (auth.role() = 'authenticated');

-- Solo puedo crear una reseña si fui participante de la juntada
CREATE POLICY "resenas_insert"
  ON public.resenas FOR INSERT
  WITH CHECK (
    auth.uid() = autor_id
    AND autor_id != destinatario_id
    AND EXISTS (
      SELECT 1 FROM public.participantes p
      WHERE p.juntada_id = resenas.juntada_id
      AND p.usuario_id = auth.uid()
      AND p.estado = 'confirmado'
    )
  );

-- ============================================================
-- POLÍTICAS: historial_puntos
-- ============================================================

-- Solo el propio usuario ve su historial
CREATE POLICY "historial_select_propio"
  ON public.historial_puntos FOR SELECT
  USING (auth.uid() = usuario_id);

-- Solo los triggers (SECURITY DEFINER) pueden insertar
CREATE POLICY "historial_no_insert_direct"
  ON public.historial_puntos FOR INSERT
  WITH CHECK (FALSE);

-- La app solo edita campos de perfil. Los campos de confianza, verificación,
-- premium, DNI y ubicación no deben poder modificarse con un UPDATE directo.
REVOKE UPDATE ON public.usuarios FROM anon, authenticated;
GRANT UPDATE (
  nombre, apellido, telefono, foto_perfil_url, intereses,
  ultima_lat, ultima_lng
) ON public.usuarios TO authenticated;
