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


-- После создания таблицы надо залить в неё данные (через CSV файл, но я так же приложила дополнительный SQL скрипт с INSERT INTO awards с небольшой выборкой данных.
-- Загрузка приложенного CSV может занять от 2 до 5 минут.


-- Для переноса данных я решила сделать процедуры. Их будет легко вызывать после загрузки нового CSV. 
-- Сначала процедура для занесения данных в каталог существующих фестивалей.

DROP PROCEDURE IF EXISTS new_events;

DELIMITER // 
CREATE PROCEDURE new_events()
BEGIN

	-- сначала нормализуем данные в таблице awards 
	DELETE FROM awards 
	WHERE awardName is NULL;

	UPDATE awards 
	SET categoryName = awardName,
		awardName = concat(eventName, " - ", awardName)
	WHERE categoryName is NULL;
	
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
 
/*	
 * в таблице awards есть поле eventId с идентификатором из IMDB. Он ссылается на ID связанный с EventName.
 * я не использую его при миграции данных. 
 * Если принебречь фактом дозагрузок(допустим каждый раз после миграции данных делать TRUNCATE таблицы Awards, что логично, ведь она занимает место,
 * то для удобства, можно заменить awards eventId на ID из таблицы Events (ключ для связки EventName + Award + Category)
 * Это ускорит дальнейшие процедуры в несколько раз.
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
		SET a.eventId = e.event_id;

END//

/*	
	Если не заменять поле EventID, то необходимо составить составной внешний ключ для ускорения запросов
	ALTER TABLE awards
ADD CONSTRAINT awards_events_fk1 FOREIGN KEY (eventName, awardName, categoryName)
	REFERENCES events(event_name, event_award_name, category);
 */
	

/* Для следующей таблицы будет нужно поменять True/False на ENUM('Nominee', 'Winner')
 * Можно было бы просто написать CASE внутри SELECT запроса, 
 * но я решила написать отдельную функцию, чтобы не нагромождать внешне селект запрос.
 */

DELIMITER ;
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

/*
 * Теперь создадим процедуру, которая будет переносить данные о номинантах фестивалей в таблицу events_competitions.
 * В связи с особенностями структуры awards нам понадобится 2 запроса:
 * INSERT на внесение данных по фильму
 * UPDATE если это номинация не для фильма, а человека, например, актера в главные роли.
 */

DROP PROCEDURE IF EXISTS new_nominations;

DELIMITER // 
CREATE PROCEDURE new_nominations()
BEGIN
	
	INSERT INTO events_competitions(film_id, `year`, award_id, award_result, person_id)
		SELECT DISTINCTROW
			d.film_id,
			a.`year`,
			a.eventId,
			win_or_not(a.isWinner),
			NULL
		FROM 
			(awards as a
			INNER JOIN 
			details as d ON a.const = d.imdb_reference)
			LEFT JOIN
			events_competitions as ec 
			ON 
 				(d.film_id = ec.film_id OR ec.film_id is NULL)
 				AND 
 				(a.`year` = ec.`year` OR ec.`year` is NULL)
 				AND
 				(a.eventId = ec.award_id OR ec.award_id is NULL)
 				AND
 				(ec.award_result = win_or_not(a.isWinner) OR ec.award_result is NULL)
		WHERE 
			a.const = d.imdb_reference
			AND a.isPrimary = 'True'
			AND ec.nomination_id is NULL
		UNION
		SELECT DISTINCTROW 
		 	d.film_id,
		 	aF.`year`,
		 	aF.eventId,
		 	win_or_not(aF.isWinner),
		 	p.person_id
		FROM 
			(awards as aF
			JOIN
			details as d ON aF.const = d.imdb_reference
			JOIN
			filmography as f ON d.film_id = f.film_id
			JOIN
			persons as p ON f.person_id = p.person_id
			JOIN 
			awards as aP ON (aP.eventId = aF.eventId AND aP.const = p.imdb_reference AND aF.isWinner = aP.isWinner))
			LEFT JOIN 
			events_competitions as ec 
			ON 
 				(d.film_id = ec.film_id OR ec.film_id is NULL)
 				AND 
 				(aF.`year` = ec.`year` OR ec.`year` is NULL)
 				AND
 				(aF.eventId = ec.award_id OR ec.award_id is NULL)
 				AND
 				(ec.award_result = win_or_not(aF.isWinner) OR ec.award_result is NULL)
		WHERE 
			aF.const = d.imdb_reference
			AND aF.isPrimary = 'False'
			AND ec.nomination_id is NULL;
END//

DELIMITER ;

-- переносим в нашу базу данные о существующих фестивалях и номинациях в таблицу events

CALL new_events();

-- и данные по номинациям и победам фильмов на этих мероприятиях

CALL new_nominations(); 	

-- можно проверить загрузились ли данные простыми селектами

SELECT * FROM events LIMIT 100;
SELECT * FROM events_competitions LIMIT 100;

-- так же можно провести проверку, точно ли подгружаются только новые данные. допустим удалим данные по одному из фильмов

DELETE FROM events_competitions WHERE film_id = 'ff00000044';
SELECT * FROM events_competitions WHERE film_id = 'ff00000044'; -- проверим, что данные удалились

CALL new_nominations(); -- запустим подгрузку данных

SELECT * FROM events_competitions WHERE film_id = 'ff00000044'; -- проверяем ещё раз

-- после окончания загрузки можно спокойно очистить таблицу awards, чтобы она не занимала место на диске. предположительно, фестивали можно грузить 1 раз в месяц, а то и реже

TRUNCATE TABLE awards;

