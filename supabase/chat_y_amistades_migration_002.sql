ALTER TABLE public.chat_participantes
  ADD COLUMN IF NOT EXISTS silenciado BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS archivado BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS fijado BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS eliminado BOOLEAN NOT NULL DEFAULT FALSE;

GRANT UPDATE (silenciado, archivado, fijado, eliminado)
  ON public.chat_participantes TO authenticated;

DROP POLICY IF EXISTS "chats_select" ON public.chats;
CREATE POLICY "chats_select"
  ON public.chats FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.chat_participantes cp
      WHERE cp.chat_id = chats.id
        AND cp.usuario_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "mensajes_select" ON public.mensajes;
CREATE POLICY "mensajes_select"
  ON public.mensajes FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.chat_participantes cp
      WHERE cp.chat_id = mensajes.chat_id
        AND cp.usuario_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "mensajes_insert" ON public.mensajes;
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

DROP POLICY IF EXISTS "chat_participantes_update_propio"
  ON public.chat_participantes;
CREATE POLICY "chat_participantes_update_propio"
  ON public.chat_participantes FOR UPDATE
  USING (auth.uid() = usuario_id)
  WITH CHECK (auth.uid() = usuario_id);

CREATE TABLE IF NOT EXISTS public.amistades (
  usuario_id UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  amigo_id UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (usuario_id, amigo_id),
  CHECK (usuario_id < amigo_id)
);

ALTER TABLE public.amistades ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "amistades_select_propio"
  ON public.amistades;
CREATE POLICY "amistades_select_propio"
  ON public.amistades FOR SELECT
  USING (auth.uid() = usuario_id OR auth.uid() = amigo_id);

DROP POLICY IF EXISTS "amistades_delete_propio"
  ON public.amistades;
CREATE POLICY "amistades_delete_propio"
  ON public.amistades FOR DELETE
  USING (auth.uid() = usuario_id OR auth.uid() = amigo_id);

CREATE OR REPLACE FUNCTION public.crear_chat_juntada()
RETURNS TRIGGER AS $$
DECLARE
  chat_id_juntada UUID;
