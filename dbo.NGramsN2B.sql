IF OBJECT_ID('dbo.NGramsN2B', 'IF') IS NOT NULL DROP FUNCTION dbo.NGramsN2B;
GO
CREATE FUNCTION dbo.NGramsN2B
(
  @string nvarchar(max), -- Input string
  @N      int            -- requested token size
)
/****************************************************************************************
!!! - UPDATE ME FOR N2B
!!! - CREATED 8/17/2017
Purpose:
 A character-level N-Grams function that outputs a contiguous stream of @N-sized tokens 
 based on an input string (@string). Accepts strings up to 4000 nvarchar characters long.
 For more information about N-Grams see: http://en.wikipedia.org/wiki/N-gram. 

Compatibility: 
 SQL Server 2008+, Azure SQL Database

Syntax:
--===== Autonomous
 SELECT position, token FROM dbo.NGramsN4K(@string,@N);

--===== Against a table using APPLY
 SELECT s.SomeID, ng.position, ng.token
 FROM dbo.SomeTable s
 CROSS APPLY dbo.NGramsN4K(s.SomeValue,@N) ng;

Parameters:
 @string  = The input string to split into tokens.
 @N       = The size of each token returned.

Returns:
 Position = bigint; the position of the token in the input string
 token    = nvarchar(4000); a @N-sized character-level N-Gram token

Developer Notes:  
 1. NGramsN4K is not case sensitive

 2. Many functions that use NGramsN4K will see a huge performance gain when the optimizer
    creates a parallel execution plan. One way to get a parallel query plan (if the 
    optimizer does not chose one) is to use make_parallel by Adam Machanic which can be 
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
    WHERE NOT(@N > 0 AND @N <= DATALENGTH(@string)) OR (@N IS NULL OR @string IS NULL);

 4. NGramsN4K is deterministic. For more about deterministic functions see:
    https://msdn.microsoft.com/en-us/library/ms178091.aspx

Usage Examples:
--===== Turn the string, 'abcd' into unigrams, bigrams and trigrams
 SELECT position, token FROM dbo.NGramsN4K('abcd',1); -- unigrams (@N=1)
 SELECT position, token FROM dbo.NGramsN4K('abcd',2); -- bigrams  (@N=2)
 SELECT position, token FROM dbo.NGramsN4K('abcd',3); -- trigrams (@N=3)

--===== How many times the substring "AB" appears in each record
 DECLARE @table TABLE(stringID int identity primary key, string nvarchar(100));
 INSERT @table(string) VALUES ('AB123AB'),('123ABABAB'),('!AB!AB!'),('AB-AB-AB-AB-AB');

 SELECT string, occurances = COUNT(*) 
 FROM @table t
 CROSS APPLY dbo.NGramsN4K(t.string,2) ng
 WHERE ng.token = 'AB'
 GROUP BY string;

----------------------------------------------------------------------------------------
Revision History:
 Rev 00 - 20170324 - Initial Development - Alan Burstein
****************************************************************************************/
RETURNS TABLE WITH SCHEMABINDING AS RETURN
WITH L1(N) AS 
(
  SELECT N FROM (VALUES 
   (0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),
   (0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),
   (0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),
   (0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),
   (0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),
   (0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),
   (0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),
   (0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),
   (0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),
   (0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),
   (0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0),(0)) t(N)
), --216 values
iTally(N) AS 
(
  SELECT 
  TOP (ABS(CONVERT(BIGINT,((DATALENGTH(ISNULL(@string,''))/2)-(ISNULL(@N,1)-1)),0)))
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL))    -- Order by a constant to avoid a sort
  FROM L1 a CROSS JOIN L1 b CROSS JOIN L1 c CROSS JOIN L1 d
)
SELECT
  position = N,                                   -- position of the token in the string(s)
  token    = SUBSTRING(@string,CAST(N AS int),@N) -- the @N-Sized token
FROM iTally
WHERE @N > 0 -- Protection against bad parameter values:
AND   @N <= (ABS(CONVERT(BIGINT,((DATALENGTH(ISNULL(@string,''))/2)-(ISNULL(@N,1)-1)),0)));
GO
