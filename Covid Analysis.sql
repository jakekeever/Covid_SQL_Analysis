-- 0. Clean the data.
SELECT * FROM covid_stats

SELECT STR_TO_DATE(submission_date, '%m/%d/20%y') AS date
FROM covid_stats

CREATE TABLE covid_stats_backup AS
SELECT * FROM covid_stats

SET SQL_SAFE_UPDATES = 0
UPDATE covid_stats
SET submission_date = STR_TO_DATE(submission_date, '%m/%d/20%y')
SET SQL_SAFE_UPDATES = 1

-- 1. Which state had the first covid case?
SELECT submission_date, state, tot_cases
FROM covid_stats
WHERE tot_cases >= 1
ORDER BY submission_date ASC
LIMIT 1

-- 2. Which state has had the highest number of covid cases?
SELECT state, MAX(tot_cases)
FROM covid_stats
GROUP BY state
ORDER BY 2 DESC
LIMIT 1

-- 3. Which state has had the highest number of covid deaths?
SELECT state, MAX(tot_death)
FROM covid_stats
GROUP BY state
ORDER BY 2 DESC
LIMIT 1

-- 4. Which state has had the highest deaths per case?
SELECT state, MAX(tot_death)/MAX(tot_cases)*100 AS death_percentage
FROM covid_stats
GROUP BY state
ORDER BY 2 DESC
LIMIT 1

-- 5. What day had the highest amount of new deaths per state?
SELECT submission_date, state, MAX(new_death) AS maximum_new_deaths
FROM covid_stats
GROUP BY state
ORDER BY 3 DESC

-- 6. Which state had the highest number of covid cases accounting for population?
-- Some setup is required before we can complete this question
SELECT * FROM us_state_pops

SET SQL_SAFE_UPDATES = 0
UPDATE us_state_pops
SET 2020_21_change = REPLACE(2020_21_change, '%', '')/100
SET SQL_SAFE_UPDATES = 1

ALTER TABLE us_state_pops
ADD COLUMN 2022_pop INT

UPDATE us_state_pops
SET 2022_pop = REPLACE(2021_pop, ',','') + (REPLACE(2021_pop, ',','') * 2020_21_change)

UPDATE us_state_pops
SET 2021_pop = REPLACE(2021_pop, ',','')

UPDATE us_state_pops
SET 2020_pop = REPLACE(2020_pop, ',','')

SELECT DISTINCT covid_stats.state, us_state_pops.name
FROM covid_stats
LEFT JOIN us_state_pops
ON covid_stats.state = us_state_pops.name
WHERE us_state_pops.name IS NULL

INSERT INTO us_state_pops (name, 2020_pop, 2021_pop, 2022_pop)
VALUES ('AS', 55197, 55100, 55030),
('PW', 18092, 18169, 18260),
('NYC', 8804190, 8823559, 8851733),
('MP', 57557, 57910, 58220),
('RMI', 59194, 59610, 60057),
('GU', 168783, 170184, 171633),
('VI', 104425, 104226, 103971),
('FSM', 114419, 114604, 114790)

ALTER TABLE covid_stats
ADD COLUMN population INT

UPDATE covid_stats
JOIN us_state_pops ON covid_stats.state = us_state_pops.name
SET covid_stats.population = CASE
								WHEN YEAR(covid_stats.submission_date) = '2020' THEN us_state_pops.2020_pop
                                WHEN YEAR(covid_stats.submission_date) = '2021' THEN us_state_pops.2021_pop
								WHEN YEAR(covid_stats.submission_date) = '2022' THEN us_state_pops.2022_pop
                                ELSE NULL
								END
-- Setup completed

SELECT state, MAX(tot_cases)/population AS 'Total cases per population'
FROM covid_stats
GROUP BY state
ORDER BY 2 DESC
LIMIT 1

-- 7. Which state has had the highest number of covid deaths accounting for population?
SELECT state, MAX(tot_death)/population AS 'Total deaths per population'
FROM covid_stats
GROUP BY state
ORDER BY 2 DESC
LIMIT 1

-- 8. Which state has had the most vaccinations?

CREATE TABLE vaccination_data_backup AS
SELECT * FROM vaccination_data

SET SQL_SAFE_UPDATES = 0
DELETE FROM vaccination_data
WHERE MMWR_week <> 'N/A'
SET SQL_SAFE_UPDATES = 1

SELECT Location, MAX(Administered) AS 'Administered Vaccinations' FROM vaccination_data
GROUP BY Location
ORDER BY 2 DESC
LIMIT 1

-- 9. Which state has had the most vaccinations accounting for population?

SET SQL_SAFE_UPDATES = 0
UPDATE vaccination_data
SET Location = 'FSM'
WHERE Location = 'FM'
SET SQL_SAFE_UPDATES = 1

ALTER TABLE vaccination_data
RENAME COLUMN ï»¿Date TO Date

UPDATE vaccination_data
SET Date = STR_TO_DATE(Date, '%m/%d/20%y')

SELECT * FROM vaccination_data
LEFT JOIN covid_stats
ON covid_stats.state = vaccination_data.Location AND covid_stats.submission_date = vaccination_data.Date

ALTER TABLE vaccination_data
RENAME COLUMN `People Receiving 1 or More Doses Cumulative` TO People_Receiving_1_or_More_Doses_Cumulative

SELECT state, MAX(`People Receiving 1 or More Doses Cumulative`)/population*100 AS 'Percent Vaccinated' FROM (
		SELECT * FROM vaccination_data
		LEFT JOIN covid_stats
		ON covid_stats.state = vaccination_data.Location AND covid_stats.submission_date = vaccination_data.Date) AS vax_pop
GROUP BY 1
ORDER BY 2 DESC

-- 10. Which day had the highest number of vaccinations per state?

SELECT Location, `Date`, MAX(`Total Doses Administered Daily`) FROM vaccination_data
GROUP BY Location