BEGIN
  SELECT id INTO chat_id_juntada
  FROM public.chats
  WHERE juntada_id = NEW.id AND es_grupal = TRUE
  LIMIT 1;

  IF chat_id_juntada IS NULL THEN
    INSERT INTO public.chats (juntada_id, es_grupal, titulo)
    VALUES (NEW.id, TRUE, NEW.titulo)
    RETURNING id INTO chat_id_juntada;
  END IF;

  INSERT INTO public.chat_participantes (chat_id, usuario_id)
  VALUES (chat_id_juntada, NEW.organizador_id)
  ON CONFLICT (chat_id, usuario_id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trigger_chat_al_crear_juntada
  ON public.juntadas;
CREATE TRIGGER trigger_chat_al_crear_juntada
  AFTER INSERT ON public.juntadas
  FOR EACH ROW EXECUTE FUNCTION public.crear_chat_juntada();

INSERT INTO public.chats (juntada_id, es_grupal, titulo)
SELECT j.id, TRUE, j.titulo
FROM public.juntadas j
WHERE NOT EXISTS (
  SELECT 1 FROM public.chats c
  WHERE c.juntada_id = j.id AND c.es_grupal = TRUE
);

CREATE OR REPLACE FUNCTION public.agregar_amigo(p_amigo_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  uid UUID := auth.uid();
  primer_usuario UUID;
  segundo_usuario UUID;
  filas_insertadas INT;
BEGIN
  IF uid IS NULL OR p_amigo_id IS NULL OR uid = p_amigo_id THEN
    RAISE EXCEPTION 'Usuario inválido';
  END IF;

  IF uid < p_amigo_id THEN
    primer_usuario := uid;
    segundo_usuario := p_amigo_id;
  ELSE
    primer_usuario := p_amigo_id;
    segundo_usuario := uid;
  END IF;

  INSERT INTO public.amistades (usuario_id, amigo_id)
  VALUES (primer_usuario, segundo_usuario)
  ON CONFLICT DO NOTHING;

  GET DIAGNOSTICS filas_insertadas = ROW_COUNT;
  RETURN filas_insertadas = 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.agregar_a_chat_juntada()
RETURNS TRIGGER AS $$
DECLARE
  chat_id_juntada UUID;
BEGIN
  SELECT id INTO chat_id_juntada
  FROM public.chats
  WHERE juntada_id = NEW.juntada_id AND es_grupal = TRUE
  LIMIT 1;

  IF chat_id_juntada IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.estado = 'confirmado' THEN
    INSERT INTO public.chat_participantes (chat_id, usuario_id)
    VALUES (chat_id_juntada, NEW.usuario_id)
    ON CONFLICT (chat_id, usuario_id) DO NOTHING;
  ELSE
    DELETE FROM public.chat_participantes
    WHERE chat_id = chat_id_juntada AND usuario_id = NEW.usuario_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trigger_agregar_chat_al_unirse
  ON public.participantes;
CREATE TRIGGER trigger_agregar_chat_al_unirse
  AFTER INSERT OR UPDATE ON public.participantes
  FOR EACH ROW EXECUTE FUNCTION public.agregar_a_chat_juntada();

INSERT INTO public.chat_participantes (chat_id, usuario_id)
SELECT c.id, j.organizador_id
FROM public.juntadas j
JOIN public.chats c ON c.juntada_id = j.id AND c.es_grupal = TRUE
ON CONFLICT (chat_id, usuario_id) DO NOTHING;

INSERT INTO public.chat_participantes (chat_id, usuario_id)
SELECT c.id, p.usuario_id
FROM public.participantes p
JOIN public.chats c ON c.juntada_id = p.juntada_id AND c.es_grupal = TRUE
WHERE p.estado = 'confirmado'
ON CONFLICT (chat_id, usuario_id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.obtener_participantes_chat(p_chat_id UUID)
RETURNS TABLE (
  usuario_id UUID,
  nombre TEXT,
  apellido TEXT,
  foto_perfil_url TEXT
) AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.chat_participantes cp
    WHERE cp.chat_id = p_chat_id AND cp.usuario_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

  RETURN QUERY
  SELECT u.id, u.nombre, u.apellido, u.foto_perfil_url
  FROM public.chat_participantes cp
  JOIN public.usuarios u ON u.id = cp.usuario_id
  WHERE cp.chat_id = p_chat_id
  ORDER BY u.nombre, u.apellido;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.obtener_o_crear_chat_directo(
  p_otro_usuario_id UUID
)
RETURNS UUID AS $$
DECLARE
  uid UUID := auth.uid();
  chat_id_directo UUID;
BEGIN
  IF uid IS NULL OR p_otro_usuario_id IS NULL OR uid = p_otro_usuario_id THEN
    RAISE EXCEPTION 'Usuario inválido';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.chat_participantes propio
    JOIN public.chat_participantes otro ON otro.chat_id = propio.chat_id
    JOIN public.chats c ON c.id = propio.chat_id AND c.es_grupal = TRUE
    WHERE propio.usuario_id = uid
      AND otro.usuario_id = p_otro_usuario_id
  ) THEN
    RAISE EXCEPTION 'Los usuarios no comparten una juntada';
  END IF;

  SELECT c.id INTO chat_id_directo
  FROM public.chats c
  WHERE c.es_grupal = FALSE
    AND EXISTS (
      SELECT 1 FROM public.chat_participantes cp
      WHERE cp.chat_id = c.id AND cp.usuario_id = uid
    )
    AND EXISTS (
      SELECT 1 FROM public.chat_participantes cp
      WHERE cp.chat_id = c.id AND cp.usuario_id = p_otro_usuario_id
    )
    AND 2 = (
      SELECT COUNT(*) FROM public.chat_participantes cp
      WHERE cp.chat_id = c.id
    )
  LIMIT 1;

  IF chat_id_directo IS NULL THEN
    INSERT INTO public.chats (es_grupal) VALUES (FALSE)
    RETURNING id INTO chat_id_directo;

    INSERT INTO public.chat_participantes (chat_id, usuario_id)
    VALUES
      (chat_id_directo, uid),
      (chat_id_directo, p_otro_usuario_id);
  END IF;

  RETURN chat_id_directo;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.agregar_amigo(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.obtener_participantes_chat(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.obtener_o_crear_chat_directo(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.agregar_amigo(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.obtener_participantes_chat(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.obtener_o_crear_chat_directo(UUID) TO authenticated;