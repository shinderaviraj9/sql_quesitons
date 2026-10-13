WITH filter_successpayments AS (
    SELECT *
    FROM payments
    WHERE status = 'SUCCESS'
),

vol_per_payments AS (
    SELECT
        merchant_id,
        payment_date,
        SUM(amount) AS daily_sum
    FROM filter_successpayments
    GROUP BY
        merchant_id,
        payment_date
),

rolling_avg AS (
    SELECT
        merchant_id,
        payment_date,
        daily_sum,

        AVG(daily_sum) OVER (
            PARTITION BY merchant_id
            ORDER BY payment_date
            ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING
        ) AS avg_3_day,

        COUNT(*) OVER (
            PARTITION BY merchant_id
            ORDER BY payment_date
            ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING
        ) AS history_days

    FROM vol_per_payments
)

SELECT
    merchant_id,
    payment_date,
    daily_sum AS daily_amt,
    avg_3_day AS previous_3_day_avg
FROM rolling_avg
WHERE history_days >= 3
  AND daily_sum > 2 * avg_3_day;