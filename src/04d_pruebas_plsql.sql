-- =============================================================================
-- PROYECTO:      RESTAURANTE SELVA ALEGRE - SISTEMA DE PEDIDOS
-- ARCHIVO:       04D_PRUEBAS_PLSQL.SQL
-- DESCRIPCION:   PRUEBAS DE FN_TOTAL_PEDIDO, SP_AGREGAR_DETALLE_PEDIDO Y
--                TRG_SYNC_ESTADO_MESA.
-- PRERREQUISITO: 01_DDL, 02_DML, 04A, 04B y 04C ejecutados (en ese orden).
-- EJECUCION:     SQL Developer: F5 (Ejecutar script) con DBMS Output abierto,
--                o SQL*Plus: @04d_pruebas_plsql.sql
-- SIN BASURA:    todo el script trabaja dentro de un SAVEPOINT y termina con
--                ROLLBACK TO SAVEPOINT. No hace COMMIT.
--                (Si la herramienta tiene AUTOCOMMIT activo, desactivarlo.)
-- DATOS USADOS (de 02_DML.SQL):
--   O064: pedido abierto con 2 detalles = 2*9000 + 1*12000 = 30000
--   O001: pedido pagado (OS4)      O021: pedido cancelado (OS5)
--   Mesa T09 (libre) y T02 (libre), cliente C01, mesero 1005123401.
--   Ni T09 ni T02 tienen pedidos activos al inicio.
-- Cada prueba imprime OK o FALLO.
-- =============================================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF

SAVEPOINT INICIO_PRUEBAS;

-- Pedido auxiliar SIN detalles (mesa T09), para el caso limite de la funcion y
-- para el procedimiento. Al crearlo se dispara el trigger (T09 -> ocupada).
INSERT INTO RESTAURANT_ORDERS
    (ID_ORDER, DATE_TIME, ORDER_STATES_ID_ORDER_STATE, CLIENT_ID_CLIENT,
     DINING_TABLES_ID_TABLE, WAITERS_EMPLOYEES_ID_EMPLOYEE)
VALUES ('ZT00', SYSDATE, 'OS1', 'C01', 'T09', '1005123401');

PROMPT
PROMPT ===== FUNCION FN_TOTAL_PEDIDO =====

-- F1: resultado normal.
DECLARE
    V_TOTAL NUMBER;
BEGIN
    V_TOTAL := FN_TOTAL_PEDIDO('O064');
    DBMS_OUTPUT.PUT_LINE('F1 total O064 (esperado 30000): ' || V_TOTAL || ' -> '
        || CASE WHEN V_TOTAL = 30000 THEN 'OK' ELSE 'FALLO' END);
END;
/

-- F2: caso limite, pedido existente sin detalles -> 0 (no NULL).
DECLARE
    V_TOTAL NUMBER;
BEGIN
    V_TOTAL := FN_TOTAL_PEDIDO('ZT00');
    DBMS_OUTPUT.PUT_LINE('F2 total pedido sin detalles (esperado 0): ' || V_TOTAL || ' -> '
        || CASE WHEN V_TOTAL = 0 THEN 'OK' ELSE 'FALLO' END);
END;
/

-- F3: caso limite, pedido inexistente -> ORA-20010.
DECLARE
    V_TOTAL NUMBER;
BEGIN
    V_TOTAL := FN_TOTAL_PEDIDO('NOEXISTE');
    DBMS_OUTPUT.PUT_LINE('F3 FALLO: no lanzo excepcion');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('F3 pedido inexistente (esperado -20010): ' || SQLCODE || ' -> '
            || CASE WHEN SQLCODE = -20010 THEN 'OK' ELSE 'FALLO' END);
END;
/

-- F4: uso dentro de SELECT, comparando con el calculo manual.
-- Columna COINCIDE debe ser 'SI' en las 3 filas.
SELECT O.ID_ORDER,
       FN_TOTAL_PEDIDO(O.ID_ORDER)  AS TOTAL_FUNCION,
       (SELECT SUM(D.QUANTITY * D.UNIT_PRICE)
          FROM ORDER_DETAILS D
         WHERE D.RESTAURANT_ORDERS_ID_ORDER = O.ID_ORDER) AS TOTAL_MANUAL,
       CASE WHEN FN_TOTAL_PEDIDO(O.ID_ORDER) =
                 (SELECT SUM(D.QUANTITY * D.UNIT_PRICE)
                    FROM ORDER_DETAILS D
                   WHERE D.RESTAURANT_ORDERS_ID_ORDER = O.ID_ORDER)
            THEN 'SI' ELSE 'NO' END AS COINCIDE
  FROM RESTAURANT_ORDERS O
 WHERE O.ID_ORDER IN ('O001', 'O062', 'O064')
 ORDER BY O.ID_ORDER;

