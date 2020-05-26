USE boxoffice;

-- Таблица Awards повторяет структуру CVS датасета, взятого с Kaggle

DROP TABLE IF EXISTS awards;
CREATE TABLE awards(
	eventId VARCHAR(60),
	eventName VARCHAR(255),
	awardName VARCHAR(255),
	`year` YEAR,
	occurrence INT,
	winAnnouncementTime DECIMAL,
	categoryName VARCHAR(255),
	nomeneeNote VARCHAR(255),
	name VARCHAR(255),
	originalName VARCHAR(255),
	songNames VARCHAR(255),
	episodeNames VARCHAR(255),
	characterNames VARCHAR(255),
	isWinner ENUM('True','False'),
	isPrimary ENUM('True','False'),
	isSecondary ENUM('True','False'),
	isPerson ENUM('True','False'),
	isTitle ENUM('True','False'),
	isCompany ENUM('True','False'),
	const VARCHAR(60),
	
	index(eventName),
	index(awardName),
	index(categoryName)
);

-- TRUNCATE TABLE events_competitions;
-- TRUNCATE TABLE events;

-- Для переноса данных я решила сделать процедуры. Их будет легко вызывать после загрузки нового CSV. 
-- Сначала процедура для занесения данных в каталог существующих фестивалей.


DROP PROCEDURE IF EXISTS new_events;

DELIMITER // 
CREATE PROCEDURE new_events()
BEGIN

	-- сначала нормализуем данные в таблице awards 
	DELETE FROM awards 
	WHERE categoryName is NULL;

	UPDATE awards 
	SET categoryName = awardName,
		awardName = concat(eventName, " - ", awardName);
	
	-- перенесем новые данные в таблицу events
	INSERT INTO events(event_name, event_award_name, category)
	SELECT 
		a.eventName,
		a.awardName,
		a.categoryName
	FROM 
		awards as a
		LEFT JOIN
		events as e
	ON
		(a.eventName = e.event_name 
		AND 
		a.awardName = e.event_award_name 
		AND 
		a.categoryName = e.category)
	WHERE 
		e.event_name is NULL
		AND 
		e.event_award_name is NULL
		AND 
		e.category is NULL
	GROUP BY
		a.eventName,
		a.awardName,
		a.categoryName;
/* в таблице awards есть поле eventId с идентификатором из IMDB. Он ссылается на ID связанный с EventName.
 * я не использую его при миграции данных. для удобства, заменю его на ID из таблицы Events (ключ для связки EventName + Award + Category
 */
	
	UPDATE awards as a
		INNER JOIN
		events as e
		ON
			a.eventName = e.event_name 
			AND 
			a.awardName = e.event_award_name 
			AND 
			a.categoryName = e.category
		GROUP BY
			a.eventName,
			a.awardName,
			a.categoryName
	SET a.eventId = e.id;

END//

DELIMITER ;

-- переносим в нашу базу данные о существующих фестивалях и номинациях

CALL new_events();

/* Для следующей таблицы будет нужно поменять True/False на ENUM('Nominee', 'Winner')
 * Можно было бы просто написать CASE внутри SELECT запроса, 
 * но я решила написать отдельную функцию, чтобы не нагромождать внешне селект запрос.
 */

DROP FUNCTION IF EXISTS win_or_not;

DELIMITER //
CREATE FUNCTION win_or_not(isWinner_value ENUM('True','False'))
RETURNS ENUM('Nominee', 'Winner') DETERMINISTIC
BEGIN
	DECLARE award_result VARCHAR(10);
	CASE isWinner_value
		WHEN 'True' THEN SET award_result = 'Winner';
		ELSE SET award_result = 'Nominee';
	END CASE;
	RETURN award_result; 
END//

DELIMITER ;

INSERT INTO events_competitions(film_id, `year`, award_id, award_result)
SELECT 
	d.film_id,
	a.`year`,
	e.id,
	win_or_not(a.isWinner)
FROM 
	awards as a
	INNER JOIN
	details as d ON a.const = d.imdb_reference
	INNER JOIN
	events as e ON (a.eventName = e.event_name AND a.awardName = event_award_name AND a.categoryName = e.category)
WHERE 
	a.const = d.imdb_reference;

DELIMITER //

DROP PROCEDURE IF EXISTS person_nominee//
CREATE PROCEDURE person_nominee()

UPDATE 
SELECT 
	comp.id,
	comp.award_id,
	ev.id,
	ev.event_name,
	ev.event_award_name,
	ev.category,
	det.film_id,
	per.id
FROM
	events_competitions as comp
	JOIN
	events as ev ON (ev.id = comp.award_id)
	JOIN 
	awards as aw1 ON (ev.event_name = aw1.eventName AND ev.event_award_name = aw1.awardName AND ev.category = aw1.categoryName AND comp.`year` = aw1.`year`)
	JOIN
	awards as aw2 ON (aw1.eventName = aw2.eventName AND aw1.awardName = aw2.awardName AND aw1.categoryName = aw2.categoryName AND aw1.`year` = aw2.`year`)
	JOIN
	details as det ON (aw1.const = det.imdb_reference)
	JOIN
	persons as per ON (aw2.const = per.imdb_reference)
	JOIN
 	filmography as film ON (det.film_id = film.film_id AND per.id = film.person_id)
WHERE aw1.occurrence > 1 AND aw1.isPrimary = 'False';
	

SELECT count(*) FROM events_competitions;


EXPLAIN SELECT 
	comp.id,
	comp.award_id,
	ev.id,
	ev.event_name,
	ev.event_award_name,
	ev.category,
	det.film_id,
	-- films.name,
	per.id
FROM 
	awards as aw1 -- 788 545 строк 
	JOIN
	awards as aw2  -- 788 545 строк 
		ON (aw1.eventName = aw2.eventName AND aw1.awardName = aw2.awardName AND aw1.categoryName = aw2.categoryName AND aw1.`year` = aw2.`year`)
	JOIN
	events as ev -- 93 441 строк
		ON (aw1.eventName = ev.event_name AND aw1.awardName = ev.event_award_name AND aw1.categoryName = ev.category) 
	JOIN
	details as det -- 55 строк
		ON (aw1.const = det.imdb_reference)
	JOIN
	persons as per  -- 161 строка
		ON (aw2.const = per.imdb_reference)
	JOIN
 	filmography as film -- 165 строк
 		ON (det.film_id = film.film_id AND per.id = film.person_id)
 	JOIN 
 	events_competitions as comp -- 1 104 строки
 		ON (ev.id = comp.award_id AND det.film_id = comp.film_id AND aw1.`year` = comp.`year`)
WHERE aw1.isPrimary = 'False';

