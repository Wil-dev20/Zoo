-- Actualiza puntuación y preguntas sin borrar el progreso ya guardado.
-- Ejecutar en Supabase después de actualizar el catálogo de animales.
alter table public.progreso_visitantes
  add column if not exists tour_reward_claimed boolean not null default false;

-- Los recorridos ya completados antes de este bono cuentan como ya reclamados.
update public.progreso_visitantes
set tour_reward_claimed = true
where completed_tours > 0 and tour_reward_claimed = false;

-- Agrega las preguntas 4 y 5 a cada animal activo, sin duplicar respuestas previas.
insert into public.preguntas(animal_id,pregunta,opcion_a,opcion_b,opcion_c,respuesta_correcta,retroalimentacion,question_order)
select a.id,'¿Qué dato curioso se aplica al '||a.name||'?',coalesce(nullif(a.fact,''),'Cada especie tiene adaptaciones propias.'),'No necesita cuidados','Vive en el espacio','A','Dato curioso: '||coalesce(nullif(a.fact,''),'Cada especie tiene adaptaciones propias.'),4
from public.animales a
where a.is_active
  and not exists (select 1 from public.preguntas q where q.animal_id=a.id and q.question_order=4);

insert into public.preguntas(animal_id,pregunta,opcion_a,opcion_b,opcion_c,respuesta_correcta,retroalimentacion,question_order)
select a.id,'¿Cómo debemos comportarnos cerca del recinto de '||a.name||'?','Observar con calma y seguir las indicaciones','Golpear el vidrio','Dar comida sin autorización','A','Respetar las indicaciones ayuda a proteger a los animales y a las personas.',5
from public.animales a
where a.is_active
  and not exists (select 1 from public.preguntas q where q.animal_id=a.id and q.question_order=5);

create or replace function public.zv_record_visit(p_animal_id uuid)
returns boolean language plpgsql security definer set search_path=''
as $$
declare uid uuid := (select auth.uid()); n integer; slug_value text;
begin
  if uid is null then raise exception 'authentication required'; end if;
  select slug into slug_value from public.animales where id=p_animal_id and is_active;
  if slug_value is null then raise exception 'animal unavailable'; end if;
  insert into public.visitas_animales(visitor_id,animal_id,points)
  values(uid,p_animal_id,25) on conflict(visitor_id,animal_id) do nothing;
  get diagnostics n = row_count;
  if n=1 then
    insert into public.progreso_visitantes(user_id) values(uid) on conflict(user_id) do nothing;
    update public.progreso_visitantes
    set points=points+25,
        visited_animals=case when visited_animals ? slug_value then visited_animals else visited_animals || jsonb_build_array(slug_value) end,
        updated_at=now()
    where user_id=uid;
    return true;
  end if;
  return false;
end;
$$;

create or replace function public.zv_submit_answer(p_question_id uuid,p_option char)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare uid uuid := (select auth.uid()); correct char(1); is_right boolean; n integer;
begin
  if uid is null then raise exception 'authentication required'; end if;
  select q.respuesta_correcta into correct
  from public.preguntas q join public.animales a on a.id=q.animal_id
  where q.id=p_question_id and q.active and a.is_active;
  if correct is null then raise exception 'question unavailable'; end if;
  is_right := upper(p_option)=correct;
  insert into public.respuestas(visitor_id,question_id,is_correct)
  values(uid,p_question_id,is_right) on conflict(visitor_id,question_id) do nothing;
  get diagnostics n = row_count;
  if n=1 then
    insert into public.progreso_visitantes(user_id) values(uid) on conflict(user_id) do nothing;
    update public.progreso_visitantes
    set answered_questions=answered_questions+1,
        correct_answers=correct_answers+(case when is_right then 1 else 0 end),
        points=points+(case when is_right then 10 else 0 end),
        updated_at=now()
    where user_id=uid;
  end if;
  return jsonb_build_object('is_correct',is_right,'already_answered',n=0);
end;
$$;

create or replace function public.zv_finish_tour()
returns void language plpgsql security definer set search_path=''
as $$
declare uid uuid := (select auth.uid());
begin
  if uid is null then raise exception 'authentication required'; end if;
  insert into public.progreso_visitantes(user_id) values(uid) on conflict(user_id) do nothing;
  update public.progreso_visitantes
  set points=points+(case when tour_reward_claimed then 0 else 25 end),
      tour_reward_claimed=true,
      completed_tours=completed_tours+1,
      updated_at=now()
  where user_id=uid;
end;
$$;

revoke all on function public.zv_record_visit(uuid) from public;
revoke all on function public.zv_submit_answer(uuid,char) from public;
revoke all on function public.zv_finish_tour() from public;
grant execute on function public.zv_record_visit(uuid) to authenticated;
grant execute on function public.zv_submit_answer(uuid,char) to authenticated;
grant execute on function public.zv_finish_tour() to authenticated;
