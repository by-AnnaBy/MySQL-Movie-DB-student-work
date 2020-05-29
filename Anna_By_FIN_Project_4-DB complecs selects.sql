USE boxoffice;


/* Одним из возможных запросов может быть таблица по сезонности данных за последние 5 лет.
 * Сделаем представление.
 * Сначала соберем представление с месячными сборами фильмов по странам
 */

DROP VIEW IF EXISTS monthly_gross_by_film_and_country;
CREATE VIEW monthly_gross_by_film_and_country AS
	SELECT bd1.film_id,
		bd1.country,
		bd1.`year`,
		bd1.months,
		CASE 
			WHEN bd1.max_gross > bd2.prev_max_gross THEN (bd1.max_gross - bd2.prev_max_gross) 
			WHEN bd1.max_gross < bd2.prev_max_gross THEN bd1.sum_gross
			WHEN bd2.prev_max_gross is NULL THEN bd1.max_gross
		END as monthly_gross
		FROM 
			(SELECT film_id,
			country,
			`year`,
			MONTH(STR_TO_DATE(CONCAT(`year`, ' ', week, ' Tuesday'), '%X %V %W')) as months,
			sum(gross_profit) as sum_gross,
			max(gross_up_to_date) as max_gross
			FROM boxoffice_data
			GROUP BY film_id, country,months) as bd1
		LEFT JOIN
			(SELECT film_id,
			country,
			`year`,
			MONTH(STR_TO_DATE(CONCAT(`year`, ' ', week, ' Tuesday'), '%X %V %W')) + 1 as months,
			max(gross_up_to_date) as prev_max_gross
			FROM boxoffice_data
			GROUP BY film_id, country,months) as bd2 
		ON bd1.film_id = bd2.film_id AND bd1.country = bd2.country AND bd1.months = bd2.months;
	
SELECT * FROM monthly_gross_by_film_and_country;

-- Теперь на основе представления с детальной разбивкой соберем представление, которое будет показывать только матрицу Сезоны - Года.

DROP VIEW IF EXISTS seasonal_gross_5_years;
CREATE VIEW seasonal_gross_5_years AS
	SELECT 
		cal.seasons,		
 		sum(prev_y4.y_gross) as '4 years ago',
 		sum(prev_y3.y_gross) as '3 years ago',
 		sum(prev_y2.y_gross) as '2 years ago',
 		sum(prev_y1.y_gross) as '1 years ago',
 		sum(cur_y.y_gross) as 'Current year'
	FROM  
		(SELECT 
 		CASE 
 			WHEN months IN (3,4,5) THEN 'Spring'
 			WHEN months IN (6,7,8) THEN 'Summer'
 			WHEN months IN (9,10,11) THEN 'Autumn'
 			ELSE 'Winter'
 		END as seasons,
		months
		FROM  
			monthly_gross_by_film_and_country
		GROUP BY months) as cal
		LEFT JOIN 
		(SELECT 
			months,
			SUM(monthly_gross) as y_gross
			FROM  
				monthly_gross_by_film_and_country
			WHERE `year` = (YEAR(NOW()))
			GROUP BY months) as cur_y ON cal.months = cur_y.months
		LEFT JOIN 
			(SELECT 
			months,
			SUM(monthly_gross) as y_gross
			FROM  
				monthly_gross_by_film_and_country
			WHERE `year` = (YEAR(NOW()) - 1)
			GROUP BY months) as prev_y1 ON cal.months = prev_y1.months
		LEFT JOIN 
			(SELECT 
			months,
			SUM(monthly_gross) as y_gross
			FROM  
				monthly_gross_by_film_and_country
			WHERE `year` = (YEAR(NOW()) - 2)
			GROUP BY months) as prev_y2 ON cal.months = prev_y2.months		
		LEFT JOIN 
			(SELECT 
			months,
			SUM(monthly_gross) as y_gross
			FROM  
				monthly_gross_by_film_and_country
			WHERE `year` = (YEAR(NOW()) - 3)
			GROUP BY months) as prev_y3 ON cal.months = prev_y3.months	
		LEFT JOIN 
			(SELECT 
			months,
			SUM(monthly_gross) as y_gross
			FROM  
				monthly_gross_by_film_and_country
			WHERE `year` = (YEAR(NOW()) - 4)
			GROUP BY months) as prev_y4 ON cal.months = prev_y4.months
	GROUP BY cal.seasons
	ORDER BY cal.months;
	
SELECT * FROM seasonal_gross_5_years;