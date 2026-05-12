-- ============================================================
-- 03_unit_economics_metrics.sql
-- Мета:
-- Порахувати funnel та monetization metrics по каналах.
--
-- Attribution logic:
-- Канал користувача визначається за channel з install event.
--
-- LTV proxy formula:
-- firstAOV + rebillAOV * rebills_per_payer + upsellAOV * cr_sub_to_upsell
-- ============================================================

WITH user_product_events AS (
  SELECT
    user_id,
    MAX(IF(event_type = 'install', 1, 0)) AS has_install,
    MAX(IF(event_type = 'registration', 1, 0)) AS has_registration,
    MAX(IF(event_type = 'paywall_view', 1, 0)) AS has_paywall_view
  FROM `cool-furnace-495912-n0.workshop_sql.product_events`
  GROUP BY user_id
),

user_channel AS (
  SELECT
    user_id,
    channel
  FROM `cool-furnace-495912-n0.workshop_sql.product_events`
  WHERE event_type = 'install'
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY user_id
    ORDER BY timestamp
  ) = 1
),

user_orders AS (
  SELECT
    user_id,

    COUNTIF(event = 'purchase') AS purchase_events,
    COUNTIF(event = 'rebill') AS rebill_events,
    COUNTIF(event = 'upsell') AS upsell_events,

    SUM(IF(event = 'purchase', amount, 0)) AS purchase_revenue,
    SUM(IF(event = 'rebill', amount, 0)) AS rebill_revenue,
    SUM(IF(event = 'upsell', amount, 0)) AS upsell_revenue
  FROM `cool-furnace-495912-n0.workshop_sql.orders`
  GROUP BY user_id
),

user_level AS (
  SELECT
    uc.channel,
    upe.user_id,

    upe.has_install,
    upe.has_registration,
    upe.has_paywall_view,

    IFNULL(uo.purchase_events, 0) AS purchase_events,
    IFNULL(uo.rebill_events, 0) AS rebill_events,
    IFNULL(uo.upsell_events, 0) AS upsell_events,

    IFNULL(uo.purchase_revenue, 0) AS purchase_revenue,
    IFNULL(uo.rebill_revenue, 0) AS rebill_revenue,
    IFNULL(uo.upsell_revenue, 0) AS upsell_revenue
  FROM user_product_events AS upe
  LEFT JOIN user_channel AS uc
    ON upe.user_id = uc.user_id
  LEFT JOIN user_orders AS uo
    ON upe.user_id = uo.user_id
),

channel_metrics AS (
  SELECT
    channel,

    COUNTIF(has_install = 1) AS installs,
    COUNTIF(has_registration = 1) AS registrations,
    COUNTIF(has_paywall_view = 1) AS paywall_view_users,

    COUNTIF(purchase_events > 0) AS purchasers,
    COUNTIF(rebill_events > 0) AS rebill_users,
    COUNTIF(upsell_events > 0) AS upsell_users,

    SUM(purchase_events) AS purchase_events,
    SUM(rebill_events) AS rebill_events,
    SUM(upsell_events) AS upsell_events,

    SUM(purchase_revenue) AS purchase_revenue,
    SUM(rebill_revenue) AS rebill_revenue,
    SUM(upsell_revenue) AS upsell_revenue
  FROM user_level
  GROUP BY channel
)

SELECT
  channel,

  installs,
  registrations,
  paywall_view_users,
  purchasers,

  ROUND(SAFE_DIVIDE(paywall_view_users, installs) * 100, 2) AS conv_install_to_paywall_pct,
  ROUND(SAFE_DIVIDE(purchasers, paywall_view_users) * 100, 2) AS conv_paywall_to_purchase_pct,
  ROUND(SAFE_DIVIDE(purchasers, installs) * 100, 2) AS conv_install_to_purchase_pct,

  ROUND(SAFE_DIVIDE(rebill_events, purchasers), 2) AS rebills_per_payer_6m,
  ROUND(SAFE_DIVIDE(upsell_users, purchasers) * 100, 2) AS cr_sub_to_upsell_pct,

  ROUND(SAFE_DIVIDE(purchase_revenue, purchase_events), 2) AS first_aov,
  ROUND(SAFE_DIVIDE(rebill_revenue, rebill_events), 2) AS rebill_aov,
  ROUND(SAFE_DIVIDE(upsell_revenue, upsell_events), 2) AS upsell_aov,

  ROUND(
    SAFE_DIVIDE(purchase_revenue, purchase_events)
    + SAFE_DIVIDE(rebill_revenue, rebill_events) * SAFE_DIVIDE(rebill_events, purchasers)
    + SAFE_DIVIDE(upsell_revenue, upsell_events) * SAFE_DIVIDE(upsell_users, purchasers),
    2
  ) AS ltv_6m_proxy

FROM channel_metrics
ORDER BY
  CASE channel
    WHEN 'tiktok' THEN 1
    WHEN 'meta' THEN 2
    WHEN 'google' THEN 3
    ELSE 4
  END;
