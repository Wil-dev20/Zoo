# Zoológico Vivo · Prototipo

Aplicación web adaptable a celular y computadora.

## Funciones incluidas
- Registro con nombre, celular y procedencia declarada (sin GPS), distrito/país, edad opcional y fuente de referencia.
- Modo invitado con progreso temporal, normas del zoológico y croquis satelital interactivo con 18 animales.
- Ruta, ficha educativa y fichas con datos curiosos, quiz de cinco preguntas con opciones en orden aleatorio y puntos por visitas, aciertos y recorrido.
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


Mapa actualizado: la app usa `mapa-aereo-zoologico.png` y muestra marcadores interactivos para 18 animales. Para que trivias y puntajes de los 11 animales añadidos funcionen con Supabase, ejecuta `actualizar-animales-mapa.sql` después del esquema inicial. La ubicación y las fichas añadidas son aproximadas/educativas y deben validarse con el zoológico.



## Actualizaciones de Supabase
Si la base ya estaba configurada, ejecuta actualizar-animales-mapa.sql y luego mejorar-quiz-puntos.sql en el SQL Editor. La nueva escala suma 25 puntos por primer recinto, 10 por cada pregunta correcta respondida una sola vez y un bono de 25 por el primer recorrido. El progreso anterior no se recalcula.
