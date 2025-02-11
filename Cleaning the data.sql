---DATA CLEANING---
---Identify Duplicates---
SELECT Employee_ID, COUNT(*) 
FROM Employee_Data
GROUP BY Employee_ID
HAVING COUNT(*) > 1;
---Delete Duplicates---
DELETE FROM Employee_Data
WHERE ctid IN (
    SELECT ctid
    FROM (
        SELECT ctid,
               ROW_NUMBER() OVER (PARTITION BY Employee_ID ORDER BY Employee_ID) AS row_num
        FROM Employee_Data
    ) sub
    WHERE row_num > 1
);
---Handling Missing Values---
--Delete the records having more nulls
DELETE FROM Employee_Data
WHERE Job_Satisfaction IS NULL AND Work_Life_Balance IS NULL AND Performance_Rating IS NULL;
---Update Age based on department average for NULL Values---
UPDATE Employee_Data AS e
SET Age = sub.Avg_Age
FROM (
    SELECT Department, ROUND(AVG(Age)) AS Avg_Age
    FROM Employee_Data
    WHERE Age IS NOT NULL
    GROUP BY Department
) AS sub
WHERE e.Age IS NULL
  AND e.Department = sub.Department;
---Udating the Gender,Marital_Status,Department,Job_Role,Overtime to other if it is null else the value will be same 
UPDATE Employee_Data
SET 
    Gender = CASE WHEN Gender IS NULL THEN 'Other' ELSE Gender END,
    Marital_Status = CASE WHEN Marital_Status IS NULL THEN 'Other' ELSE Marital_Status END,
    Department = CASE WHEN Department IS NULL THEN 'Other' ELSE Department END,
    Job_Role = CASE WHEN Job_Role IS NULL THEN 'Other' ELSE Job_Role END,
    Overtime = CASE WHEN Overtime IS NULL THEN 'Other' ELSE Overtime END;
--Update NULLs to 0 in each column
UPDATE Employee_Data
SET 
    Job_Level = COALESCE(Job_Level, 0),
    Years_at_Company = COALESCE(Years_at_Company, 0),
    Years_in_Current_Role = COALESCE(Years_in_Current_Role, 0),
    Years_Since_Last_Promotion = COALESCE(Years_Since_Last_Promotion, 0),
    Training_Hours_Last_Year = COALESCE(Training_Hours_Last_Year, 0),
    Project_Count = COALESCE(Project_Count, 0),
    Absenteeism = COALESCE(Absenteeism, 0),
    Number_of_Companies_Worked = COALESCE(Number_of_Companies_Worked, 0),
	Distance_From_Home = COALESCE(Distance_From_Home, 0)
WHERE 
    Job_Level IS NULL OR 
    Years_at_Company IS NULL OR 
    Years_in_Current_Role IS NULL OR 
    Years_Since_Last_Promotion IS NULL OR 
    Training_Hours_Last_Year IS NULL OR 
    Project_Count IS NULL OR 
    Absenteeism IS NULL OR 
    Number_of_Companies_Worked IS NULL OR
	Distance_From_Home IS NULL;
-- Update NULL Hourly Rate to average values

UPDATE Employee_Data
SET Hourly_Rate = (SELECT round(AVG(Hourly_Rate)) FROM Employee_Data WHERE Hourly_Rate IS NOT NULL)
WHERE Hourly_Rate IS NULL;

--Update the Average_Hours_Worked_Per_Week according to the level
WITH JobLevelAvg AS (
    SELECT Job_Level, round(AVG(Average_Hours_Worked_Per_Week)) AS Avg_Hours
    FROM Employee_Data
    WHERE Average_Hours_Worked_Per_Week IS NOT NULL
    GROUP BY Job_Level
)
UPDATE Employee_Data e
SET Average_Hours_Worked_Per_Week = j.Avg_Hours
FROM JobLevelAvg j
WHERE e.Job_Level = j.Job_Level
  AND e.Average_Hours_Worked_Per_Week IS NULL;

-- Update NULL Monthly Income using Hourly Rate and Average Hours Worked per Week for each record
UPDATE Employee_Data
SET Monthly_Income = Hourly_Rate * Average_Hours_Worked_Per_Week * 4
WHERE Monthly_Income IS NULL;

-- Replace NULL values in Work_Life_Balance with the average of the existing values
UPDATE Employee_Data
SET Work_Life_Balance = (SELECT round(AVG(Work_Life_Balance)) FROM Employee_Data WHERE Work_Life_Balance IS NOT NULL)
WHERE Work_Life_Balance IS NULL;

-- Update the Job_Satisfaction with the average value per Job_Role for NULL values
WITH AvgJobSatisfaction AS (
    SELECT Job_Role, round(AVG(Job_Satisfaction)) AS avg_satisfaction
    FROM Employee_Data
    WHERE Job_Satisfaction IS NOT NULL
    GROUP BY Job_Role
)
UPDATE Employee_Data
SET Job_Satisfaction = AvgJobSatisfaction.avg_satisfaction
FROM AvgJobSatisfaction
WHERE Employee_Data.Job_Role = AvgJobSatisfaction.Job_Role
  AND Employee_Data.Job_Satisfaction IS NULL;
--Performance rating based on job role
WITH ModePerformanceRating AS (
    SELECT Job_Role, Performance_Rating, COUNT(*) AS rating_count
    FROM Employee_Data
    WHERE Performance_Rating IS NOT NULL
    GROUP BY Job_Role, Performance_Rating
    HAVING COUNT(*) = (
        SELECT MAX(rating_count) FROM (
            SELECT COUNT(*) AS rating_count
            FROM Employee_Data
            WHERE Performance_Rating IS NOT NULL
            GROUP BY Job_Role, Performance_Rating
        ) AS InnerQuery
    )
)
UPDATE Employee_Data
SET Performance_Rating = ModePerformanceRating.Performance_Rating
FROM ModePerformanceRating
WHERE Employee_Data.Job_Role = ModePerformanceRating.Job_Role
  AND Employee_Data.Performance_Rating IS NULL;
