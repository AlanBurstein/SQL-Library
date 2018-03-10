IF OBJECT_ID('dbo.WNGrams2012_8K', 'IF') is not null DROP FUNCTION dbo.WNGrams2012_8K;
GO
CREATE FUNCTION dbo.WNGrams2012_8K(@string varchar(8000), @delim char(1), @N int)
/*****************************************************************************************
Purpose:
 WNGrams2012_8K takes an input string (@string) up to 8,000 characters longs and splits 
 it into @N-sized word-level tokens.
 Per Wikipedia (http://en.wikipedia.org/wiki/N-gram) an "n-gram" is defined as: 
 "a contiguous sequence of n items from a given sequence of text or speech. The items can
  be phonemes, syllables, letters, words or base pairs according to the application. "

Compatibility:
 SQL Server 2012+, Azure SQL Database

Returns:
 tokenNumber = The token ordinal position in the input string
 token   = The @N-sized word-level token

Syntax:
--===== Autonomous
 SELECT 
   ng.tokenNumber,
   ng.token
 FROM dbo.WNGrams2012_8K(@string,@delim,@N) ng;

--===== Against another table using APPLY
 SELECT 
   s.SomeID
   ng.tokenNumber,
   ng.token
 FROM dbo.SomeTable s
 CROSS APPLY dbo.WNGrams2012_8K(@string,@delim,@N) ng;

Usage Examples:
--===== Word-level Unigrams:
 SELECT 
   ng.tokenNumber,
   ng.token
 FROM dbo.WNGrams2012_8K('One two three four words',' ',1) ng;

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
 FROM dbo.WNGrams2012_8K('One two three four words',' ',2) ng;

 --Results:
 ItemNumber  gram
 1     One two 
 2     two three 
 3     three four
 4     four words 

Programmer Notes:
 1. Function requires NGrams8K which can be found here:
  http://www.sqlservercentral.com/articles/Tally+Table/142316/
 2. Kudo's to Eirikur Eiriksson; this function could not have been developed without 
    what I learned reading "Reaping the benefits of the Window functions in T-SQL" 
    https://goo.gl/Gtru6A. The code may look substantially different but, WNGrams2012_8K
    is a hacked mutation of Eiriksson's DelimitedSplit8K_LEAD (see: https://goo.gl/f58x9t)
 3. Is faster than WNGrams2012_8K, the pre-2012 version, WNGrams_8K, which cannot leverage
    LEAD and which means a less efficient self-join against a derived set is required.
 4. The most common use of WNGrams2012_8K will involve using spaces (char(32)) as the 
    delimiter; the text should be pre-formatted to address line breaks, carriage returns 
    multiple spaces, etc.
-----------------------------------------------------------------------------------------
Revision History:
 Rev 00 - 20170320 - Initial creation
       - Created using LEAD to eliminate the self join in the 2005/2008 version.
 Rev 01 - 20170320 - Minor - changed name to WNGrams2012_8K
 Rev 02 - 20180310 - Made the delimiter a parameter
*****************************************************************************************/
RETURNS TABLE WITH SCHEMABINDING AS RETURN
WITH
delim(RN,N) AS -- locate all of the spaces in the string
(
  SELECT 0,0 UNION ALL
  SELECT ROW_NUMBER() OVER (ORDER BY position), position
  FROM dbo.NGrams8k(RTRIM(LTRIM(@string)),1)
  WHERE token = CHAR(32)
),
tokens(tokenNumber, token, tokenCount) AS -- Create the tokens
(
  SELECT
    RN+1,
    SUBSTRING(@string,N+1,ISNULL(LEAD(N,@N) OVER (ORDER BY N)-N,8000)),
     -- count number of spaces in the string then apply the rows-(@N-1) formula
     -- Note: using (@N-2 to compinsate for the extra row in the delim cte).
    (LEN(@string) - LEN(REPLACE(@string,'-',''))) - (@N-2)
    FROM delim N1
)
SELECT 
  t.tokenNumber, 
  t.token
FROM tokens t
WHERE @N > 0 AND tokenNumber <= tokenCount; -- @N can't be 0, negative or greater than the number of tokens
GO