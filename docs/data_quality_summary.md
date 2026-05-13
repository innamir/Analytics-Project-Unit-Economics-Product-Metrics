# Data Quality Summary

## Overview

Цей документ описує основні перевірки якості даних для таблиць `product_events` та `orders` перед розрахунком продуктових метрик, revenue та unit economics.

Мета data quality етапу — переконатися, що ключові поля заповнені, дані не містять дублікатів, revenue values є валідними, а продуктова воронка та зв’язок між продуктовими подіями й оплатами є консистентними.

## Checks Performed

У межах data quality були виконані такі перевірки:

- null values у ключових полях;
- дублікати за natural keys;
- валідність `amount` у revenue data;
- консистентність price points для різних revenue events;
- date coverage між `product_events` та `orders`;
- базова funnel consistency;
- наявність продуктових подій для paying users.

## Null Checks

| Table | Rows Total | Null User ID | Null Event Name | Null Timestamp | Null Channel | Null Amount |
|---|---:|---:|---:|---:|---:|---:|
| product_events | 61,595 | 0 | 0 | 0 | 0 | N/A |
| orders | 2,197 | 0 | 0 | 0 | N/A | 0 |

### Result

Ключові поля в обох таблицях заповнені повністю:

- у `product_events` немає null values у `user_id`, `event_type`, `timestamp` та `channel`;
- у `orders` немає null values у `user_id`, `event`, `timestamp` та `amount`.

## Duplicate Checks

Дублікати перевірялись за natural keys:

- `product_events`: `user_id` + `event_type` + `timestamp` + `channel`;
- `orders`: `user_id` + `event` + `timestamp` + `amount`.

| Table | Unique Keys | Rows Total | Duplicated Keys | Duplicate Rows |
|---|---:|---:|---:|---:|
| product_events | 61,595 | 61,595 | 0 | 0 |
| orders | 2,197 | 2,197 | 0 | 0 |

### Result

У таблицях `product_events` та `orders` не знайдено дублікатів за обраними natural keys.


## Amount Validity

| Rows Total | Null Amount | Zero Amount | Negative Amount | Very High Amount | Min Amount | Max Amount | Avg Amount |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 2,197 | 0 | 0 | 0 | 0 | 20.00 | 49.99 | 35.80 |

### Result

Поле `amount` у таблиці `orders` виглядає валідним для revenue-аналізу:

- немає null values;
- немає нульових значень;
- немає від’ємних значень;
- немає підозріло великих значень за обраним порогом `amount > 999`;
- значення знаходяться в очікуваному діапазоні від $20.00 до $49.99.

## Amount Consistency by Revenue Event

| Event | Rows Total | Distinct Amount Values | Min Amount | Max Amount | Avg Amount |
|---|---:|---:|---:|---:|---:|
| purchase | 1,007 | 1 | 24.99 | 24.99 | 24.99 |
| rebill | 990 | 1 | 49.99 | 49.99 | 49.99 |
| upsell | 200 | 1 | 20.00 | 20.00 | 20.00 |

### Result

Кожен тип revenue event має один стабільний price point:

- `purchase` = $24.99;
- `rebill` = $49.99;
- `upsell` = $20.00.

Це спрощує подальший revenue analysis, оскільки amount є консистентним у межах кожного типу події.

## Date Coverage Consistency

| Orders Total | Orders Before Product Period | Orders After Product Period | Revenue After Product Period |
|---:|---:|---:|---:|
| 2,197 | 0 | 1 | 49.99 |

### Result

У таблиці `orders` є один revenue event після завершення періоду `product_events`.

Це не є критичною проблемою, але важливо для інтерпретації unit economics:

- якщо рахувати revenue за весь доступний період, цей платіж буде включений;
- якщо рахувати метрики лише в межах спільного періоду `product_events` та `orders`, цей платіж потрібно буде виключити.

У подальшому аналізі потрібно явно зафіксувати revenue window.

## Funnel Consistency

| Users With Registration | Registration Without Install | Users With Deeper Events | Deeper Events Without Registration |
|---:|---:|---:|---:|
| 19,970 | 0 | 11,339 | 0 |

### Result

Базова логіка продуктової воронки виглядає консистентною:

- немає користувачів із `registration` без попереднього `install`;
- немає користувачів із глибшими подіями без `registration`.

Це означає, що funnel steps можна використовувати для подальшого аналізу conversion rates.

## Paying Users Consistency

| Paying Users Total | Paying Users Without Product Events |
|---:|---:|
| 1,007 | 0 |

### Result

Усі paying users із таблиці `orders` присутні в `product_events`.

Це важливо для подальшого аналізу, оскільки дозволяє пов’язувати продуктові події та revenue через `user_id`.

## Marketing Ads Data Quality

Окрім `product_events` та `orders`, для розрахунку CAC була перевірена окрема таблиця / CSV-файл:

- `marketing_ads_raw.csv` — сирі рекламні дані з TikTok, META та Google.

Ці дані використовуються для розрахунку marketing spend, рекламної воронки та CAC на рівні каналів.

## Additional Checks Performed for Marketing Ads

Для `marketing_ads_raw.csv` були виконані такі перевірки:

