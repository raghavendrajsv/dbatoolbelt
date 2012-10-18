/*

http://www.sqlservercentral.com/articles/Database+Design/70314/

	Script   : DatabaseTestProcs.SQL
	-----------------------------------------------------------------------------
	Author   : Dave.Poole
	Date     : 22-Feb-2010
	Version  : 1.0
 -----------------------------------------------------------------------------
	MODIFICATIONS                                                           
	=============
	Version		Date        	Author  Notes
	-------		-----------		------	-----
	1.0			22-Feb-2010		DJP		Initial creation.
 -----------------------------------------------------------------------------
	GENERAL NOTES
	=================
	This script sets up stored procedures to implement tests against the database
	
	The list of tests will grow over time as the testing sophistication grows.
	
	It is assumed that these checks will eventually be run from Cruise Control.
	
	The list of tests procs is as follows: -
	1.	dbo.TestDRIConstraints - Checks for system generated primary and foreign keys.
	2.	dbo.TestDefaultConstraints - Checks for system generated default constraints
	3.	dbo.TestDomainConstraints - Checks for system generated check or unique constraints
	4.	dbo.TestParitionTableStructure - Checks that the partition switch table structure matches the main table
	5.	dbo.TestForAbsentPK - Checks that all tables have primary keys
	6.	dbo.TestForAbsentClusteredIndex - Checks that all tables have clustered keys
	7.	dbo.TestForReservedWords - Checks to see if any user objects have been created using reserved words.
*/
SET XACT_ABORT ON
SET NOCOUNT ON
GO
-----------------------------------------------------------------------------
DECLARE
	@UserName SYSNAME ,
	@DeploymentTime CHAR(18),
	@DeploymentDB SYSNAME,
	@CRLF CHAR(2)

SET	@CRLF = CHAR(13)+CHAR(10)
SET @UserName = SUSER_SNAME()+@CRLF
SET @DeploymentTime = CONVERT(CHAR(16),GETDATE(),120)+@CRLF
SET @DeploymentDB = DB_NAME()+@CRLF
PRINT '*******************************************'
RAISERROR('DEPLOYMENT SERVER: %s%sDEPLOYMENT DB: %sDEPLOYMENT TIME:%sDEPLOYER: %s',10,1,@@SERVERNAME,@CRLF,@DeploymentDB,@DeploymentTime,@UserName)
PRINT 'Script   : DatabaseTestProcs.SQL'
PRINT '*******************************************'
GO
-----------------------------------------------------------------------------
DECLARE @SQL VARCHAR(8000) , @CRLF CHAR(2)
SET @CRLF = CHAR(13)+CHAR(10)
SELECT @SQL=COALESCE(@SQL+';'+@CRLF,'') 
+	'DROP PROC '
+	QUOTENAME(ROUTINE_SCHEMA)
+	'.'
+	QUOTENAME(ROUTINE_NAME)
FROM INFORMATION_SCHEMA.routines
WHERE ROUTINE_NAME IN (
	'TestDRIConstraints',
	'TestDefaultConstraints',
	'TestDomainConstraints',
	'TestForAbsentPK',
	'TestForAbsentClusteredIndex',
	'TestForReservedWords'
)
PRINT @SQL
EXEC(@SQL)
go
--##SUMMARY Test to see whether or not system generated primary or foreign key constraints exist
--##PARAM @RETURN_VALUE 0 = Success<br />All other values indicate the number of constraints incorrectly named.
CREATE PROC dbo.TestDRIConstraints
AS 
SET NOCOUNT ON

DECLARE
	@ReturnValue INT ,
	@ErrorValue INT

SELECT QUOTENAME(TABLE_SCHEMA)+'.'+quotename(TABLE_NAME) AS FullyQualifiedTableName,CONSTRAINT_NAME,CONSTRAINT_TYPE
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
WHERE  CONSTRAINT_NAME LIKE '%[_][_][A-F0-9][A-F0-9][A-F0-9][A-F0-9][A-F0-9][A-F0-9][A-F0-9][A-F0-9]%'
AND OBJECTPROPERTY(OBJECT_ID(TABLE_NAME),'IsMSShipped')=0
ORDER BY 3,1,2

SET @ReturnValue = @@ROWCOUNT

IF @ReturnValue>0
	BEGIN
		RAISERROR('*** FAILED ***:  %i system generated DRI constraint names',16,1) WITH nowait
	END
	
RETURN @ReturnValue
GO
IF @@ERROR = 0
	BEGIN
		PRINT 'PROC CREATED: dbo.TestDRIConstraints'
	END
ELSE
	BEGIN
		PRINT '*** FAILED PROC CREATION: dbo.TestDRIConstraints'
	END
go
--##SUMMARY Test to see whether or not system generated default constraints exist
--##PARAM @RETURN_VALUE 0 = Success<br />All other values indicate the number of constraints incorrectly named.
CREATE PROC dbo.TestDefaultConstraints
AS 
SET NOCOUNT ON

DECLARE
	@ReturnValue INT ,
	@ErrorValue INT

