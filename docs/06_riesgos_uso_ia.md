# Riesgos del uso de IA generativa para desarrollar consultas SQL y reportes

Contexto: consultas DQL del sistema de pedidos del restaurante **Selva Alegre** (Oracle 21c, 13 tablas), tal como están en `src/03_dql.sql` (consultas 1A, 1B, 2A, 2B, 2C, 3, 4 y 5) sobre los datos de `src/02_dml.sql` (64 pedidos, 192 detalles, 13 clientes, 18 platos). Cada riesgo se ilustra con ese código y esos datos. Los ejemplos describen errores *posibles y típicos*, o hechos comprobables del repositorio; no son incidentes ocurridos.

## Estado de validación de las consultas citadas

| Verificación | Estado |
|---|---|
| Revisión estática de `03_dql.sql` contra `01_ddl.sql` y `02_dml.sql` | Hecha |
| Lógica de las consultas 1A, 1B, 3, 4 y 5 reproducida con los datos del DML en **SQLite** (equivalentes con ajustes mínimos de sintaxis) | Hecha. Las cifras de este documento salen de esa simulación |
| Consultas 2A, 2B y 2C (`TRUNC(...,'IW')`, `ROLLUP`) | Solo revisión estática; no se simularon |
| **Ejecución en Oracle 21c** | **Pendiente.** Ninguna consulta se ha ejecutado en Oracle desde este análisis. SQLite no demuestra compatibilidad con Oracle |

## Resumen

| # | Riesgo | Gravedad en un reporte financiero |
|---|---|---|
| 1 | Consultas incorrectas / alucinaciones | Media (suele fallar de forma visible) |
| 2 | Errores de lógica del negocio | **Alta** (resultado plausible pero falso) |
| 3 | Agregación y JOIN | **Alta** (sumas infladas sin error) |
| 4 | Seguridad y privacidad | Alta |
| 5 | Dependencia y pérdida de comprensión | Media-alta |
| 6 | Falta de validación y pruebas | **Alta** |
| 7 | Cumplimiento y responsabilidad | Alta |
| 8 | Mantenimiento y calidad | Media |

Los riesgos 2, 3 y 6 son los más peligrosos: la consulta **se ejecuta sin error y devuelve números con buena apariencia**.

---

## 1. Consultas incorrectas o alucinaciones

**Descripción.** El modelo genera código que parece válido pero usa objetos que no existen, relaciones equivocadas o sintaxis de otro motor.

**Ejemplo en Selva Alegre.**
- Escribir `SELECT TOP 5 ...` para la consulta 1A: `TOP` es de SQL Server. En Oracle se usa `FETCH FIRST n ROWS ONLY` (12c o superior), como hace el repositorio.
- Usar `ORDER_DETAILS.ORDER_ID` o `PLATES.CATEGORY_ID`, cuando las columnas reales son `RESTAURANT_ORDERS_ID_ORDER` y `CATEGORY_PLATES_ID_CATEGORY` (nombres generados por Data Modeler, poco intuitivos y fáciles de "corregir" a lo que parece lógico).
- Asumir que `RESTAURANT_ORDERS` tiene una columna `TOTAL`: el modelo explícitamente no la guarda; el total se calcula con los detalles (consulta 5 usa `FN_TOTAL_PEDIDO`).
- Unir `RESTAURANT_ORDERS` con `EMPLOYEES` olvidando que el pedido apunta a `WAITERS` (la consulta 3 resuelve el subtipo con `EMPLOYEES JOIN WAITERS`).

**Consecuencia.** Errores `ORA-00942` / `ORA-00904` (visibles y baratos) o, peor, un join sobre columnas equivocadas que sí compila.

**Mitigación.** Entregar a la IA el DDL real como contexto; contrastar cada tabla y columna con `01_ddl.sql`; compilar y ejecutar siempre; revisar la sintaxis contra la documentación de Oracle 21c.

---

## 2. Errores en la lógica del negocio

**Descripción.** La IA no conoce las reglas del negocio salvo que se las demos; rellena los vacíos con supuestos razonables pero erróneos.

