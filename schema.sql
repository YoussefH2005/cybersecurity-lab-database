/**************************************************************************
DESIGNING
**************************************************************************/

-- Represent Instructors
CREATE TABLE IF NOT EXISTS "instructors" (
    "id" SERIAL PRIMARY KEY,
    "first_name" VARCHAR(32) NOT NULL,
    "last_name" VARCHAR(32) NOT NULL,
    "date_birth" DATE
);

-- Represent Laboratories
CREATE TABLE IF NOT EXISTS "laboratories" (
    "id" SERIAL PRIMARY KEY,
    "reference" VARCHAR(32) NOT NULL UNIQUE
);

-- Represent Lab_reservations
CREATE TABLE IF NOT EXISTS "lab_reservations" (
    "id" SERIAL PRIMARY KEY,
    "lab_id" INT,
    "instructor_id" INT,
    "start_time" TIMESTAMP NOT NULL,
    "end_time" TIMESTAMP NOT NULL,
    FOREIGN KEY ("lab_id") REFERENCES "laboratories"("id") ON DELETE CASCADE,
    FOREIGN KEY ("instructor_id") REFERENCES "instructors"("id") ON DELETE CASCADE,
    CHECK ("end_time" > "start_time")
);

-- Represent Groups
CREATE TABLE IF NOT EXISTS "groups" (
    "id" SERIAL PRIMARY KEY,
    "instructor_id" INT,
    FOREIGN KEY ("instructor_id") REFERENCES "instructors"("id") ON DELETE SET NULL
);

-- Represent Students
CREATE TABLE IF NOT EXISTS "students" (
    "id" SERIAL PRIMARY KEY,
    "first_name" VARCHAR(32) NOT NULL,
    "last_name" VARCHAR(32) NOT NULL,
    "date_birth" DATE NOT NULL,
    "group_id" INT,
    FOREIGN KEY ("group_id") REFERENCES "groups"("id") ON DELETE SET NULL
);

-- Enum types
CREATE TYPE "level_type" AS ENUM ('advanced', 'intermediate', 'beginner');
CREATE TYPE "attack_scenario_type" AS ENUM ('web', 'network', 'privilege_escalation', 'active_directory', 'password', 'crypto', 'forensics');

-- Represent Attack_scenarios
CREATE TABLE IF NOT EXISTS "attack_scenarios" (
    "id" SERIAL PRIMARY KEY,
    "level" level_type NOT NULL,
    "type" attack_scenario_type NOT NULL,
    "description" TEXT NOT NULL,
    "needed_time" TIME NOT NULL,
    "instructor_id" INT NOT NULL,
    FOREIGN KEY ("instructor_id") REFERENCES "instructors"("id") ON DELETE CASCADE
);

-- Represent CVEs (Common Vulnerabilities and Exposures)
CREATE TABLE IF NOT EXISTS "cves" (
    "id" SERIAL PRIMARY KEY,
    "reference" VARCHAR(32) UNIQUE NOT NULL,
    "name" VARCHAR(32) UNIQUE NOT NULL
);

-- Junction: attack scenarios + CVEs
CREATE TABLE IF NOT EXISTS "attack_scenario_cves" (
    "id_attack_scenario" INT,
    "id_cve" INT,
    PRIMARY KEY ("id_attack_scenario", "id_cve"),
    FOREIGN KEY ("id_attack_scenario") REFERENCES "attack_scenarios"("id") ON DELETE CASCADE,
    FOREIGN KEY ("id_cve") REFERENCES "cves"("id") ON DELETE CASCADE
);

-- Represent VMs (virtual machines)
CREATE TABLE IF NOT EXISTS "vms" (
    "id" SERIAL PRIMARY KEY,
    "ip" VARCHAR(45) UNIQUE NOT NULL,
    "lab_id" INT,
    FOREIGN KEY ("lab_id") REFERENCES "laboratories"("id") ON DELETE CASCADE
);

-- Junction: attack scenarios + VMs
CREATE TABLE IF NOT EXISTS "attack_scenario_vms" (
    "id_attack_scenario" INT,
    "id_vm" INT,
    PRIMARY KEY ("id_attack_scenario", "id_vm"),
    FOREIGN KEY ("id_attack_scenario") REFERENCES "attack_scenarios"("id") ON DELETE CASCADE,
    FOREIGN KEY ("id_vm") REFERENCES "vms"("id") ON DELETE CASCADE
);

-- Represent Exercises
CREATE TABLE IF NOT EXISTS "exercises" (
    "id" SERIAL PRIMARY KEY,
    "group_id" INT,
    "attack_scenario_id" INT NOT NULL,
    "vm_id" INT,
    "start_time" TIMESTAMP NOT NULL,
    "end_time" TIMESTAMP NOT NULL,
    FOREIGN KEY ("group_id") REFERENCES "groups"("id") ON DELETE SET NULL,
    FOREIGN KEY ("attack_scenario_id") REFERENCES "attack_scenarios"("id") ON DELETE CASCADE,
    FOREIGN KEY ("vm_id") REFERENCES "vms"("id") ON DELETE SET NULL,
    CHECK ("end_time" IS NULL OR "end_time" > "start_time")
);

