USE sqlDevToolboxAB
GO
IF OBJECT_ID('dbo.wngrams2012', 'IF') is not null DROP FUNCTION dbo.wngrams2012;
GO
CREATE FUNCTION dbo.wngrams2012(@string varchar(max), @N bigint)
/*****************************************************************************************
Purpose:
 wngrams2012 accepts a varchar(max) input string (@string) and splits it into a contiguous 
  sequence of @N-sized, word-level tokens.

 Per Wikipedia (http://en.wikipedia.org/wiki/N-gram) an "n-gram" is defined as: 
 "a contiguous sequence of n items from a given sequence of text or speech. The items can
  be phonemes, syllables, letters, words or base pairs according to the application. "
------------------------------------------------------------------------------------------
Compatibility:
 SQL Server 2012+, Azure SQL Database
 2012+ because the function uses LEAD (see: https://goo.gl/6VK142)

Parameters:
 @string = varchar(max); input string to spit into n-sized items
 @N      = int; number of items per row

Returns:
 itemNumber = bigint; the item's ordinal position inside the input string
 itemIndex  = int; the items location inside the input string
 item       = The @N-sized word-level token


Determinism:
  wngrams2012  is deterministic
  
	SELECT ROUTINE_NAME, IS_DETERMINISTIC 
	FROM information_schema.routines where ROUTINE_NAME = 'wngrams2012';

------------------------------------------------------------------------------------------
Syntax:
--===== Autonomous
 SELECT 
   ng.tokenNumber,
   ng.token
 FROM dbo.wngrams2012(@string,@N) ng;

--===== Against another table using APPLY
 SELECT 
   t.someID
   ng.tokenNumber,
   ng.token
 FROM dbo.SomeTable t
 CROSS APPLY dbo.wngrams2012(@string,@N) ng;
-----------------------------------------------------------------------------------------
Usage Examples:

--===== Example #1: Word-level Unigrams:
  SELECT
    ng.itemNumber,
    ng.itemIndex,
    ng.item
  FROM dbo.wngrams2012('One two three four words', 1) ng;

 --Results:
  ItemNumber  position  token
  1           1         one
  2           4         two
  3           8         three
  4           14        four
  5           19        words

--===== Example #2: Word-level Bi-grams:
  SELECT
    ng.itemNumber,
    ng.itemIndex,
    ng.item
  FROM dbo.wngrams2012('One two three four words', 2) ng;

 --Results:
  ItemNumber  position  token
  1           1         One two
  2           4         two three
  3           8         three four
  4           14        four words

--===== Example #3: Only the first two Word-level Bi-grams:
  -- Key: TOP(2) does NOT guarantee the correct result without an order by, which will
  -- degrade performance; see programmer note #5 below for details about sorting.

  SELECT
    ng.tokenNumber,
    ng.position,
    ng.token
  FROM dbo.wngrams2012('One two three four words',2) ng
  WHERE ng.tokennumber < 3;

 --Results:
  ItemNumber  position  token
  1           1         One two 
  2           4         two three 
-----------------------------------------------------------------------------------------
Programmer Notes:
 1. This function requires ngrams8k which can be found here:
    http://www.sqlservercentral.com/articles/Tally+Table/142316/

 2. This function could not have been developed without what I learned reading "Reaping 
    the benefits of the Window functions in T-SQL"  by Eirikur Eiriksson
    https://goo.gl/Gtru6A. The code looks different but, under the covers, WNGrams2012 
   is simply a slightly altered rendition of DelimitedSplit8K_LEAD. 

 3. Requires SQL Server 2012

 4. wngrams2012 uses spaces (char(32)) as the delimiter; the text must be pre-formatted
    to address line breaks, carriage returns multiple spaces, etc.

 5. Result set order does not matter and therefore no ORDER BY clause is required. The 
    *observed* default sort order is ItemNumber which means position is also sequential.
    That said, *any* ORDER BY clause will cause a sort in the execution plan. If you need
    to sort by position (ASC) or itemNumber (ASC), follow these steps to avoid a sort:

      A. In the function DDL, replace COALESCE/NULLIF for N1.N with the N. e.g. Replace
         "COALESCE(NULLIF(N1.N,0),1)" with "N" (no quotes)

      B. Add an ORDER BY position (which is logically identical to ORDER BY itemnumber).

      C. This will cause the position of the 1st token to be 0 instead of 1 when position
         is included in the final result-set. To correct this, simply use this formula:
         "COALESCE(NULLIF(position,0),1)" for "position". Note this example:

         SELECT
           ng.itemNumber,
           itemIndex = COALESCE(NULLIF(ng.itemIndex,0),1),
           ng.item
         FROM dbo.wngrams2012('One two three four words',2) ng
         ORDER BY ng.itemIndex;

-----------------------------------------------------------------------------------------
Revision History:
 Rev 00 - 20171116 - Initial creation - Alan Burstein
*****************************************************************************************/
RETURNS TABLE WITH SCHEMABINDING AS RETURN
WITH
delim(RN,N) AS -- locate all of the spaces in the string
(
  SELECT 0,0 UNION ALL
  SELECT ROW_NUMBER() OVER (ORDER BY ng.position),	 ng.position
  FROM dbo.ngrams2b(@string,1) ng
  WHERE ng.token = ' '
),
tokens(itemNumber, itemIndex, item, itemCount) AS -- Create the tokens (split the string)
(
  SELECT N1.RN+1,
    N1.N, -- change to N then ORDER BY position to avoid a sort
    SUBSTRING(v1.s, N1.N+1, LEAD(N1.N,@N,v2.l) OVER (ORDER BY N1.N)-N1.N),
    v2.l-v2.sp-(@N-2) 
     -- count number of spaces in the string then apply the N-GRAM rows-(@N-1) formula
     -- Note: using (@N-2 to compinsate for the extra row in the delim cte).
  FROM delim N1
  CROSS JOIN  (VALUES (@string)) v1(s)
  CROSS APPLY (VALUES (LEN(v1.s), LEN(REPLACE(v1.s,' ','')))) v2(l,sp)
)
SELECT 
  t.itemNumber,
	t.itemIndex,
  t.item
FROM tokens t
WHERE @N > 0 AND t.itemNumber <= t.itemCount; -- startup predicate  
GO