**Ejemplo en Selva Alegre.**
- "Ventas" sin filtrar estado: la regla del repositorio es que solo cuentan los pedidos `pagado`. Sumar todos los estados da 6 827 500 frente a 5 564 500 de ventas efectivas (pagados), es decir **22,7 % de inflación**: 880 500 de cancelados, 86 000 de abiertos, 200 500 en preparación y 96 000 entregados.
- Valorar con `PLATES.PRICE` (precio actual): Bandeja paisa, Sancocho de gallina y Limonada de coco cambiaron de precio el 2026-10-15, y los pedidos anteriores quedarían recalculados con el precio nuevo. El repositorio usa `UNIT_PRICE`.
- **La regla no se aplica igual en todas las consultas, y eso debe estar dicho.** La consulta 4 cuenta pedidos de todos los estados (Felipe Aranda, C08, sale con 9 pedidos, pero solo 7 están pagados) y la consulta 5 muestra a propósito pedidos sin pagar. Es correcto si el comentario lo declara ("cuántos pedidos han hecho"), pero la cabecera dice que *solo cuentan los pagados*: un lector, o una IA que reescriba la consulta "para ser consistente", puede cambiar el resultado sin darse cuenta.
- Alias que sugieren más de lo que miden: en la consulta 3, `PEDIDOS_ATENDIDOS` cuenta solo pedidos **pagados**; un pedido entregado y aún sin cobrar no entra.
- Interpretar el valor de los pedidos cancelados (880 500) como "dinero perdido": es el valor de lo que se había pedido; el modelo no registra pagos ni devoluciones, así que no demuestra que se cobrara ni que se perdiera. Una IA suele redactar esas conclusiones con total seguridad aunque los datos no las sostengan.
- Suponer que un cliente es persona o empresa, cuando el DDL no impide que esté en ambos subtipos o en ninguno (ver riesgo 3).

**Consecuencia.** Reportes financieros incorrectos, decisiones erradas (retirar un plato, evaluar mal a un mesero) y pérdida de credibilidad del sistema.

**Mitigación.** Escribir las reglas en el prompt y en el encabezado del script (aquí: *venta efectiva = estado `pagado`*, *valor = `QUANTITY * UNIT_PRICE`*); anotar en cada consulta cuándo se aparta de la regla común y por qué; nombrar los alias por lo que miden (`PEDIDOS_PAGADOS` mide mejor que `PEDIDOS_ATENDIDOS`); hacer validar las reglas por quien conoce el negocio; probar con casos donde la regla importe (cancelados, cambios de precio).

---

## 3. Problemas de agregación y JOIN

**Descripción.** Combinar tablas de distinta granularidad (pedido vs. línea de detalle) y agregar sin cuidado multiplica filas o cuenta lo equivocado. No genera error.

**Ejemplo en Selva Alegre.**
- `COUNT(*)` en el join `RESTAURANT_ORDERS` × `ORDER_DETAILS` cuenta líneas (157 en los pedidos pagados) en lugar de pedidos (52). Las consultas 2A, 2B, 2C y 3 evitan el error con `COUNT(DISTINCT O.ID_ORDER)`.
- **Extender la consulta 4.** Hoy cuenta pedidos con `COUNT(O.ID_ORDER)` sobre `CLIENTS ⟕ PERSON ⟕ COMPANY ⟕ RESTAURANT_ORDERS`, y es correcta porque solo el último join es de uno a varios. Si alguien (o una IA) le añade `LEFT JOIN ORDER_DETAILS` para mostrar el valor consumido, cada pedido se repite por línea y `COUNT(O.ID_ORDER)` pasa a contar líneas: sin `COUNT(DISTINCT ...)` o una subconsulta que agregue antes por pedido, los números salen inflados y sin error.
- **Supuesto sobre los subtipos en la consulta 4.** Su comentario afirma que "un cliente está en una sola de las dos" (`PERSON`/`COMPANY`), pero el DDL no lo garantiza. Se probó en SQLite insertando a C01 también en `COMPANY`: la consulta sigue devolviendo una fila con 6 pedidos (no duplica, porque la PK de cada subtipo limita a una fila por cliente). Lo que cambia es silencioso: el tipo sale "persona natural" por el orden del `CASE`, y `NVL(P.ID_CC, M.ID_NIT)` oculta el NIT. Para clasificar sin riesgo de multiplicar filas, otra opción es `EXISTS`, que solo comprueba pertenencia (sí/no) y no devuelve filas.
- La consulta 1B pone el filtro de estado y fecha **dentro** de la vista en línea del `LEFT JOIN`; el propio script advierte que, si se mueve al `WHERE` exterior, el join externo pierde los platos sin ventas. Con los datos actuales ese plato es P18 (Chocolate con queso, 0 unidades): una "simplificación" lo haría desaparecer.
- La consulta 2C usa `ROLLUP` y un `NVL(..., 'TOTAL')`: la fila de total solo es correcta si los demás grupos no contienen NULL.

