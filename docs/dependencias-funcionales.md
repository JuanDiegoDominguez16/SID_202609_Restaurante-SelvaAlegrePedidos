# Dependencias funcionales (evidencia de 3FN)

Tomadas de la [Entrega 1](Entrega1.pdf) y actualizadas al modelo relacional vigente (`model/fuentes/ProyectoSIDMER-MR.zip`).

Cambios respecto a la Entrega 1:
- La columna `ORDER_STATES_order_state` pasó a llamarse `ORDER_STATES_id_order_state`, y `ORDER_STATES.order_state` se escribe `id_order_state`, igual que en el modelo.
- La llave de `ORDER_DETAILS` sigue siendo compuesta: `{RESTAURANT_ORDERS_id_order, id_detail}`.

## Dependencias por tabla

**ORDER_STATES**
- id_order_state → name_state
- name_state → id_order_state

**TABLES_STATES**
- id_table_state → name_state
- name_state → id_table_state

**CATEGORY_PLATES**
- id_category → name_category

**PLATES**
- id_plate → name_plate, description, price, CATEGORY_PLATES_id_category
- name_plate → id_plate

**DINING_TABLES**
- id_table → table_number, capacity, TABLES_STATES_id_table_state
- table_number → id_table

**EMPLOYEES**
- id_employee → name, telephone, date_hiring

**WAITERS**
- EMPLOYEES_id_employee → shift

**CHEFS**
- EMPLOYEES_id_employee → degree, specialty, years_experience

**CLIENTS**
- id_client → name, telephone, email

**PERSON**
- CLIENT_id_client → id_cc
- id_cc → CLIENT_id_client

**COMPANY**
- CLIENT_id_client → id_nit
- id_nit → CLIENT_id_client

**RESTAURANT_ORDERS**
- id_order → date_time, ORDER_STATES_id_order_state, DINING_TABLES_id_table, WAITERS_EMPLOYEES_id_employee, CLIENT_id_client

**ORDER_DETAILS**
- {RESTAURANT_ORDERS_id_order, id_detail} → quantity, unit_price, PLATES_id_plate

## Verificación

- Todos los determinantes son llaves primarias o candidatas (columnas `U` en el modelo), por lo que no hay dependencias parciales ni transitivas: cumple 3FN (incluso BCNF).
- `ORDER_DETAILS.unit_price` guarda el precio al momento del pedido (historia de usuario 9); no depende de `PLATES.price` en el tiempo, por eso no es redundancia.
- El total del pedido no se almacena: se calcula con la suma de `quantity * unit_price` de sus detalles.
