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

## Key Takeaways

- У ключових полях `product_events` та `orders` немає null values.
- Дублікатів за natural keys не знайдено.
- Revenue values у `orders` валідні: немає null, zero, negative або підозріло великих amount.
- Кожен revenue event має стабільний price point.
- Продуктова воронка виглядає консистентною.
- Усі paying users мають відповідні product events.
- Є один order після завершення періоду product_events, тому для unit economics потрібно явно визначити revenue window.

## Decision for Further Analysis

Дані можна використовувати для розрахунку продуктових метрик, revenue та unit economics без очищення або дедублікації.

