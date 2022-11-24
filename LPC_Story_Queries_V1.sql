--DB 1 New Dendrogram Chart 
--Main query (CTE) numbers the rows by the diffrent service students used by semester and Mode of service
--Subquery selects the distinct max usage of each service per student per semester

WITH Student_Sequence AS (
SELECT DISTINCT
	Semester,
	Student_ID,
	Mode_of_Service,
	Service_Description,
	ROW_NUMBER() OVER (PARTITION BY student_ID, Mode_of_Service,
		Service_Description, Semester ORDER BY Date ASC) AS Student_Platform_Sequence
FROM [dbo].['2021_22_Tutoring_Services_Data$']
GROUP BY 
	Date, 
	Semester, 
	Student_ID, 
	Service_Description, 
	Mode_of_Service)

SELECT DISTINCT 
	Student_ID, 
	Semester, 
	Mode_of_Service, 
	Service_Description, 
	Max(Student_Platform_Sequence) OVER (PARTITION BY Student_ID, Semester,
		Mode_of_Service, Service_Description) AS Max_Platform_Usage
FROM Student_Sequence
GROUP BY
	Student_ID, 
	Semester, 
	Mode_of_Service, 
	Service_Description,
	Student_Platform_Sequence;

--DB 1 Avg Time Donut 
--Main Query (CTE) Numbers all student Tutorial Center Visits with Row_Number
--Subquery Uses case statment to describe each visit (Data feild "Student_Retenion_Rate" will filter Bar chart)
--Student retention by retention status, that is, Used tutoring once, twice...
--Each semester students are seen as a "new user" which categories them as "used once" restarting usage trends
 --(Granular to account for durations of all uses)

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
	Duration_Hours)

SELECT DISTINCT
	Date,
	Start_Time,
	Semester,
	Week,
	Day,
	Student_ID,
	Mode_of_Service,
	Service_Description,
	Student_Platform_Sequence,
	CASE
		WHEN Student_Platform_Sequence = 1 THEN 'Used Once'
		WHEN Student_Platform_Sequence = 2 THEN 'Used Twice'
		WHEN Student_Platform_Sequence Between 3 AND 5 THEN 'Used 3 to 5 Times'
		WHEN Student_Platform_Sequence BETWEEN 6 and 10 THEN 'Used More Than 5 Times'
		ELSE 'Used More Than 10 Times'
		END AS Student_Retenion_Rate,
	Subject_Name,
	Course_Name, 
	Course_Description,
	Duration_Hours
FROM Student_Sequence
ORDER BY Student_ID;


--DB 1 - Student Retention by distinct cohorts (Bar Chart)
--First CTE numbers Tutorial Center Visits
--Second CTE Pulls the max visit status by the partition
--Last subquery uses case statment to lable distinct retention cohorts
--Only the max usage trends are kept, all "used once" only used that service for a...
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
ORDER BY Semester, Student_ID, Service_Description;


--DB 2 Cross platform with study data (Bubble chart and Bar chart)
--Query counts the total number of different services a student has used "Cross_Platform"
--Also counts total visits her service description per studnet "Tutoring_Uses"

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
ORDER BY Semester, Cross_Platform DESC;


--DB 5 Student usage catregories (Student Engagment) Donut Chart
--First CTE describes each visit as study (A) or Tuoring (B) with case statment
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

--Subquery counts each A or B as 1, denoting one type of service used "Service_Cnt_1"
Student_Service_Cnt AS (
SELECT DISTINCT
	Student_ID,
	Semester,
	Service_Code,
	COUNT(DISTINCT Service_Code) AS Service_Cnt_1
FROM Student_Tbl
GROUP BY Student_ID, Service_Code, Semester
),
--Subquery Counts how many services students have used per semester "Service_Cnt_2"
Student_Service_Cnt2 AS (
SELECT Student_ID, Semester, Service_Code, SUM(Service_Cnt_1) OVER (PARTITION BY Student_ID, Semester) AS Service_Cnt_2
FROM Student_Service_Cnt
),
--Subquery combines Service letter "Service_Code" and the count of service use "Service_Cnt_2" ...
--to isolate those who only studied(A1) or only used tutoring (B1)
T1 AS (
SELECT Student_ID, Semester, Service_Code, Service_Cnt_2, CONCAT(Service_Code, Service_Cnt_2) AS Service_Status
FROM Student_Service_Cnt2
),
--Query describes teh service stauts of each student using a case statment as...
--It is known "A1" means study and only used one service and "B1" Is used tutoring and only one service
STU_Final AS (
SELECT DISTINCT T1.Student_ID, T1.Semester,
CASE
	WHEN Service_Status = 'A2' OR Service_Status = 'B2' THEN 'Studying and Tutoring'
	WHEN Service_Status = 'B1' THEN 'Only Tutoring'
	ELSE 'Only Studying'
	END AS Service_Use_Description
FROM T1
)

