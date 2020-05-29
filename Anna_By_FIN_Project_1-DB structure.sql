/*
 * Существует сайт IMDB Pro для специалистов киноиндустрии. Он позволяет совместить
 * данные по индустрии(детальные данные о сборах фильма в кино - ресурс "бывшего" BoxOfficeMojo) 
 * с общедоступной информацией о фильмах(общая информация о фильмах, рейтинги открытый сайт IMDB).
 * Это позволяет расширить возможности анализа рынка.
 * Я решила сделать для себя такую же базу, чтобы использовать её для своих студенческих проектов по анализу рынка кино.
 */


DROP DATABASE IF EXISTS boxoffice;
CREATE DATABASE boxoffice;
USE boxoffice;


/* Основная родительская таблица с фильмами films, содержащая базовую информацию: название фильма, год, страну производства, продолжительность фильма и студия производитель.
 * Хотя в год могут выходить фильмы с одинаковыми названиями причем в одной и той же стране, 
 * надеюсь продолжительность фильма позволит создать уникальную комбинацию для отсеивания случайных дублирований фильмов.
*/

DROP TABLE IF EXISTS films;  
CREATE TABLE films(
	id INT UNSIGNED NOT NULL UNIQUE,
	film_id CHAR(10) NOT NULL PRIMARY KEY,
	name VARCHAR(120) NOT NULL COMMENT 'Название фильма',
	original_name VARCHAR(120) NOT NULL COMMENT 'Название фильм на языке оригинала',
	`year` YEAR NOT NULL,
	country VARCHAR(100) NOT NULL,
	screan_time INT NOT NULL, -- в минутах
	
	INDEX(id),
	INDEX (name),
	INDEX (original_name),
	INDEX (year),

	UNIQUE INDEX (original_name, year,screan_time)	
) COMMENT = 'Основная информация о фильмах';

/* Таблица details содержит дополнительную информацию о фильме: возрастные рейтинги, описание фильма, логлайн и тд.
 * Я выделила их в отдельную таблицу, так как к этим данным реже обращаются.
 */

DROP TABLE IF EXISTS details;  
CREATE TABLE details(
	film_id CHAR(10) NOT NULL PRIMARY KEY,
	age_rating ENUM('0+','6+','12+','16+','18+'),
	mmpa_rating ENUM('G','PG','PG-13','R','NC-17','NR'),
	description TEXT,
	logline TEXT,
	studio VARCHAR(150),
	budget BIGINT UNSIGNED,
	budget_currency CHAR(3) DEFAULT "USD",
	int_premier_date DATE,
	digital_release_date DATE,
	imdb_reference VARCHAR(10),

	
	INDEX (int_premier_date),
	INDEX (studio),
	UNIQUE INDEX (imdb_reference),
	
 	FOREIGN KEY (film_id) 
 		REFERENCES films(film_id)
    	ON UPDATE CASCADE 
    	ON DELETE RESTRICT
    ) COMMENT = 'Дополнительная информация о фильмах: возрастные рейтинги, описание и тд';

/* Таблица рейтингов содержит рейтинги фильмов со сторонних площадок. 
 * Я решила вынести их в отдельную таблицу, так как их надо достаточно часто обновлять 
 */

DROP TABLE IF EXISTS ratings;
CREATE TABLE ratings(
	film_id CHAR(10) NOT NULL PRIMARY KEY,
	imdb DECIMAL UNSIGNED COMMENT 'из 10, показатель с 1 знаком после запятой',
	rottentomatos TINYINT UNSIGNED COMMENT 'в процентах, максимум 100',
	metacritics TINYINT  UNSIGNED COMMENT 'показатель от 0 до 100',
	
	FOREIGN KEY (film_id) 
		REFERENCES films(film_id)
    	ON UPDATE CASCADE 
    	ON DELETE RESTRICT
) COMMENT = 'Данные по рейтингам с разных источников';

