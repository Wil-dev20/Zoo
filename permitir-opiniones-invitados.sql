-- Permite guardar opiniones de visitantes invitados sin cuenta.
-- Los invitados solo pueden insertar; no pueden leer opiniones ni datos personales.
alter table public.opiniones
  alter column visitor_id drop not null;

drop policy if exists opinions_guest_insert on public.opiniones;
create policy opinions_guest_insert
on public.opiniones
for insert
to anon
with check (visitor_id is null);

grant insert on public.opiniones to anon;
