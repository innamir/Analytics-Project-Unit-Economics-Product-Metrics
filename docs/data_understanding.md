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

## Key Takeaways

- Основні таблиці для аналізу — `product_events` та `orders`.
- `product_events` найкраще інтерпретувати як milestone funnel table, а не як raw behavioral event stream.
- `orders` містить кілька типів monetization events: `purchase`, `rebill`, `upsell`.
- Повторні платежі (`rebill`) формують найбільшу частину revenue.
- Дані по продуктах і revenue мають різне date coverage, тому при розрахунку unit economics потрібно чітко зафіксувати revenue window.
- Channel-level аналіз можливий через `product_events`, але CAC потребує окремих spend data.
