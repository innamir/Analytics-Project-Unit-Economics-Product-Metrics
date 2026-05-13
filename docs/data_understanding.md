# Data Understanding

## Overview

Цей документ описує структуру та первинне розуміння даних, які використовуються в проекті для аналізу продуктових метрик, monetization та unit economics.

Основний аналіз базується на двох таблицях BigQuery:

- `product_events` — продуктові події користувачів;
- `orders` — revenue events / платежі користувачів.

Таблиця `audience` не використовується в основному аналізі, оскільки ключові продуктові та revenue-метрики можна побудувати на основі `product_events` та `orders`.

## Dataset Overview

| Table | Rows Total | Unique Users | Earliest Timestamp | Latest Timestamp | Days Covered |
|---|---:|---:|---|---|---:|
| product_events | 61,595 | 21,424 | 2024-01-01 00:00:00 UTC | 2024-06-29 23:44:47 UTC | 181 |
| orders | 2,197 | 1,007 | 2024-01-02 01:16:01 UTC | 2024-07-14 14:51:34 UTC | 195 |

### Initial Observations

- `product_events` містить 61,595 продуктових подій для 21,424 унікальних користувачів. Це означає, що таблиця має event-level або milestone-level grain: один користувач може мати кілька різних продуктових подій.
- `orders` містить 2,197 revenue events для 1,007 унікальних користувачів. Це означає, що частина користувачів має більше ніж одну оплату.
- Період у `orders` довший, ніж у `product_events`: revenue events доходять до 2024-07-14, тоді як продуктові події закінчуються 2024-06-29.
- Через різне покриття дат важливо бути обережною при розрахунку unit economics: revenue може включати пізніші платежі після завершення періоду продуктових подій.

## Table Grain

### `product_events`

Потенційний grain таблиці:

`1 row = one user reaching one product milestone/event type`

Ключові поля:

| Field | Meaning |
|---|---|
| `user_id` | Ідентифікатор користувача |
| `event_type` | Тип продуктової події |
| `timestamp` | Час події |
| `channel` | Канал залучення або джерело користувача |

Таблиця використовується для:

- аналізу продуктової воронки;
- підрахунку користувачів на кожному етапі;
- аналізу активності по каналах;
- побудови бази для conversion metrics.

### `orders`

Потенційний grain таблиці:

`1 row = one revenue event / payment-related event`

Ключові поля:

| Field | Meaning |
|---|---|
| `user_id` | Ідентифікатор користувача |
| `event` | Тип revenue event |
| `timestamp` | Час revenue event |
| `amount` | Сума платежу |

Таблиця використовується для:

- розрахунку revenue;
- визначення paying users;
- аналізу purchase / rebill / upsell структури;
- розрахунку AOV, ARPPU та інших monetization metrics.

## Product Events

| Event Type | Events Count | Unique Users |
|---|---:|---:|
| install | 21,424 | 21,424 |
| registration | 19,970 | 19,970 |
| like | 11,339 | 11,339 |
| match | 6,072 | 6,072 |
| message_sent | 1,395 | 1,395 |
| paywall_view | 1,395 | 1,395 |

### Observations

- Для кожного `event_type` кількість подій дорівнює кількості унікальних користувачів. Це означає, що в межах одного типу події користувач, ймовірно, має максимум один запис.
- `product_events` виглядає не як повний behavioral event stream, а як milestone funnel table: кожен рядок фіксує, що користувач досягнув певного етапу.
- Найбільша кількість користувачів проходить етапи `install` та `registration`, після чого кількість користувачів поступово зменшується на глибших етапах funnel.
- `message_sent` і `paywall_view` мають однакову кількість користувачів. Це варто перевірити додатково в data quality або funnel analysis, оскільки ці події можуть бути пов’язані продуктово або технічно.

## Revenue Events

| Event | Events Count | Unique Users | Total Revenue | Avg Amount |
|---|---:|---:|---:|---:|
| rebill | 990 | 640 | 49,490.10 | 49.99 |
| purchase | 1,007 | 1,007 | 25,164.93 | 24.99 |
| upsell | 200 | 200 | 4,000.00 | 20.00 |

### Observations

- `purchase` має 1,007 подій і 1,007 унікальних користувачів. Це схоже на першу оплату або базову покупку.
- `rebill` формує найбільшу частину revenue: $49,490.10 із загального revenue $78,655.03. Це означає, що повторні платежі є ключовим драйвером monetization.
- `rebill` має 990 подій для 640 користувачів, отже частина користувачів має більше одного повторного платежу.
- `upsell` має найменший внесок у revenue: $4,000.00, але може бути додатковим monetization layer для частини платників.
- Середні чеки виглядають стандартизовано: `purchase` ≈ $24.99, `rebill` ≈ $49.99, `upsell` = $20.00. Це схоже на фіксовані price points.

