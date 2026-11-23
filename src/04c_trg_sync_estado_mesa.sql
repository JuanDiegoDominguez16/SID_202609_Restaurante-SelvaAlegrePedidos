-- =============================================================================
-- PROYECTO:      RESTAURANTE SELVA ALEGRE - SISTEMA DE PEDIDOS
-- ARCHIVO:       04C_TRG_SYNC_ESTADO_MESA.SQL
-- OBJETO:        TRG_SYNC_ESTADO_MESA
-- TIPO:          TRIGGER (COMPOUND TRIGGER)
-- PRERREQUISITO: 01_DDL.SQL
--
-- OBJETIVO
--   Mantener DINING_TABLES.TABLES_STATES_ID_TABLE_STATE coherente con los
--   pedidos. Regla de negocio (caso de estudio y comentario de 02_DML.SQL):
--     * Mesa OCUPADA (TS2) si tiene al menos un pedido en estado abierto (OS1),
--       en preparacion (OS2) o entregado (OS3).
--     * Mesa LIBRE (TS1) en cualquier otro caso (solo pagados/cancelados).
--   El enunciado dice que el estado de la mesa "cambia cada que un cliente va
--   y viene"; este trigger lo hace automatico y evita que quede desactualizado.
--   Las llaves foraneas y los CHECK no pueden expresar esta regla.
--
-- EVENTO
--   AFTER INSERT OR UPDATE OF ORDER_STATES_ID_ORDER_STATE,
--                              DINING_TABLES_ID_TABLE
--   ON RESTAURANT_ORDERS. Es AFTER porque la mesa se recalcula una vez el
--   pedido ya quedo guardado. Solo reacciona a las dos columnas que afectan la
--   regla (estado y mesa).
--
-- POR QUE UN COMPOUND TRIGGER (EVITAR TABLA MUTANTE)
--   Para decidir si una mesa se libera hay que consultar RESTAURANT_ORDERS
--   (puede haber otro pedido activo en esa mesa). Hacerlo dentro de un trigger
--   FOR EACH ROW normal sobre esa misma tabla produce ORA-04091 (tabla
--   mutante). Solucion:
--     * AFTER EACH ROW: solo ANOTA en una coleccion en memoria el id de cada
--       mesa afectada (sin consultar la tabla).
--     * AFTER STATEMENT: cuando la sentencia termino, la tabla ya no esta
--       mutando; alli se recalcula el estado de cada mesa anotada.
--
-- USO DE :NEW Y :OLD
--   :NEW.DINING_TABLES_ID_TABLE  mesa actual del pedido (INSERT y UPDATE).
--   :OLD.DINING_TABLES_ID_TABLE  mesa anterior (solo UPDATE): si el pedido
--                                cambia de mesa, tambien se recalcula la vieja.
--
-- TABLAS INVOLUCRADAS
--   RESTAURANT_ORDERS (tabla que dispara; se consulta en AFTER STATEMENT)
--   DINING_TABLES     (se actualiza el estado de la mesa)
--
-- MANEJO DE ERRORES
--   No captura excepciones: si el UPDATE de la mesa falla (ej. mesa o estado
--   inexistente por la FK), el error sube y Oracle deshace la sentencia
--   completa (INSERT/UPDATE del pedido), manteniendo la consistencia.
--
-- EJEMPLO
--   UPDATE RESTAURANT_ORDERS SET ORDER_STATES_ID_ORDER_STATE = 'OS4'
--    WHERE ID_ORDER = 'O058';   -- pedido pagado -> mesa T01 pasa a libre (TS1)
--   ROLLBACK;
-- =============================================================================

CREATE OR REPLACE TRIGGER TRG_SYNC_ESTADO_MESA
FOR INSERT OR UPDATE OF ORDER_STATES_ID_ORDER_STATE, DINING_TABLES_ID_TABLE
ON RESTAURANT_ORDERS
COMPOUND TRIGGER

    -- Constantes de catalogo (ver 02_DML.SQL).
    C_MESA_LIBRE   CONSTANT DINING_TABLES.TABLES_STATES_ID_TABLE_STATE%TYPE := 'TS1';
    C_MESA_OCUPADA CONSTANT DINING_TABLES.TABLES_STATES_ID_TABLE_STATE%TYPE := 'TS2';

    -- Mesas afectadas por la sentencia. Arreglo asociativo indexado por el id
    -- de la mesa: asi cada mesa queda una sola vez aunque varios pedidos la
    -- toquen.
    TYPE T_MESAS IS TABLE OF DINING_TABLES.ID_TABLE%TYPE
        INDEX BY VARCHAR2(20);
    G_MESAS T_MESAS;

    -- Se ejecuta por cada fila insertada/actualizada. NO consulta la tabla.
    AFTER EACH ROW IS
    BEGIN
        G_MESAS(:NEW.DINING_TABLES_ID_TABLE) := :NEW.DINING_TABLES_ID_TABLE;

        IF UPDATING AND :OLD.DINING_TABLES_ID_TABLE <> :NEW.DINING_TABLES_ID_TABLE THEN
            G_MESAS(:OLD.DINING_TABLES_ID_TABLE) := :OLD.DINING_TABLES_ID_TABLE;
        END IF;
    END AFTER EACH ROW;

    -- Se ejecuta una vez, al terminar la sentencia: ya es seguro consultar.
    AFTER STATEMENT IS
        V_ID_MESA VARCHAR2(20);
    BEGIN
        V_ID_MESA := G_MESAS.FIRST;
        WHILE V_ID_MESA IS NOT NULL LOOP
            UPDATE DINING_TABLES T
               SET T.TABLES_STATES_ID_TABLE_STATE =
                   CASE
                       WHEN EXISTS (SELECT 1
                                      FROM RESTAURANT_ORDERS O
                                     WHERE O.DINING_TABLES_ID_TABLE = T.ID_TABLE
                                       AND O.ORDER_STATES_ID_ORDER_STATE
                                           IN ('OS1', 'OS2', 'OS3'))
                       THEN C_MESA_OCUPADA
                       ELSE C_MESA_LIBRE
                   END
             WHERE T.ID_TABLE = V_ID_MESA;

            V_ID_MESA := G_MESAS.NEXT(V_ID_MESA);
        END LOOP;

        G_MESAS.DELETE;   -- limpiar para la siguiente sentencia
    END AFTER STATEMENT;

END TRG_SYNC_ESTADO_MESA;
/

SHOW ERRORS TRIGGER TRG_SYNC_ESTADO_MESA
