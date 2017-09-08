USE sqlDevToolboxAB
GO
IF OBJECT_ID('dbo.WNGrams8K', 'IF') is not null DROP FUNCTION dbo.WNGrams8K;
GO
CREATE FUNCTION dbo.WNGrams8K (@string varchar(8000), @N int)
/*****************************************************************************************
Purpose:
 WNGrams8K takes an input string (@string) up to 8,000 characters longs and splits 
 it into @N-sized word-level tokens.

 Per Wikipedia (http://en.wikipedia.org/wiki/N-gram) an "n-gram" is defined as: 
 "a contiguous sequence of n items from a given sequence of text or speech. The items can
  be phonemes, syllables, letters, words or base pairs according to the application. "

Compatibility:
 SQL Server 2008 (or 2005 - see programmer notes below), Azure SQL Database

Returns:
 tokenNumber = The token ordinal position in the input string
 token   = The @N-sized word-level token

Syntax:
--===== Autonomous
 SELECT 
 ng.tokenNumber,
 ng.token
 FROM dbo.WNGrams8k(@string,@N) ng;

--===== Against another table using APPLY
 SELECT 
 s.SomeID
 ng.tokenNumber,
 ng.token
 FROM dbo.SomeTable s
 CROSS APPLY dbo.WNGrams8k(@string,@N) ng;

Usage Examples:

--===== Word-level Unigrams:
 SELECT 
 ng.tokenNumber,
 ng.token
 FROM WNGrams8K('One two three four words',1) ng;

 --Results:
 ItemNumber  gram
 1     One 
 2     two 
 3     three 
 4     four 
 5     words

--===== Word-level Bi-grams:
 SELECT 
 ng.tokenNumber,
 ng.token
 FROM WNGrams8K('One two three four words',2) ng;

 --Results:
 ItemNumber  gram
 1     One two 
 2     two three 
 3     three four
 4     four words 

Programmer Notes:
 1. On SQL Server 2012+ systems use WNGrams2012_8K (found here: https://goo.gl/459Bbu), 
    which leverages LEAD, and is much faster.

 2. Function requires NGrams8K which can be found here:
    http://www.sqlservercentral.com/articles/Tally+Table/142316/
    For SQL Server 2005 compatibility you would need to download NGrams8k_2005 from the
    above link and replace the reference to NGrams8K with NGrams8K_2005 in the code below.

 3. WNGrams8K uses spaces (char(32)) as the delimiter; the text must be pre-formatted to
    address line breaks, carriage returns multiple spaces, etc.

 4. For word-level unigrams you don't need this function; instead I recommend - 
    DelimitedSplit8K for SQL 2005 & 2008:
    http://www.sqlservercentral.com/articles/Tally+Table/72993/

Revision History:
 Rev 00 - 20151012 - Initial conception - Alan Burstein
 Rev 01 - 20170320 - Completely re-written for optimal performance
*****************************************************************************************/
RETURNS TABLE WITH SCHEMABINDING AS RETURN

WITH
delim(RN,N) AS -- locate all of the spaces in the string
(
  SELECT 0,0 UNION ALL
  SELECT ROW_NUMBER() OVER (ORDER BY position), position
  FROM dbo.NGrams8k(RTRIM(LTRIM(@string)),1) -- use NGrams8K_2005 for 2005 compatability
  WHERE token = CHAR(32)
),
tokens(tokenNumber, token, tokenCount) AS
(
  SELECT N1.RN+1,
   SUBSTRING(@string, N1.N+1, ISNULL(N2.N-(N1.N+1), 8000)),
   -- count number of spaces in the string then apply the rows-(@N-1) formula
   -- Note: using (@N-2 to compinsate for the extra row in the delim cte).
   (LEN(@string) - LEN(REPLACE(@string,' ',''))) - (@N-2)
  FROM delim N1
  LEFT JOIN delim N2 ON N2.RN = N1.RN+@N
)
SELECT 
  t.tokenNumber,
  t.token
FROM tokens t
-- @N can't be 0, negative or greater than the number of tokens:
WHERE @N > 0 AND tokenNumber <= tokenCount;
GO