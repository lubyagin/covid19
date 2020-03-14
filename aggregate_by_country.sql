
-- aggregate case data by country and apply manual fixes to cleanup data
DROP TABLE IF EXISTS covid19.countries;
CREATE TABLE covid19.countries AS
WITH dte as (
    select country_region,
		   min(the_date) as start_date,
		   max(the_date) as max_date
    from covid19.cases
	where confirmed > 0
	group by country_region
)
select cases.country_region,
       the_date,
       the_date - dte.start_date as days_since_first_case,
       dte.start_date,
       dte.max_date,
       sum(confirmed) as confirmed,
       sum(deaths) as deaths,
       sum(recovered) as recovered,
       sum(active) as active,
       null::integer as population,
       null::float as confirmed_percent,
       null::float as deaths_percent,
       null::float as recovered_percent,
       null::float as active_percent,
       null::smallint as population_year,
       avg(latitude)::numeric(8,6) as latitude,
	   avg(longitude)::numeric(9,6) as longitude,
	   ST_SetSRID(ST_Makepoint(avg(longitude), avg(latitude)), 4326) as geom
from covid19.cases
inner join dte on cases.country_region = dte.country_region
group by cases.country_region,
         the_date,
		 dte.start_date,
         dte.max_date
;

ALTER TABLE covid19.countries ADD CONSTRAINT countries_pkey PRIMARY KEY (country_region, the_date);
CREATE INDEX countries_geom_idx ON covid19.countries USING gist (geom);
ALTER TABLE covid19.countries CLUSTER ON countries_geom_idx;

ANALYSE covid19.countries;

-- update country names to match World Bank names
update covid19.countries set country_region = 'Brunei Darussalam' where country_region = 'Brunei';
update covid19.countries set country_region = 'Congo, Dem. Rep.' where country_region = 'Congo (Kinshasa)';
update covid19.countries set country_region = 'Korea, Rep.' where country_region = 'Korea, South';
update covid19.countries set country_region = 'United States' where country_region = 'US';
update covid19.countries set country_region = 'Iran, Islamic Rep.' where country_region = 'Iran';
update covid19.countries set country_region = 'Egypt, Arab Rep.' where country_region = 'Egypt';
update covid19.countries set country_region = 'Russian Federation' where country_region = 'Russia';
update covid19.countries set country_region = 'Czech Republic' where country_region = 'Czechia';
update covid19.countries set country_region = 'Slovak Republic' where country_region = 'Slovakia';
update covid19.countries set country_region = 'Taiwan' where country_region = 'Taiwan*';

-- manually set populations
update covid19.countries set population = 859959, population_year = 2020 where country_region = 'Reunion';
update covid19.countries set population = 376480, population_year = 2016 where country_region = 'Martinique';
update covid19.countries set population = 23780000, population_year = 2018 where country_region = 'Taiwan';
update covid19.countries set population = 290691, population_year = 2020 where country_region = 'French Guiana';
update covid19.countries set population = 1000, population_year = 2017 where country_region = 'Holy See';

-- fix coords and geoms of countries with territories that skew their centroid
update covid19.countries
    set latitude = 47.2,
        longitude = 3.0,
        geom = ST_SetSRID(ST_Makepoint(3.0, 47.2), 4326)
where country_region = 'France';

update covid19.countries
    set latitude = 54.0,
        longitude = -2.0,
        geom = ST_SetSRID(ST_Makepoint(-2.0, 54.0), 4326)
where country_region = 'United Kingdom';

update covid19.countries
    set latitude = 56.0,
        longitude = 9.3,
        geom = ST_SetSRID(ST_Makepoint(9.3, 56.0), 4326)
where country_region = 'Denmark';


delete from covid19.countries where country_region = 'Cruise Ship';

ANALYSE covid19.countries;


-- get World Bank population and normalised infection rates by country
with latest as (
    select country_name,
           max(year) as max_year
    from covid19.world_population
    group by country_name
), pop as (
	select wb.*
	from covid19.world_population as wb
	inner join latest on wb.country_name = latest.country_name
		and wb.year = latest.max_year
)
update covid19.countries as co
	set population = pop.population,
	    population_year = pop.year,
	    confirmed_percent = co.confirmed::float / pop.population:: float * 100.0,
	    deaths_percent = co.deaths::float / pop.population:: float * 100.0,
	    recovered_percent = co.recovered::float / pop.population:: float * 100.0,
	    active_percent = co.active::float / pop.population:: float * 100.0
from pop
where co.country_region = pop.country_name
;

--select * from covid19.countries where population is null;








--DROP TABLE IF EXISTS covid19.countries;
--CREATE TABLE covid19.countries AS
--WITH latest as (
--    select province_state,
--		   country_region,
--		   max(the_date) as max_date
--    from covid19.cases
--	group by province_state,
--		     country_region
--), merge as (
--    select cases.*
--    from covid19.cases
--    inner join latest on cases.province_state IS NOT DISTINCT FROM latest.province_state  -- handle NULLS in join
--            and cases.country_region = latest.country_region
--            and cases.the_date = latest.max_date
--)
--select country_region,
--       min(the_date) as min_date,
--       max(the_date) as max_date,
--       sum(confirmed) as confirmed,
--       sum(deaths) as deaths,
--       sum(recovered) as recovered,
--       sum(active) as active,
--       null::integer as population,
--       null::float as confirmed_percent,
--       null::float as deaths_percent,
--       null::float as recovered_percent,
--       null::float as active_percent,
--       null::smallint as population_year,
--       avg(latitude)::numeric(8,6) as latitude,
--	   avg(longitude)::numeric(9,6) as longitude,
--	   ST_SetSRID(ST_Makepoint(avg(longitude), avg(latitude)), 4326) as geom
--from merge
--group by country_region
--;
--
--ALTER TABLE covid19.countries ADD CONSTRAINT countries_pkey PRIMARY KEY (country_region);
--CREATE INDEX countries_geom_idx ON covid19.countries USING gist (geom);
--ALTER TABLE covid19.countries CLUSTER ON countries_geom_idx;




















--DROP TABLE IF EXISTS covid19.countries_start_date;
--CREATE TABLE covid19.countries_start_date AS
--WITH fst as (
--    select country_region,
--		   min(the_date) as start_date
--    from covid19.cases
--	where confirmed > 0
--	group by country_region
--), merge as (
--    select cnty.*,
--		   fst.start_date
--    from covid19.countries as cnty
--    inner join fst on cnty.country_region = fst.country_region
--            and cnty.the_date >= fst.start_date
--)
--select country_region,
--       the_date - start_date as days,
--       the_date,
--       confirmed,
--       deaths,
--       recovered,
--       active,
--       latitude,
--	   longitude,
--	   ST_SetSRID(ST_Makepoint(longitude, latitude), 4326) as geom
--from merge
--;
--
--ALTER TABLE covid19.countries_start_date ADD CONSTRAINT countries_start_date_pkey PRIMARY KEY (country_region, the_date);
--CREATE INDEX countries_start_date_geom_idx ON covid19.countries_start_date USING gist (geom);
--ALTER TABLE covid19.countries_start_date CLUSTER ON countries_start_date_geom_idx;