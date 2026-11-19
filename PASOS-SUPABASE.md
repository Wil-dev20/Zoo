# Activar los puntajes compartidos

1. Crea un proyecto Supabase a nombre de la entidad responsable.
2. Ejecuta supabase-setup.sql en SQL Editor.
   Si ya tienes la base creada, ejecuta en este orden actualizar-animales-mapa.sql, mejorar-quiz-puntos.sql y niveles-quiz-escaner.sql. El último script crea el control de un quiz diario por animal, tres niveles progresivos y el registro de tickets QR canjeados.
3. Copia Project URL y anon/publishable key a zv-cloud-config.js. No pongas la clave secret/service_role en el navegador.
4. Crea las cuatro cuentas en Authentication y autorízalas desde SQL Editor. Reemplaza los correos de ejemplo y ejecuta: insert into public.admins(user_id,role) select id,'admin' from auth.users where email in ('admin1@ejemplo.com','admin2@ejemplo.com','admin3@ejemplo.com','admin4@ejemplo.com') on conflict(user_id) do nothing;
5. Publica juntos index.html, admin.html, zv-cloud-config.js, manifest.json y mapa-zoologico.png en un sitio HTTPS.
6. Prueba registro, puntaje, opinión, reporte y permisos antes de usar con visitantes reales.

El escáner suma 25 puntos por ticket con QR único y no permite canjear el mismo código dos veces. Cada visita debe tener su propio QR; si el zoológico reutiliza un mismo QR para todas las entradas, no se podrá distinguir una visita nueva de un ticket ya canjeado.

El registro envía la procedencia declarada y el progreso; opiniones y reportes también se guardan al usar una sesión Supabase. Sin URL/clave configuradas, el juego se mantiene en modo local y los datos no llegan al panel. Supabase Auth gestiona las contraseñas. player_profiles tiene acceso protegido por RLS; el panel no muestra correos ni celulares.



## Acceso rápido sin Google Cloud Console

La app permite crear una cuenta o iniciar sesión con un enlace enviado al correo. No requiere configurar Google Cloud ni guardar secretos de Google. La cuenta y los puntajes se siguen guardando en Supabase.

1. Publica la versión actualizada de `index.html` y `zv-cloud-config.js`.
2. En Supabase, abre **Authentication → URL Configuration**. Usa `https://zooconti.vercel.app` como Site URL y agrega esa URL a Redirect URLs.
3. Abre la app desde `https://zooconti.vercel.app` (no desde el archivo `.html`).
4. En registro, completa los datos, escribe tu correo y pulsa **Crear cuenta con enlace por correo**. Para iniciar sesión, escribe tu correo y pulsa **Recibir enlace de acceso por correo**.
5. Abre el enlace recibido en el mismo navegador donde tienes la app. Si no llega, revisa spam y el límite de envío de correo de Supabase.

El acceso con Google necesita credenciales de proveedor OAuth; por eso se reemplazó el botón que mostraba `Unsupported provider` por el acceso por correo, que no usa Google Cloud Console.
