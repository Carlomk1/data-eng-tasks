-- Operational job data table:

CREATE TABLE operational_xml_stage1 (
    job_id INT,
    title NVARCHAR(255),
    firstseen NVARCHAR(50),
    lastseen NVARCHAR(50),
    cmp_id INT,
    mcg_job_id INT
);

-- Stage 1 tables:

CREATE TABLE X28_Companies_stage1 (
    Firma NVARCHAR(255),
    Firma_lower NVARCHAR(255),
    cmp_id BIGINT,
    Kienbaum_ID INT,
    Homepage NVARCHAR(255)
);

CREATE TABLE X28_Functions_stage1 (
    [function] NVARCHAR(255),
    position NVARCHAR(255),
    job_id_x28 BIGINT,
    job_name_x28 NVARCHAR(255)
);

CREATE TABLE tp_companies_sectors_stage1 (
    company NVARCHAR(255),
    sector_sort INT,
    sector NVARCHAR(255),
    company_id INT,
    last_updated DATETIME,
    sector_EN NVARCHAR(255),
    sector_FR NVARCHAR(255),
    websites NVARCHAR(255)
);

CREATE TABLE tp_sectors_functions_stage1 (
    sector NVARCHAR(255),
    [function] NVARCHAR(255),
    branche_order NVARCHAR(255),
    tool_tip_text NVARCHAR(MAX),
    sector_en NVARCHAR(255),
    function_en NVARCHAR(255),
    branche_order_en NVARCHAR(255),
    tool_tip_text_en NVARCHAR(MAX),
    sector_fr NVARCHAR(255),
    function_fr NVARCHAR(255),
    branche_order_fr NVARCHAR(255),
    tool_tip_text_fr NVARCHAR(MAX)
);

-- Stage 2 tables:

CREATE TABLE dbo.operational_xml_stage2 (
    job_id INT,
    title NVARCHAR(255),
    cmp_id INT,
    mcg_job_id INT,
    first_clean DATE,
    last_clean DATE,
    days_open INT,
    weeks_open INT
);


CREATE TABLE [dbo].[X28_Companies_stage2] (
    Firma NVARCHAR(255),
    cmp_id BIGINT,
    Kienbaum_ID INT
);

CREATE TABLE tp_companies_sectors_stage2 (
    company NVARCHAR(255),
    sector NVARCHAR(255),
    company_id INT
);


CREATE TABLE dbo.X28_Functions_stage2 (
    [function] NVARCHAR(255),
    job_id_x28 INT,
    job_name_x28 NVARCHAR(255)
);

-- Final table:

CREATE TABLE dbo.t_x28_jobs_store (
    mcg_job_id INT,
    weeks_open INT,
    company NVARCHAR(255),
    sector NVARCHAR(255),
    [function] NVARCHAR(255)
);
