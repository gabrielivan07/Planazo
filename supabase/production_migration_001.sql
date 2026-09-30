-- Planazo production migration 001
-- Apply after schema.sql, rls_policies.sql and funciones_auxiliares.sql.

CREATE TABLE IF NOT EXISTS public.reportes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reportante_id UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  usuario_id UUID REFERENCES public.usuarios(id) ON DELETE SET NULL,
  juntada_id UUID REFERENCES public.juntadas(id) ON DELETE SET NULL,
  mensaje_id UUID REFERENCES public.mensajes(id) ON DELETE SET NULL,
  motivo TEXT NOT NULL CHECK (char_length(motivo) BETWEEN 3 AND 80),
  detalle TEXT CHECK (detalle IS NULL OR char_length(detalle) <= 1000),
  estado TEXT NOT NULL DEFAULT 'pendiente'
    CHECK (estado IN ('pendiente', 'en_revision', 'resuelto', 'descartado')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT reporte_un_solo_destino CHECK (
    (usuario_id IS NOT NULL)::int +
    (juntada_id IS NOT NULL)::int +
    (mensaje_id IS NOT NULL)::int = 1
  )
);

CREATE INDEX IF NOT EXISTS idx_reportes_estado ON public.reportes(estado);
CREATE INDEX IF NOT EXISTS idx_reportes_reportante ON public.reportes(reportante_id);

ALTER TABLE public.reportes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "reportes_insert_propio" ON public.reportes;
CREATE POLICY "reportes_insert_propio"
  ON public.reportes FOR INSERT
  WITH CHECK (auth.uid() = reportante_id);

DROP POLICY IF EXISTS "reportes_select_propio" ON public.reportes;
CREATE POLICY "reportes_select_propio"
  ON public.reportes FOR SELECT
  USING (auth.uid() = reportante_id);

DROP POLICY IF EXISTS "reportes_no_update_cliente" ON public.reportes;
CREATE POLICY "reportes_no_update_cliente"
  ON public.reportes FOR UPDATE
  USING (FALSE);

DROP POLICY IF EXISTS "reportes_no_delete" ON public.reportes;
CREATE POLICY "reportes_no_delete"
  ON public.reportes FOR DELETE
  USING (FALSE);

CREATE TABLE IF NOT EXISTS public.push_tokens (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  usuario_id UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  plataforma TEXT NOT NULL CHECK (plataforma IN ('android', 'ios', 'web', 'otro')),
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (usuario_id, token)
);

CREATE INDEX IF NOT EXISTS idx_push_tokens_usuario ON public.push_tokens(usuario_id);
ALTER TABLE public.push_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "push_tokens_select_propio" ON public.push_tokens;
CREATE POLICY "push_tokens_select_propio"
  ON public.push_tokens FOR SELECT
  USING (auth.uid() = usuario_id);

DROP POLICY IF EXISTS "push_tokens_insert_propio" ON public.push_tokens;
CREATE POLICY "push_tokens_insert_propio"
  ON public.push_tokens FOR INSERT
  WITH CHECK (auth.uid() = usuario_id);

DROP POLICY IF EXISTS "push_tokens_update_propio" ON public.push_tokens;
CREATE POLICY "push_tokens_update_propio"
  ON public.push_tokens FOR UPDATE
  USING (auth.uid() = usuario_id)
  WITH CHECK (auth.uid() = usuario_id);

DROP POLICY IF EXISTS "push_tokens_delete_propio" ON public.push_tokens;
CREATE POLICY "push_tokens_delete_propio"
  ON public.push_tokens FOR DELETE
  USING (auth.uid() = usuario_id);

CREATE OR REPLACE FUNCTION public.eliminar_mi_cuenta()
RETURNS VOID AS $$
DECLARE
  uid UUID := auth.uid();
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'No hay una sesión activa';
  END IF;

  DELETE FROM auth.users WHERE id = uid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

REVOKE ALL ON FUNCTION public.eliminar_mi_cuenta() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.eliminar_mi_cuenta() TO authenticated;

CREATE OR REPLACE FUNCTION public.upsert_mi_push_token(
  p_token TEXT,
  p_plataforma TEXT
)
RETURNS VOID AS $$
BEGIN
  IF auth.uid() IS NULL OR p_token IS NULL OR char_length(trim(p_token)) < 10 THEN
    RAISE EXCEPTION 'Token inválido';
  END IF;

  INSERT INTO public.push_tokens (usuario_id, token, plataforma, activo)
  VALUES (auth.uid(), trim(p_token), p_plataforma, TRUE)
  ON CONFLICT (usuario_id, token)
  DO UPDATE SET activo = TRUE, plataforma = EXCLUDED.plataforma,
                updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.upsert_mi_push_token(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.upsert_mi_push_token(TEXT, TEXT) TO authenticated;