SELECT OBJECT_NAME(parent_obj),name  ,xtype
FROM sysobjects
WHERE xtype='D'
AND  name LIKE '%[_][_][A-F0-9][A-F0-9][A-F0-9][A-F0-9][A-F0-9][A-F0-9][A-F0-9][A-F0-9]'
AND OBJECTPROPERTY(parent_obj,'IsMSShipped')=0

SET @ReturnValue = @@ROWCOUNT

IF @ReturnValue>0
	BEGIN
		RAISERROR('*** FAILED ***:  %i system generated default constraint names',16,1) WITH nowait
	END
	
RETURN @ReturnValue
GO
IF @@ERROR = 0
	BEGIN
		PRINT 'PROC CREATED: dbo.TestDefaultConstraints'
	END
ELSE
	BEGIN
		PRINT '*** FAILED PROC CREATION: dbo.TestDefaultConstraints'
	END
go
--##SUMMARY Test to see whether or not system generated domain constraints exist.<ul><li>Check constraints</li><li>Unique constraints</li></ul>
--##PARAM @RETURN_VALUE 0 = Success<br />All other values indicate the number of constraints incorrectly named.
CREATE PROC dbo.TestDomainConstraints
AS 
SET NOCOUNT ON

DECLARE
	@ReturnValue INT ,
	@ErrorValue INT

SELECT OBJECT_NAME(parent_obj),name
FROM sysobjects
WHERE xtype IN ('C','UQ')
AND  name LIKE '%[_][_][A-F0-9][A-F0-9][A-F0-9][A-F0-9][A-F0-9][A-F0-9][A-F0-9][A-F0-9]'
AND OBJECTPROPERTY(parent_obj,'IsMSShipped')=0

SET @ReturnValue = @@ROWCOUNT

IF @ReturnValue>0
	BEGIN
		RAISERROR('*** FAILED ***:  %i system generated domain constraint names',16,1) WITH nowait
	END
	
RETURN @ReturnValue
GO
IF @@ERROR = 0
	BEGIN
		PRINT 'PROC CREATED: dbo.TestDomainConstraints'
	END
ELSE
	BEGIN
		PRINT '*** FAILED PROC CREATION: dbo.TestDomainConstraints'
	END
go
--##SUMMARY Lists any tables that do not have a primary key constraint
--##ISNEW 16-Mar-2010
CREATE PROC dbo.TestForAbsentPK
AS
SET NOCOUNT ON

DECLARE
	@ReturnValue INT 

SELECT 
	SCHEMA_NAME(Cast(OBJECTPROPERTYEX(T.id,'SchemaID') AS INT)) AS SchemaName,
	T.name AS TableName
 FROM sysobjects AS T
	LEFT JOIN sysobjects AS PK
	ON T.id = PK.parent_obj
	AND PK.xtype='PK'
WHERE T.xtype='U'
AND OBJECTPROPERTY(T.id,'IsMSShipped')=0
AND PK.id IS NULL

SET @ReturnValue = @@ROWCOUNT
IF @ReturnValue >0
	BEGIN
		RAISERROR('*** FAILED ***: Primary keys are missing in %i cases',16,1,@ReturnValue ) WITH NOWAIT
	END
GO
IF @@ERROR = 0
	BEGIN
		PRINT 'PROC CREATED: dbo.TestForAbsentPK'
	END
ELSE
	BEGIN
		PRINT '*** FAILED PROC CREATION: dbo.TestForAbsentPK'
	END
GO
--##SUMMARY Lists any tables that do not have a clustered index
CREATE PROC dbo.TestForAbsentClusteredIndex
AS
SET NOCOUNT ON

DECLARE
	@ReturnValue INT 

SELECT 
	SCHEMA_NAME(Cast(OBJECTPROPERTYEX(T.id,'SchemaID') AS INT)) AS SchemaName,
	T.name AS TableName
 FROM sysobjects AS T
	LEFT JOIN sysindexes AS CI
	ON T.id = CI.id
	AND CI.indid=1
WHERE T.xtype='U'
AND OBJECTPROPERTY(T.id,'IsMSShipped')=0
AND CI.id IS NULL

SET @ReturnValue = @@ROWCOUNT
IF @ReturnValue >0
	BEGIN
		RAISERROR('*** FAILED ***: Clustered keys are missing in %i cases',16,1,@ReturnValue ) WITH NOWAIT
	END
GO
IF @@ERROR = 0
	BEGIN
		PRINT 'PROC CREATED: dbo.TestForAbsentClusteredIndex'
	END
ELSE
	BEGIN
		PRINT '*** FAILED PROC CREATION: dbo.TestForAbsentClusteredIndex'
	END
GO
-----------------------------------------------------------------------------
IF NOT EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME='ReservedWords' AND TABLE_SCHEMA='dbo')
	BEGIN
		CREATE TABLE dbo.ReservedWords (
			ReservedWord SYSNAME NOT NULL 
				CONSTRAINT PK_ReservedWords PRIMARY KEY CLUSTERED,
			CONSTRAINT CK_ReservedWords_Description CHECK (LEN(LTRIM(ReservedWord))>0)
		)
		PRINT 'TABLE CREATED: dbo.ReservedWords'
	END
