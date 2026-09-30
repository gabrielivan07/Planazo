ALTER TABLE public.usuarios
  ALTER COLUMN puntos_confianza SET DEFAULT 0;

CREATE OR REPLACE FUNCTION public.validar_plan_juntada()
RETURNS TRIGGER AS $$
DECLARE
  uid UUID := auth.uid();
  es_premium_usuario BOOLEAN;
  cantidad_mes INT;
  inicio_mes TIMESTAMPTZ :=
    date_trunc('month', NOW() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC';
BEGIN
  IF uid IS NULL OR NEW.organizador_id <> uid THEN
    RAISE EXCEPTION 'No autorizado para crear esta juntada'
      USING ERRCODE = '42501';
  END IF;

  SELECT u.es_premium INTO es_premium_usuario
  FROM public.usuarios u
  WHERE u.id = uid;

  IF COALESCE(es_premium_usuario, FALSE) THEN
    RETURN NEW;
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(uid::TEXT, 0));

  SELECT COUNT(*) INTO cantidad_mes
  FROM public.juntadas j
  WHERE j.organizador_id = uid
    AND j.created_at >= inicio_mes
    AND j.created_at < inicio_mes + INTERVAL '1 month';

  IF cantidad_mes >= 3 THEN
    RAISE EXCEPTION 'El plan gratuito permite crear 3 juntadas por mes'
      USING ERRCODE = 'P0001';
  END IF;

  IF NEW.capacidad_maxima > 10 THEN
    RAISE EXCEPTION 'El plan gratuito permite hasta 10 personas por juntada'
      USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trigger_validar_plan_juntada ON public.juntadas;
CREATE TRIGGER trigger_validar_plan_juntada
  BEFORE INSERT ON public.juntadas
  FOR EACH ROW EXECUTE FUNCTION public.validar_plan_juntada();

REVOKE ALL ON FUNCTION public.validar_plan_juntada() FROM PUBLIC, anon, authenticated;

ALTER TABLE public.usuarios
  ADD COLUMN IF NOT EXISTS racha_puntual INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS ultima_asistencia_puntual DATE;

ALTER TABLE public.participantes
  ADD COLUMN IF NOT EXISTS asistencia TEXT NOT NULL DEFAULT 'pendiente';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'participantes_asistencia_valida'
      AND conrelid = 'public.participantes'::regclass
  ) THEN
    ALTER TABLE public.participantes
      ADD CONSTRAINT participantes_asistencia_valida
      CHECK (asistencia IN ('pendiente', 'puntual', 'tarde', 'ausente'));
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_participantes_asistencia
  ON public.participantes(juntada_id, asistencia);

DROP TRIGGER IF EXISTS trigger_puntos_unirse ON public.participantes;

CREATE OR REPLACE FUNCTION public.aplicar_puntaje_asistencia()
RETURNS TRIGGER AS $$
DECLARE
  organizador UUID;
  fecha_local DATE;
  racha_actual INT;
  ultima_fecha DATE;
  puntos INT;
