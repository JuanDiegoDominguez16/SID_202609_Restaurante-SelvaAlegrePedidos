-- =============================================================================
-- PROYECTO:      RESTAURANTE SELVA ALEGRE - SISTEMA DE PEDIDOS
-- ARCHIVO:       04A_FN_TOTAL_PEDIDO.SQL
-- OBJETO:        FN_TOTAL_PEDIDO
-- TIPO:          FUNCTION
-- PRERREQUISITO: 01_DDL.SQL (y 02_DML.SQL para probarla con datos)
--
-- OBJETIVO
--   Calcular el total a cobrar de un pedido. El modelo no guarda el total
--   (ver comentario de RESTAURANT_ORDERS): se obtiene sumando los detalles.
--   Cubre la historia de usuario 5 y es la base de los reportes de ventas.
--
-- PARAMETROS
--   P_ID_ORDER (IN)  Identificador del pedido (RESTAURANT_ORDERS.ID_ORDER).
--   RETORNA          NUMBER: SUM(QUANTITY * UNIT_PRICE) del pedido.
--                    0 si el pedido existe pero aun no tiene detalles.
--
-- TABLAS INVOLUCRADAS
--   RESTAURANT_ORDERS (solo lectura: validar que el pedido exista)
--   ORDER_DETAILS     (solo lectura: cantidad y precio unitario historico)
--
-- FUNCIONAMIENTO
--   1. Verifica que el pedido exista.
--   2. Suma QUANTITY * UNIT_PRICE de sus detalles (NVL -> 0 si no hay).
--   3. Retorna el total.
--
-- EXCEPCIONES
--   -20010  El pedido no existe (o el parametro es NULL).
--   Se distingue "pedido inexistente" (error) de "pedido sin detalles" (0),
--   porque son situaciones de negocio diferentes.
--
-- NOTA: usa UNIT_PRICE (precio al momento del pedido) y NO PLATES.PRICE, para
--   que un cambio de precio en el menu no altere pedidos anteriores
--   (historia de usuario 9).
--
-- EJEMPLO
--   SELECT FN_TOTAL_PEDIDO('O064') AS TOTAL FROM DUAL;   -- 30000
-- =============================================================================

CREATE OR REPLACE FUNCTION FN_TOTAL_PEDIDO (
    P_ID_ORDER IN RESTAURANT_ORDERS.ID_ORDER%TYPE
) RETURN NUMBER
IS
    V_EXISTE NUMBER;
    V_TOTAL  NUMBER;
BEGIN
    -- Paso 1: el pedido debe existir.
    SELECT COUNT(*)
      INTO V_EXISTE
      FROM RESTAURANT_ORDERS
     WHERE ID_ORDER = P_ID_ORDER;

    IF V_EXISTE = 0 THEN
        RAISE_APPLICATION_ERROR(-20010,
            'El pedido ' || NVL(P_ID_ORDER, '(NULL)') || ' no existe.');
    END IF;

    -- Paso 2: SUM devuelve NULL si no hay filas; NVL lo convierte en 0.
    SELECT NVL(SUM(QUANTITY * UNIT_PRICE), 0)
      INTO V_TOTAL
      FROM ORDER_DETAILS
     WHERE RESTAURANT_ORDERS_ID_ORDER = P_ID_ORDER;

    -- Paso 3.
    RETURN V_TOTAL;
END FN_TOTAL_PEDIDO;
/

SHOW ERRORS FUNCTION FN_TOTAL_PEDIDO
