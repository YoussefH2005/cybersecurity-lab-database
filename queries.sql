/*********************************************************************************************
TRIGGERS AND FUNCTIONS
*********************************************************************************************/
-- A function and trigger to calculate final_grade
CREATE OR REPLACE FUNCTION "calculate_final_grade"()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW."final_grade" := NEW."report_grade" * 0.4 + NEW."exercise_grade" * 0.6;
    RETURN NEW;
END;
$$;

CREATE TRIGGER "insert_final_grade"
BEFORE INSERT OR UPDATE
ON "grades"
FOR EACH ROW
EXECUTE FUNCTION "calculate_final_grade"();

--A function and trigger that adds bonus to groups
CREATE OR REPLACE FUNCTION "add_bonus"()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    "exercise_start" TIMESTAMP;
    "exercise_end" TIMESTAMP;
    "scenario_time" TIME;
BEGIN
    SELECT
        e."start_time",
        e."end_time",
        a."needed_time"
    INTO
        "exercise_start",
        "exercise_end",
        "scenario_time"
    FROM "exercises" e
    JOIN "attack_scenarios" a
        ON a."id" = e."attack_scenario_id"
    WHERE e."id" = NEW."exercise_id";

    IF ("exercise_end"- "exercise_start") < "scenario_time"::interval
       AND NEW."bonus_grade" < 5 THEN
        NEW."bonus_grade" := NEW."bonus_grade" + 1;

    ELSIF NEW."bonus_grade" = 5 THEN
        RAISE EXCEPTION
        'The group has reached the maximum bonus grade.';

    ELSE
        RAISE EXCEPTION
        'The group did not finish early enough to receive a bonus point.';

    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER "insert_bonus_grade"
BEFORE INSERT OR UPDATE
ON "bonus_grades"
FOR EACH ROW
EXECUTE FUNCTION "add_bonus"();

--A function and trigger to prevent overlapping reservations
CREATE FUNCTION "check_overlap"()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
IF EXISTS (
    SELECT 1
    FROM "lab_reservations"
    WHERE "lab_id" = NEW."lab_id"
        AND NEW."start_time" < "end_time"
        AND NEW."end_time" > "start_time"
) THEN

    RAISE EXCEPTION
    'This laboratory is already reserved during that time.';

END IF;

RETURN NEW;

END;
$$;
CREATE TRIGGER "prevent_overlap"
BEFORE INSERT OR UPDATE
ON "lab_reservations"
FOR EACH ROW
EXECUTE FUNCTION "check_overlap"();

/**************************************************************************
INSERT DATA
**************************************************************************/

-- Instructors
INSERT INTO "instructors" ("first_name", "last_name", "date_birth") VALUES
('John','Smith','1982-03-14'),
('Sarah','Johnson','1980-07-22'),
('Michael','Brown','1978-11-03'),
('Elena','Rossi','1985-06-19'),
('Daniel','Kim','1983-02-27'),
('Fatima','Zahra','1990-09-05');

-- Laboratories
INSERT INTO "laboratories" ("reference") VALUES
('LAB-A'),
('LAB-B'),
('LAB-C'),
('LAB-D'),
('LAB-E');

-- Groups
INSERT INTO groups ("instructor_id") VALUES
(1),
(2),
(3),
(4),
(5),
(6);

-- Students
INSERT INTO "students" ("first_name","last_name","date_birth","group_id") VALUES
('Alice','Martin','2003-01-12',1),
('Bob','Wilson','2003-03-20',1),
('Charlie','Moore','2002-12-10',2),
('David','Taylor','2002-05-07',2),
('Emma','White','2003-08-16',3),
('Liam','Clark','2002-09-09',3),
('Nora','Ahmed','2003-04-02',4),
('Tom','Becker','2002-11-15',4),
('Yuki','Tanaka','2003-07-08',5),
('Omar','Haddad','2002-10-23',5),
('Ines','Duarte','2003-01-30',6),
('Karim','Benali','2002-08-14',6),
('Sofia','Lund','2003-05-25',4),
('Marco','Rinaldi','2002-06-11',5);

-- Attack Scenarios
INSERT INTO "attack_scenarios"
("level","type","description","needed_time","instructor_id")
VALUES
('beginner','web','Exploit a SQL Injection vulnerability.','01:30:00',1),
('intermediate','network','Enumerate a corporate network.','02:00:00',2),
('advanced','active_directory','Compromise an Active Directory environment.','03:00:00',3),
('advanced','privilege_escalation','Escalate privileges on Linux.','02:30:00',1),
('intermediate','password','Crack password hashes.','01:45:00',2),
('beginner','forensics','Analyze a memory dump to identify malicious activity.','01:15:00',4),
('intermediate','crypto','Break a weak custom encryption implementation.','01:50:00',5),
('advanced','web','Exploit a chained XSS and IDOR vulnerability to exfiltrate data.','02:15:00',6),
('beginner','password','Perform a dictionary attack against weak user credentials.','01:00:00',4),
('intermediate','forensics','Recover deleted files from a compromised disk image.','01:40:00',5);

