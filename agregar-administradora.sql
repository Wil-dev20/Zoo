-- Asigna el rol de administradora a esta dirección solo después de confirmar el correo.
-- Si la cuenta ya existe y está confirmada, la agrega de inmediato.
create or replace function public.zv_auto_grant_designated_admin()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if tg_op = 'UPDATE' then
    if new.email is not distinct from old.email
       and new.email_confirmed_at is not distinct from old.email_confirmed_at then
      return new;
    end if;
  end if;

  if lower(coalesce(new.email, '')) = lower('61402102@continental.edu.pe')
     and new.email_confirmed_at is not null then
    insert into public.admins(user_id, role)
    values (new.id, 'admin')
    on conflict (user_id) do update set role = excluded.role;
  end if;

  return new;
end;
$function$;

revoke all on function public.zv_auto_grant_designated_admin() from public, anon, authenticated;
drop trigger if exists zv_auto_grant_designated_admin on auth.users;
create trigger zv_auto_grant_designated_admin
after insert or update on auth.users
for each row execute function public.zv_auto_grant_designated_admin();

insert into public.admins(user_id, role)
select id, 'admin'
from auth.users
where lower(email) = lower('61402102@continental.edu.pe')
  and email_confirmed_at is not null
on conflict (user_id) do update set role = excluded.role;