PROMPT
PROMPT ===== PROCEDIMIENTO SP_AGREGAR_DETALLE_PEDIDO =====

-- P1: datos validos. ZT00 no tiene detalles -> primer detalle 'D01'.
-- P03 (Arepa con queso) cuesta 7500 -> 2 * 7500 = 15000.
DECLARE
    V_DETALLE ORDER_DETAILS.ID_DETAIL%TYPE;
    V_TOTAL   NUMBER;
BEGIN
    SP_AGREGAR_DETALLE_PEDIDO('ZT00', 'P03', 2, V_DETALLE, V_TOTAL);
    DBMS_OUTPUT.PUT_LINE('P1 detalle=' || V_DETALLE || ' total=' || V_TOTAL
        || ' (esperado D01 / 15000) -> '
        || CASE WHEN V_DETALLE = 'D01' AND V_TOTAL = 15000 THEN 'OK' ELSE 'FALLO' END);
END;
/

-- P2: segundo plato en el mismo pedido -> 'D02'. P12 (Limonada de coco) 9500.
-- Total esperado: 15000 + 9500 = 24500.
DECLARE
    V_DETALLE ORDER_DETAILS.ID_DETAIL%TYPE;
    V_TOTAL   NUMBER;
BEGIN
    SP_AGREGAR_DETALLE_PEDIDO('ZT00', 'P12', 1, V_DETALLE, V_TOTAL);
    DBMS_OUTPUT.PUT_LINE('P2 detalle=' || V_DETALLE || ' total=' || V_TOTAL
        || ' (esperado D02 / 24500) -> '
        || CASE WHEN V_DETALLE = 'D02' AND V_TOTAL = 24500 THEN 'OK' ELSE 'FALLO' END);
END;
/

-- P3: pedido existente que ya trae detalles (O064 tiene D01 y D02) -> 'D03'.
DECLARE
    V_DETALLE ORDER_DETAILS.ID_DETAIL%TYPE;
    V_TOTAL   NUMBER;
BEGIN
    SP_AGREGAR_DETALLE_PEDIDO('O064', 'P03', 2, V_DETALLE, V_TOTAL);
    DBMS_OUTPUT.PUT_LINE('P3 detalle=' || V_DETALLE || ' total=' || V_TOTAL
        || ' (esperado D03 / 45000) -> '
        || CASE WHEN V_DETALLE = 'D03' AND V_TOTAL = 45000 THEN 'OK' ELSE 'FALLO' END);
END;
/

-- Verificacion de datos: UNIT_PRICE debe ser el precio de PLATES (7500 y 9500).
SELECT D.RESTAURANT_ORDERS_ID_ORDER AS PEDIDO, D.ID_DETAIL, D.PLATES_ID_PLATE AS PLATO,
       D.QUANTITY, D.UNIT_PRICE, P.PRICE AS PRECIO_MENU
  FROM ORDER_DETAILS D
  JOIN PLATES P ON P.ID_PLATE = D.PLATES_ID_PLATE
 WHERE D.RESTAURANT_ORDERS_ID_ORDER IN ('ZT00')
    OR (D.RESTAURANT_ORDERS_ID_ORDER = 'O064' AND D.ID_DETAIL = 'D03')
 ORDER BY D.RESTAURANT_ORDERS_ID_ORDER, D.ID_DETAIL;