ELSE
	PRINT 'TABLE ALREADY CREATED: dbo.ReservedWords'
GO
-----------------------------------------------------------------------------
-- Document the dbo.ReservedWords table
-----------------------------------------------------------------------------
IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME='ReservedWords' AND TABLE_SCHEMA='dbo')
	BEGIN
		DECLARE @v sql_variant  ,
			@TableName SYSNAME ,
			@ColumnName SYSNAME
		SET @TableName='ReservedWords'
		SET @v = N'Holds a list of SQL Reserved words against which entries in sysobjects and sysindexes can be checked'


		IF EXISTS(SELECT 1 FROM   ::fn_listextendedproperty (NULL, 'schema', 'dbo', 'table', @TableName, default, default))
			EXECUTE sp_updateextendedproperty N'MS_Description', @v, N'schema', N'dbo', N'table', @TableName, NULL, NULL
		ELSE
			EXECUTE sp_addextendedproperty N'MS_Description', @v, N'schema', N'dbo', N'table', @TableName, NULL, NULL

		-- Copy the following block of code for each column
		SET @ColumnName = 'ReservedWord'
		SET @v = N'This is the SQL reserved word which should not be used under any circumstances for object names.'
		IF EXISTS(SELECT * FROM   ::fn_listextendedproperty (NULL, 'schema', 'dbo', 'table', @TableName, 'column', @ColumnName))
			EXECUTE sp_updateextendedproperty N'MS_Description', @v, N'schema', N'dbo', N'table', @TableName, N'column', @ColumnName
		ELSE
			EXECUTE sp_addextendedproperty N'MS_Description', @v, N'schema', N'dbo', N'table', @TableName, N'column', @ColumnName
	END
