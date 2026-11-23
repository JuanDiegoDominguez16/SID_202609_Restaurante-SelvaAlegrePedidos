-- =============================================================================
-- PROYECTO:      RESTAURANTE SELVA ALEGRE - SISTEMA DE PEDIDOS
-- ARCHIVO:       04B_SP_AGREGAR_DETALLE_PEDIDO.SQL
-- OBJETO:        SP_AGREGAR_DETALLE_PEDIDO
-- TIPO:          PROCEDURE
-- PRERREQUISITO: 01_DDL.SQL y 04A_FN_TOTAL_PEDIDO.SQL
--
-- OBJETIVO
--   Agregar un plato (con su cantidad) a un pedido existente. Cubre las
--   historias de usuario 2 y 9: el mesero agrega platos al pedido y el detalle
--   guarda el precio que el plato tiene EN ESE MOMENTO.
--
-- PARAMETROS
--   P_ID_ORDER    (IN)  Pedido al que se agrega el plato.
--   P_ID_PLATE    (IN)  Plato del menu (PLATES.ID_PLATE).
--   P_QUANTITY    (IN)  Cantidad: entero entre 1 y 9999 (ORDER_DETAILS.QUANTITY
--                       es NUMBER(4)).
--   P_ID_DETAIL   (OUT) Consecutivo generado ('D01', 'D02', ...).
--   P_ORDER_TOTAL (OUT) Total actualizado del pedido (usa FN_TOTAL_PEDIDO).
--
-- TABLAS INVOLUCRADAS
--   RESTAURANT_ORDERS (lectura + bloqueo de la fila del pedido)
--   PLATES            (lectura del precio vigente)
--   ORDER_DETAILS     (INSERT del nuevo detalle)
--
-- FUNCIONAMIENTO
--   1. Valida parametros (no nulos, cantidad entera 1..9999).
--   2. Lee el pedido con FOR UPDATE: lo bloquea para que dos meseros no generen
--      el mismo ID_DETAIL a la vez.
--   3. Valida que el pedido este 'abierto' (OS1) o 'en preparacion' (OS2).
--      Un pedido entregado, pagado o cancelado ya no admite cambios.
--   4. Lee el precio actual del plato en PLATES.
--   5. Calcula el siguiente ID_DETAIL = 'D' || (mayor numero actual + 1).
--   6. Inserta el detalle copiando el precio a UNIT_PRICE.
--   7. Devuelve el ID_DETAIL y el total actualizado del pedido.
--
-- EXCEPCIONES (RAISE_APPLICATION_ERROR)
--   -20001  Pedido o plato nulo.
--   -20002  Cantidad nula, no entera o fuera de 1..9999.
--   -20003  El pedido no existe.
--   -20004  El pedido no admite cambios por su estado.
--   -20005  El plato no existe.
--   Cualquier otro error (ej. violacion de una restriccion) se propaga tal cual.
--
-- TRANSACCION: el procedimiento NO hace COMMIT ni ROLLBACK; quien lo llama
--   decide. Asi un fallo posterior permite deshacer todo y las pruebas no
--   dejan datos.
--
-- EJEMPLO
--   DECLARE
--       V_DETAIL ORDER_DETAILS.ID_DETAIL%TYPE;
--       V_TOTAL  NUMBER;
--   BEGIN
--       SP_AGREGAR_DETALLE_PEDIDO('O064', 'P03', 2, V_DETAIL, V_TOTAL);
--       DBMS_OUTPUT.PUT_LINE(V_DETAIL || ' / total ' || V_TOTAL);
--       ROLLBACK;
--   END;
-- =============================================================================