## Channel Overview

| Channel | Events Count | Unique Users |
|---|---:|---:|
| meta | 48,623 | 17,143 |
| tiktok | 9,115 | 3,171 |
| google | 3,857 | 1,110 |

### Observations

- `meta` є найбільшим каналом за кількістю продуктових подій і унікальних користувачів.
- `tiktok` має суттєво менший обсяг користувачів, ніж `meta`, але більший, ніж `google`.
- `google` є найменшим каналом за кількістю користувачів у `product_events`.
- Оскільки `channel` доступний у `product_events`, подальший channel-level аналіз можливий для продуктової воронки.
- Для повного CAC-аналізу потрібні окремі marketing spend дані. У цьому проекті CAC-аналіз буде виконуватись окремо на основі marketing ads dataset.

## Marketing Ads Data

Окрім продуктових та revenue-даних, для розрахунку CAC використовується окремий CSV-файл:

- `marketing_ads_raw.csv` — сирі дані з рекламних кабінетів TikTok, META і Google.

Ця таблиця не містить `user_id`, тому її не можна напряму поєднати з `product_events` або `orders` на рівні користувача. Вона використовується окремо для channel-level аналізу marketing spend, рекламної воронки та CAC.

## Marketing Ads Dataset Overview

| Table / File | Rows Total | Unique Sources | Unique Campaigns | Unique Adsets | Unique Ads | Earliest Date | Latest Date | Days Covered | Earliest Timestamp | Latest Timestamp |
|---|---:|---:|---:|---:|---:|---|---|---:|---|---|
| marketing_ads_raw.csv | 8,814 | 3 | 6 | 10 | 10 | 2024-01-02 | 2024-07-14 | 195 | 2024-01-02 01:19:00 | 2024-07-14 14:51:34 |

### Table Grain

Потенційний grain таблиці:

`1 row = one cumulative advertising snapshot for one ad_id on one date at one load timestamp`

Практично це означає, що для одного `ad_id + date` може бути кілька рядків протягом дня. Тому перед агрегацією потрібно залишити останній snapshot за `timestamp`.


Ключові поля:

| Field | Meaning |
|---|---|
| `source` | Рекламний канал: TikTok, META або Google |
| `campaign_id` | ID кампанії |
| `adset_id` | ID групи оголошень |
| `ad_id` | ID конкретного оголошення |
| `date` | Дата рекламної статистики |
| `spend` | Кумулятивні витрати на момент snapshot |
| `impressions` | Кумулятивні покази на момент snapshot |
| `clicks` | Кумулятивні кліки на момент snapshot |
| `installs` | Кумулятивні встановлення на момент snapshot |
| `registrations` | Кумулятивні реєстрації на момент snapshot |
| `timestamp` | Час завантаження snapshot у систему |

### Observations

- `marketing_ads_raw.csv` є окремим CSV-файлом із рекламними даними, а не user-level таблицею.
- Таблиця містить 8,814 рядків за період з 2024-01-02 до 2024-07-14.
- У даних є 3 рекламні канали, 6 кампаній, 10 adsets і 10 унікальних ads.
- Дані мають cumulative snapshot structure: протягом одного дня для одного `ad_id` може бути кілька snapshot-ів.
- Через cumulative structure не можна просто робити `SUM(spend)` по raw-таблиці — це завищить результат.
- Перед розрахунком CAC потрібно залишити останній snapshot для кожного `ad_id + date`.
- Після дедублікації дані можна агрегувати до рівня `source + date`, а потім до рівня `source` за весь період.
- CAC у цьому проекті рахується на channel-level як `total_spend / registrations`.

## Key Takeaways

- Основні таблиці для LTV-аналізу — `product_events` та `orders`.
- `product_events` найкраще інтерпретувати як milestone funnel table, а не як raw behavioral event stream.
- `orders` містить кілька типів monetization events: `purchase`, `rebill`, `upsell`.
- Повторні платежі (`rebill`) формують найбільшу частину revenue.
- Для CAC використовується окремий CSV-файл `marketing_ads_raw.csv`.
- `marketing_ads_raw.csv` не містить `user_id`, тому аналіз CAC виконується на рівні каналів, а не окремих користувачів.
- Marketing ads дані є cumulative snapshot-level, тому перед розрахунком spend і CAC потрібна дедублікація.
- Для коректного LTV/CAC LTV і CAC мають мати однакову базу розрахунку: наприклад, обидва на `install` або обидва на `registration`. Оскільки `marketing_ads_raw.csv` не містить `user_id`, порівняння виконується на рівні каналу через зіставлення `channel` і `source`.



