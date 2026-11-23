# Bitácora de prompts de IA

Registro del uso de IA generativa (Claude, de Anthropic) en el proyecto. La Entrega 3 está en **nivel 4 (IAG completa)**: se puede usar la IA de forma estratégica, justificando su uso y citando todo contenido creado con ella. Las entradas están resumidas; los prompts completos están en el chat de Claude del equipo.

**Pendiente de agregar por el equipo:** los scripts de PL/SQL (`src/04a` a `src/04d`) y sus documentos (`docs/plsql-*.md`) se hicieron en otra sesión con Claude; hay que añadir esos prompts o enlazar ese chat. Lo mismo para cualquier otro uso de IA no listado aquí.

## 2026-10-15 – Claude

**Prompt 1 (resumen):** se adjuntó `MR-Modificado.dmd` y el zip del proyecto de Data Modeler. Se pidió comprobar que el MER y el MR estuvieran completos, explicar por qué el `.dmd` no abría en Data Modeler y si el equipo podía modificar el modelo o debía hacerlo Claude.
- **Qué generó la IA:** diagnóstico (el `.dmd` solo trae el encabezado y debe estar junto a la carpeta de su mismo nombre), un zip con el modelo reordenado y una lista de inconsistencias entre MER y MR.
- **Uso:** el equipo aceptó el reordenamiento y las correcciones al MR: `ORDER_DETAILS.quantity` y `CHEFS.years_experience` obligatorios, nombres de PK/UK y la columna `ORDER_STATES_id_order_state`. El MR se reexportó a PDF.

**Prompt 2 (resumen):** se adjuntó el repositorio y el documento del proyecto. Se pidió hacer los cambios necesarios para ajustar el `Readme.md` y tener claro de en donde van los cambios.
- **Qué generó la IA:** una modificacion en la organizacion del repositorio, `Readme.md`, y borradores de `descripcion-del-caso.md`, `dependencias-funcionales.md`, `acuerdos-equipo.md` y plantillas de bitácora y actas, a partir de textos del propio equipo.
- **Uso:** el equipo ajustó nombres de carpetas, integrantes y enlaces.

## 2026-11-19 – Claude

**Prompts (resumen):** (a) si `MR-Modificado.dmd` servía como DDL para ingeniería inversa; (b) cómo llevar el proyecto por SQL y si DDL y DML van en archivos separados; (c) pasar las actas 1 y 2 de Word a Markdown.
- **Qué generó la IA:** (a) respuesta: no, el archivo solo contiene el encabezado del diseño; (b) plan de cuatro archivos en `src/` (DDL, DML, DQL, PL/SQL) según el Word; (c) transcripción de las actas a `actas-clase.md` y `bitacora-reuniones.md`, sin cambiar su contenido.

## 2026-11-20 – Claude

**Prompts (resumen):** (a) aclarar las restricciones `CHECK` y el equivalente de `TOP` en Oracle, y cómo llenar las tablas con datos de ejemplo; (b) revisar el repositorio con los scripts de PL/SQL de un compañero y decir qué faltaba; (c) agregar las consultas de los reportes y un plato y un cliente sin ventas para los joins externos.
- **Qué generó la IA:** `src/02_dml.sql` (datos ficticios: 64 pedidos y 192 detalles, más el plato `P18` y el cliente `C13`) y `src/03_dql.sql` (tres reportes y dos consultas complementarias). También la revisión del repositorio con la lista de pendientes.
- **Uso:** el equipo ejecutó el DML y las pruebas de PL/SQL en Oracle, donde imprimieron OK. El DQL queda por ejecutar y revisar.

**Prompt (literal):** «Hay algo que no entiendo aun de lo pendiente, se estaba pidiendo un script o algo de todo esto para mostrar y no entiendo como lo pongo o que deberia ser si ya paso un rato en el que solo se que ya se crearon todas las tablas y no puedo poner todos los scripts de todos los archivos por lo que se, explicame»
- **Qué respondió la IA:** que el documento del proyecto no pide un script único ni pegar el contenido de los scripts en ningún lado. Lo que pide es dejar los archivos en `src/`, cada uno documentado con comentarios, y enlazarlos desde el `Readme.md`. Aclaró que el DDL ya creó las tablas y que el resto de scripts trabaja sobre ellas, y que "mostrar" se refiere a la sustentación de la semana 17, para la cual existe `docs/plsql-sustentacion.md`. Ofreció, como opcional, un `00_ejecutar_todo.sql` que llame a los demás en orden.
- **Uso:** _completar por el equipo_ (si se crea o no el script opcional y cómo quedó el `Readme.md`).

