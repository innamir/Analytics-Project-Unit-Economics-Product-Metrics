-- ============================================================
-- 01_data_description.sql
-- Мета:
-- Первинно описати таблиці product_events та orders,
-- які використовуються для аналізу продуктових подій.
--
-- Фокус:
-- 1. Зрозуміти структуру таблиць
-- 2. Визначити потенційний grain
-- 3. Оцінити обсяг даних
-- 4. Перевірити часовий період
-- 5. Дослідити події, канали та базову monetization-структуру
--
-- Dataset:
-- `cool-furnace-495912-n0.workshop_sql`
-- ============================================================


-- ============================================================
-- 1. Schema overview
-- Дивимось назви колонок, типи даних і nullable-статус.
-- Таблицю audience не включаємо, бо вона не використовується
-- в основному аналізі unit economics.
-- ============================================================

SELECT
  table_name,
  column_name,
  data_type,
  is_nullable
FROM `cool-furnace-495912-n0.workshop_sql.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name IN ('product_events', 'orders')
ORDER BY
  table_name,
  ordinal_position;


-- ============================================================
-- 2. Preview: product_events
-- Переглядаємо приклад продуктових подій.
-- ============================================================

SELECT *
FROM `cool-furnace-495912-n0.workshop_sql.product_events`
LIMIT 10;


-- ============================================================
-- 3. Preview: orders
-- Переглядаємо приклад revenue events.
-- ============================================================

SELECT *
FROM `cool-furnace-495912-n0.workshop_sql.orders`
LIMIT 10;


-- ============================================================
-- 4. Table volume overview
-- Порівнюємо загальну кількість рядків і унікальних користувачів.
-- ============================================================

SELECT
  'product_events' AS table_name,
  COUNT(*) AS rows_total,
  COUNT(DISTINCT user_id) AS unique_users
FROM `cool-furnace-495912-n0.workshop_sql.product_events`

UNION ALL

SELECT
  'orders' AS table_name,
  COUNT(*) AS rows_total,
  COUNT(DISTINCT user_id) AS unique_users
FROM `cool-furnace-495912-n0.workshop_sql.orders`;


-- ============================================================
-- 5. Date coverage by table
-- Дивимось, який часовий період покривають product_events та orders.
-- ============================================================

SELECT
  'product_events' AS table_name,
  MIN(timestamp) AS earliest_timestamp,
  MAX(timestamp) AS latest_timestamp,
  DATE_DIFF(MAX(DATE(timestamp)), MIN(DATE(timestamp)), DAY) + 1 AS days_covered
FROM `cool-furnace-495912-n0.workshop_sql.product_events`

UNION ALL

SELECT
  'orders' AS table_name,
  MIN(timestamp) AS earliest_timestamp,
  MAX(timestamp) AS latest_timestamp,
  DATE_DIFF(MAX(DATE(timestamp)), MIN(DATE(timestamp)), DAY) + 1 AS days_covered
FROM `cool-furnace-495912-n0.workshop_sql.orders`;


-- ============================================================
-- 6. Product event types
-- Дивимось, які продуктові події є в product_events.
-- ============================================================

SELECT
  event_type,
  COUNT(*) AS events_count,
  COUNT(DISTINCT user_id) AS unique_users
FROM `cool-furnace-495912-n0.workshop_sql.product_events`
GROUP BY event_type
ORDER BY events_count DESC;


-- ============================================================
-- 7. Revenue event types
-- Дивимось типи подій у orders та їх внесок у revenue.
-- ============================================================

SELECT
  event,
  COUNT(*) AS events_count,
  COUNT(DISTINCT user_id) AS unique_users,
  ROUND(SUM(amount), 2) AS total_revenue,
  ROUND(AVG(amount), 2) AS avg_amount
FROM `cool-furnace-495912-n0.workshop_sql.orders`
GROUP BY event
ORDER BY total_revenue DESC;


-- ============================================================
-- 8. Channel overview
-- Дивимось, які канали є в product_events і який обсяг подій
-- та користувачів припадає на кожен канал.
-- ============================================================

SELECT
  channel,
  COUNT(*) AS events_count,
  COUNT(DISTINCT user_id) AS unique_users
FROM `cool-furnace-495912-n0.workshop_sql.product_events`
GROUP BY channel
ORDER BY events_count DESC;


-- ============================================================
-- 9. Channel and event_type breakdown
-- Перевіряємо, які події представлені в кожному каналі.
-- ============================================================

SELECT
  channel,
  event_type,
  COUNT(*) AS events_count,
  COUNT(DISTINCT user_id) AS unique_users
FROM `cool-furnace-495912-n0.workshop_sql.product_events`
GROUP BY
  channel,
  event_type
ORDER BY
  channel,
  events_count DESC;


-- ============================================================
-- 10. Daily product activity
-- Дивимось щоденну активність у product_events:
-- кількість подій та активних користувачів.
-- Тут ми лише описуємо динаміку, а аномалії перевіримо
-- в окремому data quality файлі.
-- ============================================================

SELECT
  DATE(timestamp) AS event_date,
  COUNT(*) AS events_count,
  COUNT(DISTINCT user_id) AS active_users
FROM `cool-furnace-495912-n0.workshop_sql.product_events`
GROUP BY event_date
ORDER BY event_date;


-- ============================================================
-- 11. Daily revenue overview
-- Дивимось щоденну monetization-динаміку:
-- кількість revenue events, платників, revenue та AOV.
-- ============================================================

SELECT
  DATE(timestamp) AS order_date,
  COUNT(*) AS revenue_events,
  COUNT(DISTINCT user_id) AS paying_users,
  ROUND(SUM(amount), 2) AS total_revenue,
  ROUND(AVG(amount), 2) AS avg_order_value
FROM `cool-furnace-495912-n0.workshop_sql.orders`
GROUP BY order_date
ORDER BY order_date;


-- ============================================================
-- 12. Amount distribution
-- Дивимось базовий розподіл amount.
-- Це допомагає зрозуміти типові payment values перед пошуком outliers.
-- ============================================================

SELECT
  COUNT(*) AS rows_total,
  COUNT(amount) AS rows_with_amount,
  ROUND(MIN(amount), 2) AS min_amount,
  ROUND(MAX(amount), 2) AS max_amount,
  ROUND(AVG(amount), 2) AS avg_amount,
  ROUND(APPROX_QUANTILES(amount, 100)[OFFSET(25)], 2) AS p25_amount,
  ROUND(APPROX_QUANTILES(amount, 100)[OFFSET(50)], 2) AS median_amount,
  ROUND(APPROX_QUANTILES(amount, 100)[OFFSET(75)], 2) AS p75_amount
FROM `cool-furnace-495912-n0.workshop_sql.orders`
WHERE amount IS NOT NULL;


-- ============================================================
-- 13. Average order value by revenue event
-- Порівнюємо amount між типами revenue events.
-- Це допомагає зрозуміти, які типи оплат формують revenue.
-- ============================================================

SELECT
  event,
  COUNT(*) AS revenue_events,
  COUNT(DISTINCT user_id) AS paying_users,
  ROUND(SUM(amount), 2) AS total_revenue,
  ROUND(AVG(amount), 2) AS avg_order_value,
  ROUND(MIN(amount), 2) AS min_amount,
  ROUND(MAX(amount), 2) AS max_amount
FROM `cool-furnace-495912-n0.workshop_sql.orders`
WHERE amount IS NOT NULL
GROUP BY event
ORDER BY total_revenue DESC;

-- Data Understanding: raw overview по marketing_ads_raw

SELECT
  'marketing_ads_raw' AS table_name,
  COUNT(*) AS rows_total,
  COUNT(DISTINCT source) AS unique_sources,
  COUNT(DISTINCT campaign_id) AS unique_campaigns,
  COUNT(DISTINCT adset_id) AS unique_adsets,
  COUNT(DISTINCT ad_id) AS unique_ads,
  MIN(`date`) AS earliest_date,
  MAX(`date`) AS latest_date,
  DATEDIFF(MAX(`date`), MIN(`date`)) + 1 AS days_covered,
  MIN(CAST(`timestamp` AS DATETIME)) AS earliest_timestamp,
  MAX(CAST(`timestamp` AS DATETIME)) AS latest_timestamp
FROM marketing_ads_raw;

