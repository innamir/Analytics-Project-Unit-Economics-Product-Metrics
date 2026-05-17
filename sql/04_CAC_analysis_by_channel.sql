-- ============================================================
-- CAC Analysis by Channel
-- Dataset: marketing_ads_raw.csv
-- Environment: DBeaver / MySQL 8+
-- ============================================================
--
-- Business goal:
-- Calculate CAC and marketing funnel metrics by source.
--
-- CAC logic:
-- CAC is calculated per registered user:
-- CAC = total_spend / registrations
--
-- Data note:
-- During cross-dataset consistency checks, marketing metrics were found
-- to be stored at approximately x100 scale. Therefore absolute metrics
-- are normalized by dividing by 100 after deduplication.
--
-- LTV/CAC logic:
-- LTV values are taken from the previous sql/03_LTV_analysis_by_channel.sql
-- ============================================================

WITH ranked_snapshots AS (
  SELECT
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

    -- timestamp у MySQL-таблиці зберігається як varchar,
    -- тому приводимо його до DATETIME тільки всередині запиту.
    CAST(`timestamp` AS DATETIME) AS snapshot_ts,

    -- Дані кумулятивні протягом дня.
    -- Для кожного ad_id + date залишаємо найпізніший snapshot.
    ROW_NUMBER() OVER (
      PARTITION BY ad_id, `date`
      ORDER BY CAST(`timestamp` AS DATETIME) DESC
    ) AS rn
  FROM marketing_ads_raw
),

deduplicated_ads AS (
  SELECT
    source,
    campaign_id,
    adset_id,
    ad_id,
    `date`,

    -- Нормалізуємо absolute marketing metrics через /100
    -- згідно з cross-dataset consistency check.
    spend / 100 AS spend,
    impressions / 100 AS impressions,
    clicks / 100 AS clicks,
    installs / 100 AS installs,
    registrations / 100 AS registrations,

    snapshot_ts
  FROM ranked_snapshots

  -- rn = 1 означає останній snapshot за день для конкретного ad_id.
  WHERE rn = 1
),

daily_metrics AS (
  SELECT
    source,
    `date`,

    -- Після дедублікації можна сумувати cumulative values,
    -- бо залишився один фінальний snapshot на ad_id + date.
    SUM(spend) AS daily_spend,
    SUM(impressions) AS daily_impressions,
    SUM(clicks) AS daily_clicks,
    SUM(installs) AS daily_installs,
    SUM(registrations) AS daily_registrations
  FROM deduplicated_ads
  GROUP BY
    source,
    `date`
),

channel_metrics AS (
  SELECT
    source,

    -- Метрики по каналу за весь період.
    SUM(daily_spend) AS total_spend,
    SUM(daily_impressions) AS total_impressions,
    SUM(daily_clicks) AS total_clicks,
    SUM(daily_installs) AS total_installs,
    SUM(daily_registrations) AS total_registrations
  FROM daily_metrics
  GROUP BY source
),

channel_with_ltv AS (
  SELECT
    source,
    total_spend,
    total_impressions,
    total_clicks,
    total_installs,
    total_registrations,

    -- LTV беремо з результатів розрахунків в першій частині аналізу.
    CASE
      WHEN source = 'tiktok' THEN 7.05
      WHEN source = 'meta' THEN 2.55
      WHEN source = 'google' THEN 16.80
    END AS ltv
  FROM channel_metrics
)

SELECT
  source,

  ROUND(total_spend, 2) AS total_spend,

  -- CPM = вартість 1000 показів.
  ROUND(total_spend / NULLIF(total_impressions, 0) * 1000, 2) AS cpm,

  -- CTR = відсоток кліків від показів.
  ROUND(total_clicks / NULLIF(total_impressions, 0) * 100, 2) AS ctr_pct,

  -- CR Click -> Install = відсоток встановлень від кліків.
  ROUND(total_installs / NULLIF(total_clicks, 0) * 100, 2) AS cr_click_install_pct,

  -- CR Install -> Registration = відсоток реєстрацій від встановлень.
  ROUND(total_registrations / NULLIF(total_installs, 0) * 100, 2) AS cr_install_reg_pct,

  -- CAC = вартість одного зареєстрованого користувача.
  ROUND(total_spend / NULLIF(total_registrations, 0), 2) AS cac,

  ltv AS ltv_per_reg_user,

  -- LTV/CAC показує, скільки LTV отримуємо на кожен $1 CAC.
  ROUND(
    ltv / NULLIF(total_spend / NULLIF(total_registrations, 0), 0),
    2
  ) AS ltv_cac

FROM channel_with_ltv
ORDER BY ltv_cac DESC;
