-- Tres niveles progresivos y canje de una entrada QR unica por visita.
-- Ejecutar despues de supabase-setup.sql y mejorar-quiz-puntos.sql.

create table if not exists public.quiz_progreso (
  user_id uuid not null references auth.users(id) on delete cascade,
  animal_id uuid not null references public.animales(id) on delete cascade,
  highest_level smallint not null default 0 check (highest_level between 0 and 3),
  active_level smallint check (active_level between 1 and 3),
  last_quiz_on date,
  completed boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (user_id, animal_id)
);

alter table public.quiz_progreso enable row level security;
drop policy if exists quiz_progress_owner_read on public.quiz_progreso;
create policy quiz_progress_owner_read on public.quiz_progreso
  for select to authenticated using (user_id = (select auth.uid()) or (select private.is_app_admin()));
revoke all on public.quiz_progreso from anon, authenticated;
grant select on public.quiz_progreso to authenticated;

-- Archiva las preguntas antiguas una sola vez, conserva respuestas y permite
-- que el nuevo banco empiece limpio sin borrar puntajes ni historial.
alter table public.preguntas add column if not exists bank_version smallint not null default 0;
insert into public.quiz_progreso(user_id,animal_id,highest_level,last_quiz_on)
select r.visitor_id,q.animal_id,1,
  max((r.answered_at at time zone 'America/Lima')::date)
from public.respuestas r join public.preguntas q on q.id=r.question_id
where q.question_order between 1 and 5
group by r.visitor_id,q.animal_id
having count(distinct q.id)>=5
on conflict(user_id,animal_id) do nothing;
update public.preguntas set active=false,question_order=null,
  pregunta='[Histórica] '||pregunta
where question_order between 1 and 5 and bank_version=0;

create table if not exists public.entradas_escaneadas (
  ticket_hash text primary key,
  visitor_id uuid references auth.users(id) on delete set null,
  redeemed_at timestamptz not null default now(),
  points integer not null default 25
);
alter table public.entradas_escaneadas enable row level security;
revoke all on public.entradas_escaneadas from anon, authenticated;

alter table public.preguntas add column if not exists difficulty_level smallint not null default 1;
update public.preguntas set difficulty_level = case
  when question_order between 1 and 5 then 1
  when question_order between 6 and 10 then 2
  when question_order between 11 and 15 then 3
  else 1 end;

