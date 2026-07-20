[README_chess.md](https://github.com/user-attachments/files/30182337/README_chess.md)
# Chess Games Analysis · 66,879 Games | SQL + Power BI

<img width="2767" height="1600" alt="Chess_Dashboard" src="https://github.com/user-attachments/assets/90ebe227-bac7-4049-80e8-b461753f5e3f" />


**SQL data cleaning, PGN parsing & analysis case study**
Author: Franklin Manuel Ruiz Guadamuz · Tools: SQLite (DB Browser), SQL, Power BI · Source: Kaggle (Chess.com club games)

---

## 1. Overview
Analysis of 66,879 Chess.com club games, done **entirely in SQL**: deriving game outcomes, parsing openings from raw PGN text, engineering features, and aggregating results. Power BI is used only as the visualization layer. Focus: practical, interview-relevant SQL.

## 2. Dataset
| Attribute | Detail |
|---|---|
| Source | Kaggle — club_games_data.csv |
| Rows | 66,879 (65,778 standard chess after scope filter) |
| Columns | 14 |
| Buried in PGN | opening name, ECO code, termination (parsed with string functions) |

No missing values — but the most useful data was locked inside the free-text `pgn` field.

## 3. SQL Techniques Demonstrated
- **Text parsing** — `INSTR` + `SUBSTR` (nested) to extract opening & ECO from PGN
- **Feature engineering** — `CASE` for outcome and rating-gap buckets
- **Subquery** — count ÷ total for percentages
- **Aggregation & filtering** — `GROUP BY` + `HAVING` (min. sample size)
- **Proportion via `AVG(CASE …)`** — win rate as an average of 1/0
- **Views** — all derived logic consolidated into `games_clean`

## 4. Data Cleaning (the view)
```sql
CREATE VIEW games_clean AS
SELECT white_username, black_username, white_rating, black_rating, time_class, rated,
    CASE
        WHEN white_result = 'win' THEN 'White win'
        WHEN white_result IN ('resigned','checkmated','timeout','abandoned') THEN 'Black win'
        ELSE 'Draw'
    END AS outcome,
    REPLACE(SUBSTR(SUBSTR(pgn, INSTR(pgn,'openings/')+9), 1,
            INSTR(SUBSTR(pgn, INSTR(pgn,'openings/')+9), '"]') - 1), '-', ' ') AS opening,
    SUBSTR(pgn, INSTR(pgn,'[ECO ')+6, 3) AS eco,
    CAST(white_rating AS INTEGER) - CAST(black_rating AS INTEGER) AS rating_diff
FROM games
WHERE rules = 'chess';   -- scope: standard chess only (98.4% of games)
```

## 5. Findings

**Q1 — Win rate by color**

| Outcome | Games | % |
|---|---|---|
| White win | 32,783 | 49.84% |
| Black win | 30,697 | 46.67% |
| Draw | 2,298 | 3.49% |

White has a measurable first-move advantage (~3 pts).

**Q2 — Openings by White win rate (min. 50 games)**
Top: King's Pawn Opening 88.0% (249), Petrov's Defense Classical Damiano 69.6%, Nimzowitsch-Larsen Attack 67.4%, Sicilian McDonnell Attack 65.2%, Queen's Pawn Opening 65.1%.
_Note: King's Pawn's 88% is an outlier — likely short, low-level games, not opening strength._
Most-played openings: Bishop's Opening (1,191), Scandinavian Defense (993), Queen's Pawn Opening Accelerated London System (959), Sicilian Defense Bowdler Attack (848), Van't Kruijs Opening (815).

**Q3 — Does the higher-rated player win?**

| Rating gap | Games | White win % | Black win % |
|---|---|---|---|
| Black +100 or more | 6,545 | 17.2% | 80.2% |
| Black slightly higher | 25,873 | 33.3% | 62.8% |
| White slightly higher / even | 26,808 | 66.1% | 30.4% |
| White +100 or more | 6,552 | 81.3% | 16.0% |

Rating strongly predicts the result — win rate climbs 17% → 81%, near-symmetric between colors.

**Q4 — Results by time control**

| Time control | Games | White win % | Black win % |
|---|---|---|---|
| Blitz | 28,805 | 49.9% | 46.1% |
| Bullet | 22,222 | 50.1% | 47.6% |
| Rapid | 12,872 | 49.3% | 45.9% |
| Daily | 1,879 | 49.1% | 48.4% |

White's win rate is stable (~49–50%) across formats, but the edge over Black shrinks with thinking time: +3.8 pts in blitz vs +0.7 pts in daily.

## 6. Key Insights
1. White wins slightly more (first-move advantage).
2. Rating gap is the dominant driver of results (~17% → ~81%).
3. Extreme opening win rates (e.g., King's Pawn 88%) likely reflect game length/skill, not the opening — flagged, not headlined.
4. White's first-move edge is consistent across time controls but nearly vanishes in daily/correspondence play (+0.7 pts vs +3.8 in blitz).

## 7. Challenges & Lessons
- **PGN parsing:** an early `INSTR(pgn, '"]')` matched an earlier tag; fixed with a nested `SUBSTR` so the search started after `openings/`.
- **SQLite types:** columns import as text → `CAST` for numeric math.
- **GROUP BY discipline:** only grouped/aggregated columns in the `SELECT`.
- **Reproducibility:** one view keeps analysis queries short and re-runnable.

## 8. Visualization (Power BI)
Dark, professional dashboard built on `games_clean`, connected to SQLite via ODBC (amber accent, custom theme).

![Chess Games Analysis Dashboard](Chess_Dashboard.png)

## 9. Limitations
Standard chess only; rare-opening win rates unreliable (sample threshold applied); club-game data, not representative of all rating ranges or professional play.

---
**Files:** `chess_analysis.sql` · this README · Power BI dashboard
**SQL used:** CASE, INSTR, SUBSTR, REPLACE, CAST, COUNT, AVG, GROUP BY, HAVING, subquery, CREATE VIEW
