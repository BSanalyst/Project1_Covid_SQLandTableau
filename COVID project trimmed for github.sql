USE [Project Portfolio Solo]
/*
Tables used for querying:
*/
SELECT * from [COVID cases] 
SELECT * from [COVID deaths] 
SELECT * from [COVID tests] 

-- Vaccines -- 
--   EDA   ---

-- Q1) [People Vaccinated at least once & people_fully_vaccinated (all doses)] vs Population
SELECT continent, location, date, population, people_vaccinated, people_fully_vaccinated, round((cast(people_vaccinated as int)/population)*100,2) at_least_one_vax_proportion, round((cast(people_fully_vaccinated as int)/population)*100,2) full_vax_proportion
FROM [COVID vaccines]
WHERE continent is not null 
ORDER BY at_least_one_vax_proportion DESC

-- *results INTERPRETATION:* initially alarming as number of people vaccinated > population. Conclusion: non-residents vaccinated in countries; still intriguing to see leaders

-- Q1.1) Grouping by location: [People Vaccinated at least once & people_fully_vaccinated (all doses)] vs Population
SELECT location, max(population) [population], max(people_vaccinated) [max vaccinated at least once], max(people_fully_vaccinated) [max people_fully_vaccinated], round((max(cast(people_vaccinated as int))/population)*100,2) at_least_one_vax_proportion, round((max(cast(people_fully_vaccinated as int))/population)*100,2) full_vax_proportion
FROM [COVID vaccines]
WHERE continent is not null 
GROUP BY location,population
ORDER BY at_least_one_vax_proportion DESC


-- Q2) Which country administered the most boosters? (one person could receive multiple boosters...)
SELECT continent, location, date, population, total_boosters --total boosters is a cumulative amount based across time, taking max is fine
FROM [COVID vaccines]
WHERE continent is not null 
ORDER BY 1,2

SELECT location, population, max(cast(total_boosters as int)) [total boosters], max(cast(total_boosters as int))/population*100 as [total boosters percentage of population]--total boosters is a cumulative amount based across time, taking max is fine
FROM [COVID vaccines]
WHERE continent is not null 
GROUP BY location, population
ORDER BY 2 desc 

-- Q3) Of the people who got vaccinated: Pct who received partial doses VS Pct who received entire dose
SELECT location, population, max(cast(people_vaccinated as int)) [total partial vaccinated people], max(cast(people_fully_vaccinated as int)) [total fully vaccinated people] -- max(cast(people_fully_vaccinated as int))/max(cast(people_vaccinated as int)) as [Of vaccinated, pct of fully vaccinated] 
FROM [COVID vaccines]
WHERE continent is not null 
GROUP BY location, population
;
-- USING CTE to get proportions to get: Pct who received partial doses VS Pct who received entire dose
with vaxmax (location, population, [total partial vaccinated people], [total fully vaccinated people])
AS(
	SELECT location, population, max(cast(people_vaccinated as int)) [total partial vaccinated people], max(cast(people_fully_vaccinated as int)) [total fully vaccinated people] -- max(cast(people_fully_vaccinated as int))/max(cast(people_vaccinated as int)) as [Of vaccinated, pct of fully vaccinated] 
	FROM [COVID vaccines]
	WHERE continent is not null 
	GROUP BY location, population
)
SELECT 
	*, 
	round(cast([total fully vaccinated people]as numeric)/population*100,2) [Full Vaccinated % of population],
	round(cast([total partial vaccinated people] as numeric)/population*100,2) [Partially Vaccinated % of population],
	cast([total fully vaccinated people]as numeric)/cast([total partial vaccinated people] as numeric) [Ratio between Partial Vax vs Full Vax]
FROM vaxmax
ORDER BY 7 desc;
-- some countries like Zambia were dominated by single dose vaccines. Hence in Zambia: fully vacc num > partial vacc num 


--Cases-- 
--   EDA   ---
------------------
SELECT * FROM [COVID cases]

-- Q1) By location, where were the most cases? Where was the highest infection rates? 
SELECT location, max(population) [population], max(total_cases) [total cases], max(total_cases)/max(population)*100 [infected pct of population]
FROM [COVID cases]
WHERE continent is not null
GROUP BY location
ORDER BY 2 desc 


--Deaths-- 
--   EDA   ---
------------------

SELECT location, population, total_deaths 
FROM [COVID deaths] 
WHERE continent is not null

-- Q1) By location, where were the most deaths? which population had the highest death percentage? 
--aggregation
SELECT location, max(population) [population], max(cast(total_deaths as int)) as [total deaths], max(cast(total_deaths as int))/max(population)*100 as [death by covid % of population] 
FROM [COVID deaths] 
WHERE continent is not null
GROUP BY location
order by 3 desc

-- Q2) Joining Covid Deaths to Covid Cases. 
--    By location, % of covid cases which resulted in death
SELECT a.location, max(cast(a.total_deaths as int)) [total deaths], max(b.total_cases) [total cases], max(cast(a.total_deaths as int))/max(b.total_cases)*100 [death pct of cases]
FROM [COVID deaths] a
	INNER JOIN [COVID cases] b
		ON a.location = b.location 
			AND a.date = b.date
				AND a.continent is not null
GROUP BY a.location
ORDER BY 4 desc -- remember; people can have multiple cases of infection but they can only die once.


--------------------------
--GLOBAL FIGURES--
--------------------------

-- total deaths and total infections by continent [tableu]
with continentcount (continent, location, total_deaths, total_cases)
as
(
	SELECT a.continent continent, a.location location, max(cast(a.total_deaths as int)) total_deaths, max(b.total_cases) as total_cases
	FROM [COVID deaths] a
		INNER JOIN [COVID cases] b
			ON a.location = b.location 
				AND a.date = b.date
					AND a.continent is not null
	group by a.continent, a.location
)
SELECT continent, sum(total_deaths) total_deaths, sum(total_cases) total_cases  FROM continentcount group by continent order by 1;


-- total deaths and total infections across the world [tableau]
with metrics_by_location as
(
	SELECT a.continent continent, a.location location, a.population population, max(cast(a.total_deaths as int)) total_deaths, max(b.total_cases) as total_cases
	FROM [COVID deaths] a
		INNER JOIN [COVID cases] b
			ON a.location = b.location 
				AND a.date = b.date
					AND a.continent is not null
	group by a.continent, a.location, a.population
)
,
	metrics_by_continent as 
(
	SELECT continent, sum(population) total_population, sum(total_deaths) total_deaths, sum(total_cases) total_cases  FROM metrics_by_location group by continent
)
SELECT 
	sum(total_deaths) total_world_deaths, 
	sum(total_cases) total_world_cases, 
	sum(total_population) total_world_population,
	sum(total_deaths)/sum(total_population)*100 [global death percentage caused by covid],
	sum(total_cases)/sum(total_population)*100 [global infection percentage]
FROM metrics_by_continent