BEGIN
  IF OLD.asistencia <> 'pendiente' OR NEW.asistencia = 'pendiente' THEN
    RETURN NEW;
  END IF;

  SELECT j.organizador_id,
         (j.fecha AT TIME ZONE 'America/Argentina/Buenos_Aires')::DATE
    INTO organizador, fecha_local
  FROM public.juntadas j
  WHERE j.id = NEW.juntada_id;

  IF NEW.asistencia = 'puntual' THEN
    SELECT u.racha_puntual, u.ultima_asistencia_puntual
      INTO racha_actual, ultima_fecha
    FROM public.usuarios u
    WHERE u.id = NEW.usuario_id;

    IF ultima_fecha IS NULL OR fecha_local > ultima_fecha + 1 THEN
      racha_actual := 1;
    ELSIF fecha_local = ultima_fecha + 1 THEN
      racha_actual := racha_actual + 1;
    END IF;

    puntos := CASE WHEN NEW.usuario_id = organizador THEN 12 ELSE 10 END;
    UPDATE public.usuarios
    SET puntos_confianza = puntos_confianza + puntos,
        racha_puntual = racha_actual,
        ultima_asistencia_puntual = GREATEST(ultima_fecha, fecha_local)
    WHERE id = NEW.usuario_id;

    INSERT INTO public.historial_puntos (usuario_id, cambio, motivo, juntada_id)
    VALUES (NEW.usuario_id, puntos, 'Asistencia puntual', NEW.juntada_id);

    IF fecha_local > COALESCE(ultima_fecha, DATE '0001-01-01')
       AND racha_actual > 0 AND MOD(racha_actual, 3) = 0 THEN
      UPDATE public.usuarios
      SET puntos_confianza = puntos_confianza + 2
      WHERE id = NEW.usuario_id;

      INSERT INTO public.historial_puntos (usuario_id, cambio, motivo, juntada_id)
      VALUES (NEW.usuario_id, 2, 'Racha de 3 asistencias puntuales', NEW.juntada_id);
    END IF;
  ELSE
    puntos := CASE WHEN NEW.asistencia = 'tarde' THEN -5 ELSE -30 END;
    UPDATE public.usuarios
    SET puntos_confianza = GREATEST(0, puntos_confianza + puntos),
        racha_puntual = 0,
        ultima_asistencia_puntual = NULL
    WHERE id = NEW.usuario_id;

    INSERT INTO public.historial_puntos (usuario_id, cambio, motivo, juntada_id)
    VALUES (
      NEW.usuario_id,
      puntos,
      CASE WHEN NEW.asistencia = 'tarde' THEN 'Llegada tarde' ELSE 'Ausencia' END,
      NEW.juntada_id
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trigger_puntaje_asistencia ON public.participantes;
CREATE TRIGGER trigger_puntaje_asistencia
  AFTER UPDATE OF asistencia ON public.participantes
  FOR EACH ROW EXECUTE FUNCTION public.aplicar_puntaje_asistencia();

CREATE OR REPLACE FUNCTION public.obtener_asistencia_juntada(p_juntada_id UUID)
RETURNS TABLE (
  usuario_id UUID,
  nombre TEXT,
  apellido TEXT,
  foto_perfil_url TEXT,
  asistencia TEXT
) AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.juntadas j
    WHERE j.id = p_juntada_id
      AND j.organizador_id = auth.uid()
      AND j.fecha <= NOW()
  ) THEN
    RAISE EXCEPTION 'Solo el anfitrión puede gestionar la asistencia al terminar la juntada';
  END IF;

  RETURN QUERY
  SELECT u.id, u.nombre, u.apellido, u.foto_perfil_url, p.asistencia
  FROM public.participantes p
  JOIN public.usuarios u ON u.id = p.usuario_id
  WHERE p.juntada_id = p_juntada_id AND p.estado = 'confirmado'
  ORDER BY u.nombre, u.apellido;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.marcar_asistencia_juntada(
  p_juntada_id UUID,
  p_usuario_id UUID,
  p_asistencia TEXT
)
RETURNS VOID AS $$
BEGIN
  IF p_asistencia NOT IN ('puntual', 'tarde', 'ausente') THEN
    RAISE EXCEPTION 'Estado de asistencia inválido';
  END IF;

  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.juntadas j
    WHERE j.id = p_juntada_id
      AND j.organizador_id = auth.uid()
      AND j.fecha <= NOW()
  ) THEN
    RAISE EXCEPTION 'Solo el anfitrión puede marcar la asistencia';
  END IF;

  UPDATE public.participantes
  SET asistencia = p_asistencia
  WHERE juntada_id = p_juntada_id
    AND usuario_id = p_usuario_id
    AND estado = 'confirmado'
    AND asistencia = 'pendiente';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'La asistencia ya fue marcada o el usuario no participa';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.penalizar_ausencias()
