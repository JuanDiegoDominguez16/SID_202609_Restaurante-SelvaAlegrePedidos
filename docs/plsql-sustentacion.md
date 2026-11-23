# Guía de sustentación PL/SQL – Restaurante Selva Alegre

Complementa [plsql-documentacion.md](plsql-documentacion.md). Antes de sustentar: ejecutar los scripts en Oracle y confirmar que todas las pruebas de `04d` imprimen `OK`.

## Demostración sugerida (5 minutos)

1. `SELECT FN_TOTAL_PEDIDO('O064') FROM DUAL;` → 30000.
2. Ejecutar el ejemplo del procedimiento (agrega `P03` ×2 a `O064`, devuelve `D03` y 45000) y luego `ROLLBACK`.
3. Intentarlo con `O001` (pagado) y mostrar el error `-20004`.
4. Ejecutar `04d_pruebas_plsql.sql` completo y mostrar la tabla final de "sin basura".
5. Mostrar T2 de las pruebas del trigger (el caso de dos pedidos en la misma mesa).

---

## FN_TOTAL_PEDIDO

**¿Qué problema resuelve?** El total de un pedido no se guarda (evita inconsistencias); hay que calcularlo en cada cobro y en reportes.

**¿Por qué función y no procedimiento?** Devuelve un único valor, no modifica datos y se usa dentro de `SELECT`. Un procedimiento no se puede llamar en un `SELECT`.

**Instrucciones clave**
- `SELECT COUNT(*) ... IF V_EXISTE = 0 THEN RAISE_APPLICATION_ERROR` → distingue pedido inexistente de pedido vacío.
- `NVL(SUM(QUANTITY * UNIT_PRICE), 0)` → `SUM` sobre cero filas da `NULL`; `NVL` lo vuelve 0.
- Usa `UNIT_PRICE` y no `PLATES.PRICE` porque el precio del menú puede cambiar y los pedidos viejos deben conservar el suyo.

**Parámetros / retorno:** recibe el id del pedido; retorna `NUMBER`.
**Error:** pedido inexistente → ORA-20010 (definido por nosotros con `RAISE_APPLICATION_ERROR`, rango -20000 a -20999).

**Preguntas probables**
- *¿Por qué no `NO_DATA_FOUND`?* Un `SUM` sin filas no lanza `NO_DATA_FOUND` (devuelve `NULL`), y un pedido sin platos es válido. Por eso se cuenta aparte.
- *¿Por qué no es `DETERMINISTIC`?* Su resultado depende de datos de tablas que pueden cambiar.
- *¿Qué pasa con descuentos o impuestos?* El modelo no los tiene; no se inventaron.

---

## SP_AGREGAR_DETALLE_PEDIDO

**¿Qué problema resuelve?** Agregar un plato a un pedido requiere varios pasos que deben ir juntos: validar, tomar el precio, numerar el detalle e insertar. Si cada mesero lo hiciera con `INSERT` a mano habría precios digitados mal, números repetidos y platos agregados a pedidos ya pagados.

**¿Por qué procedimiento?** Ejecuta una operación con efecto (INSERT) que contiene lógica de negocio. Una función con `INSERT` no se puede usar en `SELECT` y es mala práctica. Un trigger no sirve porque la acción la inicia el mesero, no es una reacción a un cambio.

**Instrucciones clave**
- `SELECT ... FOR UPDATE`: bloquea la fila del pedido. Dos sesiones que agreguen platos al mismo pedido se turnan y no generan el mismo `ID_DETAIL` (que sería violación de la PK compuesta).
- `NOT IN (C_ESTADO_ABIERTO, C_ESTADO_EN_PREPARACION)`: regla de estados.
- `REGEXP_LIKE(ID_DETAIL, '^D[0-9]+$')` + `MAX(TO_NUMBER(SUBSTR(ID_DETAIL, 2))) + 1`: siguiente consecutivo; el regex evita un `ORA-01722` si hubiera un id con otro formato.
- `LPAD(V_SIGUIENTE, 2, '0')` → `'D01'`, igual al formato de `02_dml.sql`.
- `UNIT_PRICE` se llena con `V_PRECIO` leído de `PLATES`: historia 9.
- `P_ORDER_TOTAL := FN_TOTAL_PEDIDO(...)`: reutiliza la función.

**Parámetros:** 3 de entrada (pedido, plato, cantidad), 2 de salida (id del detalle, total del pedido).

**¿Qué pasa si hay un error?** Cada validación lanza una excepción con su código (-20001 a -20005) antes de insertar. Como no hay `COMMIT` dentro, si algo falla después de un `INSERT` quien llama puede hacer `ROLLBACK`. No hay `WHEN OTHERS` que oculte errores inesperados.

