USE sqlDevToolboxAB;
GO
IF OBJECT_ID('dbo.eNGrams8k', 'IF') IS NOT NULL DROP FUNCTION dbo.eNGrams8k;
GO
CREATE FUNCTION dbo.eNGrams8k
(
  @string varchar(8000), -- Input string
  @n      int            -- requested token size
)
/****************************************************************************************
Purpose:
 This is the memory optimized version of ngrams8K (see: https://goo.gl/T3DDiY). 
 
 Like ngrams8k, engrams8K is s character-level N-Grams function that outputs a contiguous 
 stream of @N-sized tokens based on an input string (@string). Accepts strings up to 8000
 varchar characters long. For more information about N-Grams see: https://goo.gl/CYTvTS.

Compatibility:
 SQL Server 2014+ 

Prerequisites:
 eNGrams8K requires an "electric" (memory optimized) tally table. 
 Below is example code that will do this on SQL Server 2014+

  ----------------------------------------------------------------------------------------
  -- add memory optimized filegroup
  alter database <yourdb,,>
    add filegroup <filegroup name,,> contains memory_optimized_data;
  
  alter database <yourdb,,>
    add file
    (
      name     = '<filename,,>', 
      filename = '<folder,,>/<filename,,>'
    ) to filegroup sqlDevToolboxAB_mod;
  
  alter database <yourdb,,>
  set MEMORY_OPTIMIZED_ELEVATE_TO_SNAPSHOT = on;

	-- create and populate eTally
  if object_id('dbo.eTally') is not null drop table eTally;
  create table dbo.eTally (n int not null unique nonclustered)
    with(memory_optimized = on, durability = schema_only);

  insert dbo.eTally(n)
  select top(10000) row_number() over (order by (select 1))
  from sys.all_columns a, sys.all_columns b;
  ----------------------------------------------------------------------------------------

Syntax:
--===== Autonomous
 SELECT position, token FROM dbo.eNGrams8K(@string,@N);

--===== Against a table using APPLY
 SELECT s.SomeID, ng.position, ng.token
 FROM dbo.SomeTable s
 CROSS APPLY dbo.eNGrams8K(s.SomeValue,@N) ng;

Parameters:
 @string  = The input string to split into tokens.
 @N       = The size of each token returned.

Returns:
 Position = bigint; the position of the token in the input string
 token    = varchar(8000); a @N-sized character-level N-Gram token

Developer Notes: 
1. eNGrams8K is not case sensitive

2. eNGrams8K uses a memory optimized tally table and therefore can only run with a
   serial execution plan.

3. ORDER BY is required in the function for it to work correctly.

4. When @N is less than 1 or greater than the datalength of the input string then no
    tokens (rows) are returned. If either @string or @N are NULL no rows are returned.
    This is a debatable topic but the thinking behind this decision is that: because you
    can't split 'xxx' into 4-grams, you can't split a NULL value into unigrams and you
    can't turn anything into NULL-grams, no rows should be returned.

    For people who would prefer that a NULL input forces the function to return a single
    NULL output you could add this code to the end of the function:

    UNION ALL
    SELECT 1, NULL
    WHERE NOT(@N > 0 AND @N <= DATALENGTH(@string)) OR (@N IS NULL OR @string IS NULL)

5. eNGrams8K can also be used as a Tally Table with the position column being your "N"
    row. To do so use REPLICATE to create an imaginary string, then use eNGrams8K to split
    it into unigrams then only return the position column. eNGrams8K will get you up to
    8000 numbers. There will be no performance penalty for sorting by position in
    ascending order but there is for sorting in descending order. To get the numbers in
    descending order without forcing a sort in the query plan use the following formula:
    N = <highest number>-position+1.

 Pseudo Tally Table Examples:
    --===== (1) Get the numbers 1 to 100 in ascending order:
    SELECT N = position
    FROM dbo.eNGrams8K(REPLICATE(0,100),1);

    --===== (2) Get the numbers 1 to 100 in descending order:
    DECLARE @maxN int = 100;
    SELECT N = @maxN-position+1
    FROM dbo.eNGrams8K(REPLICATE(0,@maxN),1)
    ORDER BY position;

 6. eNGrams8K is deterministic. For more about deterministic functions see:
    https://msdn.microsoft.com/en-us/library/ms178091.aspx

Usage Examples:
--===== Turn the string, 'abcd' into unigrams, bigrams and trigrams
 SELECT position, token FROM dbo.eNGrams8K('abcd',1); -- unigrams (@N=1)
 SELECT position, token FROM dbo.eNGrams8K('abcd',2); -- bigrams  (@N=2)
 SELECT position, token FROM dbo.eNGrams8K('abcd',3); -- trigrams (@N=3)

--===== How many times the substring "AB" appears in each record
 DECLARE @table TABLE(stringID int identity primary key, string varchar(100));
 INSERT @table(string) VALUES ('AB123AB'),('123ABABAB'),('!AB!AB!'),('AB-AB-AB-AB-AB');

 SELECT string, occurances = COUNT(*)
 FROM @table t
 CROSS APPLY dbo.eNGrams8K(t.string,2) ng
 WHERE ng.token = 'AB'
 GROUP BY string;

----------------------------------------------------------------------------------------
Revision History:
 Rev 00 - 20170819 - Initial Development - Alan Burstein (original developed 20140310)


****************************************************************************************/
RETURNS TABLE WITH SCHEMABINDING AS RETURN
--iTally(N) AS                                   -- my cte Tally Table
--(
--  SELECT TOP(ABS(CONVERT(BIGINT,(DATALENGTH(ISNULL(@string,''))-(ISNULL(@N,1)-1)),0)))
--    ROW_NUMBER() OVER (ORDER BY (SELECT NULL))    -- Order by a constant to avoid a sort
--  FROM L1 a CROSS JOIN L1 b                       -- cartesian for 8100 rows (90^2)
--)
SELECT TOP(ABS(CONVERT(BIGINT,(DATALENGTH(ISNULL(@string,''))-(ISNULL(@N,1)-1)),0)))

  position = N,                                   -- position of the token in the string(s)
  token    = SUBSTRING(@string,CAST(N AS int),@N) -- the @N-Sized token
FROM dbo.eTally
WHERE @N > 0 AND @N <= DATALENGTH(@string)        -- Protection against bad parameter values
ORDER BY N;
GO