/* Таблица Genre содержит имеющиеся жанры кино. Я её не индексирую, количество жанров не превышает 30-40 штук.
 */

DROP TABLE IF EXISTS genres;
CREATE TABLE genres(
	id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
	name VARCHAR(100)
) COMMENT = 'Жанры кино';


/* Поскольку 1 фильм редко определяется только 1 жанром, я сделала разбивку многие-ко-многим по жанрам. 
 */

DROP TABLE IF EXISTS films_genres;
CREATE TABLE films_genre(
	film_id CHAR(10) NOT NULL,
	genre_id INT UNSIGNED NOT NULL,
	
	FOREIGN KEY (film_id) 
		REFERENCES films(film_id)
    	ON UPDATE CASCADE 
    	ON DELETE RESTRICT,
	FOREIGN KEY (genre_id) 
		REFERENCES genres(id)
) COMMENT = 'Список фильмов по жанрам';

/* Таблица Persons содержит список работников киноиндустрии. Это могут быть актеры, режиссеры, продюсеры и проч.
 */

DROP TABLE IF EXISTS persons;
CREATE TABLE persons(
	id INT UNSIGNED NOT NULL UNIQUE,
	person_id CHAR(10) NOT NULL PRIMARY KEY,
	name_rus VARCHAR(120) NOT NULL,
	name_eng VARCHAR(120) NOT NULL,
	birthday DATE,
	birth_place VARCHAR(160),
	imdb_reference VARCHAR(10),
	
	INDEX(id),	
	INDEX(name_rus),
	INDEX(name_eng),
	INDEX(imdb_reference),
	
	UNIQUE KEY(name_rus, birthday)
) COMMENT = 'Работники киноиндустрии';

/* Таблица filmography соотносит список работников киноиндустрии с фильмами и их роли в них.
 * Для актеров я вывела дополнительный 
 */

DROP TABLE IF EXISTS filmography;
CREATE TABLE filmography(
	id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
	film_id CHAR(10) NOT NULL,
	person_id CHAR(10) NOT NULL,
	role_in_team VARCHAR(120), -- роль в команде: режиссер, оператор, актер и тд.
	role_in_film VARCHAR(150), -- ДЛЯ АКТЕРОВ: как указано в титрах его роль (имя персонажа или "второй друг друга")
	
	INDEX (film_id),
	INDEX (person_id),
	INDEX (role_in_team),
	
	FOREIGN KEY (film_id) 
		REFERENCES films(film_id)
		ON UPDATE CASCADE 
    	ON DELETE RESTRICT,
	FOREIGN KEY (person_id) 
		REFERENCES persons(person_id)
		ON UPDATE CASCADE 
    	ON DELETE RESTRICT
) COMMENT = 'Распределение ролей по фильму';

/* Таблица collections создана как для объединения фильмов во франшизы, 
 * так и для создания различных подборок фильмов. 
 */

DROP TABLE IF EXISTS collections;
CREATE TABLE collections(
	id INT UNSIGNED NOT NULL UNIQUE,
	collection_id CHAR(10) NOT NULL PRIMARY KEY,
	name VARCHAR(255) NOT NULL,
	
	INDEX(id)	
) COMMENT = 'Каталог франшиз, сборников, топов и тд';

/* Таблица film_collections подразумевает связь многие-ко-многим.
 */

DROP TABLE IF EXISTS films_collections;
CREATE TABLE films_collections(
	film_id  CHAR(10) NOT NULL,
	collection_id  CHAR(10) NOT NULL,
	
	FOREIGN KEY (film_id) 
		REFERENCES films(film_id)
		ON UPDATE CASCADE 
    	ON DELETE RESTRICT,
	FOREIGN KEY (collection_id) 
		REFERENCES collections(collection_id)	
		ON UPDATE CASCADE 
    	ON DELETE RESTRICT
) COMMENT = 'Список фильмов по подборкам';

