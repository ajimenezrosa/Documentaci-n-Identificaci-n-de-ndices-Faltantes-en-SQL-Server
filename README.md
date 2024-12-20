# Documentación: Identificación de Índices Faltantes en SQL Server

**Autor:** José Alejandro Jiménez Rosa  

## Descripción
Este script SQL tiene como propósito identificar índices faltantes en todas las bases de datos de una instancia de SQL Server. Utiliza las vistas de administración dinámica (DMVs) para evaluar el impacto de estos índices en el rendimiento del sistema. Los resultados incluyen las bases de datos, tablas afectadas y sugerencias de creación de índices basadas en la actividad de las consultas.

## ¿Qué hace este script?
1. Crea una tabla temporal `#missingidx` para almacenar los resultados.
2. Recorre todas las bases de datos (excepto `master`) utilizando un cursor.
3. Extrae información relevante sobre índices faltantes, incluyendo:
   - Nombre de la base de datos
   - Impacto ponderado estimado
   - Número de ejecuciones
   - Fecha de la última consulta
   - Declaración para la creación del índice sugerido
4. Ordena los resultados por base de datos e impacto.

## Cómo usarlo
### Requisitos previos
1. Acceso a una instancia de SQL Server con permisos suficientes para ejecutar consultas sobre las DMVs.
2. Preferentemente, ejecutar en un entorno de prueba antes de usar en producción.

### Pasos para ejecutar el script
1. Abra un editor SQL (por ejemplo, SQL Server Management Studio - SSMS).
2. Copie y pegue el código del script en una nueva consulta.
3. Ejecute el script. Esto creará la tabla temporal y llenará los datos correspondientes.
4. Revise los resultados utilizando el comando final:
    ```sql
    SELECT * FROM #missingidx ORDER BY 1, 3 DESC;
    ```
5. Analice las recomendaciones de índices y evalúe si son aplicables a su entorno.

### Código del Script
```sql
DROP TABLE IF EXISTS #missingidx;

CREATE TABLE #missingidx (
    DBName VARCHAR(MAX),
    [DatabaseID] SMALLINT NOT NULL,
    [Impacto_ponderado_estimado] FLOAT NULL,
    [Impacto_individual] FLOAT NULL,
    [Num_ejecuciones] BIGINT NULL,
    [Last_User_Seek] DATETIME NULL,
    [TableName] NVARCHAR(128) NULL,
    [Create_Statement] NVARCHAR(4000) NULL
);

DECLARE @SQL VARCHAR(MAX);
DECLARE @DB SYSNAME;
DECLARE curDB CURSOR FORWARD_ONLY STATIC FOR 
    SELECT [name] 
    FROM master..sysdatabases
    WHERE [name] NOT IN ('master');

OPEN curDB;
FETCH NEXT FROM curDB INTO @DB;

WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @SQL = 'USE [' + @DB + ']' + CHAR(13) +
    'INSERT INTO #missingidx SELECT TOP 10
    DB_NAME() AS DBName,
    dm_mid.database_id AS DatabaseID,
    dm_migs.avg_user_impact * (dm_migs.user_seeks + dm_migs.user_scans) AS Impacto_ponderado_estimado,
    dm_migs.avg_user_impact AS Impacto_individual,
    dm_migs.user_seeks + dm_migs.user_scans AS Num_ejecuciones,
    dm_migs.last_user_seek AS Last_User_Seek,
    OBJECT_NAME(dm_mid.OBJECT_ID, dm_mid.database_id) AS [TableName],
    ''CREATE INDEX [IX_'' + OBJECT_NAME(dm_mid.OBJECT_ID, dm_mid.database_id) + ''_''
    + REPLACE(REPLACE(REPLACE(ISNULL(dm_mid.equality_columns, ''''), '', '',''_''), ''['',''''), '']'','''')
    + CASE
        WHEN dm_mid.equality_columns IS NOT NULL
        AND dm_mid.inequality_columns IS NOT NULL THEN ''_''
        ELSE ''''
      END
    + REPLACE(REPLACE(REPLACE(ISNULL(dm_mid.inequality_columns, ''''), '', '',''_''), ''['',''''), '']'','''')
    + '']''
    + '' ON '' + dm_mid.statement
    + '' ('' + ISNULL(dm_mid.equality_columns, '''')
    + CASE WHEN dm_mid.equality_columns IS NOT NULL AND dm_mid.inequality_columns IS NOT NULL THEN '','' ELSE '''' END
    + ISNULL(dm_mid.inequality_columns, '''')
    + '')''
    + ISNULL('' INCLUDE ('' + dm_mid.included_columns + '')'', '''') AS Create_Statement
    FROM sys.dm_db_missing_index_groups dm_mig
    INNER JOIN sys.dm_db_missing_index_group_stats dm_migs
        ON dm_migs.group_handle = dm_mig.index_group_handle
    INNER JOIN sys.dm_db_missing_index_details dm_mid
        ON dm_mig.index_handle = dm_mid.index_handle
    WHERE dm_mid.database_ID = DB_ID()
    ORDER BY Impacto_ponderado_estimado DESC;' + CHAR(13);

    EXEC(@SQL);
    FETCH NEXT FROM curDB INTO @DB;
END;

CLOSE curDB;
DEALLOCATE curDB;

SELECT * FROM #missingidx
ORDER BY 1, 3 DESC;
```

## Resultados Esperados
Una tabla con información detallada sobre índices faltantes, que incluye:
- **Nombre de la base de datos:** Identifica la base de datos analizada.
- **Impacto estimado:** Proporciona una métrica del impacto esperado en el rendimiento.
- **Declaración de creación del índice:** Código para crear el índice sugerido.

---

Este script es ideal para administradores de bases de datos que buscan mejorar el rendimiento de sus sistemas a través de la optimización de índices. Si tienes dudas o comentarios, no dudes en contactarme.

---
