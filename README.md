# Pruebas de procedimientos almacenados (SQL Server)

Scaffolding para probar **procedimientos almacenados (SP)** de SQL Server con JUnit 6 y AssertJ.
Cada prueba:

1. se **alimenta de un CSV** (una fila = un caso),
2. sigue el patrón **ARRANGE → ACT → ASSERT** (SELECT → SP → SELECT),
3. genera un **reporte Excel** con lo esperado vs. lo obtenido en cada caso.

Cada caso corre en una transacción que termina con **rollback** (`BaseDBTest`): nada de lo que haga el SP queda guardado.

---

## Índice

1. [Requisitos y configuración](#1-requisitos-y-configuración)
2. [Estructura del proyecto](#2-estructura-del-proyecto)
3. [Patrones de diseño usados](#3-patrones-de-diseño-usados)
4. [Probar un SP nuevo, paso a paso](#4-probar-un-sp-nuevo-paso-a-paso)
5. [Validar datos de otras tablas](#5-validar-datos-de-otras-tablas)
6. [Verificaciones](#6-verificaciones)
7. [Reporte Excel y sus encabezados](#7-reporte-excel-y-sus-encabezados)
8. [Ejecutar las pruebas](#8-ejecutar-las-pruebas)
9. [Checklist para una prueba nueva](#9-checklist-para-una-prueba-nueva)
10. [Problemas frecuentes](#10-problemas-frecuentes)

---

## 1. Requisitos y configuración

- Java 21 y Maven.
- Una base de datos SQL Server de **desarrollo o pruebas**.

> ⚠️ **Nunca** apunte estas pruebas a una base de datos productiva.

Configure la conexión de una de estas dos formas:

**a) Archivo** (ignorado por git): copie `src/test/resources/db.properties.example` como `src/test/resources/db.properties` y complete:

```properties
db.url=jdbc:sqlserver://<servidor>;databaseName=<base_de_datos>;encrypt=false;trustServerCertificate=true;
db.user=<usuario>
db.password=<clave>
db.pool.size=5
```

**b) Variables de entorno** (tienen prioridad sobre el archivo): `DB_URL`, `DB_USER`, `DB_PASSWORD`, `DB_POOL_SIZE`.

---

## 2. Estructura del proyecto

```
src/
├── main/resources/sql/                      ← código fuente de los SPs bajo prueba (referencia)
└── test/
    ├── java/cmaccusco/rpando/
    │   ├── framework/                       ← NO se modifica para agregar pruebas
    │   │   ├── config/ConfiguracionBD       ← lee db.properties / variables de entorno
    │   │   ├── db/EjecutorSql               ← ejecuta SELECTs y SPs
    │   │   ├── db/MapeadorFila, LectorSalida
    │   │   ├── prueba/BaseDBTest            ← conexión + rollback + reporte
    │   │   ├── prueba/CasoPrueba            ← plantilla ARRANGE/ACT/ASSERT
    │   │   └── reporte/                     ← generación del Excel
    │   ├── datos/<bd>/                      ← tablas: record + Repositorio (SELECTs reutilizables)
    │   │   └── dbcmac/Producto, ProductoRepositorio, CaptacAhorros, ...
    │   └── <modulo>/                        ← un paquete por área funcional
    │       ├── sp/                          ← llamada al SP (Command) + record de respuesta
    │       └── Test<Algo>.java              ← las pruebas
    └── resources/
        ├── db.properties.example
        └── matriz_pruebas/<modulo>/*.csv    ← datos de entrada de cada prueba
```

Ejemplos de referencia ya implementados:

| Caso | Prueba | SP (Command) | CSV |
|---|---|---|---|
| Sin BD (flujo básico) | `ejemplos/TestSuma` | — | `matriz_pruebas/ejemplos/casos_prueba_suma.csv` |
| SP que devuelve un **SELECT** | `intrabancaria/TestTransferenciaXContacto#test_RespuestaSp` | `intrabancaria/sp/RegistraTransferenciaContacto` | `matriz_pruebas/intrabancaria/transferencia_x_contacto_respuesta.csv` |
| SP + validación de **otras tablas** | `intrabancaria/TestTransferenciaXContacto#test_NoOffHost` | idem | `matriz_pruebas/intrabancaria/transferencia_x_contacto_regular.csv` |
| SP con parámetros **OUTPUT** | `offhost/TestInicioOffHostDia` | `offhost/sp/InicioOffHostDia` | `matriz_pruebas/offhost/inicio_offhost_dia.csv` |

---

## 3. Patrones de diseño usados

| Patrón (GoF) | Tipo | Dónde | Para qué |
|---|---|---|---|
| Singleton | Creacional | `ConfiguracionBD`, `FuenteDatos` | Una sola configuración y un solo pool de conexiones |
| Builder | Creacional | `CasoReporte.Builder` | Armar paso a paso el resultado de un caso |
| Facade | Estructural | `EjecutorSql` | Ocultar JDBC: un SELECT o un SP en una línea |
| Command | Comportamiento | clases en `<modulo>/sp/` | Encapsular un SP y sus parámetros; si cambia la firma solo se toca esa clase |
| Template Method | Comportamiento | `CasoPrueba` | Fijar el orden ARRANGE → ACT → ASSERT y registrar siempre el resultado |
| Strategy | Comportamiento | `MapeadorFila`, `LectorSalida`, `EscritorReporte` | Cómo convertir una fila, leer OUTPUTs o escribir el reporte |
| Observer | Comportamiento | `ExtensionReporte` | Escribir el Excel al terminar cada clase de prueba |

Además, los `*Repositorio` de `datos/` siguen el patrón Repository (no GoF) para centralizar los SELECT.

---

## 4. Probar un SP nuevo, paso a paso

Ejemplo: probar `dbo.spu_RegistraPago` en un módulo nuevo `pagos`.

### Paso 1 — Guardar el SP como referencia

Copie el script a `src/main/resources/sql/spu_RegistraPago.sql`. Sirve para revisar firma, parámetros y el SELECT final.

### Paso 2 — Decidir cómo se valida la salida del SP

| El SP… | Use | Ejemplo existente |
|---|---|---|
| termina con un `SELECT` (código de respuesta, mensaje, etc.) | `sql.ejecutarSp(llamada, parametros, MAPEADOR)` | `RegistraTransferenciaContacto` |
| devuelve parámetros `OUTPUT` | `sql.ejecutarSpConSalida(llamada, parametros, lector)` | `InicioOffHostDia` |
| no devuelve nada (solo modifica tablas) | `sql.ejecutarSp(...)` ignorando el resultado y validar las tablas ([sección 5](#5-validar-datos-de-otras-tablas)) | — |

### Paso 3 — Record de respuesta (si el SP devuelve un SELECT)

`src/test/java/cmaccusco/rpando/pagos/sp/RespuestaPago.java`

```java
package cmaccusco.rpando.pagos.sp;

import cmaccusco.rpando.framework.db.MapeadorFila;

/** SELECT final de spu_RegistraPago. Para validar un campo nuevo, agréguelo aquí y en MAPEADOR. */
public record RespuestaPago(String cRespuesta, String cMensaje, String nIdOperacion) {

    public static final MapeadorFila<RespuestaPago> MAPEADOR = rs -> new RespuestaPago(
            rs.getString("cRespuesta"),
            rs.getString("cMensaje"),
            rs.getString("nIdOperacion"));

    /** Usada cuando el SP no devuelve filas. */
    public static final RespuestaPago VACIA = new RespuestaPago(null, null, null);
}
```

Los nombres de `rs.getString("...")` deben coincidir con los alias de columna del `SELECT` del SP.

### Paso 4 — Command del SP

`src/test/java/cmaccusco/rpando/pagos/sp/RegistraPago.java`

```java
package cmaccusco.rpando.pagos.sp;

import cmaccusco.rpando.framework.db.EjecutorSql;

import java.math.BigDecimal;
import java.sql.SQLException;

/** Llamada a dbo.spu_RegistraPago (fuente: src/main/resources/sql/spu_RegistraPago.sql). Patrón Command. */
public final class RegistraPago {

    private static final String SP = "{call spu_RegistraPago(?,?,?)}";

    private final String ctaCod;
    private final BigDecimal monto;
    private String usuario = "APP1";          // parámetro con valor por defecto

    private RegistraPago(String ctaCod, BigDecimal monto) {
        this.ctaCod = ctaCod;
        this.monto = monto;
    }

    /** Parámetros obligatorios. */
    public static RegistraPago de(String ctaCod, BigDecimal monto) {
        return new RegistraPago(ctaCod, monto);
    }

    /** Parámetros opcionales: métodos encadenables. */
    public RegistraPago usuario(String usuario) {
        this.usuario = usuario;
        return this;
    }

    public RespuestaPago ejecutar(EjecutorSql sql) throws SQLException {
        return sql.ejecutarSp(SP, cstmt -> {
            cstmt.setString(1, ctaCod);
            cstmt.setBigDecimal(2, monto);
            cstmt.setString(3, usuario);
        }, RespuestaPago.MAPEADOR).orElse(RespuestaPago.VACIA);
    }
}
```

**Variante con parámetros OUTPUT** (ver `offhost/sp/InicioOffHostDia.java`):

```java
public ResultadoCierre ejecutar(EjecutorSql sql) throws SQLException {
    return sql.ejecutarSpConSalida("{call spu_Cierre(?, ?, ?)}",
            cstmt -> {
                cstmt.setTimestamp(1, Timestamp.valueOf(fecha.atStartOfDay()));
                cstmt.registerOutParameter(2, Types.INTEGER);   // @Total OUTPUT
                cstmt.registerOutParameter(3, Types.VARCHAR);   // @Mensaje OUTPUT
            },
            cstmt -> new ResultadoCierre(
                    cstmt.getObject(2, Integer.class),           // getObject conserva NULL (getInt devolvería 0)
                    cstmt.getString(3)));
}
```

`ejecutarSpConSalida` consume todos los result sets antes de leer los OUTPUT (SQL Server los entrega al final), así que funciona aunque el SP también haga SELECTs.

### Paso 5 — CSV de casos

`src/test/resources/matriz_pruebas/pagos/registra_pago.csv`

```csv
cuenta,monto,respuesta_esperada,mensaje_esperado,descripcion
106172321000400249,50.00,00,,Pago correcto
106172321000400249,0,10,Monto inválido,Monto en cero
999999999999999999,50.00,20,,Cuenta inexistente
```

Reglas:

- La **primera línea es el encabezado** (se salta con `numLinesToSkip = 1`); sirve de documentación.
- El **orden de las columnas = orden de los parámetros** del método de prueba.
- La **última columna es `descripcion`**: aparece en el nombre del test y en el reporte.
- **Celda vacía = no validar** ese valor (con `verificarIgual`).
- JUnit convierte automáticamente a `String`, `int`/`Integer`, `BigDecimal`, `boolean`, `LocalDate` (`yyyy-MM-dd`), etc.
- Si un texto contiene comas, enciérrelo entre comillas dobles.

### Paso 6 — Clase de prueba

`src/test/java/cmaccusco/rpando/pagos/TestRegistraPago.java`

```java
package cmaccusco.rpando.pagos;

import cmaccusco.rpando.framework.prueba.BaseDBTest;
import cmaccusco.rpando.framework.prueba.CasoPrueba;
import cmaccusco.rpando.pagos.sp.RegistraPago;
import cmaccusco.rpando.pagos.sp.RespuestaPago;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvFileSource;

import java.math.BigDecimal;

class TestRegistraPago extends BaseDBTest {                          // conexión, rollback y reporte

    private static final String CSV = "/matriz_pruebas/pagos/registra_pago.csv";

    @ParameterizedTest(name = "[{index}] - {4}")                      // {4} = columna descripcion (base 0)
    @CsvFileSource(resources = CSV, numLinesToSkip = 1)
    void test_Respuesta(String cuenta, BigDecimal monto, String respuestaEsperada,
                        String mensajeEsperado, String descripcion) throws Exception {

        new CasoPrueba(getClass(), "Respuesta", descripcion) {        // "Respuesta" = hoja del Excel
            RespuestaPago r;

            @Override
            protected void act() throws Exception {
                r = RegistraPago.de(cuenta, monto).ejecutar(sql);
            }

            @Override
            protected void assertar() {
                verificarIgual("Respuesta", respuestaEsperada, r.cRespuesta());
                verificarIgual("Mensaje", mensajeEsperado, r.cMensaje());
            }
        }
                .parametro("Cuenta", cuenta)                          // columnas "Param: ..." del Excel
                .parametro("Monto", monto)
                .ejecutar();
    }
}
```

Puntos clave:

- La clase **extiende `BaseDBTest`**, que provee `sql` (`EjecutorSql`) y `conn`.
- `arrange()` es opcional; `act()` y `assertar()` son obligatorios.
- **No escriba SQL en la clase de prueba**: los SP van en `sp/` y los SELECT en `datos/`.
- Siempre termine con `.ejecutar()`; sin eso el caso no corre ni se reporta.

---

## 5. Validar datos de otras tablas

Muchos SPs no solo responden: **modifican tablas** (saldos, movimientos, bitácoras). Para validarlo:

- **ARRANGE**: leer el estado **antes** del SP.
- **ASSERT**: leer el estado **después** y comparar.

### 5.1 Crear el record y el repositorio de la tabla

Un repositorio por tabla, en `datos/<base_de_datos>/`, reutilizable por cualquier prueba.

`datos/dbcmac/Movimiento.java`

```java
package cmaccusco.rpando.datos.dbcmac;

import java.math.BigDecimal;

/** Fila de DBCMAC..Movimiento. Para usar un campo nuevo, agréguelo aquí y en el repositorio. */
public record Movimiento(String cCtaCod, String cOpeCod, BigDecimal nMonto) { }
```

`datos/dbcmac/MovimientoRepositorio.java`

```java
package cmaccusco.rpando.datos.dbcmac;

import cmaccusco.rpando.framework.db.EjecutorSql;
import cmaccusco.rpando.framework.db.MapeadorFila;

import java.sql.SQLException;
import java.util.List;

public class MovimientoRepositorio {

    private static final String SQL_POR_CUENTA =
            "SELECT cCtaCod, cOpeCod, nMonto FROM DBCMAC..Movimiento WITH(NOLOCK) WHERE cCtaCod = ?;";
    private static final String SQL_CONTAR =
            "SELECT COUNT(*) AS total FROM DBCMAC..Movimiento WITH(NOLOCK) WHERE cCtaCod = ?;";

    private static final MapeadorFila<Movimiento> MAPEADOR = rs -> new Movimiento(
            rs.getString("cCtaCod"),
            rs.getString("cOpeCod"),
            rs.getBigDecimal("nMonto"));

    private final EjecutorSql sql;

    public MovimientoRepositorio(EjecutorSql sql) {
        this.sql = sql;
    }

    /** Varias filas. */
    public List<Movimiento> porCuenta(String ctaCod) throws SQLException {
        return sql.consultarLista(SQL_POR_CUENTA, MAPEADOR, ctaCod);
    }

    /** Un solo valor. */
    public int contarPorCuenta(String ctaCod) throws SQLException {
        return sql.consultarValor(SQL_CONTAR, "total", Integer.class, 0, ctaCod);
    }
}
```

Métodos disponibles en `EjecutorSql`:

| Método | Devuelve | Uso |
|---|---|---|
| `consultarUno(sql, mapeador, params...)` | `Optional<T>` | Una fila |
| `consultarLista(sql, mapeador, params...)` | `List<T>` | Varias filas |
| `consultarValor(sql, columna, Tipo.class, porDefecto, params...)` | `T` | Un solo valor (COUNT, SUM, …) |

Convenciones:

- Use `?` para los parámetros; **nunca concatene valores** en el SQL.
- Use `WITH(NOLOCK)` en las lecturas, como en `ProductoRepositorio`.
- Si la fila **debe** existir, agregue un método `obtener(...)` que falle con un mensaje claro (ver `ProductoRepositorio#obtener`).
- ¿Necesita un campo más de una tabla que ya tiene repositorio? Agréguelo al `record`, al `SELECT` y al `MAPEADOR` del repositorio existente; no cree uno nuevo.

### 5.2 Usarlo en la prueba (antes / después)

Basado en `TestTransferenciaXContacto#test_NoOffHost`:

```java
@ParameterizedTest(name = "[{index}] - {3}")
@CsvFileSource(resources = CSV, numLinesToSkip = 1)
void test_Saldo(String cuenta, BigDecimal monto, String respuestaEsperada, String descripcion) throws Exception {
    ProductoRepositorio productos = new ProductoRepositorio(sql);
    MovimientoRepositorio movimientos = new MovimientoRepositorio(sql);

    new CasoPrueba(getClass(), "Saldo", descripcion) {
        Producto antes;
        int movimientosAntes;
        RespuestaPago r;

        @Override
        protected void arrange() throws Exception {                     // estado inicial
            antes = productos.obtener(cuenta);
            movimientosAntes = movimientos.contarPorCuenta(cuenta);
        }

        @Override
        protected void act() throws Exception {
            r = RegistraPago.de(cuenta, monto).ejecutar(sql);
        }

        @Override
        protected void assertar() throws Exception {                   // estado final
            Producto despues = productos.obtener(cuenta);
            int movimientosDespues = movimientos.contarPorCuenta(cuenta);

            verificarIgual("Respuesta", respuestaEsperada, r.cRespuesta());
            verificarIgual("Saldo", antes.nSaldo().subtract(monto), despues.nSaldo());
            verificarIgual("Cant. movimientos", movimientosAntes + 1, movimientosDespues);
        }
    }
            .parametro("Cuenta", cuenta)
            .parametro("Monto", monto)
            .ejecutar();
}
```

Como todo termina en rollback, los cambios del SP son visibles dentro del caso (misma conexión) pero no quedan en la base.

---

## 6. Verificaciones

Dentro de `assertar()` use siempre los métodos de `CasoPrueba`, **no** `assertThat` suelto: así cada comprobación aparece en el reporte.

### `verificarIgual(nombre, esperado, real)` — el caso común

- Si `esperado` es `null` o vacío (celda vacía en el CSV) **no valida** y no aparece en esa fila del reporte.
- Si alguno de los dos es numérico compara **por valor**: `"20"` == `20.00`.
- Si ambos son texto compara **como texto** (con `trim`): `"00"` ≠ `"0"`.

### `verificar(nombre, esperado, real, asercion)` — reglas propias

Para condiciones que no son igualdad. `esperado` y `real` solo se usan para el reporte; la regla la define la aserción:

```java
verificar("NroOperaciones informado", "no NULL", r.nroOperaciones(),
        () -> assertThat(r.nroOperaciones()).isNotNull());

verificar("Procesadas <= Operaciones", "<= " + r.nroOperaciones(), r.nroOperacionesProcesadas(),
        () -> assertThat(r.nroOperacionesProcesadas()).isLessThanOrEqualTo(r.nroOperaciones()));
```

### Verificación suave

Si una verificación falla, **las siguientes igual se ejecutan**. Al final el caso queda `FAILED` con todos los mensajes juntos en la columna *Detalle*, por ejemplo:
`Respuesta: expected "00" but was "80" | Mensaje: ...`.

Si `arrange()` o `act()` lanzan una excepción (SQL inválido, cuenta inexistente…), el caso se corta, queda `FAILED` y el mensaje de la excepción va en *Detalle*.

---

## 7. Reporte Excel y sus encabezados

Al terminar cada clase de prueba se genera:

```
target/reportes/<ClaseDePrueba>_<yyyyMMdd_HHmmss>.xlsx
```

### Cómo se arma

| Elemento del Excel | Sale de |
|---|---|
| **Archivo** | La clase de prueba (`TestRegistraPago` → `TestRegistraPago_20261103_101500.xlsx`) |
| **Hoja** | El *escenario*: 2º argumento de `new CasoPrueba(getClass(), "Respuesta", ...)` |
| **Fila** | Cada caso (fila del CSV) |
| Columna `Descripción del caso` | Columna `descripcion` del CSV |
| Columnas `Param: <nombre>` | Cada `.parametro("<nombre>", valor)` |
| Columnas `<nombre> - Esperado` / `<nombre> - Real` | Cada `verificar("<nombre>", ...)` / `verificarIgual("<nombre>", ...)` |
| `Estado` | `PASSED` (verde) / `FAILED` (rosado) |
| `Detalle` | Mensajes de error |

Ejemplo de la hoja **Respuesta** del test anterior:

| Descripción del caso | Param: Cuenta | Param: Monto | Respuesta - Esperado | Respuesta - Real | Mensaje - Esperado | Mensaje - Real | Estado | Detalle |
|---|---|---|---|---|---|---|---|---|
| Pago correcto | 1061723210… | 50.00 | 00 | 00 | | | PASSED | |
| Monto en cero | 1061723210… | 0 | 10 | 10 | Monto inválido | Monto inválido | PASSED | |
| Cuenta inexistente | 9999999999… | 50.00 | 20 | 80 | | | FAILED | Respuesta: expected "20" but was "80" |

### Cómo obtener reportes con encabezados diferentes

Los encabezados **no se configuran aparte**: salen de los nombres que use en el código.

- **Cambiar el texto de una columna** → cambie el nombre en `.parametro("...")` o en `verificar("...")` / `verificarIgual("...")`.
- **Agregar o quitar columnas** → agregue o quite llamadas a `.parametro(...)` / `verificar...(...)`. Un parámetro del CSV que no registre con `.parametro` no aparece en el reporte.
- **Hojas distintas en el mismo archivo** → use un escenario distinto en cada método de prueba (p. ej. `"Respuesta"`, `"Saldo"`, `"OffHost"`). Cada hoja tiene sus propias columnas.
- **Archivos distintos** → separe las pruebas en clases distintas.
- **Columnas que solo aplican a algunos casos** → la hoja une las columnas de todos sus casos; donde un caso no tiene valor la celda queda vacía (por ejemplo, cuando la celda del CSV estaba vacía y `verificarIgual` la omitió).
- **Mantener los mismos encabezados entre pruebas** → use exactamente el mismo texto (mayúsculas, tildes y espacios incluidos); dos nombres distintos generan dos columnas.

El orden de las columnas es el orden en que se registran: primero los parámetros, luego las verificaciones, ambos en orden de aparición.

### Otro formato de reporte

Si necesita un formato totalmente distinto (CSV, HTML, otro diseño de Excel), implemente `framework/reporte/EscritorReporte` y regístrelo en la clase de prueba con `@RegisterExtension` (no extienda `BaseDBTest` en ese caso, porque ya registra el escritor Excel; copie su manejo de conexión o cree una base equivalente):

```java
@RegisterExtension
static ExtensionReporte reporte = new ExtensionReporte(new MiEscritorHtml());
```

No modifique `EscritorReporteExcel` para un caso particular.

---

## 8. Ejecutar las pruebas

```bash
mvn test                                                   # todas
mvn test -Dtest=TestTransferenciaXContacto                 # una clase
mvn test -Dtest=TestTransferenciaXContacto#test_RespuestaSp  # un método
mvn test -Dtest=TestSuma                                   # ejemplo sin BD (útil para probar el entorno)
```

También puede ejecutarlas desde el IDE. Al final de cada clase verá en consola:

```
Reporte generado: C:\...\target\reportes\TestTransferenciaXContacto_20261103_101500.xlsx
```

`TestSuma` y `CasoPruebaTest` no usan base de datos; sirven para comprobar que el entorno y el reporte funcionan.

---

## 9. Checklist para una prueba nueva

- [ ] Script del SP en `src/main/resources/sql/`.
- [ ] Record de respuesta + `MAPEADOR` (SELECT) o lector de OUTPUT en `<modulo>/sp/`.
- [ ] Command del SP en `<modulo>/sp/` con `de(...)` y `ejecutar(sql)`.
- [ ] Repositorios en `datos/<bd>/` para cada tabla a validar (reutilice los existentes).
- [ ] CSV en `src/test/resources/matriz_pruebas/<modulo>/` con encabezado y `descripcion` al final.
- [ ] Clase `Test<Algo>` que extiende `BaseDBTest`, sin SQL dentro.
- [ ] `@ParameterizedTest(name = "[{index}] - {n}")` con `n` = índice de `descripcion`.
- [ ] Escenario con nombre claro (será la hoja del Excel).
- [ ] `.parametro(...)` para cada dato de entrada relevante y `.ejecutar()` al final.
- [ ] Revisar el `.xlsx` en `target/reportes/`.

---

## 10. Problemas frecuentes

| Síntoma | Causa / solución |
|---|---|
| `Configuración de BD incompleta...` | Falta `db.properties` o las variables `DB_URL`, `DB_USER`, `DB_PASSWORD`. |
| `ParameterResolutionException` / error de conversión | Las columnas del CSV no coinciden en cantidad u orden con los parámetros del método, o un valor no se puede convertir al tipo (p. ej. fecha que no es `yyyy-MM-dd`). |
| El record de respuesta viene todo en `null` | El SP no devolvió filas (se usa `VACIA`) o los nombres en `rs.getString("...")` no coinciden con los alias del SELECT del SP. |
| `SQLException: The column name X is not valid` | El `MAPEADOR` pide una columna que el SELECT no trae. |
| Parámetro OUTPUT siempre `NULL` | Revise el SP: el OUTPUT puede no asignarse nunca o sumarse sin inicializar (`NULL + 1 = NULL`). Use `getObject(i, Tipo.class)` para distinguir NULL de 0. |
| El SP no tiene `SET NOCOUNT ON` | No hace falta cambiarlo: `EjecutorSql` ignora los "update counts" previos. |
| No se generó el reporte | La clase no extiende `BaseDBTest` (ni tiene `@ExtendWith(ExtensionReporte.class)`) o el caso no llamó a `.ejecutar()`. |
| Una verificación no aparece en el reporte | Se usó `verificarIgual` con esperado vacío (se omite a propósito) o se usó `assertThat` directo en lugar de `verificar`. |