/* Список кинофестивалей с имеющимися внутри фестиваля номинациями. 
 * Несмотря на наличие общих для всех фестивалей категорий номинаций, такие как "Лучшая мужская роль первого плана", "Лучшая операторская работа" и тд,
 * я не стала разделять фестивали и номинации в разные таблицы, так как во многих фестивалях есть свои специфические номинации,
 * например, Золотой и Серебрянный медведь в Берлинале.
 */

DROP TABLE IF EXISTS events;
CREATE TABLE events(
	id INT UNSIGNED NOT NULL UNIQUE,
	event_id CHAR(10) NOT NULL PRIMARY KEY,
	event_name VARCHAR(255) NOT NULL,
	event_award_name VARCHAR(255),
	category VARCHAR(255) NOT NULL,

	INDEX(id),
	INDEX(event_award_name),
	INDEX(category),
	
	UNIQUE KEY (event_name, event_award_name, category)
) COMMENT = 'Список фестивалей и номинаций внутри';

/* Таблица номинантов и победителей фестивалей. 
 * Для актерских номинация добавлена отдельная ссылка на таблицу с работниками киноиндустрии.
 */

DROP TABLE IF EXISTS events_competitions;
CREATE TABLE events_competitions(
	id INT UNSIGNED NOT NULL,
	nomination_id CHAR(10) NOT NULL PRIMARY KEY,
	film_id CHAR(10) NOT NULL,
	`year` YEAR NOT NULL,
	award_id CHAR(10) NOT NULL,
	award_result ENUM('Nominee', 'Winner'), -- Nominee or Winner
	person_id CHAR(10),

	INDEX(film_id),
	INDEX(award_id),
	UNIQUE INDEX(film_id, `year`, award_id, person_id),
	
	FOREIGN KEY (film_id) 
		REFERENCES films(film_id)
		ON UPDATE CASCADE 
    	ON DELETE RESTRICT,
	FOREIGN KEY (award_id) 
		REFERENCES events(event_id)
		ON UPDATE CASCADE 
    	ON DELETE RESTRICT,
	FOREIGN KEY (person_id) 
		REFERENCES persons(person_id)
		ON UPDATE CASCADE 
    	ON DELETE RESTRICT
) COMMENT = 'Учатсники фестивалей по номинациям';

/* Таблица boxoffice содержит ежедневные отчеты по сборам с фильмов. 
 * В идеале данные должны вноситься по городам, однако не всегда можно достать такую детальную информацию, 
 * поэтому проставила данные по странам.
 * 
 * В таблице ведется лог апдейтов на случай исправления ранее не правильно внесенных данных по прокату.
 */

DROP TABLE IF EXISTS boxoffice_data;
CREATE TABLE boxoffice_data(
	id SERIAL PRIMARY KEY,
	film_id CHAR(10) NOT NULL,	
	country VARCHAR(100) NOT NULL,
	city VARCHAR(100),
	`year` YEAR NOT NULL,
	`week` SMALLINT UNSIGNED NOT NULL, -- номер недели в году (Пон - Вск). иногда информацию можно найти только по неделям/уикэндам, поэтому она в приоритете над днём  
	`date` DATE, -- может быть пустой, если по стране не собирают информацию по дням проката
	day_of_week VARCHAR (10),
	date_comment VARCHAR (255),
	days_in_theaters SMALLINT UNSIGNED,
	weeks_in_theaters SMALLINT UNSIGNED,
	currency CHAR(3) DEFAULT "USD",
	gross_profit BIGINT UNSIGNED NOT NULL,
	screans INT UNSIGNED,
	viewers INT UNSIGNED,
	gross_up_to_date BIGINT UNSIGNED NOT NULL,
	created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
	updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	
	INDEX(film_id),
	INDEX(country),
	
	FOREIGN KEY (film_id) 
		REFERENCES films(film_id)
		ON UPDATE CASCADE 
    	ON DELETE RESTRICT
) COMMENT = 'Сборы фильма по дням по городам/странам';



	

