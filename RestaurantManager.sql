-- SEQUENCES
CREATE SEQUENCE menu_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE order_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE feedback_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE customer_seq START WITH 1 INCREMENT BY 1;

-- TABLES
CREATE TABLE menu (
    id INTEGER DEFAULT menu_seq.nextval PRIMARY KEY,
    name VARCHAR(30) CONSTRAINT name_notnull NOT NULL
                     CONSTRAINT name_uniq UNIQUE,
    cost INTEGER CONSTRAINT cost_notnull NOT NULL,
    allergens VARCHAR(10)
);

CREATE TABLE customers (
    id INTEGER DEFAULT customer_seq.nextval PRIMARY KEY,
    order_count INTEGER DEFAULT 0,
    name VARCHAR(30) CONSTRAINT customer_name_notnull NOT NULL
);

CREATE TABLE order_log (
    id INTEGER DEFAULT order_seq.nextval PRIMARY KEY,
    recv_time TIMESTAMP DEFAULT sysdate,
    item_id INTEGER,
    customer_id INTEGER,
    status VARCHAR(10) DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'CLOSED')),
    FOREIGN KEY (item_id) REFERENCES menu(id),
    FOREIGN KEY (customer_id) REFERENCES customers(id)
);

CREATE TABLE feedback (
    id INTEGER DEFAULT feedback_seq.nextval PRIMARY KEY,
    order_id INTEGER,
    rating INTEGER,
    note VARCHAR(200),
    FOREIGN KEY (order_id) REFERENCES order_log(id)
);

-- DATA 
INSERT INTO menu(name, cost, allergens) VALUES ('Hamburger', 200, '12689');
INSERT INTO menu(name, cost, allergens) VALUES ('Salad', 100, '4');
INSERT INTO menu(name, cost, allergens) VALUES ('Pizza', 300, '167');

INSERT INTO customers(name) VALUES ('Mark');
INSERT INTO customers(name) VALUES ('Bob');
INSERT INTO customers(name) VALUES ('Wade');

INSERT INTO order_log (item_id, customer_id) VALUES (1, 1);
INSERT INTO order_log (item_id, customer_id) VALUES (3, 1);
INSERT INTO order_log (item_id, customer_id) VALUES (3, 1);
INSERT INTO order_log (item_id, customer_id) VALUES (3, 2);
INSERT INTO order_log (item_id, customer_id) VALUES (2, 3);
INSERT INTO order_log (item_id, customer_id, status) VALUES (2, 3, 'CLOSED');

INSERT INTO feedback (order_id, rating, note) VALUES (1, 7, 'Pretty good');
INSERT INTO feedback (order_id, rating, note) VALUES (2, 3, 'Ugh, i ate it, but its bad');
INSERT INTO feedback (order_id, rating, note) VALUES (3, 10, 'Nice and moldy');
INSERT INTO feedback (order_id, rating, note) VALUES (4, 5, 'Could have made a better one in one of my 5 ovens.');
INSERT INTO feedback (order_id, rating, note) VALUES (5, 7, 'Very good');
INSERT INTO feedback (order_id, rating, note) VALUES (6, 4, 'Nice');

-- TRIGGERS
CREATE OR REPLACE TRIGGER enforce_rating_bounds_trigger
BEFORE INSERT ON feedback
FOR EACH ROW
BEGIN
    IF :new.rating < 0 THEN
        :new.rating := 0;
    ELSIF :new.rating > 10 THEN
        :new.rating := 10;
    END IF;
END;

CREATE OR REPLACE TRIGGER order_count_increment_trigger
BEFORE INSERT ON order_log
FOR EACH ROW
BEGIN
    UPDATE customers
    SET order_count = order_count + 1
    where id = :new.customer_id;
END;

CREATE OR REPLACE TRIGGER update_order_status_trigger
AFTER INSERT ON feedback
FOR EACH ROW
BEGIN
    UPDATE order_log
    SET status = 'CLOSED'
    WHERE id = :new.order_id;
END;

-- CURSOR
-- calculate the cost of current visit
CREATE OR REPLACE FUNCTION calculate_total_cost(customer_id_param INTEGER)
RETURN INTEGER
AS
    total_cost INTEGER := 0;
    item_cost INTEGER;
    CURSOR order_cur IS
        SELECT menu.cost
        FROM order_log
        INNER JOIN menu ON order_log.item_id = menu.id
        WHERE order_log.customer_id = customer_id_param
        AND order_log.status = 'OPEN';
BEGIN
    OPEN order_cur;
    LOOP
        FETCH order_cur INTO item_cost;
        EXIT WHEN order_cur%NOTFOUND;
        total_cost := total_cost + item_cost;
    END LOOP;
    CLOSE order_cur;

    RETURN total_cost;
END;
/


-- NON-TRIVIAL SELECT

-- AVERAGE ITEM RATING, ORDERED
SELECT menu.name AS item, AVG(feedback.rating) AS average_rating
FROM menu
LEFT JOIN order_log ON menu.id = order_log.item_id
LEFT JOIN feedback ON order_log.id = feedback.order_id
GROUP BY menu.name
ORDER BY average_rating DESC;

-- ITEMS THAT HAVE NOT BEEN ORDERED THIS MONTH
SELECT name AS item
FROM menu
WHERE id NOT IN (
    SELECT item_id
    FROM order_log
    WHERE EXTRACT(MONTH FROM recv_time) = EXTRACT(MONTH FROM SYSDATE)
);
-- ITEMS THAT HAVE NOT BEEN ORDERED FOR 3 MINUTES
SELECT name AS item
FROM menu
WHERE id NOT IN (
    SELECT item_id
    FROM order_log
    WHERE recv_time >= SYSDATE - INTERVAL '3' MINUTE
);

-- GROUP BY, AGGREGATE IN HAVING

-- CUSTOMERS WHO ORDERED MORE THEN 500 WORTH OF FOOD
SELECT customers.name AS name, SUM(menu.cost) AS total_spent
FROM order_log
LEFT JOIN customers ON customers.id = order_log.customer_id
LEFT JOIN menu ON order_log.item_id = menu.id
GROUP BY customers.name
HAVING SUM(menu.cost) > 500;
