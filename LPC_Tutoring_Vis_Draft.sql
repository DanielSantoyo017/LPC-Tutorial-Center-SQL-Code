--DB1 
--Student retention by retention status, that is, Used tutoring once, twice...
--Each semester students are seen as a "new user" which categories them as "used once" restarting usage trends
 --(Granular)

WITH
Student_Sequence AS (
SELECT DISTINCT
	Date,
	Start_Time,
	Semester,
	Week,
	Day,
	Student_ID,
	Mode_of_Service,
	COUNT(Mode_of_Service) OVER (PARTITION BY Mode_of_Service,
		Semester) AS Mode_Totals,
	Service_Description,
	COUNT(Service_Description) OVER (PARTITION BY Service_Description,
		Semester) AS Service_Totals,
	ROW_NUMBER() OVER (PARTITION BY student_ID, Mode_of_Service,
		Service_Description, Semester ORDER BY Date ASC) AS Student_Platform_Sequence,
	Subject_Name,
	Course_Name, 
	Course_Description,
	Duration_Hours
FROM [dbo].['2021_22_Tutoring_Services_Data$']
GROUP BY Date, 
	Semester, 
	Week, 
	Day,
	Start_Time,
	Student_ID, 
	Subject_Name, 
	Course_Name, 
	Course_Description, 
	Service_Description, 
	Mode_of_Service, 
	Duration_Hours)

SELECT DISTINCT
	Date,
	Start_Time,
	Semester,
	Week,
	Day,
	Student_ID,
	Mode_of_Service,
	Mode_Totals,
	Service_Description,
	Service_Totals,
	Student_Platform_Sequence,
	CASE
		WHEN Student_Platform_Sequence = 1 THEN 'Used Once'
		WHEN Student_Platform_Sequence = 2 THEN 'Used Twice'
		WHEN Student_Platform_Sequence Between 3 AND 5 THEN 'Used 3 to 5 Times'
		WHEN Student_Platform_Sequence BETWEEN 6 and 10 THEN 'Used More Than 5 Times'
		ELSE 'Used More Than 10 Times'
		END AS Student_Life_Cycle,
	Subject_Name,
	Course_Name, 
	Course_Description,
	Duration_Hours
FROM Student_Sequence
ORDER BY Student_ID


--Student Retention by distinct cohorts
--Only the max usage trends are kept, all "used once" only used that service for a
--particular subject once, allows for faster, more effective targeted student out reach

WITH
Student_Sequence AS (
SELECT DISTINCT
	Date,
	Start_Time,
	Semester,
	Week,
	Day,
	Student_ID,
	Mode_of_Service,
	ROW_NUMBER() OVER (Partition BY  student_ID, Mode_of_Service,
		Semester ORDER BY Date ASC) AS Student_Mode_Sequence,
	Service_Description,
	ROW_NUMBER() OVER (PARTITION BY student_ID, Mode_of_Service, 
		Service_Description, Semester ORDER BY Date ASC) AS Student_Platform_Sequence,
	Subject_Name,
	Course_Name, 
	Course_Description,
	Duration_Hours
FROM [dbo].['2021_22_Tutoring_Services_Data$']
GROUP BY Date,
	Semester, 
	Week, 
	Day,
	Start_Time, 
	Student_ID, 
	Subject_Name, 
	Course_Name, 
	Course_Description, 
	Service_Description,
	Mode_of_Service, 
	Duration_Hours),

Student_Cohorts_Distinct as (

SELECT DISTINCT
	Student_ID,
	Semester,
	Mode_of_Service,
	MAX(Student_Mode_Sequence) OVER(PARTITION BY Student_ID, Mode_of_service, Semester)  AS Dist_mode_Cohort,
	Service_Description,
	MAX(Student_Platform_Sequence) OVER(PARTITION BY Student_ID, Service_Description, Semester)  AS Dist_Sequence_Cohort
FROM Student_Sequence
GROUP BY
	Student_ID,
	Semester,
	Mode_of_Service,
	Student_Mode_Sequence,
	Service_Description,
	Student_Platform_Sequence)