-- P4..P8: datos invalidos. Cada uno debe fallar con su codigo.
DECLARE
    V_DETALLE ORDER_DETAILS.ID_DETAIL%TYPE;
    V_TOTAL   NUMBER;

    PROCEDURE PROBAR(P_NOMBRE VARCHAR2, P_PEDIDO VARCHAR2, P_PLATO VARCHAR2,
                     P_CANT NUMBER, P_CODIGO_ESPERADO NUMBER) IS
    BEGIN
        SP_AGREGAR_DETALLE_PEDIDO(P_PEDIDO, P_PLATO, P_CANT, V_DETALLE, V_TOTAL);
        DBMS_OUTPUT.PUT_LINE(P_NOMBRE || ' FALLO: no lanzo excepcion');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE(P_NOMBRE || ' (esperado ' || P_CODIGO_ESPERADO || '): '
                || SQLCODE || ' -> '
                || CASE WHEN SQLCODE = P_CODIGO_ESPERADO THEN 'OK' ELSE 'FALLO' END);
    END PROBAR;
BEGIN
    PROBAR('P4 cantidad 0       ', 'ZT00',     'P03', 0,    -20002);
    PROBAR('P5 cantidad 1.5     ', 'ZT00',     'P03', 1.5,  -20002);
    PROBAR('P6 pedido inexistente', 'NOEXISTE', 'P03', 1,    -20003);
    PROBAR('P7 pedido pagado O001', 'O001',     'P03', 1,    -20004);
    PROBAR('P8 pedido cancelado O021', 'O021',  'P03', 1,    -20004);
    PROBAR('P9 plato inexistente', 'ZT00',     'P99', 1,    -20005);
    PROBAR('P10 plato nulo      ', 'ZT00',     NULL,  1,    -20001);
END;
/

PROMPT
PROMPT ===== TRIGGER TRG_SYNC_ESTADO_MESA =====

-- Estado inicial: T09 quedo ocupada (TS2) al insertar ZT00 en la seccion 1.
-- T02 esta libre (TS1) y sin pedidos activos.
-- T1: INSERT de pedido abierto en T02 -> T02 pasa a TS2.
INSERT INTO RESTAURANT_ORDERS
    (ID_ORDER, DATE_TIME, ORDER_STATES_ID_ORDER_STATE, CLIENT_ID_CLIENT,
     DINING_TABLES_ID_TABLE, WAITERS_EMPLOYEES_ID_EMPLOYEE)
VALUES ('ZT01', SYSDATE, 'OS1', 'C01', 'T02', '1005123401');

DECLARE
    V_ESTADO DINING_TABLES.TABLES_STATES_ID_TABLE_STATE%TYPE;
BEGIN
    SELECT TABLES_STATES_ID_TABLE_STATE INTO V_ESTADO FROM DINING_TABLES WHERE ID_TABLE = 'T02';
    DBMS_OUTPUT.PUT_LINE('T1 INSERT pedido abierto -> T02 (esperado TS2): ' || V_ESTADO || ' -> '
        || CASE WHEN V_ESTADO = 'TS2' THEN 'OK' ELSE 'FALLO' END);

    SELECT TABLES_STATES_ID_TABLE_STATE INTO V_ESTADO FROM DINING_TABLES WHERE ID_TABLE = 'T09';
    DBMS_OUTPUT.PUT_LINE('T1b ZT00 abierto -> T09 (esperado TS2): ' || V_ESTADO || ' -> '
        || CASE WHEN V_ESTADO = 'TS2' THEN 'OK' ELSE 'FALLO' END);
END;
/

-- T2: segundo pedido activo en T02, luego se paga el primero.
-- T02 debe seguir ocupada porque ZT02 sigue abierto (caso de tabla mutante).
INSERT INTO RESTAURANT_ORDERS
    (ID_ORDER, DATE_TIME, ORDER_STATES_ID_ORDER_STATE, CLIENT_ID_CLIENT,
     DINING_TABLES_ID_TABLE, WAITERS_EMPLOYEES_ID_EMPLOYEE)
VALUES ('ZT02', SYSDATE, 'OS1', 'C01', 'T02', '1005123401');

UPDATE RESTAURANT_ORDERS SET ORDER_STATES_ID_ORDER_STATE = 'OS4' WHERE ID_ORDER = 'ZT01';

DECLARE
    V_ESTADO DINING_TABLES.TABLES_STATES_ID_TABLE_STATE%TYPE;