-- CVEs
INSERT INTO "cves"("reference","name") VALUES
('CVE-2021-44228','Log4Shell'),
('CVE-2021-34527','PrintNightmare'),
('CVE-2017-0144','EternalBlue'),
('CVE-2019-0708','BlueKeep'),
('CVE-2023-23397','Outlook');
('CVE-2014-0160','Heartbleed'),
('CVE-2020-1472','Zerologon'),
('CVE-2022-22965','Spring4Shell'),
('CVE-2014-0160','Heartbleed'),
('CVE-2020-1472','Zerologon'),
('CVE-2022-22965','Spring4Shell');

-- Attack_scenario_cves
INSERT INTO "attack_scenario_cves" VALUES
(1,1),
(2,3),
(3,2),
(4,4),
(5,5),
(3,1),
(7,7),
(8,6),
(9,8);

-- Virtual Machines
INSERT INTO "vms"("ip","lab_id") VALUES
('192.168.1.10',1),
('192.168.1.11',1),
('192.168.2.10',2),
('192.168.2.11',2),
('192.168.3.10',3),
('192.168.4.10',4),
('192.168.4.11',4),
('192.168.5.10',5);

-- Attack_scenario_vms
INSERT INTO "attack_scenario_vms" VALUES
(1,1),
(2,2),
(3,3),
(4,4),
(5,5),
(6,6),
(7,7),
(8,8),
(9,6),
(10,7);

-- Exercises
INSERT INTO "exercises"
("group_id","attack_scenario_id","vm_id","start_time","end_time")
VALUES

(1,1,1,'2026-09-01 09:00','2026-09-01 10:10'),
(1,2,2,'2026-09-03 09:00','2026-09-03 10:45'),
(2,3,3,'2026-09-05 08:00','2026-09-05 10:40'),
(2,4,4,'2026-09-07 08:30','2026-09-07 10:15'),
(3,5,5,'2026-09-09 09:00','2026-09-09 10:20'),
(4,6,6,'2026-09-11 09:00','2026-09-11 10:00'),
(4,9,6,'2026-09-13 09:00','2026-09-13 09:55'),
(5,7,7,'2026-09-14 08:30','2026-09-14 10:00'),
(5,10,7,'2026-09-16 09:00','2026-09-16 10:20'),
(6,8,8,'2026-09-17 09:00','2026-09-17 11:00'),
(1,3,3,'2026-09-18 08:00','2026-09-18 10:50'),
(2,1,1,'2026-09-19 09:00','2026-09-19 10:20'),
(3,2,2,'2026-09-20 09:00','2026-09-20 10:50'),
(6,6,6,'2026-09-21 09:00','2026-09-21 10:05'),
(4,7,7,'2026-09-22 08:30','2026-09-22 10:10');

-- Reports
INSERT INTO "reports"
("exercise_id","submitted_by","content","submitted_at","status")
VALUES

(1,1,'SQL Injection report.','2026-09-01 10:30','graded'),
(2,2,'Network enumeration report.','2026-09-03 11:00','graded'),
(3,3,'Active Directory exploitation.','2026-09-05 11:00','graded'),
(4,4,'Privilege escalation report.','2026-09-07 10:30','under_review'),
(5,5,'Password cracking report.','2026-09-09 10:30','submitted'),
(6,7,'Memory forensics analysis report.','2026-09-11 10:15','graded'),
(7,8,'Weak dictionary credential attack report.','2026-09-13 10:10','graded'),
(8,9,'Custom crypto scheme cryptanalysis report.','2026-09-14 10:15','graded'),
(9,10,'Deleted file recovery forensics report.','2026-09-16 10:35','under_review'),
(10,11,'Chained XSS/IDOR exploitation report.','2026-09-17 11:20','submitted'),
(11,1,'Active Directory retest report.','2026-09-18 11:10','graded'),
(12,3,'SQL injection retest report.','2026-09-19 10:35','graded'),
(13,5,'Network enumeration retest report.','2026-09-20 11:05','graded'),
(14,13,'Forensics memory dump report, second attempt.','2026-09-21 10:20','graded'),
(15,7,'Password attack report, advanced group.','2026-09-22 10:25','under_review');

-- Grades
INSERT INTO "grades"
("exercise_id","report_id","exercise_grade","report_grade")
VALUES

(1,1,17,20),
(2,2,15,18),
(3,3,19,16),
(4,4,16,14),
(5,5,18,12),
(6,6,14,15),
(7,7,16,13),
(8,8,12,14),
(9,9,17,16),
(10,10,19,18),
(11,11,15,17),
(12,12,18,19),
(13,13,13,12),
(14,14,16,15),
(15,15,11,10);

-- final_grade is automatically calculated by "insert_final_grade"