CREATE OR REPLACE PROCEDURE SP_AGREGAR_DETALLE_PEDIDO (
    P_ID_ORDER    IN  RESTAURANT_ORDERS.ID_ORDER%TYPE,
    P_ID_PLATE    IN  PLATES.ID_PLATE%TYPE,
    P_QUANTITY    IN  ORDER_DETAILS.QUANTITY%TYPE,
    P_ID_DETAIL   OUT ORDER_DETAILS.ID_DETAIL%TYPE,
    P_ORDER_TOTAL OUT NUMBER
)
IS
    -- Estados del pedido (ORDER_STATES) que permiten agregar platos.
    C_ESTADO_ABIERTO        CONSTANT ORDER_STATES.ID_ORDER_STATE%TYPE := 'OS1';
    C_ESTADO_EN_PREPARACION CONSTANT ORDER_STATES.ID_ORDER_STATE%TYPE := 'OS2';

    V_ESTADO_PEDIDO RESTAURANT_ORDERS.ORDER_STATES_ID_ORDER_STATE%TYPE;
    V_PRECIO        PLATES.PRICE%TYPE;
    V_SIGUIENTE     NUMBER;
BEGIN
    -- 1. Validacion de parametros.
    IF P_ID_ORDER IS NULL OR P_ID_PLATE IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'El pedido y el plato son obligatorios.');
    END IF;

    IF P_QUANTITY IS NULL OR P_QUANTITY < 1 OR P_QUANTITY > 9999
       OR P_QUANTITY <> TRUNC(P_QUANTITY) THEN
        RAISE_APPLICATION_ERROR(-20002,
            'La cantidad debe ser un entero entre 1 y 9999.');
    END IF;

    -- 2. Bloquear el pedido y leer su estado.
    BEGIN
        SELECT ORDER_STATES_ID_ORDER_STATE
          INTO V_ESTADO_PEDIDO
          FROM RESTAURANT_ORDERS
         WHERE ID_ORDER = P_ID_ORDER
           FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20003,
                'El pedido ' || P_ID_ORDER || ' no existe.');
    END;

    -- 3. Solo se agregan platos a pedidos abiertos o en preparacion.
    IF V_ESTADO_PEDIDO NOT IN (C_ESTADO_ABIERTO, C_ESTADO_EN_PREPARACION) THEN
        RAISE_APPLICATION_ERROR(-20004,
            'El pedido ' || P_ID_ORDER || ' esta en estado ' || V_ESTADO_PEDIDO
            || ' y no admite nuevos platos.');
    END IF;

    -- 4. Precio vigente del plato.
    BEGIN
        SELECT PRICE
          INTO V_PRECIO
          FROM PLATES
         WHERE ID_PLATE = P_ID_PLATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20005,
                'El plato ' || P_ID_PLATE || ' no existe.');
    END;

    -- 5. Siguiente consecutivo del detalle dentro del pedido. El REGEXP_LIKE
    --    ignora identificadores que no tengan el formato 'D' + numero.
    SELECT NVL(MAX(TO_NUMBER(SUBSTR(ID_DETAIL, 2))), 0) + 1
      INTO V_SIGUIENTE
      FROM ORDER_DETAILS
     WHERE RESTAURANT_ORDERS_ID_ORDER = P_ID_ORDER
       AND REGEXP_LIKE(ID_DETAIL, '^D[0-9]+$');

    P_ID_DETAIL := 'D' || LPAD(V_SIGUIENTE, 2, '0');

    -- 6. Insertar el detalle con el precio del momento.
    INSERT INTO ORDER_DETAILS
        (RESTAURANT_ORDERS_ID_ORDER, ID_DETAIL, QUANTITY, UNIT_PRICE, PLATES_ID_PLATE)
    VALUES
        (P_ID_ORDER, P_ID_DETAIL, P_QUANTITY, V_PRECIO, P_ID_PLATE);

    -- 7. Total actualizado.
    P_ORDER_TOTAL := FN_TOTAL_PEDIDO(P_ID_ORDER);
END SP_AGREGAR_DETALLE_PEDIDO;
/

SHOW ERRORS PROCEDURE SP_AGREGAR_DETALLE_PEDIDO
