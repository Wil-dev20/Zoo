# Zoológico Vivo · Prototipo

Aplicación web adaptable a celular y computadora.

## Funciones incluidas
- Registro con nombre, celular y procedencia declarada (sin GPS), distrito/país, edad opcional y fuente de referencia.
- Modo invitado con progreso temporal, normas del zoológico y croquis interactivo con siete especies de ejemplo.
- Ruta, ficha educativa y quiz de tres preguntas por animal; puntos, visitas e insignias.
- Opiniones e informes guardados en Supabase cuando se configura el proyecto.
- Portal de administración con resumen diario, calificación promedio, reportes pendientes, gráfica de procedencia, buscador de visitantes, opiniones recientes y estados de reportes.
- Supabase Auth, PostgreSQL y RLS. El esquema crea las tablas visitantes, animales, preguntas, visitas_animales, respuestas, opiniones, reportes y admins, más progreso_visitantes para el puntaje acumulado.

## Archivos
- index.html: aplicación de visitantes.
- admin.html: portal independiente del personal.
- supabase-setup.sql: tablas, permisos y vistas.
- zv-cloud-config.js: URL y clave pública del proyecto.
- PASOS-SUPABASE.md: conexión y alta de las cuatro administradoras.

El modo local conserva el progreso solo en el navegador. La sincronización entre dispositivos y el panel requieren configurar Supabase y publicar por HTTPS. Valida las fichas de especies con fuentes oficiales antes del uso público.
