USE sqlDevToolboxAB;
GO
IF OBJECT_ID('dbo.NGrams8k', 'IF') IS NOT NULL DROP FUNCTION dbo.NGrams8k;
GO
CREATE FUNCTION dbo.NGrams8k
(
  @string varchar(8000), -- Input string
  @N      int            -- requested token size
)
/****************************************************************************************
Purpose:
 A character-level N-Grams function that outputs a contiguous stream of @N-sized tokens
 based on an input string (@string). Accepts strings up to 8000 varchar characters long.
 For more information about N-Grams see: http://en.wikipedia.org/wiki/N-gram.

Compatibility:
 SQL Server 2008+, Azure SQL Database

Syntax:
--===== Autonomous
 SELECT position, token FROM dbo.NGrams8k(@string,@N);

--===== Against a table using APPLY
 SELECT s.SomeID, ng.position, ng.token
 FROM dbo.SomeTable s
 CROSS APPLY dbo.NGrams8K(s.SomeValue,@N) ng;

Parameters:
 @string  = The input string to split into tokens.
 @N       = The size of each token returned.

Returns:
 Position = bigint; the position of the token in the input string
 token    = varchar(8000); a @N-sized character-level N-Gram token

Developer Notes: 
 1. NGrams8k is not case sensitive

 2. Many functions that use NGrams8k will see a huge performance gain when the optimizer
    creates a parallel execution plan. One way to get a parallel query plan (if the
    optimizer does not choose one) is to use make_parallel by Adam Machanic which can be
    found here:
 sqlblog.com/blogs/adam_machanic/archive/2013/07/11/next-level-parallel-plan-porcing.aspx

3. When @N is less than 1 or greater than the datalength of the input string then no
    tokens (rows) are returned. If either @string or @N are NULL no rows are returned.
    This is a debatable topic but the thinking behind this decision is that: because you
    can't split 'xxx' into 4-grams, you can't split a NULL value into unigrams and you
    can't turn anything into NULL-grams, no rows should be returned.

    For people who would prefer that a NULL input forces the function to return a single
    NULL output you could add this code to the end of the function:

    UNION ALL
    SELECT 1, NULL
    WHERE NOT(@N > 0 AND @N <= DATALENGTH(@string)) OR (@N IS NULL OR @string IS NULL)

 4. NGrams8k can also be used as a Tally Table with the position column being your "N"
    row. To do so use REPLICATE to create an imaginary string, then use NGrams8k to split
    it into unigrams then only return the position column. NGrams8k will get you up to
    8000 numbers. There will be no performance penalty for sorting by position in
    ascending order but there is for sorting in descending order. To get the numbers in
    descending order without forcing a sort in the query plan use the following formula:
    N = <highest number>-position+1.

 Pseudo Tally Table Examples:
    --===== (1) Get the numbers 1 to 100 in ascending order:
    SELECT N = position
    FROM dbo.NGrams8k(REPLICATE(0,100),1);

    --===== (2) Get the numbers 1 to 100 in descending order:
    DECLARE @maxN int = 100;
    SELECT N = @maxN-position+1
    FROM dbo.NGrams8k(REPLICATE(0,@maxN),1)
    ORDER BY position;

 5. NGrams8k is deterministic. For more about deterministic functions see:
    https://msdn.microsoft.com/en-us/library/ms178091.aspx

Usage Examples:
--===== Turn the string, 'abcd' into unigrams, bigrams and trigrams
 SELECT position, token FROM dbo.NGrams8k('abcd',1); -- unigrams (@N=1)
 SELECT position, token FROM dbo.NGrams8k('abcd',2); -- bigrams  (@N=2)
 SELECT position, token FROM dbo.NGrams8k('abcd',3); -- trigrams (@N=3)

--===== How many times the substring "AB" appears in each record
 DECLARE @table TABLE(stringID int identity primary key, string varchar(100));
 INSERT @table(string) VALUES ('AB123AB'),('123ABABAB'),('!AB!AB!'),('AB-AB-AB-AB-AB');

 SELECT string, occurances = COUNT(*)
 FROM @table t
 CROSS APPLY dbo.NGrams8k(t.string,2) ng
 WHERE ng.token = 'AB'
 GROUP BY string;

----------------------------------------------------------------------------------------
Revision History:
 Rev 00 - 20140310 - Initial Development - Alan Burstein
 Rev 01 - 20150522 - Removed DQS N-Grams functionality, improved iTally logic. Also Added
                     conversion to bigint in the TOP logic to remove implicit conversion
                     to bigint - Alan Burstein
 Rev 03 - 20150909 - Added logic to only return values if @N is greater than 0 and less
                     than the length of @string. Updated comment section. - Alan Burstein
 Rev 04 - 20151029 - Added ISNULL logic to the TOP clause for the @string and @N
                     parameters to prevent a NULL string or NULL @N from causing "an
                     improper value" being passed to the TOP clause. - Alan Burstein
****************************************************************************************/
RETURNS TABLE WITH SCHEMABINDING AS RETURN
WITH
L1(N) AS
(
  SELECT 1
  FROM (VALUES    -- 90 NULL values used to create the CTE Tally Table
        (NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),
        (NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),
        (NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),
        (NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),
        (NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),
        (NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),
        (NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),
        (NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),
        (NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL),(NULL)
       ) t(N)
),
iTally(N) AS                                   -- my cte Tally Table
(
  SELECT TOP(ABS(CONVERT(BIGINT,(DATALENGTH(ISNULL(@string,''))-(ISNULL(@N,1)-1)),0)))
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL))    -- Order by a constant to avoid a sort
  FROM L1 a CROSS JOIN L1 b                       -- cartesian for 8100 rows (90^2)
)
SELECT
  position = N,                                   -- position of the token in the string(s)
  token    = SUBSTRING(@string,CAST(N AS int),@N) -- the @N-Sized token
FROM iTally
WHERE @N > 0 AND @N <= DATALENGTH(@string);       -- Protection against bad parameter values
GO