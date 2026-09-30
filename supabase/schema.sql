-- ============================================================
-- PLANAZO — ESQUEMA DE BASE DE DATOS (PostgreSQL / Supabase)
-- Ejecutar en Supabase > SQL Editor
-- ============================================================

-- Habilitar la extensión de UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";   -- Para consultas geoespaciales reales

-- ============================================================
-- TABLA: usuarios
-- Extiende auth.users de Supabase Auth
-- ============================================================
CREATE TABLE public.usuarios (
  id                   UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nombre               TEXT        NOT NULL CHECK (char_length(nombre) BETWEEN 1 AND 50),
  apellido             TEXT        NOT NULL CHECK (char_length(apellido) BETWEEN 1 AND 50),
  telefono             TEXT,
  foto_perfil_url      TEXT,
  puntos_confianza     INT         NOT NULL DEFAULT 100 CHECK (puntos_confianza >= 0),
  intereses            TEXT[]      NOT NULL DEFAULT '{}',
  es_premium           BOOLEAN     NOT NULL DEFAULT FALSE,
  verificado           BOOLEAN     NOT NULL DEFAULT FALSE,
  dni_numero           TEXT,                -- Hasheado, nunca en texto plano
  fecha_nacimiento     DATE,
  ultima_lat           DOUBLE PRECISION,   -- Última ubicación conocida
  ultima_lng           DOUBLE PRECISION,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índices
CREATE INDEX idx_usuarios_verificado ON public.usuarios(verificado);
CREATE INDEX idx_usuarios_puntos     ON public.usuarios(puntos_confianza DESC);

-- Trigger: actualiza updated_at automáticamente
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_usuarios_updated_at
  BEFORE UPDATE ON public.usuarios
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Trigger: crea el perfil cuando el usuario se registra en Auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.usuarios (id, nombre, apellido)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'nombre', 'Usuario'),
    COALESCE(NULLIF(NEW.raw_user_meta_data->>'apellido', ''), 'Usuario')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- TABLA: juntadas
