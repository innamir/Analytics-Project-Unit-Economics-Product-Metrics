-- BigQuery Standard SQL
-- Декомпозиція LTV по каналах.
-- LTV рахуємо на registered user, бо CAC у наступній частині рахується як spend / registrations.

WITH registrations AS (
  SELECT
    user_id,
    channel,
    MIN(timestamp) AS registration_ts
  FROM `cool-furnace-495912-n0.workshop_sql.product_events`
  WHERE event_type = 'registration'
  GROUP BY
    user_id,
    channel
),

orders_in_6m AS (
  SELECT
    r.user_id,
    r.channel,
    o.event,
    o.amount,
    o.timestamp AS order_ts
  FROM registrations r
  -- LEFT JOIN залишає всіх registered users у denominator,
  -- включно з користувачами без оплат.
  LEFT JOIN `cool-furnace-495912-n0.workshop_sql.orders` o
    ON r.user_id = o.user_id
    -- Revenue window: 6 календарних місяців від registration.
    -- TIMESTAMP_ADD не підтримує MONTH, тому використовуємо DATETIME_ADD.
    AND o.timestamp >= r.registration_ts
    AND o.timestamp < TIMESTAMP(DATETIME_ADD(DATETIME(r.registration_ts), INTERVAL 6 MONTH))
),

user_monetization AS (
  SELECT
    user_id,
    channel,

    -- Purchase показує, що registered user став покупцем / subscriber.
    COUNTIF(event = 'purchase') AS purchase_count,
    SUM(CASE WHEN event = 'purchase' THEN amount ELSE 0 END) AS purchase_revenue,

    -- Рахуємо rebill events, бо у формулі потрібні rebills per payer.
    COUNTIF(event = 'rebill') AS rebill_count,
    SUM(CASE WHEN event = 'rebill' THEN amount ELSE 0 END) AS rebill_revenue,

    -- Upsell users потрібні для CR Sub -> Upsell.
    COUNTIF(event = 'upsell') AS upsell_count,
    SUM(CASE WHEN event = 'upsell' THEN amount ELSE 0 END) AS upsell_revenue
  FROM orders_in_6m
  GROUP BY
    user_id,
    channel
),

channel_components AS (
  SELECT
    channel,

    -- База для LTV, узгоджена з CAC = spend / registrations.
    COUNT(DISTINCT user_id) AS registered_users,

    -- COUNT DISTINCT, бо один user_id може мати кілька payment events.
    COUNT(DISTINCT IF(purchase_count > 0, user_id, NULL)) AS buyers,

    -- Purchase metrics для first AOV.
    SUM(purchase_count) AS purchase_events,
    SUM(purchase_revenue) AS purchase_revenue,

    -- Diagnostic metric: скільки buyers мали хоча б один rebill.
    COUNT(DISTINCT IF(rebill_count > 0, user_id, NULL)) AS rebill_users,
    SUM(rebill_count) AS rebill_events,
    SUM(rebill_revenue) AS rebill_revenue,

    -- Upsell metrics для CR Sub -> Upsell та upsell AOV.
    COUNT(DISTINCT IF(upsell_count > 0, user_id, NULL)) AS upsell_users,
    SUM(upsell_count) AS upsell_events,
    SUM(upsell_revenue) AS upsell_revenue
  FROM user_monetization
  GROUP BY channel
)

SELECT
  channel,

  registered_users,
  buyers,

  -- Registration -> Purchase conversion.
  ROUND(SAFE_DIVIDE(buyers, registered_users), 4) AS cr_registration_to_purchase,

  -- Середній чек першої оплати.
  ROUND(SAFE_DIVIDE(purchase_revenue, purchase_events), 2) AS aov_first_purchase,

  -- LTV на payer до застосування Registration -> Purchase conversion.
  ROUND(
    SAFE_DIVIDE(purchase_revenue, purchase_events)
    + SAFE_DIVIDE(rebill_revenue, rebill_events) * SAFE_DIVIDE(rebill_events, buyers)
    + SAFE_DIVIDE(upsell_revenue, upsell_events) * SAFE_DIVIDE(upsell_users, buyers),
    2
  ) AS ltv_6m_per_payer,

  -- Компонент першої покупки в LTV на registered user.
  ROUND(
    SAFE_DIVIDE(buyers, registered_users)
    * SAFE_DIVIDE(purchase_revenue, purchase_events),
    2
  ) AS ltv_component_first_purchase,

  rebill_users,

  -- Середня кількість rebill events на payer за 6 місяців.
  ROUND(SAFE_DIVIDE(rebill_events, buyers), 4) AS freq_rebills_per_payer_6m,

  -- Середній чек rebill.
  ROUND(SAFE_DIVIDE(rebill_revenue, rebill_events), 2) AS aov_rebill,

  -- Компонент rebill в LTV на registered user.
  ROUND(
    SAFE_DIVIDE(buyers, registered_users)
    * SAFE_DIVIDE(rebill_revenue, rebill_events)
    * SAFE_DIVIDE(rebill_events, buyers),
    2
  ) AS ltv_component_rebill,

  upsell_users,

  -- Частка buyers, які купили хоча б один upsell.
  ROUND(SAFE_DIVIDE(upsell_users, buyers), 4) AS cr_sub_to_upsell,

  -- Середній чек upsell.
  ROUND(SAFE_DIVIDE(upsell_revenue, upsell_events), 2) AS aov_upsell,

  -- Компонент upsell в LTV на registered user.
  ROUND(
    SAFE_DIVIDE(buyers, registered_users)
    * SAFE_DIVIDE(upsell_revenue, upsell_events)
    * SAFE_DIVIDE(upsell_users, buyers),
    2
  ) AS ltv_component_upsell,

  -- Фінальний 6-month LTV на registered user.
  ROUND(
    SAFE_DIVIDE(buyers, registered_users)
    *
    (
      SAFE_DIVIDE(purchase_revenue, purchase_events)
      + SAFE_DIVIDE(rebill_revenue, rebill_events) * SAFE_DIVIDE(rebill_events, buyers)
      + SAFE_DIVIDE(upsell_revenue, upsell_events) * SAFE_DIVIDE(upsell_users, buyers)
    ),
    2
  ) AS ltv_6m_per_registered_user

  

FROM channel_components
ORDER BY ltv_6m_per_registered_user DESC;
