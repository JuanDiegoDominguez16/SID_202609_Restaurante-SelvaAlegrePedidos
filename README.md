# Selva Alegre – Sistema de pedidos

Proyecto de curso de **Sistemas Intensivos en Datos** (2026-2).
Diseño e implementación de la base de datos de un sistema de información transaccional (OLTP) para el restaurante **Selva Alegre**, un local de comida típica colombiana con servicio en mesa que hoy lleva pedidos, mesas y cuentas en papel.

## Equipo

| Integrante | Rol |
|---|---|
| Juan Diego Domínguez | Líder, coordinador y encargado de consistencia  |
| Valeria Valencia | Encargada de modelado MER y MR  |
| Santiago Cabal | Encargado de QA, documentacion, SQL y PL/SQL|

## Estado de las entregas

| Entrega | Contenido | Estado |
|---|---|---|
| 0 | Caso de estudio y requerimientos | Entregada |
| 1 | Modelo conceptual (MER) | Entregada |
| 2 | Modelo relacional en 3FN | En cierre (ver pendientes en `docs/bitacora-reuniones.md`) |
| 3 | SQL, PL/SQL y sustentación | Pendiente (`src/`) |

## Estructura del repositorio

```
README.md
docs/        Documentación del caso y del trabajo en equipo
model/      Modelos de Data Modeler (PDF + fuentes)
src/        Scripts SQL y PL/SQL (Entrega 3)
```

### `docs/`

- [Descripción del caso](docs/descripcion-del-caso.md): enunciado, objetivo, reportes, historias de usuario y origen del caso.
- [Dependencias funcionales](docs/dependencias-funcionales.md): evidencia de normalización a 3FN.
- [Acuerdos de equipo](docs/acuerdos-equipo.md): roles, responsabilidades, estrategia y cronograma.
- [Bitácora de reuniones](docs/bitacora-reuniones.md)
- [Actas de reuniones en clase](docs/actas-clase.md)
- [Bitácora de prompts de IA](docs/bitacora-prompts.md)
- Entregas anteriores: [Entrega 0](docs/Entrega0.docsx) y [Entrega 1](docs/Entrega1.pdf).
- [Versiones anteriores de los modelos](docs/historico/) (solo consulta).

### `model/`

| Modelo | PDF | Fuentes |
|---|---|---|
| Conceptual (MER) | [MER-V2.pdf](model/conceptual/MER-V2.pdf) | [ProyectoSIDMER-MR.zip](model/fuentes/ProyectoSIDMER-MR.zip) |
| Relacional (3FN) | [Relational.pdf](model/relational/Relational.pdf) | [ProyectoSIDMER-MR.zip](model/fuentes/ProyectoSIDMER-MR.zip) |

Un mismo proyecto de Data Modeler contiene el modelo lógico (MER) y el relacional.

### `src/`

Reservada para la Entrega 3: script DDL, script DML (inserts), consultas DQL de los tres reportes y script PL/SQL (procedimiento, función y trigger).

## Cómo abrir el modelo en Data Modeler

1. Descomprime `model/fuentes/ProyectoSIDMER-MR.zip` en una carpeta vacía. Deben quedar **lado a lado** `ProyectoSIDMER-MR.dmd` y la carpeta `ProyectoSIDMER-MR/`.
2. En Oracle SQL Developer Data Modeler: **File ▸ Open** y elige `ProyectoSIDMER-MR.dmd`.
3. Si haces cambios, guarda desde Data Modeler, vuelve a comprimir **el `.dmd` y su carpeta juntos** (sin carpetas intermedias) y reemplaza el zip en `model/fuentes/`.
4. Re-exporta los PDF (File ▸ Print Diagram ▸ To PDF) y reemplázalos en `model/`.

> Un `.dmd` sin su carpeta se abre vacío: el archivo solo guarda el encabezado del diseño.
