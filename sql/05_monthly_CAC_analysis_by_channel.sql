-- ============================================================
-- Monthly CAC Analysis by Channel
-- Датасет: marketing_ads_raw.csv
-- Середовище: DBeaver / MySQL 8+
-- ============================================================
--
-- Бізнес-ціль:
-- Розбити CAC по місяцях і перевірити, чи змінювалась
-- ефективність каналів протягом кампанії.
--
-- Логіка:
-- 1. Залишаємо останній snapshot на кожен ad_id + date.
-- 2. Нормалізуємо absolute marketing metrics через /100.
-- 3. Агрегуємо дані по channel + month.
-- 4. Рахуємо CAC та marketing funnel metrics по місяцях.
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

monthly_metrics AS (
  SELECT
    source,

    -- Групуємо дані до рівня місяця.
    DATE_FORMAT(`date`, '%Y-%m') AS month,

    -- Метрики по каналу за місяць.
    SUM(spend) AS total_spend,
    SUM(impressions) AS total_impressions,
    SUM(clicks) AS total_clicks,
    SUM(installs) AS total_installs,
    SUM(registrations) AS total_registrations
  FROM deduplicated_ads
  GROUP BY
    source,
    DATE_FORMAT(`date`, '%Y-%m')
),

monthly_cac AS (
  SELECT
    source,
    month,

    total_spend,
    total_impressions,
    total_clicks,
    total_installs,
    total_registrations,

    -- CAC = вартість одного зареєстрованого користувача.
    total_spend / NULLIF(total_registrations, 0) AS cac,

    -- CPM = вартість 1000 показів.
    total_spend / NULLIF(total_impressions, 0) * 1000 AS cpm,

    -- CTR = відсоток кліків від показів.
    total_clicks / NULLIF(total_impressions, 0) * 100 AS ctr_pct,

    -- CR Click -> Install = відсоток встановлень від кліків.
    total_installs / NULLIF(total_clicks, 0) * 100 AS cr_click_install_pct,

    -- CR Install -> Registration = відсоток реєстрацій від встановлень.
    total_registrations / NULLIF(total_installs, 0) * 100 AS cr_install_reg_pct
  FROM monthly_metrics
)

SELECT
  source AS channel,
  month,

  ROUND(total_spend, 2) AS total_spend,
  ROUND(total_registrations, 0) AS registrations,

  ROUND(cac, 2) AS cac,

  -- CAC попереднього місяця для цього ж каналу.
  ROUND(
    LAG(cac) OVER (
      PARTITION BY source
      ORDER BY month
    ),
    2
  ) AS previous_month_cac,

  -- MoM зміна CAC: показує, чи канал стає дорожчим або дешевшим.
  ROUND(
    (
      cac
      - LAG(cac) OVER (
          PARTITION BY source
          ORDER BY month
        )
    )
    / NULLIF(
        LAG(cac) OVER (
          PARTITION BY source
          ORDER BY month
        ),
        0
      )
    * 100,
    2
  ) AS cac_mom_change_pct,

  ROUND(cpm, 2) AS cpm,
  ROUND(ctr_pct, 2) AS ctr_pct,
  ROUND(cr_click_install_pct, 2) AS cr_click_install_pct,
  ROUND(cr_install_reg_pct, 2) AS cr_install_reg_pct

FROM monthly_cac
ORDER BY
  channel,
  month;
