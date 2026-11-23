# Documentación PL/SQL – Restaurante Selva Alegre

Requerimiento: *"Realizar script PL/SQL. Realice por lo menos un procedimiento almacenado, una función y un trigger sobre la base de datos creada. Cada uno de estos elementos debe estar documentado, indicando su funcionalidad."*

Motor: Oracle Database 21c. No se modificó el modelo (`01_ddl.sql`) ni los datos (`02_dml.sql`); no se crearon tablas, secuencias ni paquetes.

## Estado de validación (leer primero)

| Tipo de verificación | Estado |
|---|---|
| Revisión estática contra `01_ddl.sql` / `02_dml.sql` (nombres de tablas, columnas, tipos, llaves, IDs usados en las pruebas, saldos esperados calculados a mano) | Hecha |
| **Ejecución en Oracle** (compilación y corrida de `04d_pruebas_plsql.sql`) | **No realizada**: en el entorno donde se desarrolló no había instancia de Oracle. Debe ejecutarla el equipo antes de la sustentación. |

Si algún script no compila, `SHOW ERRORS` (ya incluido al final de cada script) muestra la línea y el error.

## Orden de ejecución

| # | Script | Contenido |
|---|---|---|
| 1 | `src/01_ddl.sql` | Tablas (ya existente) |
| 2 | `src/02_dml.sql` | Datos (ya existente) |
| 3 | `src/04a_fn_total_pedido.sql` | Función `FN_TOTAL_PEDIDO` |
| 4 | `src/04b_sp_agregar_detalle_pedido.sql` | Procedimiento `SP_AGREGAR_DETALLE_PEDIDO` (usa la función, por eso va después) |
| 5 | `src/04c_trg_sync_estado_mesa.sql` | Trigger `TRG_SYNC_ESTADO_MESA` |
| 6 | `src/04d_pruebas_plsql.sql` | Pruebas de los tres objetos (terminan en `ROLLBACK`) |

En SQL Developer: abrir cada archivo y ejecutar con **F5** (Run Script), con la ventana *DBMS Output* activa. Los scripts `04a`–`04c` usan `CREATE OR REPLACE`, por lo que pueden repetirse.

---

## 1. FN_TOTAL_PEDIDO

| Campo | Detalle |
|---|---|
| Tipo | FUNCTION |
| Objetivo | Calcular el total a cobrar de un pedido |
| Funcionalidad | Historia de usuario 5. El modelo no guarda el total; se calcula sumando los detalles |
| Parámetros | `P_ID_ORDER` (IN): id del pedido. Retorna `NUMBER` |
| Tablas | `RESTAURANT_ORDERS` (lectura), `ORDER_DETAILS` (lectura) |

**Funcionamiento paso a paso**
1. Cuenta si existe el pedido.
2. Si no existe → error `-20010`.
3. `SELECT NVL(SUM(QUANTITY * UNIT_PRICE), 0)` sobre sus detalles. Usa `UNIT_PRICE` (precio histórico) y no `PLATES.PRICE`, para respetar la historia de usuario 9.
4. Retorna el total.

**Validaciones/excepciones:** pedido inexistente o nulo → `-20010`. Pedido existente sin detalles → retorna `0` (no es error).

**Ejemplo**
```sql
SELECT FN_TOTAL_PEDIDO('O064') FROM DUAL;   -- 30000
SELECT ID_ORDER, FN_TOTAL_PEDIDO(ID_ORDER) AS TOTAL FROM RESTAURANT_ORDERS;
```

---

## 2. SP_AGREGAR_DETALLE_PEDIDO

| Campo | Detalle |
|---|---|
| Tipo | PROCEDURE |
| Objetivo | Agregar un plato con su cantidad a un pedido |
| Funcionalidad | Historias de usuario 2 y 9: el mesero agrega platos y el detalle guarda el precio del momento |
| Parámetros | `P_ID_ORDER` IN, `P_ID_PLATE` IN, `P_QUANTITY` IN (entero 1–9999), `P_ID_DETAIL` OUT (consecutivo generado), `P_ORDER_TOTAL` OUT (total actualizado) |
| Tablas | `RESTAURANT_ORDERS` (lee y bloquea), `PLATES` (lee), `ORDER_DETAILS` (inserta) |

**Funcionamiento paso a paso**
1. Valida parámetros: pedido y plato no nulos; cantidad entera entre 1 y 9999.
2. `SELECT ... FOR UPDATE` del pedido: lee su estado y lo bloquea para que dos sesiones no generen el mismo `ID_DETAIL`.
3. Verifica que el estado sea `OS1` (abierto) u `OS2` (en preparación).
4. Lee el precio actual del plato.
5. Calcula el siguiente consecutivo: mayor número de los `ID_DETAIL` con formato `D<n>` del pedido + 1 (`'D01'`, `'D02'`…).
6. `INSERT` en `ORDER_DETAILS` copiando el precio a `UNIT_PRICE`.
7. Retorna el `ID_DETAIL` y el total vía `FN_TOTAL_PEDIDO`.

**Excepciones**

