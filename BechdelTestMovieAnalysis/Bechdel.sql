USE Bechdel;

-- View the two tables we are working with, limiting the imdb list since it is a large dataset
SELECT * FROM bechdel_movies;

SELECT * FROM imdb_movies
LIMIT 100;

-- Move the imdbid column to the first in the table
ALTER TABLE bechdel_movies MODIFY COLUMN imdbid INT FIRST;

-- Change column name from 'tconst' to 'id' 
ALTER TABLE imdb_movies
RENAME COLUMN tconst
TO id;

-- Split genres into 3 different columns
ALTER TABLE imdb_movies
ADD genre1 VARCHAR(20), ADD genre2 VARCHAR(20), ADD genre3 VARCHAR(20);

SELECT genres, substring_index(genres, ',', 1) first, substring_index(substr(replace(genres, substring_index(genres, ',', 1), ''),2), ',', 1) second, 
substr(replace(genres, substring_index(genres, ',', 2), ''),2) third
FROM imdb_movies;

UPDATE imdb_movies
SET genre1 = substring_index(genres, ',', 1);

UPDATE imdb_movies
SET genre2 = substring_index(substr(replace(genres, substring_index(genres, ',', 1), ''),2), ',', 1);

UPDATE imdb_movies
SET genre3 = substr(replace(genres, substring_index(genres, ',', 2), ''),2);

ALTER TABLE imdb_movies
DROP genres;

-- Change column name in bechdel table from 'id' to 'bechdelid'
-- Change column name from 'tconst' to 'id' 
ALTER TABLE bechdel_movies
RENAME COLUMN id
TO bechdelid;

-- Remove the 'tt' in front of the id #'s so they match the other table's imdbid column
SELECT SUBSTRING(id, 3, length(id))
FROM imdb_movies
LIMIT 1000;

SET SQL_SAFE_UPDATES = 0;
UPDATE imdb_movies
SET id = SUBSTRING(id, 3, length(id));
SET SQL_SAFE_UPDATES = 1;

-- Join imdb and bechdel tables
SELECT * 
FROM imdb_movies
INNER JOIN bechdel_movies
	ON imdb_movies.id = bechdel_movies.imdbid;

-- Since the INNER join returned 9800 rows and the bechdel table is 9807 rows, find what was left out
WITH CTE_combinedmovies AS 
	(SELECT imdb_movies.id, primaryTitle, title, imdbid
	FROM imdb_movies
	RIGHT JOIN bechdel_movies
		ON imdb_movies.id = bechdel_movies.imdbid)
SELECT *
FROM CTE_combinedmovies
WHERE primaryTitle is NULL;

-- The imdb id's of the 7 records that were left out are: 7343762, 3630276, 8419312, 14807308, 257001, 98675, 10174382.
-- Check to see if they are in the imdb_movies database
SELECT * 
FROM imdb_movies
WHERE id = 10174382;

-- All above results show that the 7 missing records are not in the imdb database, so we can safely use the INNER join
CREATE TEMPORARY TABLE comb_movies AS
(SELECT * 
FROM imdb_movies
INNER JOIN bechdel_movies
	ON imdb_movies.id = bechdel_movies.imdbid);

-- Make sure view was creates with correct number of records
SELECT * 
FROM comb_movies;

-- See rows where the titles differ
SELECT primaryTitle, originalTitle, title
FROM comb_movies
WHERE primaryTitle != title
AND originalTitle != title;

-- Based on the results, the title column has replaced certain characters with symbols and all the titles with 'The' in front are formatted with 'The' at the end.
-- We can drop this column and use the cleaner primaryTitle column
ALTER TABLE comb_movies
DROP COLUMN title;

-- The id column and imdbid columns are identical, so we can drop imdbid
ALTER TABLE comb_movies
DROP COLUMN imdbid;

-- Since the visible column will always return 1 per the data documentation, we can drop this column as well. 
-- First double check that it only returns 1.
SELECT DISTINCT visible
FROM comb_movies;

ALTER TABLE comb_movies
DROP COLUMN visible;

-- See where the differences in the year columns are
SELECT imdbid, titleType, primaryTitle, startYear, year, startYear - year AS diff
FROM comb_movies
WHERE startYear != year
ORDER BY diff;

-- There are some titles with quite a large year difference. After reviewing the 
-- ones with the biggest differences, it is clear that since the years from the bechdel 
-- dataset are user input, they are prone to errors. Therefore, we will use the imdb years.
ALTER TABLE comb_movies
DROP COLUMN year;