--Work Environment Satisfaction
WITH WeightedAvgWorkEnvSatisfaction AS (
    SELECT Job_Role, Job_Level, round(AVG(Work_Environment_Satisfaction)) AS weighted_avg_satisfaction
    FROM Employee_Data
    WHERE Work_Environment_Satisfaction IS NOT NULL
    GROUP BY Job_Role, Job_Level
)
UPDATE Employee_Data
SET Work_Environment_Satisfaction = WeightedAvgWorkEnvSatisfaction.weighted_avg_satisfaction
FROM WeightedAvgWorkEnvSatisfaction
WHERE Employee_Data.Job_Role = WeightedAvgWorkEnvSatisfaction.Job_Role
  AND Employee_Data.Job_Level = WeightedAvgWorkEnvSatisfaction.Job_Level
  AND Employee_Data.Work_Environment_Satisfaction IS NULL;
--- Relationship with manager based on department
-- Step 1: Calculate the mode (most frequent) 'Relationship_with_Manager' for each 'Department'
WITH RankedRelationship AS (
    SELECT 
        Department, 
        Relationship_with_Manager,
        COUNT(*) AS relationship_count,
        ROW_NUMBER() OVER (PARTITION BY Department ORDER BY COUNT(*) DESC) AS rn
    FROM Employee_Data
    WHERE Relationship_with_Manager IS NOT NULL
    GROUP BY Department, Relationship_with_Manager
)
-- Step 2: Select only the mode (most frequent) for each department
, ModeRelationshipByDept AS (
    SELECT Department, Relationship_with_Manager
    FROM RankedRelationship
    WHERE rn = 1
)
-- Step 3: Update 'Relationship_with_Manager' where it's NULL
UPDATE Employee_Data
SET Relationship_with_Manager = ModeRelationshipByDept.Relationship_with_Manager
FROM ModeRelationshipByDept
WHERE Employee_Data.Department = ModeRelationshipByDept.Department
  AND Employee_Data.Relationship_with_Manager IS NULL;



---- JobInvolvement


WITH RankedJobInvolvement AS (
    SELECT 
        Job_Level, 
        Job_Involvement, 
        COUNT(*) AS involvement_count,
        ROW_NUMBER() OVER (PARTITION BY Job_Level ORDER BY COUNT(*) DESC) AS rn
    FROM Employee_Data
    WHERE Job_Involvement IS NOT NULL
    GROUP BY Job_Level, Job_Involvement
)
, ModeJobInvolvement AS (
    SELECT Job_Level, Job_Involvement
    FROM RankedJobInvolvement
    WHERE rn = 1  -- Select the mode (most frequent value)
)
UPDATE Employee_Data
SET Job_Involvement = ModeJobInvolvement.Job_Involvement
FROM ModeJobInvolvement
WHERE Employee_Data.Job_Level = ModeJobInvolvement.Job_Level
  AND Employee_Data.Job_Involvement IS NULL;

--Udating the attrition rate
UPDATE Employee_Data
SET Attrition = CASE
    WHEN Attrition IS NULL AND Job_Satisfaction < 3 THEN 1  -- Assume attrition if job satisfaction is low
    WHEN Attrition IS NULL AND Years_at_Company > 5 THEN 0  -- Assume no attrition if they have been with the company for a long time
    ELSE 0  -- Default to no attrition for others
END
WHERE Attrition IS NULL;

--Standardize Categorical Values doesn’t have inconsistent values like Sales, sales,
UPDATE Employee_Data
SET Department = INITCAP(Department);
UPDATE Employee_Data
SET Gender = INITCAP(Gender);
UPDATE Employee_Data
SET Marital_Status = INITCAP(Marital_Status);
UPDATE Employee_Data
SET Job_Role = INITCAP(Job_Role);
UPDATE Employee_Data
SET Overtime = INITCAP(Overtime);
--Remove unnecessary spaces in text fields.
UPDATE Employee_Data
SET Department = Trim(Department);
UPDATE Employee_Data
SET Gender = Trim(Gender);
UPDATE Employee_Data
SET Marital_Status = Trim(Marital_Status);
UPDATE Employee_Data
SET Job_Role = Trim(Job_Role);
UPDATE Employee_Data
SET Overtime = Trim(Overtime);
--Check for Invalid Values
SELECT * 
FROM Employee_Data
WHERE Monthly_Income < 0 
   OR Average_Hours_Worked_Per_Week > 168;
-- HANDLING OUTLIERS
WITH Income_Stats AS (
    SELECT 
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY Monthly_Income) AS Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY Monthly_Income) AS Q3
    FROM Employee_Data
),
Bounds AS (
    SELECT 
        (Q1 - 1.5 * (Q3 - Q1)) AS Lower_Bound,
        (Q3 + 1.5 * (Q3 - Q1)) AS Upper_Bound
    FROM Income_Stats
)
UPDATE Employee_Data
SET Monthly_Income = 
    CASE
        WHEN Monthly_Income < (SELECT Lower_Bound FROM Bounds) THEN (SELECT Lower_Bound FROM Bounds)
        WHEN Monthly_Income > (SELECT Upper_Bound FROM Bounds) THEN (SELECT Upper_Bound FROM Bounds)
        ELSE Monthly_Income
    END;
--Creation of Cleaned data view
CREATE VIEW Cleaned_Employee_Data AS
SELECT * FROM Employee_Data
WHERE Attrition IS NOT NULL;
select * from Cleaned_Employee_Data;