RETURNS VOID AS $$
BEGIN
  UPDATE public.participantes p
  SET asistencia = 'ausente'
  FROM public.juntadas j
  WHERE j.id = p.juntada_id
    AND p.estado = 'confirmado'
    AND p.asistencia = 'pendiente'
    AND j.fecha < NOW() - INTERVAL '48 hours';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.aplicar_puntaje_asistencia() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.obtener_asistencia_juntada(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.marcar_asistencia_juntada(UUID, UUID, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.penalizar_ausencias() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.obtener_asistencia_juntada(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.marcar_asistencia_juntada(UUID, UUID, TEXT) TO authenticated;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.schedule(
      'planazo-penalizar-ausencias',
      '0 3 * * *',
      'SELECT public.penalizar_ausencias();'
    );
  END IF;
END;
$$;

CREATE TABLE IF NOT EXISTS public.resenas_juntadas (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  juntada_id UUID NOT NULL REFERENCES public.juntadas(id) ON DELETE CASCADE,
  autor_id UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  puntuacion INT NOT NULL CHECK (puntuacion BETWEEN 1 AND 5),
  comentario TEXT NOT NULL CHECK (char_length(comentario) BETWEEN 5 AND 500),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (juntada_id, autor_id)
);

CREATE INDEX IF NOT EXISTS idx_resenas_juntadas_juntada
  ON public.resenas_juntadas(juntada_id, created_at DESC);

ALTER TABLE public.resenas_juntadas ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT ON public.resenas_juntadas TO authenticated;

DROP POLICY IF EXISTS "resenas_juntadas_select" ON public.resenas_juntadas;
CREATE POLICY "resenas_juntadas_select"
  ON public.resenas_juntadas FOR SELECT
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "resenas_juntadas_insert" ON public.resenas_juntadas;
CREATE POLICY "resenas_juntadas_insert"
  ON public.resenas_juntadas FOR INSERT
  WITH CHECK (
    auth.uid() = autor_id
    AND EXISTS (
      SELECT 1 FROM public.participantes p
      JOIN public.juntadas j ON j.id = p.juntada_id
      WHERE p.juntada_id = resenas_juntadas.juntada_id
        AND p.usuario_id = auth.uid()
        AND p.estado = 'confirmado'
        AND j.fecha <= NOW()
    )
  );

DROP POLICY IF EXISTS "resenas_insert" ON public.resenas;
CREATE POLICY "resenas_insert"
  ON public.resenas FOR INSERT
  WITH CHECK (
    auth.uid() = autor_id
    AND juntada_id IS NOT NULL
    AND autor_id <> destinatario_id
    AND EXISTS (
      SELECT 1 FROM public.participantes autor
      JOIN public.juntadas j ON j.id = autor.juntada_id
      JOIN public.participantes destinatario
        ON destinatario.juntada_id = autor.juntada_id
      WHERE autor.juntada_id = resenas.juntada_id
        AND autor.usuario_id = auth.uid()
        AND autor.estado = 'confirmado'
        AND destinatario.usuario_id = resenas.destinatario_id
        AND destinatario.estado = 'confirmado'
        AND j.fecha <= NOW()
    )
  );

CREATE OR REPLACE FUNCTION public.obtener_participantes_para_resena(
  p_juntada_id UUID
)
RETURNS TABLE (
  usuario_id UUID,
  nombre TEXT,
  apellido TEXT,
  foto_perfil_url TEXT
) AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.participantes p
    JOIN public.juntadas j ON j.id = p.juntada_id
    WHERE p.juntada_id = p_juntada_id
      AND p.usuario_id = auth.uid()
      AND p.estado = 'confirmado'
      AND j.fecha <= NOW()
  ) THEN
    RAISE EXCEPTION 'Solo participantes confirmados pueden reseñar una juntada finalizada';
  END IF;

  RETURN QUERY
  SELECT u.id, u.nombre, u.apellido, u.foto_perfil_url
  FROM public.participantes p
  JOIN public.usuarios u ON u.id = p.usuario_id
  WHERE p.juntada_id = p_juntada_id
    AND p.usuario_id <> auth.uid()
    AND p.estado = 'confirmado'
  ORDER BY u.nombre, u.apellido;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.puntuar_anfitrion_por_resena()
RETURNS TRIGGER AS $$
DECLARE
  anfitrion UUID;
  cambio INT;
BEGIN
  SELECT organizador_id INTO anfitrion
  FROM public.juntadas WHERE id = NEW.juntada_id;

  IF anfitrion IS NULL OR anfitrion = NEW.autor_id THEN
    RETURN NEW;
  END IF;

  cambio := CASE
    WHEN NEW.puntuacion >= 4 THEN 5
    WHEN NEW.puntuacion <= 2 THEN -5
    ELSE 0
  END;

  IF cambio <> 0 THEN
    UPDATE public.usuarios
    SET puntos_confianza = GREATEST(0, puntos_confianza + cambio)
    WHERE id = anfitrion;

    INSERT INTO public.historial_puntos (usuario_id, cambio, motivo, juntada_id)
    VALUES (
      anfitrion,
      cambio,
      CASE WHEN cambio > 0 THEN 'Reseña positiva de una juntada' ELSE 'Reseña negativa de una juntada' END,
      NEW.juntada_id
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trigger_puntuar_anfitrion_por_resena
  ON public.resenas_juntadas;
CREATE TRIGGER trigger_puntuar_anfitrion_por_resena
  AFTER INSERT ON public.resenas_juntadas
  FOR EACH ROW EXECUTE FUNCTION public.puntuar_anfitrion_por_resena();

REVOKE ALL ON FUNCTION public.obtener_participantes_para_resena(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.puntuar_anfitrion_por_resena() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.obtener_participantes_para_resena(UUID) TO authenticated;