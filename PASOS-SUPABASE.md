# Activar los puntajes compartidos

1. Crea un proyecto Supabase a nombre de la entidad responsable.
2. Ejecuta supabase-setup.sql en SQL Editor.
3. Copia Project URL y anon/publishable key a zv-cloud-config.js. No pongas la clave secret/service_role en el navegador.
4. Crea las cuatro cuentas en Authentication y autorízalas desde SQL Editor. Reemplaza los correos de ejemplo y ejecuta: insert into public.admins(user_id,role) select id,'admin' from auth.users where email in ('admin1@ejemplo.com','admin2@ejemplo.com','admin3@ejemplo.com','admin4@ejemplo.com') on conflict(user_id) do nothing;
5. Publica juntos index.html, admin.html, zv-cloud-config.js, manifest.json y mapa-zoologico.png en un sitio HTTPS.
6. Prueba registro, puntaje, opinión, reporte y permisos antes de usar con visitantes reales.

El registro envía la procedencia declarada y el progreso; opiniones y reportes también se guardan al usar una sesión Supabase. Sin URL/clave configuradas, el juego se mantiene en modo local y los datos no llegan al panel. Supabase Auth gestiona las contraseñas. player_profiles tiene acceso protegido por RLS; el panel no muestra correos ni celulares.


## Activar registro e inicio de sesión con Google

La app ya muestra el botón **Continuar con Google**. Para habilitar el proveedor en la nube:

1. En Google Cloud Console, crea un cliente OAuth de tipo **Aplicación web** y configura la pantalla de consentimiento. Si la app está en pruebas, añade las cuentas Google autorizadas como usuarios de prueba.
2. En los orígenes autorizados de JavaScript agrega `https://zooconti.vercel.app`.
3. En los URI de redireccionamiento autorizados agrega `https://igtutwenpfcqgtnargfk.supabase.co/auth/v1/callback`.
4. En Supabase, abre **Authentication → Sign In / Providers → Google**, habilita Google y pega el **Client ID** y el **Client Secret** de Google Cloud. Guarda los cambios.
5. En **Authentication → URL Configuration**, fija `https://zooconti.vercel.app` como Site URL y agrega `https://zooconti.vercel.app/**` a Redirect URLs.
6. Publica desde GitHub los cambios de `index.html` y `zv-cloud-config.js`. Después abre la app con `https://zooconti.vercel.app`; no uses el archivo local `.html` para iniciar sesión.

Google todavía figura deshabilitado en el proyecto Supabase. El botón mostrará un aviso hasta completar los pasos 1–5. No compartas el Client Secret ni lo guardes en archivos del sitio.