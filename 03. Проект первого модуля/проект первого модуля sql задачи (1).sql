/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 *
 * Автор:
 * Дата:
*/
-- 1. в задаче 1 (время активности объявлений) не понимаю в пункет нужно доработать вопроса "какие типы квартир продаются быстро", а также не понимаю как рассчитать и вставить долю по регионам, не увеличивая по объему код еще на несколько CTE
-- также не понял как округлить значения медианы для средних показателей



-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
 SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats 
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
-- Продолжите запрос здесь
-- Используйте id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных
SELECT 
	CASE 
	WHEN c.city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
	WHEN c.city != 'Санкт-Петербург' AND t.type = 'город' THEN 'города Ленинградской области'
	ELSE 'территория Ленинградской области'
END AS "region",
	CASE 
	WHEN days_exposition <=30 THEN 'low'
	WHEN days_exposition BETWEEN 31 AND 90 THEN 'middle'
	WHEN days_exposition BETWEEN 91 AND 180 THEN 'hight'
	WHEN days_exposition > 181 THEN 'very_hight'
	ELSE 'non category'
END AS "category",
	round(count(f.id)::numeric, 2) AS adv_count,
	round(avg(a.last_price / f.total_area)::NUMERIC, 2) AS meter_price,
	round(avg(f.total_area)::NUMERIC, 2) AS avg_area,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.total_area) AS med_total_area,
	round(avg(f.rooms)::NUMERIC, 2) AS avg_rooms,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.rooms) AS med_rooms,
	round(avg(f.balcony)::NUMERIC, 2) AS balcony_avg,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.balcony) AS med_balcony,
	round(avg( f.ceiling_height)::NUMERIC, 2) AS avg_ceil,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.ceiling_height) AS med_ceiling_height
from real_estate.advertisement as a 
join real_estate.flats as f on a.id = f.id
join real_estate.city as c on f.city_id = c.city_id 
join real_estate.type as t on f.type_id = t.type_id
WHERE f.id IN (SELECT f.id FROM filtered_id) AND first_day_exposition BETWEEN '2015.01.01' AND '2018.12.31'
GROUP BY region, category
-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
    	PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
-- Продолжите запрос здесь
-- Используйте id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных
adv_months AS (
SELECT 
	a.id,
	TO_CHAR(first_day_exposition, 'Month') AS f_month,
    TO_CHAR(first_day_exposition + (days_exposition::int), 'Month') AS l_month,
	last_price,
	f.total_area,
	c.city
FROM real_estate.advertisement AS a
JOIN real_estate.flats AS f ON a.id = f.id 
JOIN real_estate.city AS c ON f.city_id = c.city_id
JOIN real_estate.TYPE AS t ON f.type_id = t.TYPE_id
WHERE a.id IN (SELECT * FROM filtered_id) AND days_exposition IS NOT NULL AND first_day_exposition BETWEEN '2015.01.01' AND '2018.12.31' AND t.type = 'город'
),
publication_stats AS (
    SELECT 
        f_month AS month_period,
        COUNT(id) AS adv_count_published,
        round(AVG(last_price / total_area)::NUMERIC, 2) AS avg_meter_published,
        round(AVG(total_area)::NUMERIC, 2) AS avg_area_published
    FROM adv_months
    WHERE total_area > 0 AND last_price > 0
    GROUP BY f_month
),
removal_stats AS (
    SELECT 
        l_month AS month_period,
        COUNT(id) AS adv_count_removed,
        round(AVG(last_price / total_area)::NUMERIC, 2) AS avg_meter_removed,
        round(AVG(total_area)::NUMERIC, 2) AS avg_area_removed
    FROM adv_months
    WHERE total_area > 0 AND last_price > 0
    GROUP BY l_month
)
SELECT *
FROM publication_stats AS ps 
JOIN removal_stats AS rs ON ps.month_period = rs.month_period
ORDER BY adv_count_published DESC 