**Consecuencia.** Cifras infladas o incompletas, con aspecto de correctas; son difíciles de detectar sin un control independiente.

**Mitigación.** Pensar siempre en la granularidad de cada tabla; usar `COUNT(DISTINCT)` o subconsultas que primero agreguen por pedido; **conciliar totales entre reportes**: con el periodo por defecto (2026-09-01 a 2026-11-30) las ventas pagadas deben dar **5 564 500** en la suma de las filas de 2A, en la suma de 2B, en la fila `TOTAL` de 2C, en la suma de `VALOR_VENDIDO` de la consulta 3 y en la suma de la 1B (la 1A es solo un top y no debe sumar el total); comparar con el cálculo manual de un pedido (ej. `O064` = 30 000); probar casos de borde (cliente en ambos subtipos, cliente sin subtipo, plato sin ventas).

---

## 4. Seguridad y privacidad de los datos

**Descripción.** Para pedir ayuda se suelen pegar datos reales en una herramienta externa; esa información sale del control de la organización y puede conservarse o usarse para entrenamiento según el servicio.

**Ejemplo en Selva Alegre.**
- Pegar filas de `CLIENTS`/`PERSON` (nombre, teléfono, correo, cédula; la consulta 4 incluso muestra el documento) o de `EMPLOYEES` (cédula, teléfono) para "ver por qué falla el join".
- Pegar la cadena de conexión o usuario/clave de la base de datos de producción en el chat.
- Pegar el reporte de ventas o de desempeño por mesero (consulta 3), que es información comercial y de personal.

**Consecuencia.** Incumplimiento de la normativa de protección de datos personales (Ley 1581 de 2012 en Colombia), fuga de información comercial, sanciones y daño reputacional.

**Mitigación.** Compartir solo estructura (DDL) y datos anonimizados o sintéticos (los del DML de este proyecto son ficticios); nunca credenciales; usar herramientas aprobadas por la organización con las condiciones de privacidad adecuadas; revisar lo que se pega antes de enviarlo.

---

## 5. Dependencia de la IA y pérdida de comprensión técnica

**Descripción.** Aceptar consultas que no se entienden deja al equipo incapaz de explicarlas, corregirlas o adaptarlas.

**Ejemplo en Selva Alegre.**
- La consulta 3 usa `RANK() OVER (ORDER BY ...)`. Quien no distingue `RANK`, `DENSE_RANK` y `ROW_NUMBER` no puede explicar qué pasa con dos meseros empatados (ambos reciben el mismo puesto y se salta el siguiente) ni por qué el `ORDER BY` final es distinto del de la función de ventana.
- La consulta 2C usa `GROUP BY ROLLUP` y `NVL(..., 'TOTAL')`: ¿por qué el total sale al final? Porque el mes es NULL en esa fila y Oracle ordena NULL al final por defecto en orden ascendente. Sin entenderlo, cualquier cambio del `ORDER BY` desordena el reporte.
- La consulta 1A desempata por nombre del plato. Con los datos actuales hay un empate real por unidades entre Ajiaco santafereño y Tres leches (18 cada uno); gana el Ajiaco **por orden alfabético**, que no es un criterio de negocio (coincide, además, con el mayor ingreso). Si el top fuera 6, o si cambiara el nombre, el resultado cambiaría. `FETCH FIRST ... WITH TIES` compara todas las columnas del `ORDER BY` y, con ese desempate único, igual devolvería exactamente N filas.
- En la sustentación no se puede justificar el `LEFT JOIN` con el filtro en el `ON`/vista en línea ni el uso de `TRUNC(fecha) + 1` para incluir todo el último día.

