# Descripción del caso: Restaurante Selva Alegre

(Versión vigente, tomada de la Entrega 1: [Entrega1.pdf](Entrega1.pdf).)

## Enunciado

Selva Alegre es un restaurante de comida típica y tradicional colombiana, de un solo local, con servicio en mesa. Actualmente todo el proceso de atención, desde la toma del pedido hasta el cobro de la cuenta, se maneja de forma manual, en papel. Esto genera dificultades como pérdida de comandas, errores al calcular la cuenta, demoras en la atención, falta de información histórica sobre qué platos se venden más, y ninguna visibilidad sobre el desempeño de los meseros o las horas de mayor movimiento.

El local maneja cada pedido con un código de identificación único, la fecha y hora del pedido y un estado del pedido, que puede ser abierto, en preparación, entregado, pagado o cancelado. Cada pedido se asigna a una mesa, que cuenta con un número identificador, una capacidad límite y un estado de mesa, libre u ocupada, que cambia cada que un cliente va y viene.

Un pedido cuenta con una lista de los platos pedidos, y un plato cuenta con un identificador único, un nombre que no se repite en el menú, una descripción de los ingredientes que lo componen, un precio y cada uno es parte de una única categoría del menú. El plato puede estar más de una vez en un pedido, por lo que de cada plato pedido se guarda la cantidad y el precio que tenía en ese momento. El total del pedido no se guarda como un dato aparte, sino que se calcula con la suma de todos sus platos.

Un empleado del restaurante es identificado con su número de cédula, nombre completo, número de teléfono y fecha de ingreso al restaurante. Los empleados que se registran son meseros o chefs. El chef cuenta aparte con su título, especialidad y años de experiencia, y el mesero cuenta con su turno de trabajo (mañana, tarde o noche) para conocer el horario en el que trabajó. A cada pedido se le asigna el mesero que lo atendió, para poder identificarlo.

Cada pedido registra también al cliente que realizó la orden. De todo cliente se guarda su nombre, teléfono y correo de contacto, y puede ser anotado como persona natural o jurídica. En caso de persona natural se necesita su número de cédula, y en caso de persona jurídica el NIT de la empresa.

Ante esta necesidad, se propone el diseño e implementación de un sistema de información transaccional (OLTP) que permita registrar de forma estructurada el menú del restaurante, las mesas disponibles, los pedidos realizados por los clientes y los empleados que los atienden, sustituyendo el proceso manual y sentando las bases para el análisis posterior de la operación del negocio.

## Objetivo de la aplicación

Automatizar el registro y control de pedidos, mesas, menú, empleados y clientes del restaurante Selva Alegre, garantizando información confiable y oportuna para la operación diaria y la toma de decisiones.

## Reportes de interés

1. Platos más vendidos en un período determinado (top N).
2. Ventas totales agrupadas por día, semana o mes.
3. Desempeño por mesero: número de pedidos atendidos y valor total vendido por cada empleado.

## Historias de usuario

1. Como mesero, quiero registrar un nuevo pedido asociado a una mesa y a un cliente, para llevar el control de lo que se debe preparar y cobrar.
2. Como mesero, quiero agregar platos a un pedido indicando la cantidad de cada uno, para que el pedido refleje lo que pidió el cliente.
3. Como mesero, quiero consultar el estado de las mesas (libre u ocupada), para saber dónde ubicar a los clientes.
4. Como mesero, quiero actualizar el estado de un pedido (abierto, en preparación, entregado, pagado o cancelado), para saber en qué etapa está.
5. Como mesero, quiero consultar el total de un pedido calculado a partir de sus platos, para cobrar la cuenta sin errores.
6. Como mesero, quiero registrar los datos de un cliente como persona natural o jurídica, para asociarlo a sus pedidos.
7. Como chef, quiero consultar los pedidos en preparación con sus platos y cantidades, para saber qué debo cocinar.
8. Como administrador, quiero registrar y actualizar los platos del menú con su nombre, descripción, precio y categoría, para mantener el menú al día.
9. Como administrador, quiero que cada plato pedido guarde el precio que tenía en ese momento, para que un cambio en el menú no altere los pedidos anteriores.
10. Como administrador, quiero registrar las mesas con su número y capacidad, para saber cuántos clientes puede atender el local.
11. Como administrador, quiero registrar a los empleados como meseros o chefs con sus datos, para tener control del personal.
12. Como administrador, quiero que cada pedido quede asociado al mesero que lo atendió, para tener trazabilidad de la atención.
13. Como administrador, quiero ver los platos más vendidos en un período, para ajustar el menú.
14. Como administrador, quiero ver las ventas totales por día, semana o mes, para evaluar el desempeño del negocio.
15. Como administrador, quiero ver cuántos pedidos atendió cada mesero y su valor total vendido, para evaluar al personal.

Aclaración: el administrador es el dueño del restaurante y usuario del sistema, no es otra entidad.
