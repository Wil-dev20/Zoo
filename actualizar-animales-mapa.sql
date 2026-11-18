-- Añade al catálogo los animales compartidos para el mapa interactivo.
-- Ejecutar después de supabase-setup.sql en Supabase SQL Editor.
-- La especie exacta, dieta y ubicación del recinto deben validarse con el zoológico.
insert into public.animales(slug,name,species,description,food,habitat,fact,estado_datos) values
('zorro','Zorro','Zorro (especie por confirmar)','Ficha educativa general; confirmar especie y datos del ejemplar.','Omnívoro','Diversos ecosistemas','Los zorros se adaptan a distintos ambientes.','Pendiente de validación'),('buho','Búho','Búho (especie por confirmar)','Ficha educativa general; confirmar especie y datos del ejemplar.','Carnívoro','Bosques y zonas arboladas','Los búhos tienen una audición muy desarrollada.','Pendiente de validación'),
('coati','Coatí','Coatí (especie por confirmar)','Ficha educativa general; confirmar especie y datos del ejemplar.','Omnívoro','Bosques de América','El coatí busca alimento con su hocico alargado.','Pendiente de validación'),
('halcon','Halcón','Halcón (especie por confirmar)','Ficha educativa general; confirmar especie y datos del ejemplar.','Carnívoro','Bosques, montañas y campos','Los halcones son aves rapaces de vuelo veloz.','Pendiente de validación'),
('loro','Loro','Loro (especie por confirmar)','Ficha educativa general; confirmar especie y datos del ejemplar.','Frutas, semillas y brotes','Bosques tropicales','Los loros tienen un pico fuerte para abrir semillas.','Pendiente de validación'),
('perdiz','Perdiz','Perdiz (especie por confirmar)','Ficha educativa general; confirmar especie y datos del ejemplar.','Semillas e insectos','Matorrales y pastizales','Las perdices suelen desplazarse por el suelo.','Pendiente de validación'),
('perezoso','Perezoso','Perezoso (especie por confirmar)','Ficha educativa general; confirmar especie y datos del ejemplar.','Hojas','Bosques tropicales','El perezoso se mueve lentamente y pasa mucho tiempo en los árboles.','Pendiente de validación'),
('puma','Puma','Puma','Ficha educativa general; confirmar datos del ejemplar.','Carnívoro','Montañas, bosques y otros ambientes','El puma es un felino americano que se adapta a varios ambientes.','Pendiente de validación'),
('serpiente','Serpiente','Serpiente (especie por confirmar)','Ficha educativa general; confirmar especie y datos del ejemplar.','Carnívora','Diversos ambientes terrestres','Las serpientes perciben vibraciones del suelo y mudan su piel.','Pendiente de validación'),
('tortuga','Tortuga','Tortuga (especie por confirmar)','Ficha educativa general; confirmar especie y datos del ejemplar.','Variable según la especie','Ambientes terrestres o acuáticos según la especie','El caparazón de la tortuga forma parte de su esqueleto.','Pendiente de validación'),
('vicuna','Vicuña','Vicuña','Ficha educativa general; confirmar datos del ejemplar.','Pastos altoandinos','Puna altoandina','La vicuña está adaptada a las alturas andinas.','Pendiente de validación')
on conflict(name) do update set slug=excluded.slug,species=excluded.species,description=excluded.description,food=excluded.food,habitat=excluded.habitat,fact=excluded.fact,estado_datos=excluded.estado_datos;

with q as (
  select id as animal_id,name,habitat,food,fact
  from public.animales
  where slug in ('zorro','buho','coati','halcon','loro','perdiz','perezoso','puma','serpiente','tortuga','vicuna')
)
insert into public.preguntas(animal_id,pregunta,opcion_a,opcion_b,opcion_c,respuesta_correcta,retroalimentacion,question_order)
select q.animal_id,x.pregunta,x.a,x.b,x.c,'A',x.feedback,x.ord
from q cross join lateral(values
  (1,'¿Qué dato describe al '||q.name||'?',q.fact,'Vive siempre bajo el agua','No necesita alimento','Dato educativo: '||q.fact),
  (2,'¿Qué alimentación corresponde al '||q.name||'?',q.food,'Solo piedras','Solo agua','La alimentación indicada es '||q.food||'.'),
  (3,'¿Cuál es el hábitat general del '||q.name||'?',q.habitat,'El océano polar','Un arrecife coralino','El hábitat indicado es '||q.habitat||'.')
) as x(ord,pregunta,a,b,c,feedback)
on conflict(animal_id,pregunta) do nothing;
