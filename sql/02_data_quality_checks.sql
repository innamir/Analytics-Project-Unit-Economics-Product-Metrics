-- ============================================================
-- 02_data_quality_checks.sql
-- Мета:
-- Перевірити якість даних у product_events та orders

-- Основні ризики:
-- - null у ключових полях
-- - дублікати
-- - невалідні revenue values
-- - різне date coverage
-- - неконсистентна funnel-логіка
-- ============================================================


-- ============================================================
-- 1. Null checks
-- Перевіряємо пропуски у ключових полях.
-- ============================================================

SELECT
  'product_events' AS table_name,
  COUNT(*) AS rows_total,
  COUNTIF(user_id IS NULL) AS null_user_id,
  COUNTIF(event_type IS NULL) AS null_event_name,
  COUNTIF(timestamp IS NULL) AS null_timestamp,
  COUNTIF(channel IS NULL) AS null_channel,
  NULL AS null_amount
FROM `cool-furnace-495912-n0.workshop_sql.product_events`

UNION ALL

SELECT
  'orders' AS table_name,
  COUNT(*) AS rows_total,
  COUNTIF(user_id IS NULL) AS null_user_id,
  COUNTIF(event IS NULL) AS null_event_name,
  COUNTIF(timestamp IS NULL) AS null_timestamp,
  NULL AS null_channel,
  COUNTIF(amount IS NULL) AS null_amount
FROM `cool-furnace-495912-n0.workshop_sql.orders`;


-- ============================================================
-- 2. Duplicate summary
-- Перевіряємо дублікати за natural keys.
--
-- product_events: user_id + event_type + timestamp + channel
-- orders: user_id + event + timestamp + amount
-- ============================================================

WITH product_event_keys AS (
  SELECT
    user_id,
    event_type,
    timestamp,
    channel,
    COUNT(*) AS rows_per_key
  FROM `cool-furnace-495912-n0.workshop_sql.product_events`
  GROUP BY
    user_id,
    event_type,
    timestamp,
    channel
),

order_keys AS (
  SELECT
    user_id,
    event,
    timestamp,
    amount,
    COUNT(*) AS rows_per_key
  FROM `cool-furnace-495912-n0.workshop_sql.orders`
  GROUP BY
    user_id,
    event,
    timestamp,
    amount
)

SELECT
  'product_events' AS table_name,
  COUNT(*) AS unique_keys,
  SUM(rows_per_key) AS rows_total,
  COUNTIF(rows_per_key > 1) AS duplicated_keys,
  SUM(IF(rows_per_key > 1, rows_per_key - 1, 0)) AS duplicate_rows
FROM product_event_keys

UNION ALL

SELECT
  'orders' AS table_name,
  COUNT(*) AS unique_keys,
  SUM(rows_per_key) AS rows_total,
  COUNTIF(rows_per_key > 1) AS duplicated_keys,
  SUM(IF(rows_per_key > 1, rows_per_key - 1, 0)) AS duplicate_rows
FROM order_keys;


-- ============================================================
-- 3. Amount validity
-- Перевіряємо, чи amount підходить для revenue-аналізу.
-- ============================================================

SELECT
  COUNT(*) AS rows_total,
  COUNTIF(amount IS NULL) AS null_amount,
  COUNTIF(amount = 0) AS zero_amount,
  COUNTIF(amount < 0) AS negative_amount,
  COUNTIF(amount > 999) AS very_high_amount,
  ROUND(MIN(amount), 2) AS min_amount,
  ROUND(MAX(amount), 2) AS max_amount,
  ROUND(AVG(amount), 2) AS avg_amount
FROM `cool-furnace-495912-n0.workshop_sql.orders`;


-- ============================================================
-- 4. Amount consistency by event
-- Перевіряємо, чи price points стабільні в межах revenue event types.
-- ============================================================

SELECT
  event,
  COUNT(*) AS rows_total,
  COUNT(DISTINCT amount) AS distinct_amount_values,
  ROUND(MIN(amount), 2) AS min_amount,
  ROUND(MAX(amount), 2) AS max_amount,
  ROUND(AVG(amount), 2) AS avg_amount
FROM `cool-furnace-495912-n0.workshop_sql.orders`
GROUP BY event
ORDER BY event;


-- ============================================================
-- 5. Date coverage consistency
-- Перевіряємо, чи orders виходять за період product_events.
-- ============================================================

WITH product_period AS (
  SELECT
    MIN(timestamp) AS min_product_ts,
    MAX(timestamp) AS max_product_ts
  FROM `cool-furnace-495912-n0.workshop_sql.product_events`
)

SELECT
  COUNT(*) AS orders_total,
  COUNTIF(o.timestamp < p.min_product_ts) AS orders_before_product_period,
  COUNTIF(o.timestamp > p.max_product_ts) AS orders_after_product_period,
  ROUND(SUM(IF(o.timestamp > p.max_product_ts, o.amount, 0)), 2) AS revenue_after_product_period
FROM `cool-furnace-495912-n0.workshop_sql.orders` AS o
CROSS JOIN product_period AS p;


-- ============================================================
-- 6. Funnel consistency
-- Перевіряємо базову логіку воронки:
-- registration без install та глибші події без registration.
-- ============================================================

