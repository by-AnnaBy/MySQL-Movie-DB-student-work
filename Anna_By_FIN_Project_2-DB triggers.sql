USE boxoffice;


--  Сначала я сделала триггеры на "создание" показателей при заполнении таблиц.

/* Первый триггер для автоматического формаривания ID для таблиц по принципу: буквы + цифры.
 * Такие разделения ID позволять в случае необходимости помещать ID разных таблиц в один столбец и при этом их идентифицировать.
*/

DELIMITER //
DROP TRIGGER IF EXISTS film_id_creation//
CREATE TRIGGER film_id_creation BEFORE INSERT ON films
FOR EACH ROW
BEGIN
	DECLARE max_id INT;
	SELECT MAX(id) INTO max_id FROM films;
	IF max_id IS NULL THEN SET NEW.id = 1;
	ELSE SET NEW.id = max_id + 1;
	END IF;
	SET NEW.film_id = concat('ff', lpad(NEW.id, 8, '0'));
END//

DELIMITER ;

/* film_name_check - пусть поле Name будет равно Original name, если его не внесли.  
 * Таким образом, у нас не будет строчек со значением NULL в названии фильма, несмотря на отсутсвие наименования на русском
 */

DELIMITER //

DROP TRIGGER IF EXISTS film_name_check// -- замена пустых значений
CREATE TRIGGER film_name_check BEFORE INSERT ON films
FOR EACH ROW
BEGIN
	SET NEW.name = COALESCE (NEW.name, NEW.original_name);
END//

DELIMITER ;

/* Ещё один триггер, наобходимый при внесении данных - указание дней недели в таблице boxoffice_data  
 */

DELIMITER //
DROP TRIGGER IF EXISTS day_of_week//
CREATE TRIGGER day_of_week BEFORE INSERT ON boxoffice_data
FOR EACH ROW 
BEGIN 
	IF NEW.date IS NULL THEN SET NEW.day_of_week = NULL;
	ELSE SET NEW.day_of_week = DAYNAME(NEW.date);
	END IF;
END//


DELIMITER ;

/* Если брать во внимание не занесение исторических данных в таблицу boxoffice_data, а регулярные апдейты информации по сборам,
 * рационально добавить следующие DEFAULT значения для указания даты.
 * 
 * К сожалениею, у меня не получилось сделать это через ALTER TABLE, выдало ошибку, так что сделаю триггер вместо
 * ALTER TABLE boxoffice_data 
 * 	ALTER COLUMN `year` SET DEFAULT YEAR(NOW());
 * 
 * ALTER TABLE boxoffice_data
 * 	ALTER COLUMN `week` SET DEFAULT WEEK(NOW(), 3);
 * 
 */ 

DELIMITER //
DROP TRIGGER IF EXISTS boxoffice_data_default_year//
CREATE TRIGGER boxoffice_data_default_year BEFORE INSERT ON boxoffice_data
FOR EACH ROW 
BEGIN 
	SET NEW.`year` = COALESCE (NEW.`year`, YEAR(current_date));
END//
DELIMITER ;

DELIMITER //
DROP TRIGGER IF EXISTS boxoffice_data_default_week//
CREATE TRIGGER boxoffice_data_default_week BEFORE INSERT ON boxoffice_data
FOR EACH ROW 
BEGIN 
	SET NEW.`week` = COALESCE (NEW.`week`, WEEK(NOW(), 1));
END//
DELIMITER ;


/* Ниже созданы триггеры по аналогии с описанными выше (xxx)_id_creation и category_check.
 * А так же повторение триггера day_of_week, но уже на апдейт таблицы.
*/
DELIMITER //

DROP TRIGGER IF EXISTS person_id_creation//
CREATE TRIGGER person_id_creation BEFORE INSERT ON persons
FOR EACH ROW
BEGIN
	DECLARE max_id INT;
	SELECT MAX(id) INTO max_id FROM persons;
	IF max_id IS NULL THEN SET NEW.id = 1;
	ELSE SET NEW.id = max_id + 1;
	END IF;
	SET NEW.person_id = concat('pp', lpad(NEW.id, 8, '0'));
END//

DROP TRIGGER IF EXISTS collections_id_creation//
CREATE TRIGGER collections_id_creation BEFORE INSERT ON collections
FOR EACH ROW
BEGIN
	DECLARE max_id INT;
	SELECT MAX(id) INTO max_id FROM collections;
	IF max_id IS NULL THEN SET NEW.id = 1;
	ELSE SET NEW.id = max_id + 1;
	END IF;
	SET NEW.collection_id = concat('cc', lpad(NEW.id, 8, '0'));
END//

DROP TRIGGER IF EXISTS event_id_creation//
CREATE TRIGGER event_id_creation BEFORE INSERT ON events
FOR EACH ROW
BEGIN
	DECLARE max_id INT;
	SELECT MAX(id) INTO max_id FROM events;
	IF max_id IS NULL THEN SET NEW.id = 1;
	ELSE SET NEW.id = max_id + 1;
	END IF;
	SET NEW.event_id = concat('ee', lpad(NEW.id, 8, '0'));
END//

DROP TRIGGER IF EXISTS nomination_id_creation//
CREATE TRIGGER nomination_id_creation BEFORE INSERT ON events_competitions
FOR EACH ROW
BEGIN
	DECLARE max_id INT;
	SELECT MAX(id) INTO max_id FROM events_competitions;
	IF max_id IS NULL THEN SET NEW.id = 1;
	ELSE SET NEW.id = max_id + 1;
	END IF;
	SET NEW.nomination_id = concat('ec', lpad(NEW.id, 8, '0'));
END//

/*  
 * category_check аналогично film_name_check 
 * при отсутсвии названия Категории награды на фестивалях.
 */

DROP TRIGGER IF EXISTS category_check// -- замена пустых значений
CREATE TRIGGER category_check BEFORE INSERT ON events
FOR EACH ROW
BEGIN
	SET NEW.category = COALESCE (NEW.category, NEW.event_award_name);
END//

/*  
 * Триггер на апдейт на случай исправления даты.
 */
DROP TRIGGER IF EXISTS day_of_week//
CREATE TRIGGER day_of_week BEFORE UPDATE ON boxoffice_data
FOR EACH ROW 
BEGIN 
	IF NEW.date IS NULL THEN SET NEW.day_of_week = NULL;
	ELSE SET NEW.day_of_week = DAYNAME(NEW.date);
	END IF;
END//
DELIMITER ;