-- Represent Bonus_grades
CREATE TABLE IF NOT EXISTS "bonus_grades" (
    "id" SERIAL PRIMARY KEY,
    "student_id" INT NOT NULL,
    "exercise_id" INT NOT NULL,
    "bonus_grade" NUMERIC(4,2) NOT NULL DEFAULT 0 CHECK ("bonus_grade" >= -5 AND "bonus_grade" <= 5),
    FOREIGN KEY ("student_id") REFERENCES "students"("id") ON DELETE CASCADE,
    FOREIGN KEY ("exercise_id") REFERENCES "exercises"("id") ON DELETE CASCADE
);

-- Represent Reports
CREATE TABLE IF NOT EXISTS "reports" (
    "id" SERIAL PRIMARY KEY,
    "exercise_id" INT NOT NULL,
    "submitted_by" INT NOT NULL,
    "content" TEXT NOT NULL,
    "submitted_at" TIMESTAMP NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'submitted' CHECK ("status" IN ('submitted', 'under_review', 'graded')),
    FOREIGN KEY ("exercise_id") REFERENCES "exercises"("id") ON DELETE CASCADE,
    FOREIGN KEY ("submitted_by") REFERENCES "students"("id") ON DELETE CASCADE
);

-- Represent Grades
CREATE TABLE IF NOT EXISTS "grades" (
    "id" SERIAL PRIMARY KEY,
    "exercise_id" INT NOT NULL,
    "exercise_grade" NUMERIC(4,2) NOT NULL DEFAULT 0 CHECK ("exercise_grade" BETWEEN 0 AND 20),
    "report_id" INT NOT NULL,
    "report_grade" NUMERIC(4,2) DEFAULT 0 CHECK ("report_grade" BETWEEN 0 AND 20),
    "final_grade" NUMERIC(4,2),
    FOREIGN KEY ("exercise_id") REFERENCES "exercises"("id") ON DELETE CASCADE,
    FOREIGN KEY ("report_id") REFERENCES "reports"("id") ON DELETE SET DEFAULT
);

/********************************************************************************************************
VIEWING
********************************************************************************************************/

--Viewing the students' final results in each attack scenario
CREATE OR REPLACE VIEW "student_scenario_final_grades" AS
SELECT a."id" AS "attack_scenario_id",
    s."id" AS "student_id",
    s."first_name",
    s."last_name",
    a."type" AS "scenario_type",
    a."level" AS "scenario_level",
    ROUND(AVG("g"."final_grade"),2) AS "scenario_grade",
    COALESCE(SUM("b"."bonus_grade"),0) AS "total_bonus",
    LEAST(GREATEST(ROUND(COALESCE(SUM(b."bonus_grade"),0) + AVG(g."final_grade"), 2), 0), 20) AS "final_scenario_grade"
FROM "students" s
JOIN "groups" gr
ON gr."id" = s."group_id"
JOIN "exercises" e
ON e."group_id" = gr."id"
JOIN "attack_scenarios" a
ON a."id" = e."attack_scenario_id"
JOIN "grades" g
ON g."exercise_id" = "e"."id"
LEFT JOIN "bonus_grades" b
ON b."student_id" = s."id" AND b."exercise_id" = e."id"
GROUP BY s."id",
    a."id",
    s."first_name",
    s."last_name",
    a."type",
    a."level"
ORDER BY s."first_name", s."last_name";

--Viewing groups leaderboard
CREATE OR REPLACE VIEW "group_leaderboard" AS
SELECT gr."id" AS "group_id",
    COUNT(e.id) AS exercises_completed,
    ROUND(AVG("g"."final_grade"), 2) AS "average_grade",
    DENSE_RANK() OVER (ORDER BY ROUND(AVG(g."final_grade"), 2) DESC) AS "rank"
FROM "groups" gr
JOIN "exercises" e
ON e."group_id" = gr."id"
JOIN "grades" g
ON g."exercise_id" = e."id"
GROUP BY gr."id";


/* ******************************************************************
OPTIMIZING
********************************************************************/
CREATE INDEX "idx_attack_scenarios_level" ON "attack_scenarios"("level");
CREATE INDEX "idx_groups_instructor" ON "groups"("instructor_id");
CREATE INDEX "idx_exercises_group_scenario" ON "exercises"("group_id", "attack_scenario_id");
CREATE INDEX "idx_grades_exercise" ON "grades"("exercise_id","final_grade");
CREATE INDEX "idx_scenario_cves_reverse" ON "attack_scenario_cves"("id_cve", "id_attack_scenario");
CREATE INDEX "idx_scenario_vms" ON "attack_scenario_vms"("id_vm", "id_attack_scenario");