| Código | Causa |
|---|---|
| -20001 | Pedido o plato nulo |
| -20002 | Cantidad nula, no entera o fuera de 1–9999 |
| -20003 | El pedido no existe |
| -20004 | Estado del pedido no admite cambios (entregado, pagado o cancelado) |
| -20005 | El plato no existe |

No hace `COMMIT`/`ROLLBACK`: la transacción la controla quien lo invoca.

**Decisión de negocio (supuesto del equipo):** el enunciado no dice en qué estados se pueden agregar platos; se asumió abierto y en preparación. Si el profesor define otra regla, solo cambia la condición del paso 3.

**Ejemplo**
```sql
DECLARE
    V_DETALLE ORDER_DETAILS.ID_DETAIL%TYPE;
    V_TOTAL   NUMBER;
BEGIN
    SP_AGREGAR_DETALLE_PEDIDO('O064', 'P03', 2, V_DETALLE, V_TOTAL);
    DBMS_OUTPUT.PUT_LINE(V_DETALLE || ' total ' || V_TOTAL);  -- D03 total 45000
    ROLLBACK;
END;
/
```

---

## 3. TRG_SYNC_ESTADO_MESA

| Campo | Detalle |
|---|---|
| Tipo | TRIGGER (compound trigger) |
| Objetivo | Mantener el estado de la mesa (libre/ocupada) coherente con sus pedidos |
| Funcionalidad | Regla del caso: la mesa "cambia de estado cada que un cliente va y viene" (historia 3). Mesa ocupada (`TS2`) si tiene algún pedido en `OS1`, `OS2` u `OS3`; si no, libre (`TS1`) |
| Evento | `AFTER INSERT OR UPDATE OF ORDER_STATES_ID_ORDER_STATE, DINING_TABLES_ID_TABLE ON RESTAURANT_ORDERS` |
| Nivel | Fila (`AFTER EACH ROW`) para anotar y sentencia (`AFTER STATEMENT`) para actualizar |
| Tablas | `RESTAURANT_ORDERS` (dispara y se consulta), `DINING_TABLES` (se actualiza) |

**Funcionamiento paso a paso**
1. Por cada fila insertada o modificada (`AFTER EACH ROW`), guarda en una colección en memoria el id de la mesa nueva (`:NEW`) y, si el pedido cambió de mesa, también el de la anterior (`:OLD`). No consulta la tabla.
2. Al terminar la sentencia (`AFTER STATEMENT`), para cada mesa anotada hace un `UPDATE` de `DINING_TABLES` con `CASE WHEN EXISTS (pedido activo en esa mesa) THEN 'TS2' ELSE 'TS1'`.
3. Vacía la colección.

**Tablas mutantes:** consultar `RESTAURANT_ORDERS` desde un trigger de fila sobre `RESTAURANT_ORDERS` da ORA-04091. Por eso la consulta se hace en `AFTER STATEMENT`, cuando la tabla ya no está en cambio.

**No duplica restricciones:** ni las FK ni los CHECK pueden expresar "mesa ocupada si hay pedido activo", así que la regla solo vive en este trigger.

**Errores:** no se capturan; si el `UPDATE` falla se revierte toda la sentencia que disparó el trigger.

**Ejemplo**
```sql
UPDATE RESTAURANT_ORDERS SET ORDER_STATES_ID_ORDER_STATE = 'OS4'
 WHERE ID_ORDER = 'O058';           -- T01 pasa a TS1 (no tiene otro pedido activo)
SELECT ID_TABLE, TABLES_STATES_ID_TABLE_STATE FROM DINING_TABLES WHERE ID_TABLE = 'T01';
ROLLBACK;
```

**Observación sobre los datos actuales:** el trigger solo recalcula las mesas de los pedidos que se tocan; no corrige datos existentes. Con `02_dml.sql` las mesas ya cuadran con la regla.

---

## Pruebas (`src/04d_pruebas_plsql.sql`)

Todo el script va entre `SAVEPOINT` y `ROLLBACK TO SAVEPOINT`. Cada prueba imprime `OK` o `FALLO`; al final una consulta confirma que no quedaron datos.

| Prueba | Qué comprueba | Resultado esperado |
|---|---|---|
| F1 | Total de `O064` | 30000 |
| F2 | Pedido sin detalles (`ZT00`) | 0 |
| F3 | Pedido inexistente | ORA-20010 |
| F4 | Uso en `SELECT` vs. suma manual | `COINCIDE = SI` en 3 pedidos |
| P1 / P2 | Agregar a pedido sin detalles | `D01` / 15000, luego `D02` / 24500 |
| P3 | Agregar a `O064` | `D03` / 45000 |
| P4–P10 | Cantidad 0, cantidad 1.5, pedido inexistente, pedido pagado, pedido cancelado, plato inexistente, plato nulo | -20002, -20002, -20003, -20004, -20004, -20005, -20001 |
| T1 | INSERT de pedido abierto en mesa libre T02 | T02 = TS2 |
| T2 | Se paga un pedido pero hay otro abierto en la misma mesa | T02 sigue TS2 |
| T3 | Se cancela el último pedido activo | T02 = TS1 |
| T4 | Pedido cambia de mesa T09 → T02 | T02 = TS2, T09 = TS1 |

Resultado de la ejecución real en Oracle: **pendiente** (ver "Estado de validación").