-- Bonus Grades
INSERT INTO "bonus_grades"
("student_id","exercise_id","bonus_grade")
VALUES

(1,1,0),
(2,1,0),
(3,3,0),
(4,3,0),
(5,5,0),
(6,5,0),
(7,6,0),
(8,7,0),
(9,8,0),
(10,9,0),
(11,10,0),
(1,11,0),
(3,12,0),
(5,13,0),
(13,14,0),
(7,15,0);

-- Laboratory Reservations
INSERT INTO "lab_reservations"
("lab_id","instructor_id","start_time","end_time")
VALUES

(1,1,'2026-09-01 08:00','2026-09-01 12:00'),
(2,2,'2026-09-05 08:00','2026-09-05 12:00'),
(3,3,'2026-09-09 08:00','2026-09-09 12:00'),
(4,4,'2026-09-11 08:00','2026-09-11 12:00'),
(5,5,'2026-09-14 08:00','2026-09-14 12:00'),
(4,6,'2026-09-17 08:00','2026-09-17 12:00'),
(1,1,'2026-09-18 07:30','2026-09-18 11:30'),
(2,2,'2026-09-20 08:00','2026-09-20 12:00');

/*********************************************************************************************
QUERYING
*********************************************************************************************/

--1/ Best 5 students at the highest difficulty level:

SELECT "attack_scenario_id",
       "student_id",
       "first_name",
       "last_name",
       "scenario_type",
       "final_scenario_grade"
FROM "student_scenario_final_grades"
WHERE "scenario_level" = 'advanced'
ORDER BY "final_scenario_grade" DESC
LIMIT 5;

--2/ Most difficult attack scenario + who mastered it:

SELECT v."attack_scenario_id",
       v."student_id",
       v."first_name",
       v."last_name",
       v."final_scenario_grade"
FROM "student_scenario_final_grades" v
WHERE v."attack_scenario_id" IN
        (SELECT "attack_scenario_id"
         FROM "student_scenario_final_grades"
         WHERE "scenario_grade" <
                 (SELECT AVG("scenario_grade")
                  FROM "student_scenario_final_grades"))
    AND v."final_scenario_grade" =
        (SELECT MAX(v2."final_scenario_grade")
         FROM "student_scenario_final_grades" v2
         WHERE v2."attack_scenario_id" = v."attack_scenario_id")
ORDER BY v."scenario_grade" ASC;

--3/ Instructor whose groups perform best on average

SELECT i."first_name" || ' ' || i."last_name" AS "instructor_full_name",
       g."id" AS "group_id",
       ROUND(AVG(gr."final_grade"), 2) AS "average_grades",
       DENSE_RANK() OVER(ORDER BY ROUND(AVG(gr."final_grade"), 2) DESC) AS "rank"
FROM "instructors" i
JOIN "groups" g ON g."instructor_id" = i."id"
JOIN "exercises" e ON e."group_id" = g."id"
JOIN "grades" gr ON gr."exercise_id" = e."id"
GROUP BY i."id",
         i."first_name",
         i."last_name",
         g."id"
HAVING AVG(gr."final_grade") >
    (SELECT AVG("final_grade")
     FROM "grades");

--4/Students who completed every attack scenario

SELECT s."first_name" ||' '|| s."last_name" AS "student_full_name"
FROM "students" s
JOIN "groups" g ON g."id" = s."group_id"
JOIN "exercises" e ON e."group_id" = g."id"
JOIN "attack_scenarios" a ON a."id" = e."attack_scenario_id"
GROUP BY s."id", "student_full_name"
HAVING COUNT(DISTINCT(e."attack_scenario_id")) =
(
    SELECT COUNT(*)
    FROM "attack_scenarios"
);

--5/ Number of scenarios by category

SELECT "type",
    COUNT(*) AS "total"
FROM "attack_scenarios"
GROUP BY "type";

--6/ Number of attack scenarios by difficulty

SELECT "level",
    COUNT(*) AS "total"
FROM "attack_scenarios"
GROUP BY "level"
ORDER BY "total" DESC;

--7/ Most used CVEs
SELECT c."reference",
    c."name",
    COUNT(ac.id_attack_scenario) AS "times_used"
FROM "cves" c
JOIN "attack_scenario_cves" ac
ON ac."id_cve" = c."id"
JOIN "attack_scenarios" a
ON a."id" = ac."id_attack_scenario"
JOIN "exercises" e
ON e."attack_scenario_id" = a."id"
JOIN "grades" g
ON g."exercise_id" = e."id"
GROUP BY
    c."id",
    c."reference",
    c."name"
ORDER BY "times_used" DESC;

--8 Which VM is associated with the most scenarios

SELECT "v"."ip",
    COUNT(*) AS "scenarios"
FROM "vms" v
JOIN "attack_scenario_vms" av
ON av."id_vm"=v."id"
GROUP BY v."id",
    v."ip"
ORDER BY scenarios DESC;
