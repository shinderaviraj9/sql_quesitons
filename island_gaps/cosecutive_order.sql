WITH distinct_dates AS (
    SELECT DISTINCT
        customer_id,
        order_date
    FROM orders
),

interim_seq AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY order_date
        ) AS rn
    FROM distinct_dates
),

grp_as AS (
    SELECT
        *,
        order_date - (rn * INTERVAL '1 day') AS grp
--        postgre sql
        DATEADD(day, -rn,order_date)
--        snowfalke

    FROM interim_seq
),

grp_orders AS (
    SELECT
        customer_id,
        grp,
        MIN(order_date) AS streak_start,
        MAX(order_date) AS streak_end,
        COUNT(*) AS streak
    FROM grp_as
    GROUP BY customer_id, grp
    HAVING COUNT(*) >= 3
)

SELECT
    customer_id,
    streak_start,
    streak_end,
    streak
FROM grp_orders
ORDER BY customer_id, streak_start;