SELECT DISTINCT
	Student_ID,
	Semester,
	Mode_of_service,
	CASE
		WHEN Dist_mode_Cohort = 1 THEN 'Used Once'
		WHEN Dist_mode_Cohort = 2 THEN 'Used Twice'
		WHEN Dist_mode_Cohort Between 3 AND 5 THEN 'Used 3 to 5 Times'
		WHEN Dist_mode_Cohort BETWEEN 6 and 10 THEN 'Used More Than 5 Times'
		ELSE 'Used More Than 10 Times'
		END AS Student_Mode_Cycle,
	Dist_mode_Cohort,
	Service_Description,
	CASE
		WHEN Dist_Sequence_Cohort = 1 THEN 'Used Once'
		WHEN Dist_Sequence_Cohort = 2 THEN 'Used Twice'
		WHEN Dist_Sequence_Cohort Between 3 AND 5 THEN 'Used 3 to 5 Times'
		WHEN Dist_Sequence_Cohort BETWEEN 6 and 10 THEN 'Used More Than 5 Times'
		ELSE 'Used More Than 10 Times'
		END AS Student_Service_Cycle,
	Dist_Sequence_Cohort
FROM Student_Cohorts_Distinct
ORDER BY Semester, Student_ID, Service_Description


--DB 2 Cross platform with study data (students who study usually don't recive tutoring)

SELECT
	DISTINCT Service_Description, 
	Student_ID,
	Semester,
	Mode_of_Service,
	COUNT(Service_Description) OVER (PARTITION BY Student_ID, Semester) AS Cross_Platform,
	COUNT(Service_Description) AS Tutoring_Uses
FROM dbo.['2021_22_Tutoring_Services_Data$']
GROUP BY Student_ID, 
	Mode_of_Service,
	Service_Description,
	Semester
ORDER BY Semester, Cross_Platform DESC

--DB 2, Out of the students who studied How many of them al recived tutoring

SELECT Student_ID, Service_Description
FROM dbo.['2021_22_Tutoring_Services_Data$']
WHERE Service_Description IN ('Study - Room 2401')

--DB-3 Cross subject usage (students who used tutoring service for two or more courses) and courses linked to those uses

SELECT
	DISTINCT 
	Student_ID,
	COUNT(Course_Name) OVER (PARTITION BY Semester, Student_ID, Mode_of_Service) AS Cross_Subject,
	Semester,
	Subject_Name, 
	Course_Description,
	Course_Name,
	COUNT(Service_Description) AS Tutoring_Uses,
	Mode_of_Service
FROM dbo.['2021_22_Tutoring_Services_Data$']
WHERE Subject_Name != 'NULL'
GROUP BY Student_ID, 
	Subject_Name, 
	Course_Name, 
	Course_Description,
	Semester,
	Mode_of_Service
ORDER BY Semester, 
	Cross_Subject DESC, 
	Student_ID 

--DB 4 Gaanular Retention subject data
	
WITH
Student_Sequence_b AS (

SELECT DISTINCT
	Date,
	Start_Time,
	Semester,
	Week,
	Day,
	Student_ID,
	Subject_Name,
	Course_Name, 
	Course_Description,
	ROW_NUMBER() OVER (PARTITION BY student_ID, Subject_Name,
		Course_Name, Semester ORDER BY Date ASC) AS Student_Use_Sequence,
	LAG(Start_Time) OVER (PARTITION BY Student_ID 
		ORDER BY Date ASC) AS Pervious_Use_Date,
	Mode_of_Service,
	Service_Description,
	Duration_Hours
FROM [dbo].['2021_22_Tutoring_Services_Data$']
WHERE Subject_Name != 'NULL'
GROUP BY Date, 
	Semester,
	Week,
	Day,
	Start_Time,
	Student_ID,
	Subject_Name,
	Course_Name,
	Course_Description,
	Service_Description, 
	Mode_of_Service,
	Duration_Hours)


SELECT DISTINCT
	Date,
	Start_Time,
	Semester,
	Week,
	Day,
	Student_ID,
	Subject_Name,
	Course_Name, 
	Course_Description,
	CASE
		WHEN Student_Use_Sequence = 1 THEN 'First Visit'
		WHEN Student_Use_Sequence = 2 THEN 'Second Visit'
		WHEN Student_Use_Sequence Between 3 AND 5 THEN '3rd-5th Visit'
		ELSE 'Other Visit'
		END AS Student_Life_Cycle,
	Student_Use_Sequence,
	Mode_of_Service,
	Service_Description,
	Duration_Hours,
	Pervious_Use_Date
FROM Student_Sequence_b
ORDER BY Semester, Student_ID


--DB 4 Service Count data

WITH Subject_Service_Cnt AS (
SELECT
	Date,
	Start_Time,
	Semester,
	Student_ID,
	Subject_Name,
	Course_Name,
	Course_Description,
	Mode_of_Service,
	COUNT(Subject_Name) OVER(PARTITION BY Student_ID, Semester, Mode_of_Service, Course_Name) AS Subject_Cnt,
	Service_Description,
	COUNT(Service_Description) OVER (PARTITION BY Student_ID, Semester, Mode_of_Service, Course_Name, Service_Description) AS Service_Cnt
	--ROW_NUMBER() OVER (PARTITION BY Student_ID, 
	--	Semester, Mode_of_Service, Course_Name, Service_Description ORDER BY Student_ID) AS Ser
FROM F21_SP22_Penji_Data
WHERE Service_Description !='Study - Room 2401'
--ORDER BY Semester, Mode_of_Service, Course_Name 
),

Service_Cnt AS (
SELECT DISTINCT 
	Semester,
	Student_ID,
	Subject_Name,
	Course_Name,
	Course_Description,
	Mode_of_Service,
	Subject_Cnt,
	CASE 
		WHEN Subject_Cnt = 1 THEN 'First Visit'
		WHEN Subject_Cnt = 2 THEN 'Second Visit'
		WHEN Subject_Cnt Between 3 AND 5 THEN '3rd-5th Visit'
		ELSE 'Other Visit' 
	END AS Student_Life_Cycle,
	Service_Description,
	Service_Cnt
FROM Subject_Service_Cnt
ORDER BY Student_ID, Semester, Subject_Name, Course_Name, Mode_of_Service, Service_Description 
)


--DB 5 Final

--Student usage catregory Donut Charts

WITH Student_Tbl AS (

SELECT DISTINCT
	Date,
	Start_Time,
	Semester,
	Week,
	Day,
	Student_ID,
	Service_Description,
	Subject_Name,
	Course_Name, 
	Course_Description,
	CASE 
		WHEN Service_Description = 'Study - Room 2401' THEN 'A'
		ELSE 'B'
	END AS Service_Code,
	Mode_of_Service,
	Duration_Hours
FROM [dbo].['2021_22_Tutoring_Services_Data$']
GROUP BY Date, 
	Semester,
	Week,
	Day,
	Start_Time,
	Student_ID,
	Service_Description,
	Subject_Name,
	Course_Name,
	Course_Description,
	Mode_of_Service,
	Duration_Hours),

Student_Service_Cnt AS (
SELECT DISTINCT
	Student_ID,
	Semester,
	Service_Code,
	COUNT(DISTINCT Service_Code) AS Service_Cnt
FROM Student_Tbl
GROUP BY Student_ID, Service_Code, Semester
),

Stu_Ser AS (

SELECT Student_ID, Semester, Service_Code, Service_Cnt
FROM Student_Service_Cnt
 ),

 STU AS (
SELECT Student_ID, Semester, Service_Code, SUM(Service_Cnt) OVER (PARTITION BY Student_ID, Semester) AS Service_Count
FROM Stu_Ser
),

T1 AS (
SELECT Student_ID, Semester, Service_Code, Service_Count, CONCAT(Service_Code, Service_Count) AS h
FROM STU
),

STU_Final AS (
SELECT DISTINCT T1.Student_ID, T1.Semester,
CASE
	WHEN h = 'A2' OR h = 'B2' THEN 'Studying and Tutoring'
	WHEN h = 'B1' THEN 'Only Tutoring'
	ELSE 'Only Studying'
	END AS Service_Use_Description
FROM T1
)

--Creating table to place category data

SELECT Semester, Student_ID, Service_Use_Description INTO Student_Use_Categories
FROM STU_Final
ORDER BY Semester, Service_Use_Description, Student_ID


--Final Penji categorized dataset - Uses Donut chart 

SELECT DISTINCT 
	t1.Semester,
	t2.Week,
	t2.Day,
	t1.Student_ID,
	t1.Service_Use_Description,
	t2.Service_Used, 
	t2.Mode_of_Service, 
	t2.Service_Description,
	t2.Subject_Name,
	t2.Course_Name,
	t2.Course_Description,
	t2.Organization_Description,
	t2.Duration_Hours,
	t2.Date,
	t2.Start_Time
INTO F21_SP22_Penji_Student_Data
FROM Student_Use_Categories AS t1 INNER JOIN F21_SP22_Penji_Data AS t2 ON t1.Student_ID = t2.Student_ID AND t1.Semester = t2.Semester
ORDER BY t1.Semester, t1.Student_ID


--DB 5 - Final First impression data


WITH Service_Num1 AS (
SELECT
	Date, 
	Semester, 
	Student_ID, 
	Service_Use_Description, 
	Service_Used, 
	Mode_of_Service, 
	Service_Description,
	ROW_NUMBER() OVER (PARTITION BY Student_ID, Semester ORDER BY Student_ID) AS Service_Num,
	Subject_Name, 
	Course_Name, 
	Course_Description, 
	Duration_Hours
FROM F21_SP22_Penji_Student_Data
)

SELECT 
	Date, 
	Semester, 
	Student_ID, 
	Service_Use_Description, 
	Service_Used, 
	Mode_of_Service, 
	Service_Description,
	Service_Num,
	CASE 
		WHEN Service_Num = 1 THEN 'First Visit'
		WHEN Service_Num = 2 THEN 'Second Visit'
		WHEN Service_Num Between 3 AND 5 THEN '3rd-5th Visit'
		ELSE 'Other Visit' 
	END AS Tutoring_Retention_Rate,
	Subject_Name, 
	Course_Name, 
	Course_Description, 
	Duration_Hours
FROM Service_Num1 
WHERE Service_Num = 1 
ORDER BY Semester, Student_ID


--DB 5 - Final first tutoring usage data (Specifically for Studying and tutoring)

WITH Service_Num AS (
SELECT
	Date, 
	Semester, 
	Student_ID, 
	Service_Use_Description, 
	Service_Used, 
	Mode_of_Service, 
	Service_Description,
	ROW_NUMBER() OVER (PARTITION BY Student_ID, Semester ORDER BY Student_ID) AS Service_Num,
	Subject_Name, 
	Course_Name, 
	Course_Description, 
	Duration_Hours
FROM F21_SP22_Penji_Student_Data
WHERE Service_Use_Description = 'Studying and Tutoring'),

Service_NumA AS (
SELECT 
	Date, 
	Semester, 
	Student_ID, 
	Service_Use_Description, 
	Service_Used, 
	Mode_of_Service, 
	Service_Description,
	Service_Num,
	Subject_Name, 
	Course_Name, 
	Course_Description, 
	Duration_Hours
FROM Service_Num
WHERE Service_Used = 'Tutoring'),

Service_NumB AS (
SELECT 
	Date, 
	Semester, 
	Student_ID, 
	Service_Use_Description, 
	Service_Used, 
	Mode_of_Service, 
	Service_Description,
	Service_Num,
	ROW_NUMBER() OVER (PARTITION BY Student_ID, Semester ORDER BY Student_ID) AS Tutoring_Num,
	Subject_Name, 
	Course_Name, 
	Course_Description, 
	Duration_Hours
FROM Service_NumA)

SELECT 
	Date, 
	Semester, 
	Student_ID, 
	Service_Use_Description, 
	Service_Used, 
	Mode_of_Service, 
	Service_Description,
	Service_Num,
	CASE 
		WHEN Service_Num = 1 THEN 'First Visit'
		WHEN Service_Num = 2 THEN 'Second Visit'
		WHEN Service_Num Between 3 AND 5 THEN '3rd-5th Visit'
		ELSE 'Other Visit' 
	END AS Tutoring_Retention_Rate,
	Tutoring_Num,
	Subject_Name, 
	Course_Name, 
	Course_Description, 
	Duration_Hours
FROM Service_NumB
WHERE Tutoring_Num = 1 