BEGIN
    SELECT TABLES_STATES_ID_TABLE_STATE INTO V_ESTADO FROM DINING_TABLES WHERE ID_TABLE = 'T02';
    DBMS_OUTPUT.PUT_LINE('T2 paga ZT01 pero ZT02 sigue abierto -> T02 (esperado TS2): '
        || V_ESTADO || ' -> ' || CASE WHEN V_ESTADO = 'TS2' THEN 'OK' ELSE 'FALLO' END);
END;
/

-- T3: se cancela ZT02 (ya no quedan pedidos activos) -> T02 pasa a TS1.
UPDATE RESTAURANT_ORDERS SET ORDER_STATES_ID_ORDER_STATE = 'OS5' WHERE ID_ORDER = 'ZT02';

DECLARE
    V_ESTADO DINING_TABLES.TABLES_STATES_ID_TABLE_STATE%TYPE;
BEGIN
    SELECT TABLES_STATES_ID_TABLE_STATE INTO V_ESTADO FROM DINING_TABLES WHERE ID_TABLE = 'T02';
    DBMS_OUTPUT.PUT_LINE('T3 cancela ZT02, sin activos -> T02 (esperado TS1): ' || V_ESTADO || ' -> '
        || CASE WHEN V_ESTADO = 'TS1' THEN 'OK' ELSE 'FALLO' END);
END;
/

-- T4: cambio de mesa. ZT00 (abierto, en T09) se mueve a T02:
-- T02 -> ocupada (TS2) y T09 (la vieja) -> libre (TS1).
UPDATE RESTAURANT_ORDERS SET DINING_TABLES_ID_TABLE = 'T02' WHERE ID_ORDER = 'ZT00';

DECLARE
    V_NUEVA DINING_TABLES.TABLES_STATES_ID_TABLE_STATE%TYPE;
    V_VIEJA DINING_TABLES.TABLES_STATES_ID_TABLE_STATE%TYPE;
BEGIN
    SELECT TABLES_STATES_ID_TABLE_STATE INTO V_NUEVA FROM DINING_TABLES WHERE ID_TABLE = 'T02';
    SELECT TABLES_STATES_ID_TABLE_STATE INTO V_VIEJA FROM DINING_TABLES WHERE ID_TABLE = 'T09';
    DBMS_OUTPUT.PUT_LINE('T4 cambio de mesa -> T02=' || V_NUEVA || ' T09=' || V_VIEJA
        || ' (esperado TS2 / TS1) -> '
        || CASE WHEN V_NUEVA = 'TS2' AND V_VIEJA = 'TS1' THEN 'OK' ELSE 'FALLO' END);
END;
/

-- Consulta de comprobacion: pedidos de prueba y estado final de las mesas.
SELECT O.ID_ORDER, O.ORDER_STATES_ID_ORDER_STATE AS ESTADO_PEDIDO,
       O.DINING_TABLES_ID_TABLE AS MESA, T.TABLES_STATES_ID_TABLE_STATE AS ESTADO_MESA
  FROM RESTAURANT_ORDERS O
  JOIN DINING_TABLES T ON T.ID_TABLE = O.DINING_TABLES_ID_TABLE
 WHERE O.ID_ORDER LIKE 'ZT%'
 ORDER BY O.ID_ORDER;

PROMPT
PROMPT ===== LIMPIEZA: ROLLBACK =====
ROLLBACK TO SAVEPOINT INICIO_PRUEBAS;

-- Comprobacion de que no quedo nada: pedidos de prueba = 0, detalle D03 de O064
-- = 0, mesas T02 y T09 de nuevo en TS1.
SELECT (SELECT COUNT(*) FROM RESTAURANT_ORDERS WHERE ID_ORDER LIKE 'ZT%') AS PEDIDOS_PRUEBA,
       (SELECT COUNT(*) FROM ORDER_DETAILS
         WHERE RESTAURANT_ORDERS_ID_ORDER = 'O064' AND ID_DETAIL = 'D03')   AS DETALLE_D03_O064,
       (SELECT LISTAGG(ID_TABLE || '=' || TABLES_STATES_ID_TABLE_STATE, ', ')
                WITHIN GROUP (ORDER BY ID_TABLE)
          FROM DINING_TABLES WHERE ID_TABLE IN ('T02', 'T09'))             AS MESAS_T02_T09
  FROM DUAL;

SET FEEDBACK ON
-- FIN DEL SCRIPT
