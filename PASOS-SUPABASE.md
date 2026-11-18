# Activar los puntajes compartidos

1. Crea un proyecto Supabase a nombre de la entidad responsable.
2. Ejecuta supabase-setup.sql en SQL Editor.
3. Copia Project URL y anon/publishable key a zv-cloud-config.js. No pongas la clave secret/service_role en el navegador.
4. Crea las cuatro cuentas en Authentication y autorízalas desde SQL Editor. Reemplaza los correos de ejemplo y ejecuta: insert into public.admins(user_id,role) select id,'admin' from auth.users where email in ('admin1@ejemplo.com','admin2@ejemplo.com','admin3@ejemplo.com','admin4@ejemplo.com') on conflict(user_id) do nothing;
5. Publica juntos index.html, admin.html, zv-cloud-config.js, manifest.json y mapa-zoologico.png en un sitio HTTPS.
6. Prueba registro, puntaje, opinión, reporte y permisos antes de usar con visitantes reales.

El registro envía la procedencia declarada y el progreso; opiniones y reportes también se guardan al usar una sesión Supabase. Sin URL/clave configuradas, el juego se mantiene en modo local y los datos no llegan al panel. Supabase Auth gestiona las contraseñas. player_profiles tiene acceso protegido por RLS; el panel no muestra correos ni celulares.