-- ============================================================
CREATE TABLE public.juntadas (
  id                   UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  titulo               TEXT        NOT NULL CHECK (char_length(titulo) BETWEEN 3 AND 100),
  descripcion          TEXT        NOT NULL CHECK (char_length(descripcion) BETWEEN 10 AND 1000),
  organizador_id       UUID        NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  fecha                TIMESTAMPTZ NOT NULL CHECK (fecha > NOW()),
  lugar                TEXT        NOT NULL CHECK (char_length(lugar) >= 5),
  lat                  DOUBLE PRECISION NOT NULL,
  lng                  DOUBLE PRECISION NOT NULL,
  barrio               TEXT,
  capacidad_maxima     INT         NOT NULL CHECK (capacidad_maxima BETWEEN 2 AND 200),
  categoria            TEXT        NOT NULL,
  etiquetas            TEXT[]      NOT NULL DEFAULT '{}',
  es_publica           BOOLEAN     NOT NULL DEFAULT TRUE,
  solo_verificados     BOOLEAN     NOT NULL DEFAULT FALSE,
  estado               TEXT        NOT NULL DEFAULT 'activa'
                                   CHECK (estado IN ('activa', 'cancelada', 'finalizada', 'pendiente')),
  imagen_url           TEXT,
  edad_minima          INT         CHECK (edad_minima >= 18),
  edad_maxima          INT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índices
CREATE INDEX idx_juntadas_organizador ON public.juntadas(organizador_id);
CREATE INDEX idx_juntadas_fecha       ON public.juntadas(fecha);
CREATE INDEX idx_juntadas_categoria   ON public.juntadas(categoria);
CREATE INDEX idx_juntadas_estado      ON public.juntadas(estado);
-- Índice geoespacial para búsquedas por distancia
CREATE INDEX idx_juntadas_geo ON public.juntadas USING GIST (
  ST_SetSRID(ST_MakePoint(lng, lat), 4326)
);

CREATE TRIGGER trigger_juntadas_updated_at
  BEFORE UPDATE ON public.juntadas
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- TABLA: participantes
-- Relación muchos-a-muchos entre usuarios y juntadas
-- ============================================================
CREATE TABLE public.participantes (
  juntada_id           UUID        NOT NULL REFERENCES public.juntadas(id) ON DELETE CASCADE,
  usuario_id           UUID        NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  estado               TEXT        NOT NULL DEFAULT 'confirmado'
                                   CHECK (estado IN ('confirmado', 'pendiente', 'cancelado')),
  joined_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (juntada_id, usuario_id)
);

CREATE INDEX idx_participantes_usuario  ON public.participantes(usuario_id);
CREATE INDEX idx_participantes_juntada  ON public.participantes(juntada_id);

-- Vista: juntadas con su count de participantes
CREATE OR REPLACE VIEW public.juntadas_con_participantes AS
SELECT
  j.*,
  u.nombre              AS organizador_nombre,
  u.apellido            AS organizador_apellido,
  u.foto_perfil_url     AS organizador_foto,
  u.verificado          AS organizador_verificado,
  COUNT(p.usuario_id)   AS participantes_count
FROM public.juntadas j
LEFT JOIN public.usuarios u  ON u.id = j.organizador_id
LEFT JOIN public.participantes p ON p.juntada_id = j.id AND p.estado = 'confirmado'
GROUP BY j.id, u.id;

-- ============================================================
-- TABLA: chats
-- Un chat por juntada (grupal) + chats directos 1:1
-- ============================================================
CREATE TABLE public.chats (
  id                   UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  juntada_id           UUID        REFERENCES public.juntadas(id) ON DELETE SET NULL,
  es_grupal            BOOLEAN     NOT NULL DEFAULT TRUE,
  titulo               TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_chats_juntada ON public.chats(juntada_id);

-- Participantes del chat
CREATE TABLE IF NOT EXISTS public.chat_participantes (
  chat_id              UUID        NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
  usuario_id           UUID        NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  joined_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (chat_id, usuario_id)
);

-- ============================================================
-- TABLA: mensajes
-- ============================================================
CREATE TABLE public.mensajes (
  id                   UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  chat_id              UUID        NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
  remitente_id         UUID        NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  contenido            TEXT        NOT NULL CHECK (char_length(contenido) BETWEEN 1 AND 2000),
  tipo                 TEXT        NOT NULL DEFAULT 'texto' CHECK (tipo IN ('texto', 'imagen', 'sistema')),
  imagen_url           TEXT,
  leido_por            UUID[]      NOT NULL DEFAULT '{}',
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_mensajes_chat      ON public.mensajes(chat_id);
CREATE INDEX idx_mensajes_remitente ON public.mensajes(remitente_id);
CREATE INDEX idx_mensajes_created   ON public.mensajes(created_at DESC);

-- ============================================================
-- TABLA: resenas
-- ============================================================
CREATE TABLE public.resenas (
  id                   UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  autor_id             UUID        NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  destinatario_id      UUID        NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  juntada_id           UUID        REFERENCES public.juntadas(id) ON DELETE SET NULL,
  puntuacion           NUMERIC(2,1) NOT NULL CHECK (puntuacion BETWEEN 1.0 AND 5.0),
  comentario           TEXT        NOT NULL CHECK (char_length(comentario) BETWEEN 5 AND 500),
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- Un usuario solo puede dejar una reseña por destinatario por juntada
  UNIQUE (autor_id, destinatario_id, juntada_id)
);

CREATE INDEX idx_resenas_destinatario ON public.resenas(destinatario_id);

-- ============================================================
-- TABLA: historial_puntos
-- Auditoría del sistema de confianza
-- ============================================================
CREATE TABLE public.historial_puntos (
  id                   UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  usuario_id           UUID        NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  cambio               INT         NOT NULL,          -- +20, -30, etc.
  motivo               TEXT        NOT NULL,
  juntada_id           UUID        REFERENCES public.juntadas(id),
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_historial_usuario ON public.historial_puntos(usuario_id);

-- ============================================================
-- FUNCIÓN: buscar juntadas por distancia (PostGIS)
-- ============================================================
CREATE OR REPLACE FUNCTION public.juntadas_cercanas(
  lat_usuario   DOUBLE PRECISION,
  lng_usuario   DOUBLE PRECISION,
  radio_km      DOUBLE PRECISION DEFAULT 10,
  limite        INT DEFAULT 50
)
RETURNS TABLE (
  id            UUID,
  titulo        TEXT,
  distancia_km  DOUBLE PRECISION
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    j.id,
    j.titulo,
    ST_Distance(
      ST_SetSRID(ST_MakePoint(j.lng, j.lat), 4326)::geography,
      ST_SetSRID(ST_MakePoint(lng_usuario, lat_usuario), 4326)::geography
    ) / 1000 AS distancia_km
  FROM public.juntadas j
  WHERE
    j.estado = 'activa'
    AND j.fecha > NOW()
    AND ST_DWithin(
      ST_SetSRID(ST_MakePoint(j.lng, j.lat), 4326)::geography,
      ST_SetSRID(ST_MakePoint(lng_usuario, lat_usuario), 4326)::geography,
      radio_km * 1000
    )
  ORDER BY distancia_km ASC
  LIMIT limite;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- TRIGGER: Sumar puntos al unirse a una juntada
-- ============================================================
CREATE OR REPLACE FUNCTION public.puntos_al_unirse()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.estado = 'confirmado' THEN
    UPDATE public.usuarios
    SET puntos_confianza = puntos_confianza + 5
    WHERE id = NEW.usuario_id;

    INSERT INTO public.historial_puntos (usuario_id, cambio, motivo, juntada_id)
    VALUES (NEW.usuario_id, 5, 'Se unió a una juntada', NEW.juntada_id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_puntos_unirse
  AFTER INSERT ON public.participantes
  FOR EACH ROW EXECUTE FUNCTION public.puntos_al_unirse();

-- ============================================================
-- TRIGGER: Crear chat grupal al crear una juntada
-- ============================================================
CREATE OR REPLACE FUNCTION public.crear_chat_juntada()
RETURNS TRIGGER AS $$
DECLARE
  nuevo_chat_id UUID;
BEGIN
  INSERT INTO public.chats (juntada_id, es_grupal, titulo)
  VALUES (NEW.id, TRUE, NEW.titulo)
  RETURNING id INTO nuevo_chat_id;

  -- El organizador es el primer participante del chat
  INSERT INTO public.chat_participantes (chat_id, usuario_id)
  VALUES (nuevo_chat_id, NEW.organizador_id);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_chat_al_crear_juntada
  AFTER INSERT ON public.juntadas
  FOR EACH ROW EXECUTE FUNCTION public.crear_chat_juntada();

-- ============================================================
-- TRIGGER: Agregar al chat cuando alguien se une a la juntada
-- ============================================================
CREATE OR REPLACE FUNCTION public.agregar_a_chat_juntada()
RETURNS TRIGGER AS $$
DECLARE
  chat_id_juntada UUID;
BEGIN
  IF NEW.estado = 'confirmado' THEN
    SELECT id INTO chat_id_juntada
    FROM public.chats
    WHERE juntada_id = NEW.juntada_id AND es_grupal = TRUE
    LIMIT 1;

    IF chat_id_juntada IS NOT NULL THEN
      INSERT INTO public.chat_participantes (chat_id, usuario_id)
      VALUES (chat_id_juntada, NEW.usuario_id)
      ON CONFLICT DO NOTHING;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_agregar_chat_al_unirse
  AFTER INSERT ON public.participantes
  FOR EACH ROW EXECUTE FUNCTION public.agregar_a_chat_juntada();