- null values у ключових полях;
- дублікати за raw natural key;
- валідність `timestamp` для вибору останнього snapshot;
- валідність marketing metrics (`spend`, `impressions`, `clicks`, `installs`, `registrations`);
- базова funnel consistency для рекламної воронки;
- snapshot structure для підтвердження cumulative nature даних.

## Marketing Ads Null Checks

| Table / File | Rows Total | Null Source | Null Campaign ID | Null Adset ID | Null Ad ID | Null Date | Null Spend | Null Impressions | Null Clicks | Null Installs | Null Registrations | Null Timestamp |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| marketing_ads_raw.csv | 8,814 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

### Result

Ключові поля в `marketing_ads_raw.csv` заповнені повністю:

- немає null values у полях для ідентифікації рекламної структури: `source`, `campaign_id`, `adset_id`, `ad_id`;
- немає null values у полях для дедублікації snapshot-ів: `date`, `timestamp`;
- немає null values у метриках для розрахунку CAC і рекламної воронки: `spend`, `impressions`, `clicks`, `installs`, `registrations`.


## Marketing Ads Duplicate Checks

Дублікати перевірялись за raw natural key:

`source + campaign_id + adset_id + ad_id + date + spend + impressions + clicks + installs + registrations + timestamp`

|rows_total|unique_raw_keys|duplicate_rows|
|----------|---------------|--------------|
|8814|8814|0|


### Result

Ця перевірка показує, чи є повністю повторені snapshot-и.  
Важливо: кілька рядків на один `ad_id + date` не є помилкою, якщо вони мають різний `timestamp`. Це очікувана cumulative snapshot structure.

## Timestamp Validity

|rows_total|invalid_timestamp_rows|earliest_timestamp|latest_timestamp|
|----------|----------------------|------------------|----------------|
|8814|0|2024-01-02 01:19:00|2024-07-14 14:51:34|


### Result

Поле `timestamp` зберігається як текстове значення, але для розрахунків його потрібно приводити до `DATETIME`.

Це потрібно не для очищення raw-даних, а для коректного сортування snapshot-ів:

`ROW_NUMBER() OVER (PARTITION BY ad_id, date ORDER BY CAST(timestamp AS DATETIME) DESC)`

## Marketing Metrics Validity

|rows_total|negative_spend|negative_impressions|negative_clicks|negative_installs|negative_registrations|min_spend|max_spend|avg_spend|
|----------|--------------|--------------------|---------------|-----------------|----------------------|---------|---------|---------|
|8814|0|0|0|0|0|3.63|12500.00|4055.71|


### Result

Для рекламних метрик не очікуються відʼємні значення.  
Якщо `spend`, `impressions`, `clicks`, `installs` або `registrations` мають negative values, такі рядки потрібно окремо перевірити перед CAC-розрахунком.

## Ads Funnel Consistency

|rows_total|clicks_gt_impressions|installs_gt_clicks|registrations_gt_installs|
|----------|---------------------|------------------|-------------------------|
|8814|0|0|0|


### Result

Базова рекламна воронка має вигляд:

`impressions → clicks → installs → registrations`

Тому на рівні snapshot очікується:

- `clicks <= impressions`;
- `installs <= clicks`;
- `registrations <= installs`.

Порушення цієї логіки можуть означати проблему в сирих рекламних даних або різні правила attribution між платформами.

## Snapshot Structure

|snapshots_per_ad_day|ad_day_groups|
|--------------------|-------------|
|3|474|
|4|497|
|5|470|
|6|509|


### Result

`marketing_ads_raw.csv` має cumulative snapshot structure.

Це означає, що для одного `ad_id + date` може бути кілька snapshot-ів протягом дня. 
Тому перед розрахунком daily spend і CAC потрібно залишити тільки останній snapshot за день:

`ad_id + date + latest timestamp`

## Deduplication Logic Check

Після застосування логіки:

`PARTITION BY ad_id, date ORDER BY CAST(timestamp AS DATETIME) DESC`

та фільтрації:

`rn = 1`

очікується, що залишиться рівно один рядок на кожен `ad_id + date`.

| Check | Expected Result |
|---|---:|
| Rows with more than 1 record after deduplication by `ad_id + date` | 0 |

### Result

Ця перевірка підтверджує, що логіка дедублікації працює коректно і може використовуватись перед агрегацією до `source + date`, а потім до `source`.

## Updated Key Takeaways

- У ключових полях `product_events` та `orders` немає null values.
- Дублікатів за natural keys у `product_events` та `orders` не знайдено.
- Revenue values у `orders` валідні.
- Кожен revenue event має стабільний price point.
- Продуктова воронка виглядає консистентною.
- Усі paying users мають відповідні product events.
- Для CAC використовується окремий файл `marketing_ads_raw.csv`.
- `marketing_ads_raw.csv` має cumulative snapshot structure, тому перед розрахунком spend і CAC потрібна дедублікація.
- Правильна логіка дедублікації: залишити останній snapshot за `timestamp` для кожного `ad_id + date`.
- Для коректного LTV/CAC LTV і CAC мають мати однакову базу розрахунку: наприклад, обидва на `install` або обидва на `registration`.


## Decision for Further Analysis

Дані можна використовувати для розрахунку продуктових метрик, revenue та unit economics без очищення або дедублікації.