--Creating table "Student_Use_Categories" to place category data to then join to original data set to gather granular tutoring data

SELECT Semester, Student_ID, Service_Use_Description INTO Student_Use_Categories
FROM STU_Final
ORDER BY Semester, Service_Use_Description, Student_ID;


--Newly categorized student table "t1" joined to original data set "t2" to obtain all data per student

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
ORDER BY t1.Semester, t1.Student_ID;


--DB 5 - Final First impression data
--Query numbers each use as "Service_Num"
WITH Student_Service_Number AS (
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
--Subquery obtains first use data (only where service_Num = 1 is filtered) case statement describes the visit
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
FROM Student_Service_Number
WHERE Service_Num = 1 
ORDER BY Semester, Student_ID;


--DB 3 - First impression tutoring usage data (Specifically for Studying and tutoring)
--CTE counts each visit only for the cohort of students that studied and tutored (where clause)
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
--Subquery Isolates tutoring uses of those students who studied and used tutoring with where clause
Service_Num_A AS (
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
--Subquery re-numbers the isolated tutoring uses as "Tutoring_Num" which represents...
--when the students used tutoring out of all thier visits
Service_Num_B AS (
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
FROM Service_Num_A)
--Final query Describes the visit status as "Tutoring_Retention_Rate" and isolates (where clause) only...
---the first tutoring uses to identify if students are delaying reciving tutoring
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
FROM Service_Num_B
WHERE Tutoring_Num = 1 
ORDER BY Semester, Student_ID;


--DB-4 Cross subject usage 
--Query Counts the total subjects a student has gotten tutoring for "Cross_Subject"
--Also counts the total visits per each subject "Tutoring_Uses"
--No subject data avalible for studying therefore NULL values have been excluded
--students who used tutoring service for two or more subjects and courses linked to those uses

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


	
--DB 5 Granular Retention subject data
--CTE numbers each tutoring visit by the partition
--Pervious use can help indeitify how long students wait to return to the tutorial center
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
	Service_Description,
	ROW_NUMBER() OVER (PARTITION BY Student_ID, Mode_of_Service, 
		Course_Name, Semester ORDER BY Course_Name ASC) AS Student_Use_Sequence,
	LAG(Start_Time) OVER (PARTITION BY Student_ID 
		ORDER BY Date ASC) AS Pervious_Use_Date,
	Mode_of_Service,
	Duration_Hours
FROM [dbo].['2021_22_Tutoring_Services_Data$']
WHERE Service_Description != 'Study - Room 2401'
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
--Subquery takes the max usage number per subject to form distinct subject retention cohorts
Distinct_Subject_Use AS (

SELECT DISTINCT
    Date,
	Student_ID,
	Semester,
	Subject_Name,
	Course_Name, 
	Course_Description,
	Mode_of_Service, 
	MAX(Student_Use_Sequence) OVER(PARTITION BY Student_ID, Mode_of_Service,
		Course_Name) AS Dist_Sequence_Cohort
FROM Student_Sequence_b
GROUP BY
	Date,
	Student_ID,
	Semester,
	Subject_Name,
	Course_Name, 
	Course_Description, 
	Student_Use_Sequence,
	Mode_of_Service
	)
--Case statment used to label distinct subject retention based on the number of max visits per subject and course
SELECT 
	Date,
	Student_ID,
	Semester,
	Subject_Name,
	Course_Name, 
	Course_Description,
	Mode_of_Service,
	Dist_Sequence_Cohort,
	CASE 
		WHEN Dist_Sequence_Cohort = 1 THEN 'First Visit'
		WHEN Dist_Sequence_Cohort = 2 THEN 'Second Visit'
		WHEN Dist_Sequence_Cohort Between 3 AND 5 THEN '3rd-5th Visit'
		ELSE 'Other Visit' 
	END AS Subject_Retention
FROM Distinct_Subject_Use
GROUP BY
	Date,
	Student_ID,
	Semester,
	Subject_Name,
	Course_Name, 
	Course_Description, 
	Mode_of_Service,
	Dist_Sequence_Cohort;


--DB 5 Service Count data
--Query counts the total number of visits 
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
FROM F21_SP22_Penji_Data
WHERE Service_Description !='Study - Room 2401'
)
--Case statement used to describe the service use status
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