WITH user_events AS (
  SELECT
    user_id,
    MAX(IF(event_type = 'install', 1, 0)) AS has_install,
    MAX(IF(event_type = 'registration', 1, 0)) AS has_registration,
    MAX(IF(event_type IN ('like', 'match', 'message_sent', 'paywall_view'), 1, 0)) AS has_deeper_event
  FROM `cool-furnace-495912-n0.workshop_sql.product_events`
  GROUP BY user_id
)

SELECT
  COUNTIF(has_registration = 1) AS users_with_registration,
  COUNTIF(has_registration = 1 AND has_install = 0) AS users_registration_without_install,
  COUNTIF(has_deeper_event = 1) AS users_with_deeper_events,
  COUNTIF(has_deeper_event = 1 AND has_registration = 0) AS users_deeper_events_without_registration
FROM user_events;


-- ============================================================
-- 7. Paying users consistency
-- Перевіряємо, чи всі paying users мають product_events.
-- ============================================================

WITH product_users AS (
  SELECT DISTINCT user_id
  FROM `cool-furnace-495912-n0.workshop_sql.product_events`
),

paying_users AS (
  SELECT DISTINCT user_id
  FROM `cool-furnace-495912-n0.workshop_sql.orders`
)

SELECT
  COUNT(*) AS paying_users_total,
  COUNTIF(pu.user_id IS NULL) AS paying_users_without_product_events
FROM paying_users AS pay
LEFT JOIN product_users AS pu
  ON pay.user_id = pu.user_id;


-- ============================================================
-- Data Quality Checks для таблиці 'marketing_ads_raw'
-- ============================================================

-- 1. Null checks

SELECT
  'marketing_ads_raw' AS table_name,
  COUNT(*) AS rows_total,

  SUM(source IS NULL) AS null_source,
  SUM(campaign_id IS NULL) AS null_campaign_id,
  SUM(adset_id IS NULL) AS null_adset_id,
  SUM(ad_id IS NULL) AS null_ad_id,
  SUM(`date` IS NULL) AS null_date,
  SUM(spend IS NULL) AS null_spend,
  SUM(impressions IS NULL) AS null_impressions,
  SUM(clicks IS NULL) AS null_clicks,
  SUM(installs IS NULL) AS null_installs,
  SUM(registrations IS NULL) AS null_registrations,
  SUM(`timestamp` IS NULL) AS null_timestamp
FROM marketing_ads_raw;

-- 2. Duplicate checks за raw natural key
-- Якщо один і той самий snapshot повторюється повністю, це справжній дублікат.

SELECT
  COUNT(*) AS rows_total,
  COUNT(DISTINCT CONCAT_WS(
    '|',
    source,
    campaign_id,
    adset_id,
    ad_id,
    `date`,
    spend,
    impressions,
    clicks,
    installs,
    registrations,
    `timestamp`
  )) AS unique_raw_keys,

  COUNT(*) - COUNT(DISTINCT CONCAT_WS(
    '|',
    source,
    campaign_id,
    adset_id,
    ad_id,
    `date`,
    spend,
    impressions,
    clicks,
    installs,
    registrations,
    `timestamp`
  )) AS duplicate_rows
FROM marketing_ads_raw;

-- 3. Timestamp validity
-- Перевіряємо, чи varchar timestamp коректно конвертується в DATETIME.

SELECT
  COUNT(*) AS rows_total,
  SUM(CAST(`timestamp` AS DATETIME) IS NULL) AS invalid_timestamp_rows,
  MIN(CAST(`timestamp` AS DATETIME)) AS earliest_timestamp,
  MAX(CAST(`timestamp` AS DATETIME)) AS latest_timestamp
FROM marketing_ads_raw;

-- 4. Metric validity
-- Для рекламних метрик не очікуємо negative values.

SELECT
  COUNT(*) AS rows_total,

  SUM(spend < 0) AS negative_spend,
  SUM(impressions < 0) AS negative_impressions,
  SUM(clicks < 0) AS negative_clicks,
  SUM(installs < 0) AS negative_installs,
  SUM(registrations < 0) AS negative_registrations,

  MIN(spend) AS min_spend,
  MAX(spend) AS max_spend,
  ROUND(AVG(spend), 2) AS avg_spend
FROM marketing_ads_raw;

-- 5. Funnel metric consistency
-- На рівні snapshot clicks не мають перевищувати impressions,
-- installs не мають перевищувати clicks,
-- registrations не мають перевищувати installs.

SELECT
  COUNT(*) AS rows_total,
  SUM(clicks > impressions) AS clicks_gt_impressions,
  SUM(installs > clicks) AS installs_gt_clicks,
  SUM(registrations > installs) AS registrations_gt_installs
FROM marketing_ads_raw;

-- 6. Snapshot structure
-- Перевіряємо, скільки snapshot-ів є на один ad_id + date.

SELECT
  snapshots_per_ad_day,
  COUNT(*) AS ad_day_groups
FROM (
  SELECT
    ad_id,
    `date`,
    COUNT(*) AS snapshots_per_ad_day
  FROM marketing_ads_raw
  GROUP BY ad_id, `date`
) s
GROUP BY snapshots_per_ad_day
ORDER BY snapshots_per_ad_day;


