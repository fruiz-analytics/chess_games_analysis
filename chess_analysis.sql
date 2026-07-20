/* ============================================================================
   CHESS GAMES ANALYSIS — Chess.com club games (1970s style dataset)
   Author : Franklin Manuel Ruiz Guadamuz
   Engine : SQLite (DB Browser for SQLite)
   Source : Kaggle — club_games_data.csv (66,879 games)

   Goal   : Clean and analyze 66,879 chess games entirely in SQL — deriving
            game outcomes, parsing openings from raw PGN text, and measuring
            how color, rating gap, opening, and time control affect results.
            Power BI is used only as the visualization layer.
   ============================================================================ */


/* ----------------------------------------------------------------------------
   1. DATA EXPLORATION
   Quick profiling of the raw table before any transformation.
   ---------------------------------------------------------------------------- */

-- Total number of games in the raw dataset
SELECT COUNT(*) AS total_games
FROM games;

-- How games end (from White's perspective): win, resigned, timeout, etc.
SELECT white_result, COUNT(*) AS games
FROM games
GROUP BY white_result
ORDER BY games DESC;

-- Distribution of time controls (blitz, bullet, rapid, daily)
SELECT time_class, COUNT(*) AS games
FROM games
GROUP BY time_class
ORDER BY games DESC;

-- Game variants. Standard chess dominates (~98%); variants are excluded later.
SELECT rules, COUNT(*) AS games
FROM games
GROUP BY rules
ORDER BY games DESC;


/* ----------------------------------------------------------------------------
   2. CLEAN VIEW — games_clean
   Consolidates all cleaning and feature engineering into a single reusable
   view so every analysis query below stays short and readable.

   Derived fields:
     - outcome      : White win / Black win / Draw, derived with CASE
     - opening      : opening name parsed from the free-text PGN field
     - eco          : ECO opening code parsed from the PGN field
     - rating_diff  : white_rating - black_rating (CAST to INTEGER, since
                      DB Browser imports every column as TEXT)

   Scope decision: only standard chess (rules = 'chess'). Variants such as
   crazyhouse or king-of-the-hill follow different rules and are not comparable.
   ---------------------------------------------------------------------------- */

CREATE VIEW games_clean AS
SELECT
    white_username,
    black_username,
    white_rating,
    black_rating,
    time_class,
    rated,

    -- Derive the game result from White's result code
    CASE
        WHEN white_result = 'win' THEN 'White win'
        WHEN white_result IN ('resigned', 'checkmated', 'timeout', 'abandoned') THEN 'Black win'
        ELSE 'Draw'
    END AS outcome,

    -- Parse the opening name from the PGN. The name sits after '.../openings/'
    -- and ends just before the closing '"]'. A nested SUBSTR is used so the
    -- search for '"]' starts AFTER 'openings/' (avoids matching earlier tags).
    -- Hyphens from the URL are replaced with spaces for readability.
    REPLACE(
        SUBSTR(
            SUBSTR(pgn, INSTR(pgn, 'openings/') + 9),
            1,
            INSTR(SUBSTR(pgn, INSTR(pgn, 'openings/') + 9), '"]') - 1
        ),
        '-', ' '
    ) AS opening,

    -- Parse the 3-character ECO code that follows the tag [ECO "
    SUBSTR(pgn, INSTR(pgn, '[ECO ') + 6, 3) AS eco,

    -- Rating gap (CAST because ratings were imported as text)
    CAST(white_rating AS INTEGER) - CAST(black_rating AS INTEGER) AS rating_diff

FROM games
WHERE rules = 'chess';


/* ----------------------------------------------------------------------------
   3. ANALYSIS
   ---------------------------------------------------------------------------- */

-- Q1. Win rate by color: does White win more often? (first-move advantage)
--     Percentages use a subquery to divide each count by the total.
SELECT
    CASE
        WHEN white_result = 'win' THEN 'White win'
        WHEN white_result IN ('resigned', 'checkmated', 'timeout', 'abandoned') THEN 'Black win'
        ELSE 'Draw'
    END AS outcome,
    COUNT(*) AS games,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM games WHERE rules = 'chess'), 2) AS pct
FROM games
WHERE rules = 'chess'
GROUP BY outcome
ORDER BY games DESC;


-- Q2a. Most frequently played openings
SELECT
    opening,
    COUNT(*) AS times_played
FROM games_clean
GROUP BY opening
ORDER BY times_played DESC
LIMIT 15;


-- Q2b. Openings with the highest White win rate (min. 50 games for reliability).
--      The AVG(CASE ... 1.0 ELSE 0) pattern turns wins into a proportion.
SELECT
    opening,
    COUNT(*) AS times_played,
    ROUND(AVG(CASE WHEN outcome = 'White win' THEN 1.0 ELSE 0 END), 3) * 100 AS white_win_rate
FROM games_clean
GROUP BY opening
HAVING COUNT(*) >= 50
ORDER BY white_win_rate DESC
LIMIT 15;


-- Q3. Does the higher-rated player win? Rating gap bucketed with CASE,
--     then White/Black win rate measured per bucket.
SELECT
    CASE
        WHEN rating_diff > 100 THEN 'White +100 or more'
        WHEN rating_diff BETWEEN 0 AND 100 THEN 'White slightly higher / even'
        WHEN rating_diff BETWEEN -100 AND 0 THEN 'Black slightly higher'
        WHEN rating_diff < -100 THEN 'Black +100 or more'
    END AS rating_gap_bucket,
    COUNT(*) AS total_games,
    ROUND(AVG(CASE WHEN outcome = 'White win' THEN 1.0 ELSE 0 END), 3) * 100 AS white_win_rate,
    ROUND(AVG(CASE WHEN outcome = 'Black win' THEN 1.0 ELSE 0 END), 3) * 100 AS black_win_rate
FROM games_clean
GROUP BY rating_gap_bucket
ORDER BY MIN(rating_diff);


-- Q4. Do results change by time control? White/Black win rate per time_class.
SELECT
    time_class,
    COUNT(*) AS total_games,
    ROUND(AVG(CASE WHEN outcome = 'White win' THEN 1.0 ELSE 0 END), 3) * 100 AS white_win_rate,
    ROUND(AVG(CASE WHEN outcome = 'Black win' THEN 1.0 ELSE 0 END), 3) * 100 AS black_win_rate
FROM games_clean
GROUP BY time_class
ORDER BY total_games DESC;
