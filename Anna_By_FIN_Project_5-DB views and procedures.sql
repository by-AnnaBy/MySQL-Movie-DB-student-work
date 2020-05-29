USE boxoffice;


/* Самым очевидным запросом является поиск фильма по его названию/жанру/году
 * Я решила сделать представление с базовой информацией по фильму, которую обычно можно увидеть в результатах поиска (например, на сайте Кинопоиск)ю
 * Это представление я буду использовать в процедурах для поиска
 */

CREATE VIEW film_general_info AS
	SELECT f.film_id as 'ID',
	f.name as 'Название',
	f.original_name as 'На языке оригинала',
	f.`year` as 'Год',
	f.country as 'Страна',
	GROUP_CONCAT(DISTINCT g.name ORDER BY g.name ASC SEPARATOR ', ') as 'Жанр',
	CASE 
		WHEN p.name_rus IS NULL THEN ''
		ELSE GROUP_CONCAT(DISTINCT p.name_rus ORDER BY p.name_rus ASC SEPARATOR ', ')
	END as 'Режиссёр',
	CONCAT(f.screan_time, ' мин') as 'Продолжительность'
	FROM films as f 
	LEFT JOIN 
	((SELECT * FROM filmography WHERE role_in_team = 'режиссер') as film 
		JOIN
		persons as p ON film.person_id = p.person_id) ON f.film_id = film.film_id
	LEFT JOIN 
	(films_genre as fg
		JOIN
		genres as g ON fg.genre_id = g.id) ON f.film_id = fg.film_id 
	GROUP BY f.film_id;

-- для начала сделаю процедуру, которая будет искать только по названиям фильмов

DELIMITER //
DROP PROCEDURE IF EXISTS search_by_film_name//
CREATE PROCEDURE search_by_film_name(text VARCHAR(100))
BEGIN
	SELECT *
	FROM film_general_info
	WHERE 
	`Название` like concat('%', text, '%')
	OR `На языке оригинала` like concat('%', text, '%');
END//
DELIMITER ;

-- теперь добавлю процедуру, в которой можно искать среди любых полей в представлении. Ожидаю, что такой запрос будет работать медленнее, при большом количестве строк

DELIMITER //
DROP PROCEDURE IF EXISTS search_in_film_general_info//
CREATE PROCEDURE search_in_film_general_info (text VARCHAR(100))
BEGIN
	SELECT *
	FROM film_general_info WHERE  
	`Название` like concat('%', text, '%')
	OR
	`На языке оригинала` like concat('%', text, '%')
	OR 
	`Год` like concat('%', text, '%')
	OR
	`Страна` like concat('%', text, '%')
	OR
	`Жанр` like concat('%', text, '%')
	OR
	`Режиссёр` like concat('%', text, '%')
	OR
	`Продолжительность` like concat('%', text, '%');
END//
DELIMITER ;

-- Проверка работы процедур

CALL search_by_film_name('k'); -- результат: 6 фильмов, у которых в названии есть K
CALL search_in_film_general_info('k'); -- результат: 11 фильмов, у которых в инфу есть K, включая фильмы, произведенные в UK и тд

CALL search_in_film_general_info('Фавро'); 