SELECT DISTINCT titleType, COUNT(titleType)
FROM comb_movies
GROUP BY titleType;

-- There isn't enough data for the types tvShort, tvSpecial, or videoGame to be a decent sample size. 
-- We won't be able to draw any meaningful conclusions with this data.
SET SQL_SAFE_UPDATES = 0;
DELETE FROM comb_movies
WHERE titleType = 'tvShort'
OR titleType = 'tvSpecial'
OR titleType = 'videoGame';
SET SQL_SAFE_UPDATES = 1;

-- The columns bechdelid, submitterid, and date are not useful for analysis
ALTER TABLE comb_movies
DROP bechdelid,
DROP submitterid,
DROP date;

-- Based on the documentation for the bechdel data, we should make the data for isAdult, rating, and dubious more readable
 -- isAdult:
 ALTER TABLE comb_movies
 ADD COLUMN adultRating VARCHAR(10);
 
 SET SQL_SAFE_UPDATES = 0;
 UPDATE comb_movies
 SET adultRating = (
 CASE
	WHEN isAdult = 0 THEN 'Non-Adult'
    WHEN isAdult = 1 THEN 'Adult'
    END);
SET SQL_SAFE_UPDATES = 1;

ALTER TABLE comb_movies
DROP isAdult;

-- rating:
SELECT rating, 
CASE 
	WHEN rating = 0 THEN 'No two women'
    WHEN rating = 1 THEN 'Women don\'t converse'
    WHEN rating = 2 THEN 'Women talk about a man'
    WHEN rating = 3 THEN 'Pass'
    END as bechdelRating
FROM comb_movies
ORDER BY rating;
    
 ALTER TABLE comb_movies
 ADD COLUMN bechdelRating VARCHAR(25);
 
 SET SQL_SAFE_UPDATES = 0;
 UPDATE comb_movies
 SET bechdelRating = (
 CASE 
	WHEN rating = 0 THEN 'No two women'
    WHEN rating = 1 THEN 'Women don\'t converse'
    WHEN rating = 2 THEN 'Women talk about a man'
    WHEN rating = 3 THEN 'Pass'
    END);
SET SQL_SAFE_UPDATES = 1;

ALTER TABLE comb_movies
DROP rating;

-- dubious:
SELECT dubious, 
CASE 
	WHEN dubious = 0 THEN 'No'
    WHEN dubious = 1 THEN 'Yes'
    END as dubiousStatus
FROM comb_movies
ORDER BY dubious;
    
 ALTER TABLE comb_movies
 ADD COLUMN isDubious VARCHAR(25);
 
 SET SQL_SAFE_UPDATES = 0;
 UPDATE comb_movies
 SET isDubious = (
 CASE 
	WHEN dubious = 0 THEN 'No'
    WHEN dubious = 1 THEN 'Yes'
    END);
SET SQL_SAFE_UPDATES = 1;

ALTER TABLE comb_movies
DROP dubious;

-- Add in ratings columns from imdb_ratings

-- Change column name from 'tconst' to 'id' in ratings table
ALTER TABLE imdb_ratings
RENAME COLUMN tconst
TO imdbid;

-- Remove the 'tt' in front of the imdbid #'s
SELECT SUBSTRING(imdbid, 3, length(imdbid))
FROM imdb_ratings
LIMIT 1000;

SET SQL_SAFE_UPDATES = 0;
UPDATE imdb_ratings
SET imdbid = SUBSTRING(imdbid, 3, length(imdbid));
SET SQL_SAFE_UPDATES = 1;

-- Add the averageRating and numVotes to the comb_movies table

SELECT *
FROM comb_movies
LEFT JOIN imdb_ratings
	ON comb_movies.id = imdb_ratings.imdbid;
    
ALTER TABLE comb_movies
ADD COLUMN avgWgtdRating VARCHAR(10),
ADD COLUMN numberVotes VARCHAR(10);

SET SQL_SAFE_UPDATES = 0;    
UPDATE comb_movies
SET avgWgtdRating = (SELECT averageRating FROM imdb_ratings WHERE comb_movies.id = imdb_ratings.imdbid);

UPDATE comb_movies
SET numberVotes = (SELECT numVotes FROM imdb_ratings WHERE comb_movies.id = imdb_ratings.imdbid);
SET SQL_SAFE_UPDATES = 1;

-- Convert temp table to a real table to export data
CREATE TABLE movies 
AS (SELECT *
	FROM comb_movies);

