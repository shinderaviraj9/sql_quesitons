
WITH params AS (
    SELECT
        DATE '2026-10-01' AS start_date,
        DATE '2026-11-01' AS end_date
),

date_spine AS (
    SELECT gs::date AS txn_date
    FROM params p
    CROSS JOIN LATERAL generate_series(
        p.start_date - INTERVAL '3 days',
        p.end_date - INTERVAL '1 day',
        INTERVAL '1 day'
    ) AS gs
),

-- Step 1: Aggregate raw transactions
daily_volume AS (
    SELECT
        t.merchant_id,
        t.transaction_ts::date AS txn_date,
        COUNT(*) AS txn_count
    FROM transactions t
    CROSS JOIN params p
    WHERE t.transaction_ts >= p.start_date - INTERVAL '3 days'
      AND t.transaction_ts < p.end_date
    GROUP BY
        t.merchant_id,
        t.transaction_ts::date
),

-- Step 2: Identify merchants
merchants AS (
    SELECT DISTINCT merchant_id
    FROM daily_volume
),

-- Step 3: Create merchant-date combinations
merchant_date_grid AS (
    SELECT
        m.merchant_id,
        d.txn_date
    FROM merchants m
    CROSS JOIN date_spine d
),

-- Step 4: Fill missing dates with zero
filled_volume AS (
    SELECT
        g.merchant_id,
        g.txn_date,
        COALESCE(v.txn_count, 0) AS txn_count
    FROM merchant_date_grid g
    LEFT JOIN daily_volume v
        ON g.merchant_id = v.merchant_id
       AND g.txn_date = v.txn_date
),

-- Step 5: Calculate rolling average
rolling_stats AS (
    SELECT
        merchant_id,
        txn_date,
        txn_count,

        AVG(txn_count * 1.0) OVER (
            PARTITION BY merchant_id
            ORDER BY txn_date
            ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING
        ) AS avg_prev_3_days,

        COUNT(*) OVER (
            PARTITION BY merchant_id
            ORDER BY txn_date
            ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING
        ) AS history_days

    FROM filled_volume
)

-- Step 6: Detect spikes
SELECT
    merchant_id,
    txn_date,
    txn_count,
    ROUND(avg_prev_3_days, 2) AS avg_prev_3_days,
    ROUND(
        txn_count / NULLIF(avg_prev_3_days, 0),
        2
    ) AS spike_ratio
FROM rolling_stats
CROSS JOIN params p
WHERE history_days = 3
  AND txn_date >= p.start_date
  AND txn_date < p.end_date
  AND txn_count > 2 * avg_prev_3_days
ORDER BY merchant_id, txn_date;
