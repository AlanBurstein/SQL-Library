IF OBJECT_ID('dbo.NTally') IS NOT NULL DROP FUNCTION dbo.NTally;
GO
CREATE FUNCTION dbo.NTally(@tiles bigint, @rows bigint)
/****************************************************************************************
Purpose:
 Returns a tally table with "tile groups" and can be used as an alternative to the T-SQL
 NTILE function introduced in SQL Server 2005. See the usage examples below for more 
 details on how to use this function.

Compatibility: 
 SQL Server 2005+ and Azure SQL Database

Syntax:
 --===== Autonomous
  SELECT rn, tile 
  FROM dbo.NTally(@tiles,@rows);

 --===== Against a table using APPLY
  WITH anchor AS
  (
    SELECT rn = ROW_NUMBER() OVER (ORDER BY t.SomeValue), t.SomeValue
    FROM SomeTable t
  )
  SELECT t.SomeValue, Tile = nt.tile
  FROM anchor t
  CROSS APPLY dbo.NTally(@tiles, (SELECT COUNT(*) FROM anchor)) nt
  WHERE t.rn = nt.rn

Parameters:
 @tiles = bigint; requested number of tile groups (same as the parameter passed to NTILE)
 @rows  = bigint; the number of rows to be "tiled" (have group number assigned to it)

Return Types:
 Inline Table Valued Function returns:
 rn   = bigint; a row number beginning with 1 and ending with @rows
 tile = int; a "tile number" or group number the same 

Developer Notes:
 1. An inline derived tally table using a CTE or subquery WILL NOT WORK. NTally requires 
    a correctly indexed tally table named dbo.tally; if you have or choose to use a
    permanent tally table with a different name or in a different schema make sure to 
    change the DDL for this function accordingly. The recomended number of rows is 
    1,000,000; below is the recomended DDL for dbo.tally. Note the "Beginning" and "End"
    of tally code.To learn more about tally tables see:
    http://www.sqlservercentral.com/articles/T-SQL/62867/

----------------------------------------------------------------------------------------
  --===== Beginning of dbo.tally code
    -- Drop if NTALLY function and tally table if they exist
    IF OBJECT_ID('dbo.tally') IS NOT NULL DROP TABLE dbo.tally;

    -- Create the tally table
    CREATE TABLE dbo.tally (N int NOT NULL);

    -- Insert the numbers 1 through 1,000,0000 into dbo.tally
    INSERT dbo.tally
    SELECT TOP (1000000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
    FROM sys.all_columns a, sys.all_columns b;

    -- Create required primary key, clustered index and unique nonclustered indexes
    ALTER TABLE dbo.tally ADD CONSTRAINT pk_tally PRIMARY KEY CLUSTERED(N) 
	  WITH FILLFACTOR=100;
    ALTER TABLE dbo.tally ADD CONSTRAINT uq_tally UNIQUE NONCLUSTERED(N);
  --===== End of tally table code
 ----------------------------------------------------------------------------------------

 2. With R as the number of rows in your tally table the maximum number of rows this 
    function will create is (R*R) for each "tile" group per partition. R also represents
	the maximum number of tile groups available. A one million row tally table will requires
	roughly 20MB of uncompressed disk space and will support up to one million tile groups
	with up to one trillion rows per tile group.

 3. For best results a P.O.C. index should exists on the table that you are "tiling". For 
    more information about P.O.C. indexes see:
    http://sqlmag.com/sql-server-2012/sql-server-2012-how-write-t-sql-window-functions-part-3

 4. NTally is deterministic; for more about deterministic and nondeterministic functions
    see https://msdn.microsoft.com/en-us/library/ms178091.aspx

Examples:
--===== 1. Demonstrating how the function mimics NTILE
 -- To better understand NTally, run the DML with different values assigned to @rows and
 -- @tiles. Note how the tile column and NTILE produces the same results.

 DECLARE @rows bigint = 8, @tiles bigint = 3;

 SELECT rn, tile, NTILE(@tiles) OVER (ORDER BY rn) as [NTILE]
 FROM dbo.NTally(@tiles, @rows);

--===== 2. Using NTally as a faster alternative to NTILE (with no PARTITION BY clause)
 -- Run the code below from <START> to <END>. 
 -- Note how you get the same result but how, the more rows you add, the more efficient 
 -- the NTALLY solution is, with respect to reads, when compared to NTILE: 
 -- e.g. NTILE against 100K rows = 200K+ reads, only 560+ reads for the the NTally method

 -- <START>
  -- Declare variables
  DECLARE @rows bigint = 8, @tiles bigint = 5;

  -- Setup sample data
  DECLARE @SomeTable TABLE (SomeValue int primary key);
  INSERT @SomeTable
  SELECT TOP(@rows) ROW_NUMBER() OVER (ORDER BY (SELECT NULL))*5
  FROM sys.all_columns a, sys.all_columns b;

  -- How to divide @some table into 3 tile groups using NTILE
  SET STATISTICS IO ON;
  PRINT 'NTILE version:';
  SELECT SomeValue, NTILE(@tiles) OVER (ORDER BY SomeValue) AS TileGroup
  FROM @SomeTable;

  -- How to divide @SomeTable into 3 tile groups using NTally
  PRINT CHAR(10)+'NTally version:';
  WITH anchor AS
  (
   SELECT SomeValue, ROW_NUMBER() OVER (ORDER BY SomeValue) AS rn
   FROM @SomeTable
  )
  SELECT SomeValue, nt.tile AS TileGroup
  FROM anchor a
  CROSS APPLY dbo.NTally(@tiles, (SELECT COUNT(*) FROM @SomeTable)) nt
  WHERE a.rn = nt.rn;
  SET STATISTICS IO OFF;
 -- <END>

--===== 3. Using NTally an alternative to NTILE with a PARTITION BY clause

  -- Create sample table with 10 rows and 3 partitions
  IF OBJECT_ID('tempdb..#SomeTable') IS NOT NULL DROP TABLE #SomeTable;
  CREATE TABLE #SomeTable
  (
    PartitionKey int NOT NULL, 
    SomeValue int NOT NULL,
	CONSTRAINT pk_SomeTable PRIMARY KEY(PartitionKey,SomeValue)
  );

  INSERT #SomeTable
  SELECT TOP (12) 
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL))/5+1,
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL))*5
  FROM sys.all_columns;

  -- Using NTILE and PARTITION BY
  SELECT 
    s.PartitionKey, 
    s.SomeValue, 
    NTILE(3) OVER (PARTITION BY s.PartitionKey ORDER BY s.SomeValue) AS TileGroup
  FROM #SomeTable s;

  -- Using the NTally function
  WITH 
  anchor AS  -- Use ROW_NUMBER for your partitioning and sorting
  (
    SELECT
      rn = ROW_NUMBER() OVER (PARTITION BY PartitionKey ORDER BY SomeValue), 
      PartitionKey, 
	  SomeValue
    FROM #SomeTable v
  ),
  parts AS -- collect the number of rows per partition
  (
    SELECT PartitionKey, mxrn = MAX(rn) 
    FROM anchor
    GROUP BY PartitionKey
  )
  SELECT a.PartitionKey, a.SomeValue, nt.tile AS TileGroup
  FROM parts p
  CROSS APPLY dbo.NTally(3,mxrn) nt
  CROSS APPLY anchor a
  WHERE p.PartitionKey = a.PartitionKey AND a.rn = nt.rn;

  DROP TABLE #SomeTable;

---------------------------------------------------------------------------------------
Revision History: 
 Rev 00 - 20140501 - Initial Creation - Alan Burstein
 Rev 01 - 20160324 - Final touches and optimization including comments - Alan Burstein
****************************************************************************************/
RETURNS TABLE WITH SCHEMABINDING AS RETURN
WITH
calculate_tiles AS -- Calculate the number of tiles per tile group
(
  SELECT t.N, tile = (@rows/@tiles) + CASE WHEN t.N <= (@rows%@tiles) THEN 1 ELSE 0 END
  FROM dbo.tally t
  WHERE t.N <= @tiles
),
assemble_tiles AS
(
  SELECT tile = topn.N
  FROM calculate_tiles ct
  CROSS APPLY
  (
    SELECT TOP(ct.tile) N = ct.N
    FROM dbo.tally t1 CROSS JOIN dbo.tally t2
  ) topn
)
SELECT TOP 100 PERCENT
  rn = ROW_NUMBER() OVER (ORDER BY a.tile), -- Your anchor row
  a.tile
FROM assemble_tiles a
ORDER BY a.tile; -- Your spoon
GO