-- PLANAZO: reparar la relación de participantes de chats
-- Ejecutar una vez en Supabase SQL Editor si aparece:
-- relation "public.chat_participantes" does not exist

CREATE TABLE IF NOT EXISTS public.chat_participantes (
  chat_id     UUID NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
  usuario_id  UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  joined_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (chat_id, usuario_id)
);

CREATE INDEX IF NOT EXISTS idx_chat_participantes_usuario
  ON public.chat_participantes(usuario_id);
CREATE INDEX IF NOT EXISTS idx_chat_participantes_chat
  ON public.chat_participantes(chat_id);

ALTER TABLE public.chat_participantes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "chat_participantes_select_propio"
  ON public.chat_participantes;
CREATE POLICY "chat_participantes_select_propio"
  ON public.chat_participantes FOR SELECT
  USING (auth.uid() = usuario_id);

DROP POLICY IF EXISTS "chat_participantes_no_insert_direct"
  ON public.chat_participantes;
CREATE POLICY "chat_participantes_no_insert_direct"
  ON public.chat_participantes FOR INSERT
  WITH CHECK (FALSE);

DROP POLICY IF EXISTS "chat_participantes_no_update"
  ON public.chat_participantes;
CREATE POLICY "chat_participantes_no_update"
  ON public.chat_participantes FOR UPDATE
  USING (FALSE);

DROP POLICY IF EXISTS "chat_participantes_no_delete"
  ON public.chat_participantes;
CREATE POLICY "chat_participantes_no_delete"
  ON public.chat_participantes FOR DELETE
  USING (FALSE);