**Cómo interactúa con las tablas:** lee y bloquea `RESTAURANT_ORDERS`, lee `PLATES`, escribe en `ORDER_DETAILS`. Las FK (`ORDER_DETAILS_ORDER_FK`, `ORDER_DETAILS_PLATE_FK`) y los CHECK de cantidad/precio siguen protegiendo; el procedimiento valida antes para dar mensajes claros.

**Preguntas probables**
- *¿Por qué no hay COMMIT?* La transacción es del llamador; permite agrupar varias operaciones y hacer pruebas con `ROLLBACK`.
- *¿Por qué `FOR UPDATE`?* Evita la condición de carrera al calcular el consecutivo.
- *¿Qué pasa si el mismo plato se agrega dos veces?* Se crean dos detalles; el caso dice que un plato puede estar más de una vez en un pedido.
- *¿Por qué solo abierto y en preparación?* Es un supuesto nuestro (el enunciado no lo fija); un pedido entregado/pagado/cancelado ya no debería cambiar su cuenta. Se cambia en una condición.
- *¿Por qué validar la cantidad si hay un CHECK?* Para dar un error entendible; el CHECK queda como red de seguridad. Además `NUMBER(4)` no impide en el parámetro valores como 1.5 o 99999, y se rechazan aquí.
- *¿Y si cambia el precio del plato después?* El detalle conserva el precio copiado en `UNIT_PRICE`.

---

## TRG_SYNC_ESTADO_MESA

**¿Qué problema resuelve?** El estado de la mesa (libre/ocupada) depende del estado de los pedidos; si se actualiza a mano se desincroniza (mesa "ocupada" sin cliente o pedido nuevo en mesa "libre"). Ninguna FK ni CHECK puede expresar esa regla.

**¿Por qué trigger?** La regla debe cumplirse siempre, sin importar desde dónde se modifique el pedido (procedimiento, SQL manual, otra aplicación). Un procedimiento solo la aplicaría si todos lo llaman.

**¿Por qué compound trigger?** Para liberar una mesa hay que saber si tiene otro pedido activo, es decir consultar `RESTAURANT_ORDERS`. Hacerlo en un trigger `FOR EACH ROW` sobre esa misma tabla causa ORA-04091 (tabla mutante). El compound trigger separa: por fila solo anota la mesa; al final de la sentencia (`AFTER STATEMENT`) consulta y actualiza.

**Instrucciones clave**
- `FOR INSERT OR UPDATE OF ORDER_STATES_ID_ORDER_STATE, DINING_TABLES_ID_TABLE`: solo se dispara cuando cambia algo relevante.
- `TYPE T_MESAS IS TABLE OF ... INDEX BY VARCHAR2(20)`: arreglo asociativo; usar el id como índice evita repetir la mesa.
- `:NEW` (mesa actual) y `:OLD` (mesa anterior, solo si hay `UPDATING` y cambió).
- `CASE WHEN EXISTS (...) THEN 'TS2' ELSE 'TS1' END`: ocupada si hay algún pedido en OS1/OS2/OS3.
- `G_MESAS.DELETE`: limpia la colección para la siguiente sentencia.

**Si ocurre un error:** el trigger no captura excepciones; si falla, Oracle revierte la sentencia del pedido que lo disparó, así no queda un pedido sin mesa actualizada.

**Cómo demostrarlo:** pruebas T1–T4 de `04d`; en vivo, `UPDATE` del estado de `O058` a `OS4` y `SELECT` de la mesa `T01`.

**Preguntas probables**
- *¿Qué es una tabla mutante?* Tabla que está siendo modificada por la sentencia que disparó el trigger; Oracle prohíbe consultarla en un trigger de fila (ORA-04091).
- *¿Por qué AFTER y no BEFORE?* Porque se necesita que el pedido ya esté guardado para que el `EXISTS` lo vea.
- *¿Por qué `OF` columnas?* Evita ejecutarse cuando se cambia, por ejemplo, el mesero o la fecha.
- *¿Y si un `UPDATE` toca 100 pedidos?* La colección deduplica mesas y se hace un `UPDATE` por mesa afectada.
- *¿Qué pasa si se borra un pedido?* No está cubierto (los pedidos con detalles no se pueden borrar por la FK); se podría añadir `DELETE` con `:OLD`.
- *¿Qué no hace?* No corrige mesas de pedidos que no se tocan, ni valida el orden de los estados del pedido (p. ej. impedir reabrir uno pagado). Son extensiones posibles.

---

## Pendiente que ve el equipo (fuera de este alcance)

`01_ddl.sql` indica que la regla "un empleado no puede ser mesero y chef a la vez" (y análogamente cliente persona/empresa) se controlaría en `04_PLSQL`. **No se implementó** porque el requerimiento pide un solo objeto de cada tipo y la consigna prohíbe funcionalidades innecesarias; si el profesor la espera, sería un trigger sobre `WAITERS`/`CHEFS` y `PERSON`/`COMPANY`.
