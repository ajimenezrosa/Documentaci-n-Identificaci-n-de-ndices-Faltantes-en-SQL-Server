DROP TABLE #missingidx

create table #missingidx (

    DBName  VARCHAR(MAX),

    [DatabaseID] [smallint] NOT NULL,

    [Impacto_ponderado_estimado] [float] NULL,

    [Impacto_individual] [float] NULL,

    [Num_ejecuciones] [bigint] NULL,

    [Last_User_Seek] [datetime] NULL,

    [TableName] [nvarchar](128) NULL,

    [Create_Statement] [nvarchar](4000) NULL )

 

 

DECLARE @SQL VARCHAR(max) 

DECLARE @DB sysname 

DECLARE curDB CURSOR FORWARD_ONLY STATIC FOR 

   SELECT [name] 

   FROM master..sysdatabases

   WHERE [name] not in ('master')

    

OPEN curDB 

FETCH NEXT FROM curDB INTO @DB 

WHILE @@FETCH_STATUS = 0 

   BEGIN 

       SELECT @SQL = 'USE [' + @DB +']' + CHAR(13) +

'INSERT INTO #missingidx SELECT TOP 10

DB_NAME() as DBName,

dm_mid.database_id AS DatabaseID,

dm_migs.avg_user_impact*(dm_migs.user_seeks+dm_migs.user_scans) As Impacto_ponderado_estimado,

dm_migs.avg_user_impact as Impacto_individual,

dm_migs.user_seeks+dm_migs.user_scans as Num_ejecuciones,

dm_migs.last_user_seek AS Last_User_Seek,

OBJECT_NAME(dm_mid.OBJECT_ID,dm_mid.database_id) AS [TableName],

''CREATE INDEX [IX_'' + OBJECT_NAME(dm_mid.OBJECT_ID,dm_mid.database_id) + ''_''

+ REPLACE(REPLACE(REPLACE(ISNULL(dm_mid.equality_columns,''''),'', '',''_''),''['',''''),'']'','''')

+ CASE

WHEN dm_mid.equality_columns IS NOT NULL

AND dm_mid.inequality_columns IS NOT NULL THEN ''_''

ELSE ''''

END

+ REPLACE(REPLACE(REPLACE(ISNULL(dm_mid.inequality_columns,''''),'', '',''_''),''['',''''),'']'','''')

+ '']''

+ '' ON '' + dm_mid.statement

+ '' ('' + ISNULL (dm_mid.equality_columns,'''')

+ CASE WHEN dm_mid.equality_columns IS NOT NULL AND dm_mid.inequality_columns

IS NOT NULL THEN '','' ELSE

'''' END

+ ISNULL (dm_mid.inequality_columns, '''')

+ '')''

+ ISNULL ('' INCLUDE ('' + dm_mid.included_columns + '')'', '''') AS Create_Statement

FROM sys.dm_db_missing_index_groups dm_mig

INNER JOIN sys.dm_db_missing_index_group_stats dm_migs

ON dm_migs.group_handle = dm_mig.index_group_handle

INNER JOIN sys.dm_db_missing_index_details dm_mid

ON dm_mig.index_handle = dm_mid.index_handle

WHERE dm_mid.database_ID = DB_ID()

ORDER BY Impacto_ponderado_estimado DESC'  + CHAR(13) 

 

       EXEC(@SQL) 

       FETCH NEXT FROM curDB INTO @DB 

   END 

    

CLOSE curDB 

DEALLOCATE curDB

 

SELECT * FROM #missingidx order by 1,3 desc