**Consecuencia.** Nadie puede mantener el reporte; cuando el resultado es dudoso, no hay quien lo audite; mala evaluación académica o, en el trabajo, pérdida de confianza.

**Mitigación.** Regla: *no se entrega lo que no se puede explicar línea a línea*; documentar cada decisión en comentarios; revisión por pares; practicar modificando la consulta sin la IA.

---

## 6. Falta de validación y pruebas

**Descripción.** Dar por buena una consulta porque la IA la escribió o porque "devuelve filas".

**Ejemplo en Selva Alegre.**
- **Qué debe dar cada reporte con los datos actuales** es lo que separa un resultado correcto de uno que solo "parece" bien. Por ejemplo: la 1B debe devolver 18 filas, con P18 en 0 unidades; la consulta 4 debe devolver 13 clientes, con C13 en 0 pedidos; la consulta 2A devuelve **23** días (hay 25 días con pedidos, pero en 2 solo hay pedidos cancelados o sin pagar). Quien espera 25 podría "corregir" una consulta que es correcta.
- Un top que cambia entre ejecuciones por falta de desempate.
- Probar solo con datos que no incluyen cancelados, ni cambios de precio, ni clientes o platos sin movimiento.
- Ejecutar la consulta como sentencia suelta (F9) en lugar de script (F5): las variables `&V_FECHA_INI`, `&V_FECHA_FIN` y `&V_TOP` (`DEFINE`) pueden pedirse por ventana o no estar definidas, y una fecha mal escrita da `ORA-01861`.
- Declarar "probado en Oracle" cuando solo se revisó a ojo o se ejecutó en otro motor, que tiene diferencias (división entera, funciones de fecha, `FETCH FIRST`, `ROLLUP`, `TRUNC(...,'IW')`).
- Dar por cierto un diagnóstico plausible sin comprobarlo: es razonable suponer que dos `LEFT JOIN` a `PERSON` y `COMPANY` inflan los pedidos de un cliente presente en ambas; al probarlo en SQLite (consulta 4 con C01 en las dos tablas) **no** ocurre. Sin la prueba se habría documentado un error inexistente.

**Consecuencia.** Defectos que llegan a producción, informes que contradicen la contabilidad y afirmaciones falsas sobre el nivel de verificación.

**Mitigación.** Ejecutar en el motor objetivo (en este proyecto, **pendiente en Oracle 21c**); comparar con cálculos independientes; conciliar totales (ver riesgo 3); probar casos límite (sin datos, empates, NULL, cancelados); **dejar escrito qué se validó y cómo**, distinguiendo lo verificado en SQLite de lo verificado en Oracle.

---

## 7. Cumplimiento y responsabilidad profesional

**Descripción.** El uso de IA en una organización está sujeto a políticas, licencias y trazabilidad; la responsabilidad por el resultado es del profesional, no de la herramienta.

**Ejemplo en Selva Alegre.**
- El encabezado de `03_dql.sql` declara que las consultas se escribieron con ayuda de IA y remite a `docs/bitacora-prompts.md`; el DML dice lo mismo de sus datos ("generados con ayuda de IA y pendientes de revisión del equipo"). En esta revisión, `docs/bitacora-prompts.md` solo contiene el encabezado: **no hay entradas** con el prompt, lo que se hizo y quién revisó. La declaración existe, la trazabilidad todavía no.
- La bitácora establece que las Entregas 0, 1 y 2 están en **nivel 2 (planificación con IAG)**: el producto final debe ser de autoría del equipo y no contener contenido creado con IAG. El nivel permitido para la Entrega 3 (SQL y PL/SQL) no está documentado en el repositorio; usar IA para escribir el código sin confirmarlo con el docente es un riesgo de incumplimiento académico.
- Reportes que llegan al dueño sin saber quién los revisó ni con qué criterios.
- Usar una herramienta no autorizada para trabajar con datos reales del restaurante, o ignorar licencias y términos de uso del servicio.

