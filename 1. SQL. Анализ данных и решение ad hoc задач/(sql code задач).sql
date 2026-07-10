/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Artem Sokolskii
 * Дата: 11.03.26
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
-- Напишите ваш запрос здесь
SELECT 
	COUNT(payer) AS all_players,
	SUM(payer) AS pay_players,
	ROUND(AVG(payer), 2) AS share_players_want_pay
FROM fantasy.users
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- Напишите ваш запрос здесь
SELECT 
	race_id,
	COUNT(DISTINCT id) AS all_players,
	SUM(payer),
	ROUND((SUM(payer)::numeric / COUNT(DISTINCT id)), 2) AS pay_share
FROM fantasy.users
GROUP BY race_id
ORDER BY pay_share DESC
-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- Напишите ваш запрос здесь
SELECT
	COUNT(transaction_id) AS all_transactions,
	SUM(amount) AS all_amonts,
	ROUND((AVG(amount))::numeric, 2) AS avg_amount,
	MIN(amount) AS min_amount,
	MAX(amount) AS max_amount,
	ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount))::numeric, 2) AS perc_50,
	ROUND(STDDEV(amount)::numeric, 2) AS stddev_amount,
	COUNT(*) FILTER (WHERE amount = 0) AS zero_counts,
	COUNT(*) AS total_amounts,
	COUNT(*) FILTER (WHERE amount = 0)::REAL / COUNT(*) AS zero_share
FROM fantasy.events
UNION
SELECT 
	COUNT(transaction_id) AS all_transactions,
	SUM(amount) AS all_amonts,
	ROUND((AVG(amount))::numeric, 2) AS avg_amount,
	MIN(amount) AS min_amount,
	MAX(amount) AS max_amount,
	ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount))::numeric, 2) AS perc_50,
	ROUND(STDDEV(amount)::numeric, 2) AS stddev_amount,
	COUNT(*) FILTER (WHERE amount = 0) AS zero_counts,
COUNT(*) AS total_amounts,
COUNT(*) FILTER (WHERE amount = 0)::REAL / COUNT(*) AS zero_share
FROM fantasy.events
WHERE amount > 0
-- 2.2: Аномальные нулевые покупки:
-- Напишите ваш запрос здесь
SELECT
	item_code,
	COUNT(*) AS all_transactions,
	COUNT(DISTINCT seller_id) AS all_payers
FROM fantasy.events
WHERE amount > 0
GROUP BY item_code
ORDER BY COUNT(*) DESC
-- 2.3: Популярные эпические предметы:
-- Напишите ваш запрос здесь
WITH wo_zero AS (
SELECT
	item_code,
	COUNT(*) AS all_transactions,
	COUNT(DISTINCT id) AS all_payers
FROM fantasy.events
WHERE amount > 0
GROUP BY item_code
ORDER BY COUNT(*) DESC
),
epic_items AS (
SELECT
	i.item_code,
	i.game_items AS item_name,
	COUNT(e.transaction_id) AS all_transactions,
	ROUND(COUNT(e.transaction_id)::numeric / NULLIF((SELECT SUM(all_transactions) FROM wo_zero), 0) * 100, 2) AS transactions_percent,
	COUNT(DISTINCT e.id) AS unique_payers,
	ROUND(COUNT(DISTINCT e.id)::numeric / NULLIF((SELECT COUNT(DISTINCT id) FROM fantasy.events WHERE amount > 0), 0) * 100, 2) AS payers_percent
FROM fantasy.items AS i
LEFT JOIN fantasy.events AS e ON i.item_code = e.item_code AND e.amount > 0
GROUP BY i.item_code, i.game_items
)
SELECT * 
FROM epic_items
WHERE all_transactions > 0
ORDER BY payers_percent DESC
-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:
-- Напишите ваш запрос здесь
WITH
all_players AS (
    SELECT r.race, COUNT(DISTINCT u.id) AS total_players
    FROM fantasy.race AS r
    LEFT JOIN fantasy.users AS u ON r.race_id = u.race_id
    GROUP BY r.race
),
payers AS (
    SELECT r.race, COUNT(DISTINCT u.id) AS buyers
    FROM fantasy.race AS r
    LEFT JOIN fantasy.users AS u ON r.race_id = u.race_id
    LEFT JOIN fantasy.events AS e ON u.id = e.id
    WHERE e.amount > 0
    GROUP BY r.race
),
buyers AS (
    SELECT r.race, COUNT(DISTINCT u.id) AS payers
    FROM fantasy.race AS r
    LEFT JOIN fantasy.users AS u ON r.race_id = u.race_id
    LEFT JOIN fantasy.events AS e ON u.id = e.id
    WHERE u.payer = 1 AND e.amount > 0
    GROUP BY r.race
),
purchase_stats AS (
    SELECT r.race, u.id,
        COUNT(e.transaction_id) AS purchases_per_player,
        AVG(e.amount) AS avg_amount_per_player,
        SUM(e.amount) AS total_amount_per_player
    FROM fantasy.race AS r
    LEFT JOIN fantasy.users AS u ON r.race_id = u.race_id
    LEFT JOIN fantasy.events AS e ON u.id = e.id
    WHERE e.amount > 0
    GROUP BY r.race, u.id
)
SELECT
    ap.race,
    ap.total_players,
    p.buyers,
    ROUND(((buyers::float / total_players)::float)::NUMERIC, 2) AS buyer_share,
    ROUND(((payers::float / p.buyers)::float)::NUMERIC, 2) AS payer_share_among_buyers,
    ROUND((AVG(ps.purchases_per_player))::NUMERIC, 2) AS avg_purchases_per_buyer,
    ROUND((AVG(ps.avg_amount_per_player))::NUMERIC, 2) AS avg_amount_per_purchase,
    ROUND((AVG(ps.total_amount_per_player))::NUMERIC, 2) AS avg_total_per_buyer
FROM all_players AS ap
LEFT JOIN payers AS p ON ap.race = p.race
LEFT JOIN buyers AS b ON p.race = b.race
LEFT JOIN purchase_stats AS ps ON b.race = ps.race
GROUP BY ap.race, ap.total_players, b.payers, p.buyers
ORDER BY ap.race;