-- Completa un cuestionario diario del siguiente nivel; si se interrumpio hoy,
-- permite reanudar el mismo nivel, pero no abrir otro cuestionario ese dia.
create or replace function public.zv_start_animal_quiz(p_animal_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  today date := (now() at time zone 'America/Lima')::date;
  p public.quiz_progreso%rowtype;
  lvl smallint;
  q_count integer;
begin
  if uid is null then raise exception 'authentication required'; end if;
  if not exists (select 1 from public.animales a where a.id=p_animal_id and a.is_active) then
    raise exception 'animal unavailable';
  end if;
  insert into public.quiz_progreso(user_id,animal_id)
  values(uid,p_animal_id) on conflict(user_id,animal_id) do nothing;
  select * into p from public.quiz_progreso
  where user_id=uid and animal_id=p_animal_id for update;
  if p.completed or p.highest_level >= 3 then
    return jsonb_build_object('can_play',false,'completed',true,'highest_level',3);
  end if;
  if p.last_quiz_on=today then
    if p.active_level is not null then
      return jsonb_build_object('can_play',true,'resume',true,'level',p.active_level,'highest_level',p.highest_level);
    end if;
    return jsonb_build_object('can_play',false,'completed',false,'played_today',true,'highest_level',p.highest_level);
  end if;
  lvl := p.highest_level + 1;
  select count(*) into q_count from public.preguntas q
  where q.animal_id=p_animal_id and q.active
    and q.question_order between ((lvl-1)*5+1) and (lvl*5);
  if q_count < 5 then raise exception 'quiz level not configured'; end if;
  update public.quiz_progreso set active_level=lvl,last_quiz_on=today,updated_at=now()
  where user_id=uid and animal_id=p_animal_id;
  return jsonb_build_object('can_play',true,'resume',false,'level',lvl,'highest_level',p.highest_level);
end;
$$;

create or replace function public.zv_submit_level_answer(p_question_id uuid,p_option char,p_level smallint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  today date := (now() at time zone 'America/Lima')::date;
  q record;
  is_right boolean;
  inserted_count integer;
begin
  if uid is null then raise exception 'authentication required'; end if;
  select id,animal_id,respuesta_correcta,question_order into q
  from public.preguntas where id=p_question_id and active;
  if q.id is null then raise exception 'question unavailable'; end if;
  if q.question_order < ((p_level-1)*5+1) or q.question_order > (p_level*5) then
    raise exception 'question level mismatch';
  end if;
  if not exists (select 1 from public.quiz_progreso p where p.user_id=uid and p.animal_id=q.animal_id
      and p.active_level=p_level and p.last_quiz_on=today and not p.completed) then
    raise exception 'daily quiz unavailable';
  end if;
  is_right := upper(p_option)=q.respuesta_correcta;
  insert into public.respuestas(visitor_id,question_id,is_correct)
  values(uid,p_question_id,is_right) on conflict(visitor_id,question_id) do nothing;
  get diagnostics inserted_count = row_count;
  if inserted_count=1 then
    insert into public.progreso_visitantes(user_id) values(uid) on conflict(user_id) do nothing;
    update public.progreso_visitantes set answered_questions=answered_questions+1,
      correct_answers=correct_answers+(case when is_right then 1 else 0 end),
      points=points+(case when is_right then 10 else 0 end),updated_at=now()
    where user_id=uid;
  end if;
  return jsonb_build_object('is_correct',is_right,'already_answered',inserted_count=0,
      'correct_option',q.respuesta_correcta);
end;
$$;

create or replace function public.zv_complete_animal_quiz(p_animal_id uuid,p_level smallint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  today date := (now() at time zone 'America/Lima')::date;
  answered_count integer;
  finished boolean;
begin
  if uid is null then raise exception 'authentication required'; end if;
  if p_level not between 1 and 3 then raise exception 'invalid quiz level'; end if;
  if not exists (select 1 from public.quiz_progreso p where p.user_id=uid and p.animal_id=p_animal_id
      and p.active_level=p_level and p.last_quiz_on=today and not p.completed) then
    raise exception 'daily quiz unavailable';
  end if;
  select count(*) into answered_count from public.respuestas r
  join public.preguntas q on q.id=r.question_id
  where r.visitor_id=uid and q.animal_id=p_animal_id
    and q.question_order between ((p_level-1)*5+1) and (p_level*5);
  if answered_count < 5 then raise exception 'answer all quiz questions first'; end if;
  finished := p_level=3;
  update public.quiz_progreso set highest_level=p_level,active_level=null,completed=finished,updated_at=now()
  where user_id=uid and animal_id=p_animal_id;
  return jsonb_build_object('completed',finished,'highest_level',p_level);
end;
$$;

-- Un codigo QR distinto por entrada: el mismo ticket solo se canjea una vez.
create or replace function public.zv_redeem_ticket(p_qr_code text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  ticket_key text;
  inserted_count integer;
  ticket_points integer := 25;
begin
  if uid is null then raise exception 'authentication required'; end if;
  if p_qr_code is null or length(trim(p_qr_code)) < 4 or length(trim(p_qr_code)) > 4096 then
    raise exception 'invalid ticket qr';
  end if;
  ticket_key := md5(trim(p_qr_code));
  insert into public.entradas_escaneadas(ticket_hash,visitor_id,points)
  values(ticket_key,uid,ticket_points) on conflict(ticket_hash) do nothing;
  get diagnostics inserted_count = row_count;
  if inserted_count=0 then return jsonb_build_object('redeemed',false,'points',0,'reason','already_used'); end if;
  insert into public.progreso_visitantes(user_id) values(uid) on conflict(user_id) do nothing;
  update public.progreso_visitantes set points=points+ticket_points,updated_at=now() where user_id=uid;
  return jsonb_build_object('redeemed',true,'points',ticket_points);
end;
$$;

revoke all on function public.zv_start_animal_quiz(uuid) from public,anon;
revoke all on function public.zv_submit_level_answer(uuid,char,smallint) from public,anon;
revoke all on function public.zv_complete_animal_quiz(uuid,smallint) from public,anon;
revoke all on function public.zv_redeem_ticket(text) from public,anon;
grant execute on function public.zv_start_animal_quiz(uuid) to authenticated;
grant execute on function public.zv_submit_level_answer(uuid,char,smallint) to authenticated;
grant execute on function public.zv_complete_animal_quiz(uuid,smallint) to authenticated;
grant execute on function public.zv_redeem_ticket(text) to authenticated;
revoke execute on function public.zv_submit_answer(uuid,char) from authenticated;

-- Add ten new questions per active species for levels 2 and 3 (orders 6-15).
with source as (
  select a.id,a.name,coalesce(nullif(a.food,''),'dieta segun la especie') food,
    coalesce(nullif(a.habitat,''),'habitat segun la especie') habitat,
    coalesce(nullif(a.fact,''),'Cada especie tiene rasgos propios.') fact,
    case when a.slug in ('condor','buho','halcon','loro','perdiz') then 'Ave'
      when a.slug in ('serpiente','tortuga') then 'Reptil' else 'Mamífero' end animal_group
  from public.animales a where a.is_active
), bank as (
  select s.id animal_id,v.question_order,v.pregunta,v.opcion_a,v.opcion_b,v.opcion_c,v.feedback
  from source s cross join lateral (values
    (1,'¿Qué dato describe a '||s.name||'?',s.fact,'Tiene hojas en vez de órganos.','Es una especie que vive fuera del planeta.',s.fact),
    (2,'¿Cuál es la alimentación general de '||s.name||'?',s.food,'Se alimenta de rocas.','No necesita comer ni beber.','La dieta puede variar según la especie y el ejemplar.'),
    (3,'¿Qué ambiente se asocia con '||s.name||'?',s.habitat,'Un arrecife coralino.','La superficie lunar.','El hábitat puede variar según la especie y el ejemplar.'),
    (4,'¿Cómo debemos observar a '||s.name||' de manera segura?','Mirar a distancia y seguir las indicaciones.','Darle comida sin autorización.','Tocar o molestar al animal.','Mantener distancia y seguir las indicaciones protege a los animales y visitantes.'),
    (5,'¿A qué grupo zoológico pertenece '||s.name||'?',s.animal_group,
      case when s.animal_group='Ave' then 'Mamífero' else 'Ave' end,
      case when s.animal_group='Reptil' then 'Mamífero' else 'Reptil' end,
      'Este animal pertenece al grupo '||s.animal_group||'.'),
    (6,'Un cuidador prepara la dieta de '||s.name||'. ¿Qué opción coincide con su ficha?',s.food,s.habitat,'No necesita alimento','La ficha indica una alimentación general: '||s.food||'.'),
    (7,'¿Cuál descripción del lugar donde vive '||s.name||' coincide con su ficha?',s.habitat,'La superficie lunar','Un arrecife coralino','Su hábitat general registrado es: '||s.habitat||'.'),
    (8,'¿Qué rasgo elegirías para reconocer a '||s.name||'?',s.fact,'No necesita cuidados ni alimentación.','Todas las especies comparten el mismo hábitat.',s.fact),
    (9,'¿Qué combinación resume mejor la ficha de '||s.name||'?',s.food||' · '||s.habitat,'Carnívoro · superficie lunar','No come · arrecife coralino','La ficha relaciona su alimentación y su hábitat.'),
    (10,'Un visitante quiere ayudar a '||s.name||'. ¿Qué acción es adecuada?','Observar a distancia y seguir las indicaciones.','Ofrecerle comida por cuenta propia.','Intentar tocarlo para llamar su atención.','El equipo cuidador define la alimentación y el manejo del recinto.'),
    (11,'En una ficha de cuidado de '||s.name||', ¿qué combinación respeta los datos registrados?','Dieta: '||s.food||'; ambiente: '||s.habitat,'Dieta: rocas; ambiente: la Luna','Sin dieta; ambiente: cualquier lugar','Las necesidades deben basarse en la información de la especie y del ejemplar.'),
    (12,'¿Qué conclusión está respaldada por el dato sobre '||s.name||'?',s.fact,'No necesita cuidadores.','Puede vivir sin su hábitat.',s.fact),
    (13,'¿Quién debe definir qué alimento recibe '||s.name||'?','El equipo cuidador, según sus necesidades.','Cada visitante, con cualquier alimento.','Nadie; no necesita una dieta.','No se debe alimentar a los animales sin autorización del equipo del zoológico.'),
    (14,'¿Qué par de datos ayuda a identificar a '||s.name||' en esta ficha?',s.animal_group||' · '||s.habitat,'Ave marina · arrecife coralino','Reptil polar · hielo','Clasificación y hábitat ayudan a describir una especie.'),
    (15,'Si la ficha no identifica al ejemplar de '||s.name||' con más detalle, ¿qué es responsable hacer?','Confirmar los detalles con el zoológico.','Adivinar su edad y procedencia.','Aplicar datos de otra especie.','Los datos específicos del ejemplar deben ser confirmados por el zoológico.')
  ) as v(question_order,pregunta,opcion_a,opcion_b,opcion_c,feedback)
)
insert into public.preguntas(animal_id,pregunta,opcion_a,opcion_b,opcion_c,respuesta_correcta,retroalimentacion,question_order,difficulty_level,bank_version)
select animal_id,pregunta,opcion_a,opcion_b,opcion_c,'A',feedback,question_order,
  case when question_order between 1 and 5 then 1
       when question_order between 6 and 10 then 2 else 3 end,1
from bank
on conflict (animal_id,question_order) do update set
  pregunta=excluded.pregunta,opcion_a=excluded.opcion_a,opcion_b=excluded.opcion_b,
  opcion_c=excluded.opcion_c,respuesta_correcta='A',retroalimentacion=excluded.retroalimentacion,
  difficulty_level=excluded.difficulty_level,bank_version=1,active=true;

-- El conjunto basico tambien debe figurar en el nivel 1.
update public.preguntas set difficulty_level=1 where question_order between 1 and 5;