**Consecuencia.** Sanciones disciplinarias o contractuales, responsabilidad legal por decisiones tomadas con datos erróneos, imposibilidad de auditar.

**Mitigación.** Usar solo herramientas autorizadas; confirmar con el docente el nivel de uso permitido para cada entrega; registrar en la bitácora cada uso (herramienta, prompt, resultado, **quién lo revisó y cómo**); declarar el uso de IA según la política; el profesional firma lo que entrega.

---

## 8. Mantenimiento y calidad del código

**Descripción.** El código generado puede ser innecesariamente complejo, inconsistente o acoplado a supuestos implícitos, y difícil de adaptar.

**Ejemplo en Selva Alegre.**
- **Estados por texto.** Las consultas filtran por `S.NAME_STATE = 'pagado'` y `'en preparación'` (con tilde, en 1A, 1B, 2A a 2C, 3 y 5). Es legible, pero si el catálogo se renombra (`'Pagado'`) o el archivo se abre con otra codificación y la tilde se corrompe, el filtro no falla: **devuelve menos filas o ninguna**. Filtrar por `ID_ORDER_STATE = 'OS4'` es menos legible pero más estable; el equipo debe elegir y documentar.
- **Comentarios acoplados a los datos.** La consulta 4 dice "(EJ. C13)". El cliente C13 y el plato P18 se agregaron al DML para ilustrar los joins externos; si se regenera el DML sin ellos, los comentarios y los resultados esperados quedan desactualizados. Cada cambio de datos debe revisarse junto con las consultas y su documentación.
- **Función dentro de un `SELECT`.** La consulta 5 llama a `FN_TOTAL_PEDIDO` por cada fila (cada llamada ejecuta consultas propias) y depende de haber creado antes `04a_fn_total_pedido.sql`. Es simple y reutiliza la lógica, pero sobre muchos pedidos conviene una agregación directa. Si se cambia la función, cambian los reportes que la usan.
- **Variables `DEFINE`** (`&V_FECHA_INI`, etc.): funcionan en SQL Developer como script; en otra herramienta o en una aplicación hay que reemplazarlas por variables de enlace.
- Si el equipo agrega una columna o cambia el catálogo de estados, las consultas con estados fijos y sin comentarios no se pueden revisar rápido; reportes parecidos (2A, 2B y 2C) pueden divergir si solo se corrige uno.

**Consecuencia.** Costos altos de cambio, errores cuando evoluciona el modelo, consultas lentas que nadie sabe optimizar.

**Mitigación.** Estándares de estilo (alias claros, sin `SELECT *`); comentario con propósito y reglas por consulta; reglas comunes al inicio del script; simplicidad antes que sofisticación; revisión de código; plan de pruebas que se vuelva a ejecutar cuando cambie el modelo o los datos.

---

## Reflexión final

La IA generativa es útil como **asistente**: acelera borradores, sugiere alternativas, explica errores de Oracle y ayuda a documentar. No conoce el negocio de Selva Alegre, no ve los datos reales ni asume la responsabilidad por lo que se entrega. Sus errores más costosos no son los que fallan con un mensaje, sino los que devuelven resultados convincentes pero incorrectos (ventas infladas, pedidos mal contados, un top que depende del orden alfabético).

Por eso el criterio técnico, la validación y la responsabilidad permanecen en la persona: quien entrega debe entender cada línea, comprobarla contra el modelo y los datos reales, y poder defenderla sin la herramienta. Usada de esa manera (con contexto preciso, datos protegidos, revisión independiente y trazabilidad), la IA mejora la productividad; usada como sustituto del criterio, aumenta el riesgo.