GO
-----------------------------------------------------------------------------
-- Populate a table variable with the list of reserved words.
-----------------------------------------------------------------------------
DECLARE @ReservedWords TABLE (ReservedWord sysname NOT NULL PRIMARY KEY CLUSTERED)
INSERT INTO @ReservedWords(ReservedWord) VALUES('A')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ABORT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ABS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ABSOLUTE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ACCESS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ACOS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ACQUIRE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ACTION')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ACTIVATE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ADA')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ADD')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ADDFORM')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ADMIN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('AFTER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('AGGREGATE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ALIAS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ALL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ALLOCATE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ALTER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('AN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ANALYZE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('AND')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ANY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('APPEND')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ARCHIVE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ARCHIVELOG')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ARE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ARRAY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ARRAYLEN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('AS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ASC')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ASCII')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ASIN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ASSERTION')
INSERT INTO @ReservedWords(ReservedWord) VALUES('AT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ATAN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('AUDIT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('AUTHORIZATION')
INSERT INTO @ReservedWords(ReservedWord) VALUES('AVG')
INSERT INTO @ReservedWords(ReservedWord) VALUES('AVGU')
INSERT INTO @ReservedWords(ReservedWord) VALUES('BACKUP')
INSERT INTO @ReservedWords(ReservedWord) VALUES('BECOME')
INSERT INTO @ReservedWords(ReservedWord) VALUES('BEFORE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('BEGIN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('BETWEEN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('BIGINT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('BINARY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('BIND')
INSERT INTO @ReservedWords(ReservedWord) VALUES('BINDING')
INSERT INTO @ReservedWords(ReservedWord) VALUES('BIT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('BIT_LENGTH')
INSERT INTO @ReservedWords(ReservedWord) VALUES('BLOB')
INSERT INTO @ReservedWords(ReservedWord) VALUES('BLOCK')
INSERT INTO @ReservedWords(ReservedWord) VALUES('BODY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('BOOLEAN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('BOTH')
INSERT INTO @ReservedWords(ReservedWord) VALUES('BREADTH')
INSERT INTO @ReservedWords(ReservedWord) VALUES('BREAK')
INSERT INTO @ReservedWords(ReservedWord) VALUES('BREAKDISPLAY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('BROWSE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('BUFFERPOOL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('BULK')
INSERT INTO @ReservedWords(ReservedWord) VALUES('BY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('BYREF')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CACHE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CALL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CALLPROC')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CANCEL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CAPTURE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CASCADE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CASCADED')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CASE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CAST')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CATALOG')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CCSID')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CEILING')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CHANGE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CHAR')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CHAR_LENGTH')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CHARACTER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CHARACTER_LENGTH')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CHARTOROWID')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CHECK')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CHECKPOINT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CHR')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CLASS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CLEANUP')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CLEAR')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CLEARROW')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CLOB')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CLOSE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CLUSTER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CLUSTERED')
INSERT INTO @ReservedWords(ReservedWord) VALUES('COALESCE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('COBOL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('COLGROUP')
INSERT INTO @ReservedWords(ReservedWord) VALUES('COLLATE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('COLLATION')
INSERT INTO @ReservedWords(ReservedWord) VALUES('COLLECTION')
INSERT INTO @ReservedWords(ReservedWord) VALUES('COLUMN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('COMMAND')
INSERT INTO @ReservedWords(ReservedWord) VALUES('COMMENT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('COMMIT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('COMMITTED')
INSERT INTO @ReservedWords(ReservedWord) VALUES('COMPILE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('COMPLETION')
INSERT INTO @ReservedWords(ReservedWord) VALUES('COMPLEX')
INSERT INTO @ReservedWords(ReservedWord) VALUES('COMPRESS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('COMPUTE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CONCAT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CONFIRM')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CONNECT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CONNECTION')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CONSTRAINT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CONSTRAINTS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CONSTRUCTOR')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CONTAINS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CONTAINSTABLE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CONTENTS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CONTINUE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CONTROLFILE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CONTROLROW')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CONVERSATION')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CONVERT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('COPY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CORRESPONDING')
INSERT INTO @ReservedWords(ReservedWord) VALUES('COS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('COUNT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('COUNTU')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CREATE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CROSS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CUBE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CURRENT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CURRENT_DATE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CURRENT_PATH')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CURRENT_ROLE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CURRENT_TIME')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CURRENT_TIMESTAMP')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CURRENT_USER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CURSOR')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CVAR')
INSERT INTO @ReservedWords(ReservedWord) VALUES('CYCLE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DATA')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DATABASE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DATAFILE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DATAHANDLER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DATAPAGES')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DATE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DAY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DAYOFMONTH')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DAYOFWEEK')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DAYOFYEAR')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DAYS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DBA')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DBCC')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DBSPACE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DEALLOCATE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DEC')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DECIMAL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DECLARATION')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DECLARE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DECODE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DEFAULT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DEFERRABLE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DEFERRED')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DEFINE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DEFINITION')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DEGREES')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DELETE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DELETEROW')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DENY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DEPTH')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DEREF')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DESC')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DESCRIBE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DESCRIPTOR')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DESTROY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DESTRUCTOR')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DETERMINISTIC')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DHTYPE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DIAGNOSTICS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DICTIONARY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DIRECT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DISABLE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DISCONNECT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DISK')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DISMOUNT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DISPLAY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DISTINCT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DISTRIBUTE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DISTRIBUTED')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DO')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DOMAIN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DOUBLE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DOWN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DROP')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DUMMY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DUMP')
INSERT INTO @ReservedWords(ReservedWord) VALUES('DYNAMIC')
INSERT INTO @ReservedWords(ReservedWord) VALUES('EACH')
INSERT INTO @ReservedWords(ReservedWord) VALUES('EDITPROC')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ELSE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ELSEIF')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ENABLE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('END')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ENDDATA')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ENDDISPLAY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ENDEXEC')
INSERT INTO @ReservedWords(ReservedWord) VALUES('END-EXEC')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ENDFORMS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ENDIF')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ENDLOOP')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ENDSELECT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ENDWHILE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('EQUALS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ERASE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ERRLVL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ERROREXIT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ESCAPE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('EVENTS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('EVERY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('EXCEPT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('EXCEPTION')
INSERT INTO @ReservedWords(ReservedWord) VALUES('EXCEPTIONS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('EXCLUDE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('EXCLUDING')
INSERT INTO @ReservedWords(ReservedWord) VALUES('EXCLUSIVE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('EXEC')
INSERT INTO @ReservedWords(ReservedWord) VALUES('EXECUTE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('EXISTS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('EXIT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('EXP')
INSERT INTO @ReservedWords(ReservedWord) VALUES('EXPLAIN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('EXPLICIT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('EXTENT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('EXTERNAL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('EXTERNALLY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('EXTRACT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('FALSE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('FETCH')
INSERT INTO @ReservedWords(ReservedWord) VALUES('FIELD')
INSERT INTO @ReservedWords(ReservedWord) VALUES('FIELDPROC')
INSERT INTO @ReservedWords(ReservedWord) VALUES('FILE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('FILLFACTOR')
INSERT INTO @ReservedWords(ReservedWord) VALUES('FINALIZE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('FIRST')
INSERT INTO @ReservedWords(ReservedWord) VALUES('FLOAT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('FLOOR')
INSERT INTO @ReservedWords(ReservedWord) VALUES('FLOPPY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('FLUSH')
INSERT INTO @ReservedWords(ReservedWord) VALUES('FOR')
INSERT INTO @ReservedWords(ReservedWord) VALUES('FORCE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('FOREIGN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('FORMDATA')
INSERT INTO @ReservedWords(ReservedWord) VALUES('FORMINIT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('FORMS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('FORTRAN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('FOUND')
INSERT INTO @ReservedWords(ReservedWord) VALUES('FREE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('FREELIST')
INSERT INTO @ReservedWords(ReservedWord) VALUES('FREELISTS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('FREETEXT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('FREETEXTTABLE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('FROM')
INSERT INTO @ReservedWords(ReservedWord) VALUES('FULL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('FULLTEXTTABLE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('FUNCTION')
INSERT INTO @ReservedWords(ReservedWord) VALUES('GENERAL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('GET')
INSERT INTO @ReservedWords(ReservedWord) VALUES('GETCURRENTCONNECTION')
INSERT INTO @ReservedWords(ReservedWord) VALUES('GETFORM')
INSERT INTO @ReservedWords(ReservedWord) VALUES('GETOPER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('GETROW')
INSERT INTO @ReservedWords(ReservedWord) VALUES('GLOBAL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('GO')
INSERT INTO @ReservedWords(ReservedWord) VALUES('GOTO')
INSERT INTO @ReservedWords(ReservedWord) VALUES('GRANT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('GRANTED')
INSERT INTO @ReservedWords(ReservedWord) VALUES('GRAPHIC')
INSERT INTO @ReservedWords(ReservedWord) VALUES('GREATEST')
INSERT INTO @ReservedWords(ReservedWord) VALUES('GROUP')
INSERT INTO @ReservedWords(ReservedWord) VALUES('GROUPING')
INSERT INTO @ReservedWords(ReservedWord) VALUES('GROUPS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('HASH')
INSERT INTO @ReservedWords(ReservedWord) VALUES('HAVING')
INSERT INTO @ReservedWords(ReservedWord) VALUES('HELP')
INSERT INTO @ReservedWords(ReservedWord) VALUES('HELPFILE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('HOLDLOCK')
INSERT INTO @ReservedWords(ReservedWord) VALUES('HOST')
INSERT INTO @ReservedWords(ReservedWord) VALUES('HOUR')
INSERT INTO @ReservedWords(ReservedWord) VALUES('HOURS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('IDENTIFIED')
INSERT INTO @ReservedWords(ReservedWord) VALUES('IDENTITY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('IDENTITY_INSERT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('IDENTITYCOL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('IF')
INSERT INTO @ReservedWords(ReservedWord) VALUES('IFNULL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('IGNORE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('IIMESSAGE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('IIPRINTF')
INSERT INTO @ReservedWords(ReservedWord) VALUES('IMMEDIATE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('IMPORT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('IN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('INCLUDE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('INCLUDING')
INSERT INTO @ReservedWords(ReservedWord) VALUES('INCREMENT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('INDEX')
INSERT INTO @ReservedWords(ReservedWord) VALUES('INDEXPAGES')
INSERT INTO @ReservedWords(ReservedWord) VALUES('INDICATOR')
INSERT INTO @ReservedWords(ReservedWord) VALUES('INITCAP')
INSERT INTO @ReservedWords(ReservedWord) VALUES('INITIAL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('INITIALIZE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('INITIALLY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('INITRANS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('INITTABLE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('INNER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('INOUT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('INPUT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('INSENSITIVE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('INSERT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('INSERTROW')
INSERT INTO @ReservedWords(ReservedWord) VALUES('INSTANCE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('INSTR')
INSERT INTO @ReservedWords(ReservedWord) VALUES('INT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('INTEGER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('INTEGRITY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('INTERFACE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('INTERSECT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('INTERVAL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('INTO')
INSERT INTO @ReservedWords(ReservedWord) VALUES('IS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ISOLATION')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ITERATE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('JOIN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('KEY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('KILL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LABEL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LANGUAGE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LARGE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LAST')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LATERAL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LAYER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LEADING')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LEAST')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LEFT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LENGTH')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LESS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LEVEL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LIKE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LIMIT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LINENO')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LINK')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LIST')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LISTS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LOAD')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LOADTABLE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LOCAL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LOCALTIME')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LOCALTIMESTAMP')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LOCATE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LOCATOR')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LOCK')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LOCKSIZE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LOG')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LOGFILE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LONG')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LONGINT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LOWER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LPAD')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LTRIM')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LVARBINARY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('LVARCHAR')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MAIN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MANAGE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MANUAL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MAP')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MATCH')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MAX')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MAXDATAFILES')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MAXEXTENTS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MAXINSTANCES')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MAXLOGFILES')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MAXLOGHISTORY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MAXLOGMEMBERS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MAXTRANS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MAXVALUE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MENUITEM')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MERGE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MESSAGE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MICROSECOND')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MICROSECONDS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MIN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MINEXTENTS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MINUS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MINUTE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MINUTES')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MINVALUE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MIRROREXIT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MOD')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MODE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MODIFIES')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MODIFY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MODULE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MONEY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MONTH')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MONTHS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MOUNT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('MOVE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NAMED')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NAMES')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NATIONAL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NATURAL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NCHAR')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NCLOB')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NEW')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NEXT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NHEADER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NO')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NOARCHIVELOG')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NOAUDIT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NOCACHE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NOCHECK')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NOCOMPRESS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NOCYCLE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NOECHO')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NOMAXVALUE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NOMINVALUE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NONCLUSTERED')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NONE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NOORDER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NORESETLOGS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NORMAL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NOSORT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NOT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NOTFOUND')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NOTRIM')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NOWAIT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NULL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NULLIF')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NULLVALUE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NUMBER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NUMERIC')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NUMPARTS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('NVL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('OBID')
INSERT INTO @ReservedWords(ReservedWord) VALUES('OBJECT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('OCTET_LENGTH')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ODBCINFO')
INSERT INTO @ReservedWords(ReservedWord) VALUES('OF')
INSERT INTO @ReservedWords(ReservedWord) VALUES('OFF')
INSERT INTO @ReservedWords(ReservedWord) VALUES('OFFLINE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('OFFSETS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('OLD')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ON')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ONCE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ONLINE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ONLY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('OPEN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('OPENDATASOURCE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('OPENQUERY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('OPENROWSET')
INSERT INTO @ReservedWords(ReservedWord) VALUES('OPENXML')
INSERT INTO @ReservedWords(ReservedWord) VALUES('OPERATION')
INSERT INTO @ReservedWords(ReservedWord) VALUES('OPTIMAL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('OPTIMIZE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('OPTION')
INSERT INTO @ReservedWords(ReservedWord) VALUES('OR')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ORDER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ORDINALITY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('OUT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('OUTER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('OUTPUT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('OVER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('OVERLAPS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('OWN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PACKAGE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PAD')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PAGE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PAGES')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PARALLEL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PARAMETER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PARAMETERS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PART')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PARTIAL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PASCAL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PATH')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PCTFREE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PCTINCREASE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PCTINDEX')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PCTUSED')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PERCENT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PERM')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PERMANENT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PERMIT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PI')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PIPE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PIVOT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PLAN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PLI')
INSERT INTO @ReservedWords(ReservedWord) VALUES('POSITION')
INSERT INTO @ReservedWords(ReservedWord) VALUES('POSTFIX')
INSERT INTO @ReservedWords(ReservedWord) VALUES('POWER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PRECISION')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PREFIX')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PREORDER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PREPARE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PRESERVE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PRIMARY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PRINT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PRINTSCREEN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PRIOR')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PRIQTY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PRIVATE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PRIVILEGES')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PROC')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PROCEDURE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PROCESSEXIT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PROFILE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PROGRAM')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PROMPT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PUBLIC')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PUTFORM')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PUTOPER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('PUTROW')
INSERT INTO @ReservedWords(ReservedWord) VALUES('QUALIFICATION')
INSERT INTO @ReservedWords(ReservedWord) VALUES('QUARTER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('QUOTA')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RADIANS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RAISE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RAISERROR')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RAND')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RANGE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RAW')
INSERT INTO @ReservedWords(ReservedWord) VALUES('READ')
INSERT INTO @ReservedWords(ReservedWord) VALUES('READS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('READTEXT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('REAL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RECONFIGURE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RECORD')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RECOVER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RECURSIVE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('REDISPLAY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('REF')
INSERT INTO @ReservedWords(ReservedWord) VALUES('REFERENCES')
INSERT INTO @ReservedWords(ReservedWord) VALUES('REFERENCING')
INSERT INTO @ReservedWords(ReservedWord) VALUES('REGISTER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RELATIVE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RELEASE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RELOCATE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('REMOVE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RENAME')
INSERT INTO @ReservedWords(ReservedWord) VALUES('REPEAT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('REPEATABLE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('REPEATED')
INSERT INTO @ReservedWords(ReservedWord) VALUES('REPLACE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('REPLICATE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('REPLICATION')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RESET')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RESETLOGS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RESOURCE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RESTORE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RESTRICT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RESTRICTED')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RESULT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RESUME')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RETRIEVE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RETURN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RETURNS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('REUSE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('REVERT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('REVOKE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RIGHT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ROLE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ROLES')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ROLLBACK')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ROLLUP')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ROUTINE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ROW')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ROWCOUNT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ROWGUIDCOL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ROWID')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ROWIDTOCHAR')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ROWLABEL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ROWNUM')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ROWS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RPAD')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RRN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RTRIM')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RULE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RUN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('RUNTIMESTATISTICS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SAVE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SAVEPOINT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SCHEDULE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SCHEMA')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SCN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SCOPE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SCREEN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SCROLL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SCROLLDOWN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SCROLLUP')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SEARCH')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SECOND')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SECONDS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SECQTY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SECTION')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SECURITYAUDIT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SEGMENT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SELECT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SEQUENCE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SERIALIZABLE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SERVICE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SESSION')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SESSION_USER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SET')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SETS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SETUSER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SHARE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SHARED')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SHORT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SHUTDOWN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SIGN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SIMPLE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SIN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SIZE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SLEEP')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SMALLINT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SNAPSHOT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SOME')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SORT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SOUNDEX')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SPACE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SPECIFIC')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SPECIFICTYPE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SQL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SQLBUF')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SQLCA')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SQLCODE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SQLERROR')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SQLEXCEPTION')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SQLSTATE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SQLWARNING')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SQRT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('START')
INSERT INTO @ReservedWords(ReservedWord) VALUES('STATE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('STATEMENT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('STATIC')
INSERT INTO @ReservedWords(ReservedWord) VALUES('STATISTICS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('STOGROUP')
INSERT INTO @ReservedWords(ReservedWord) VALUES('STOP')
INSERT INTO @ReservedWords(ReservedWord) VALUES('STORAGE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('STORPOOL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('STRUCTURE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SUBMENU')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SUBPAGES')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SUBSTR')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SUBSTRING')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SUCCESSFUL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SUFFIX')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SUM')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SUMU')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SWITCH')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SYNONYM')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SYSCAT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SYSDATE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SYSFUN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SYSIBM')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SYSSTAT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SYSTEM')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SYSTEM_USER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SYSTIME')
INSERT INTO @ReservedWords(ReservedWord) VALUES('SYSTIMESTAMP')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TABLE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TABLEDATA')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TABLES')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TABLESAMPLE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TABLESPACE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TAN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TAPE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TEMP')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TEMPORARY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TERMINATE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TEXTSIZE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('THAN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('THEN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('THREAD')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TIME')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TIMEOUT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TIMESTAMP')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TIMEZONE_HOUR')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TIMEZONE_MINUTE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TINYINT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TO')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TOP')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TPE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TRACING')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TRAILING')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TRAN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TRANSACTION')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TRANSLATE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TRANSLATION')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TREAT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TRIGGER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TRIGGERS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TRIM')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TRUE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TRUNCATE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TSEQUAL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('TYPE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('UID')
INSERT INTO @ReservedWords(ReservedWord) VALUES('UNCOMMITTED')
INSERT INTO @ReservedWords(ReservedWord) VALUES('UNDER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('UNION')
INSERT INTO @ReservedWords(ReservedWord) VALUES('UNIQUE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('UNKNOWN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('UNLIMITED')
INSERT INTO @ReservedWords(ReservedWord) VALUES('UNLOADTABLE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('UNNEST')
INSERT INTO @ReservedWords(ReservedWord) VALUES('UNPIVOT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('UNSIGNED')
INSERT INTO @ReservedWords(ReservedWord) VALUES('UNTIL')
INSERT INTO @ReservedWords(ReservedWord) VALUES('UP')
INSERT INTO @ReservedWords(ReservedWord) VALUES('UPDATE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('UPDATETEXT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('UPPER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('USAGE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('USE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('USER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('USING')
INSERT INTO @ReservedWords(ReservedWord) VALUES('UUID')
INSERT INTO @ReservedWords(ReservedWord) VALUES('VALIDATE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('VALIDPROC')
INSERT INTO @ReservedWords(ReservedWord) VALUES('VALIDROW')
INSERT INTO @ReservedWords(ReservedWord) VALUES('VALUE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('VALUES')
INSERT INTO @ReservedWords(ReservedWord) VALUES('VARBINARY')
INSERT INTO @ReservedWords(ReservedWord) VALUES('VARCHAR')
INSERT INTO @ReservedWords(ReservedWord) VALUES('VARIABLE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('VARIABLES')
INSERT INTO @ReservedWords(ReservedWord) VALUES('VARYING')
INSERT INTO @ReservedWords(ReservedWord) VALUES('VCAT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('VERSION')
INSERT INTO @ReservedWords(ReservedWord) VALUES('VIEW')
INSERT INTO @ReservedWords(ReservedWord) VALUES('VOLUMES')
INSERT INTO @ReservedWords(ReservedWord) VALUES('WAITFOR')
INSERT INTO @ReservedWords(ReservedWord) VALUES('WEEK')
INSERT INTO @ReservedWords(ReservedWord) VALUES('WHEN')
INSERT INTO @ReservedWords(ReservedWord) VALUES('WHENEVER')
INSERT INTO @ReservedWords(ReservedWord) VALUES('WHERE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('WHILE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('WITH')
INSERT INTO @ReservedWords(ReservedWord) VALUES('WITHOUT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('WORK')
INSERT INTO @ReservedWords(ReservedWord) VALUES('WRITE')
INSERT INTO @ReservedWords(ReservedWord) VALUES('WRITETEXT')
INSERT INTO @ReservedWords(ReservedWord) VALUES('YEAR')
INSERT INTO @ReservedWords(ReservedWord) VALUES('YEARS')
INSERT INTO @ReservedWords(ReservedWord) VALUES('ZONE')
-----------------------------------------------------------------------------
-- Populate the dbo.ReservedWords table with the list of reserved words.
-----------------------------------------------------------------------------
INSERT INTO dbo.ReservedWords(ReservedWord)
SELECT	SRC.ReservedWord
	FROM @ReservedWords AS SRC
		LEFT JOIN dbo.ReservedWords AS DEST
		ON SRC.ReservedWord = DEST.ReservedWord
WHERE DEST.ReservedWord IS NULL
RAISERROR('DATA DEPLOYED: %i records deployed to dbo.ReservedWords',10,1,@@ROWCOUNT) WITH NOWAIT
GO
--##SUMMARY Tests database objects and field names to see whether SQL reserved words have been used and if so the test will fail.
--##REMARKS The reserved words are from the <a href="https://publib.boulder.ibm.com/infocenter/wasinfo/v6r1/index.jsp?topic=/com.ibm.etools.ejbbatchdeploy.doc/topics/rsqlMSSQLSERVER_2005.html" title="Websphere SQL Reserved Words">IBM Websphere</a> site which does not include certain SQL functions such as OBJECTPROPERTY
CREATE PROC dbo.TestForReservedWords 
AS
SET NOCOUNT ON

DECLARE
	@ReturnValue INT 

SELECT 
	SCHEMA_NAME(CAST(OBJECTPROPERTYEX(O.id,'schemaid')AS INT)) AS SchemaName,
	O.NAME AS ObjectName,
	CASE O.xtype
		WHEN 'C' THEN 'CHECK CONSTRAINT'
		WHEN 'D' THEN 'DEFAULT CONSTRAINT'
		WHEN 'F' THEN 'FOREIGN KEY CONSTRAINT'
		WHEN 'L' THEN 'LOG'
		WHEN 'FN' THEN 'SCALAR FUNCTION'
		WHEN 'IF' THEN 'IN-LINED TABLE FUNCTION'
		WHEN 'P' THEN 'STORED PROCEDURE'
		WHEN 'PK' THEN 'PRIMARY KEY'
		WHEN 'RF' THEN 'REPLICATION STORED PROC'
		WHEN 'S' THEN 'SYSTEM TABLE'
		WHEN 'TF' THEN 'TABLE FUNCTION'
		WHEN 'TR' THEN 'TRIGGER'
		WHEN 'U' THEN 'USER TABLE'
		WHEN 'UQ' THEN 'UNIQUE CONSTRAINT'
		WHEN 'V' THEN 'VIEW'
		WHEN 'X' THEN 'EXTENDED STORED PROC'
		END AS ObjectType,
	CASE O.parent_obj WHEN 0 THEN ''
		ELSE QUOTENAME(SCHEMA_NAME(CAST(OBJECTPROPERTYEX(O.id,'schemaid')AS INT)))
			+	'.'
			+	QUOTENAME(OBJECT_NAME(O.parent_obj)) END AS ParentObject
FROM sysobjects AS O
	INNER JOIN dbo.ReservedWords AS RW
	ON O.name = RW.ReservedWord
WHERE OBJECTPROPERTY(O.id,'IsMSShipped')	=0

SET @ReturnValue = @@ROWCOUNT
IF @ReturnValue >0
	BEGIN
		RAISERROR('*** FAILED ***: Objects are named with reserved words in %i cases',16,1,@ReturnValue ) WITH NOWAIT
	END

SELECT 
	SCHEMA_NAME(CAST(OBJECTPROPERTYEX(O.id,'schemaid')AS INT)) AS SchemaName,
	O.NAME AS ObjectName,
	CASE O.xtype
		WHEN 'C' THEN 'CHECK CONSTRAINT'
		WHEN 'D' THEN 'DEFAULT CONSTRAINT'
		WHEN 'F' THEN 'FOREIGN KEY CONSTRAINT'
		WHEN 'L' THEN 'LOG'
		WHEN 'FN' THEN 'SCALAR FUNCTION'
		WHEN 'IF' THEN 'IN-LINED TABLE FUNCTION'
		WHEN 'P' THEN 'STORED PROCEDURE'
		WHEN 'PK' THEN 'PRIMARY KEY'
		WHEN 'RF' THEN 'REPLICATION STORED PROC'
		WHEN 'S' THEN 'SYSTEM TABLE'
		WHEN 'TF' THEN 'TABLE FUNCTION'
		WHEN 'TR' THEN 'TRIGGER'
		WHEN 'U' THEN 'USER TABLE'
		WHEN 'UQ' THEN 'UNIQUE CONSTRAINT'
		WHEN 'V' THEN 'VIEW'
		WHEN 'X' THEN 'EXTENDED STORED PROC'
		END AS ObjectType,
	C.name AS ColumnName
FROM syscolumns AS C
	INNER JOIN sysobjects AS O
	ON C.id = O.id
	INNER JOIN dbo.ReservedWords AS RW
	ON C.name = RW.ReservedWord
WHERE OBJECTPROPERTY(O.id,'IsMSShipped')	=0
	
SET @ReturnValue = @@ROWCOUNT
IF @ReturnValue >0
	BEGIN
		RAISERROR('*** FAILED ***: Objects are named with reserved words in %i cases',16,1,@ReturnValue ) WITH NOWAIT
	END
GO


IF @@ERROR = 0
	BEGIN
		PRINT 'PROC CREATED: dbo.TestForReservedWords'
	END
ELSE
	BEGIN
		PRINT '*** FAILED PROC CREATION: dbo.TestForReservedWords'
	END
GO
-----------------------------------------------------------------------------
SET XACT_ABORT OFF
SET NOCOUNT OFF
GO
