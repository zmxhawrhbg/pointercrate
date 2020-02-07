
DROP VIEW IF EXISTS players_with_score;
DROP FUNCTION IF EXISTS record_score(FLOAT, FLOAT, FLOAT); -- depended on so delete

CREATE OR REPLACE FUNCTION record_score(progress FLOAT, demon FLOAT, list_size FLOAT, requirement FLOAT) RETURNS FLOAT AS $record_score$
    SELECT CASE
        WHEN progress = 100 THEN
            list_size * EXP((1.0 - demon) * LN(1.0 / 30.0) / (-list_size + 1.0))  -- i wanted to do one of those bitwise things but it doesn't like floats
        WHEN progress < requirement THEN
            0.0
				WHEN list_size < demon THEN -- if sql messes up then this
						0.0
        ELSE
            list_size * EXP((1.0 - demon) * LN(1.0 / 30.0) / (-list_size + 1.0)) * (0.25 * (progress - requirement) / (100 - requirement) + 0.25)
    END;
$record_score$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE VIEW players_with_score AS
SELECT players.id,
	players.name,
	RANK() OVER(
													ORDER BY scores.total_score DESC) AS rank,
	CASE
					WHEN scores.total_score IS NULL THEN 0.0::FLOAT
					ELSE scores.total_score
	END AS score,
	ROW_NUMBER() OVER(
																			ORDER BY scores.total_score DESC) AS index,
	nationalities.iso_country_code,
	nationalities.nation
FROM
		( SELECT pseudo_records.player,
				SUM(record_score(pseudo_records.progress::FLOAT, pseudo_records.position::FLOAT, 100::FLOAT, pseudo_records.requirement)) as total_score
			FROM
					( SELECT player,
							progress,
							position,
							requirement
						FROM records
						INNER JOIN demons ON demons.id = demon
						WHERE demons.position <= 75
								AND status_ = 'APPROVED'
						UNION SELECT verifier as player,
							CASE
											WHEN demons.position > 75 THEN 0.0::FLOAT
											ELSE 100.0::FLOAT
							END as progress,
							position,
							100.0::FLOAT
						FROM demons
						UNION SELECT publisher as player,
							0.0::FLOAT as progress,
							position,
							100.0::FLOAT
						FROM demons
						UNION SELECT creator as player,
							0.0::FLOAT as progress,
							1.0::FLOAT as position, -- doesn't matter
							100.0::FLOAT
						FROM creators ) AS pseudo_records
			GROUP BY player ) scores
INNER JOIN players ON scores.player = players.id
LEFT OUTER JOIN nationalities ON players.nationality = nationalities.iso_country_code
WHERE NOT players.banned;