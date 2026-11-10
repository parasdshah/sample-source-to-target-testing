-- Target model (HR_DW schema). Fictional. Merges two HRMS systems (HRA01, HRB02).
CREATE TABLE HR_DW.DIM_ENTITY (                     -- SCD type 1; ONE level (legal entity)
    ENTITY_SK              BIGINT        NOT NULL,   -- surrogate key
    ENTITY_CD              VARCHAR(12)   NOT NULL,   -- business key (source prefixed until the group crosswalk exists)
    ENTITY_NM              VARCHAR(80)   NOT NULL,
    COUNTRY_CD             CHAR(2)       NOT NULL,   -- ISO 3166 alpha-2
    FUNCTIONAL_CCY_CD      CHAR(3)       NOT NULL,   -- ISO 4217
    ACTIVE_FLG             CHAR(1)       NOT NULL,   -- Y/N
    SRC_SYSTEM_CD          VARCHAR(10)   NOT NULL,
    BATCH_ID               BIGINT        NOT NULL,
    LOAD_TS                TIMESTAMP     NOT NULL,
    CONSTRAINT PK_DIM_ENTITY PRIMARY KEY (ENTITY_SK)
);

CREATE TABLE HR_DW.DIM_DEPARTMENT (                 -- SCD type 1; THREE levels, grain = level-3 unit
    DEPARTMENT_SK          BIGINT        NOT NULL,
    DEPARTMENT_KEY         VARCHAR(30)   NOT NULL,   -- business key, source prefixed
    DEPT_L1_CD             VARCHAR(10)   NOT NULL,   -- level 1 = division
    DEPT_L1_NM             VARCHAR(80)   NOT NULL,
    DEPT_L2_CD             VARCHAR(10)   NOT NULL,   -- level 2 = department
    DEPT_L2_NM             VARCHAR(80)   NOT NULL,
    DEPT_L3_CD             VARCHAR(10)   NOT NULL,   -- level 3 = team (filled down when the source has fewer levels)
    DEPT_L3_NM             VARCHAR(80)   NOT NULL,
    ACTIVE_FLG             CHAR(1)       NOT NULL,   -- Y/N
    SRC_SYSTEM_CD          VARCHAR(10)   NOT NULL,
    BATCH_ID               BIGINT        NOT NULL,
    LOAD_TS                TIMESTAMP     NOT NULL,
    CONSTRAINT PK_DIM_DEPARTMENT PRIMARY KEY (DEPARTMENT_SK)
);

CREATE TABLE HR_DW.DIM_REGION (                     -- SCD type 1; FIVE levels, grain = city
    REGION_SK              BIGINT        NOT NULL,
    REGION_KEY             VARCHAR(250)  NOT NULL,   -- business key = UPPER(country code|L2|L5)
    COUNTRY_CD             CHAR(2)       NOT NULL,   -- ISO 3166 alpha-2
    REGION_L1_NM           VARCHAR(60)   NOT NULL,   -- country name
    REGION_L2_NM           VARCHAR(60)   NOT NULL,   -- state or province
    REGION_L3_NM           VARCHAR(60)   NOT NULL,   -- district or county
    REGION_L4_NM           VARCHAR(60)   NOT NULL,   -- metro area or sub-region
    REGION_L5_NM           VARCHAR(60)   NOT NULL,   -- city
    ACTIVE_FLG             CHAR(1)       NOT NULL,   -- Y/N
    SRC_SYSTEM_CD          VARCHAR(10)   NOT NULL,
    BATCH_ID               BIGINT        NOT NULL,
    LOAD_TS                TIMESTAMP     NOT NULL,
    CONSTRAINT PK_DIM_REGION PRIMARY KEY (REGION_SK)
);

CREATE TABLE HR_DW.DIM_PERSON (                     -- SCD type 1; one row per REAL person (golden record)
    PERSON_SK              BIGINT        NOT NULL,
    GLOBAL_PERSON_ID       VARCHAR(12)   NOT NULL,   -- business key, group-wide, 'P' + 10 digits
    FIRST_NM               VARCHAR(50)   NOT NULL,
    LAST_NM                VARCHAR(50)   NOT NULL,
    FULL_NM                VARCHAR(101)  NOT NULL,
    BIRTH_DT               DATE          NULL,
    GENDER_CD              VARCHAR(7)    NOT NULL,   -- MALE, FEMALE, OTHER, UNKNOWN
    NATIONAL_ID_TYPE_CD    VARCHAR(11)   NULL,       -- NATIONAL_ID, TAX_ID, PASSPORT, OTHER
    NATIONAL_ID_HASH       CHAR(64)      NULL,       -- salted SHA-256 of the normalised number; the number itself is NOT stored
    WORK_EMAIL             VARCHAR(100)  NULL,       -- lower case
    FIRST_HIRE_DT          DATE          NOT NULL,   -- earliest hire date over all linked employments
    ACTIVE_EMPLOYMENT_FLG  CHAR(1)       NOT NULL,   -- Y when any linked employment is active
    SOURCE_RECORD_CNT      SMALLINT      NOT NULL,   -- number of source employee records merged into this person
    MERGE_RULE_CD          VARCHAR(12)   NOT NULL,   -- SINGLE, NATID_DOB, LINK_KEY, STEWARD
    RETENTION_END_DT       DATE          NULL,       -- NULL while any employment is active
    SRC_SYSTEM_CD          VARCHAR(10)   NOT NULL,   -- system of the surviving record
    BATCH_ID               BIGINT        NOT NULL,
    LOAD_TS                TIMESTAMP     NOT NULL,
    CONSTRAINT PK_DIM_PERSON PRIMARY KEY (PERSON_SK)
);

CREATE TABLE HR_DW.FACT_EMPLOYMENT (                -- upsert on EMPLOYMENT_KEY; one row per source employee record
    EMPLOYMENT_SK          BIGINT        NOT NULL,
    EMPLOYMENT_KEY         VARCHAR(30)   NOT NULL,   -- business key, source prefixed
    PERSON_SK              BIGINT        NOT NULL,   -- FK to DIM_PERSON
    ENTITY_SK              BIGINT        NOT NULL,   -- FK to DIM_ENTITY (hiring entity)
    HIRE_DT                DATE          NOT NULL,
    TERMINATION_DT         DATE          NULL,       -- NULL = still employed
    TERMINATION_REASON_CD  VARCHAR(18)   NULL,       -- RESIGNED, RETIRED, TERMINATED, DECEASED, CONTRACT_END, INTERNAL_TRANSFER, REGION_TRANSFER, UNKNOWN
    EMPLOYMENT_STATUS_CD   VARCHAR(10)   NOT NULL,   -- ACTIVE, ON_LEAVE, SUSPENDED, TERMINATED, UNKNOWN
    PREVIOUS_EMPLOYMENT_SK BIGINT        NULL,       -- employment this record continues or follows
    DUPLICATE_REASON_CD    VARCHAR(12)   NULL,       -- DEPT_CHANGE, REGION_CHANGE, ACQ_REJOIN, REHIRE; NULL = not a duplicate record
    SERVICE_START_DT       DATE          NOT NULL,   -- start of continuous service
    SRC_LAST_UPD_TS_UTC    TIMESTAMP     NOT NULL,
    SRC_SYSTEM_CD          VARCHAR(10)   NOT NULL,
    BATCH_ID               BIGINT        NOT NULL,
    LOAD_TS                TIMESTAMP     NOT NULL,
    CONSTRAINT PK_FACT_EMPLOYMENT PRIMARY KEY (EMPLOYMENT_SK)
);

CREATE TABLE HR_DW.FACT_ASSIGNMENT (                -- one row per effective-dated assignment period; history kept for 15+ years
    ASSIGNMENT_SK          BIGINT        NOT NULL,
    EMPLOYMENT_SK          BIGINT        NOT NULL,   -- FK to FACT_EMPLOYMENT
    EFFECTIVE_FROM_DT      DATE          NOT NULL,
    EFFECTIVE_TO_DT        DATE          NOT NULL,   -- inclusive; 9999-12-31 = open
    CURRENT_FLG            CHAR(1)       NOT NULL,   -- Y when EFFECTIVE_TO_DT = 9999-12-31
    ENTITY_SK              BIGINT        NOT NULL,   -- FK to DIM_ENTITY (entity of the assignment)
    DEPARTMENT_SK          BIGINT        NOT NULL,   -- FK to DIM_DEPARTMENT
    REGION_SK              BIGINT        NOT NULL,   -- FK to DIM_REGION
    JOB_TITLE              VARCHAR(80)   NULL,
    GRADE_CD               VARCHAR(7)    NOT NULL,   -- GR1..GR6, UNKNOWN
    MANAGER_PERSON_SK      BIGINT        NULL,       -- FK to DIM_PERSON
    FTE_RATIO              DECIMAL(4,3)  NOT NULL,   -- 0.000 to 1.000
    ASSIGNMENT_REASON_CD   VARCHAR(13)   NOT NULL,   -- HIRE, PROMOTION, TRANSFER, DEPT_CHANGE, REGION_CHANGE, TERMINATION, OTHER, UNKNOWN
    SRC_SYSTEM_CD          VARCHAR(10)   NOT NULL,
    BATCH_ID               BIGINT        NOT NULL,
    LOAD_TS                TIMESTAMP     NOT NULL,
    CONSTRAINT PK_FACT_ASSIGNMENT PRIMARY KEY (ASSIGNMENT_SK)
);

CREATE TABLE HR_DW.XREF_PERSON_SOURCE (             -- crosswalk: which source records make up which person
    XREF_SK                BIGINT        NOT NULL,
    PERSON_SK              BIGINT        NOT NULL,   -- FK to DIM_PERSON
    SRC_SYSTEM_CD          VARCHAR(10)   NOT NULL,   -- HRA01 or HRB02
    SRC_REGION_CD          VARCHAR(4)    NULL,       -- HRB02 only (management region)
    SRC_PERSON_KEY         VARCHAR(10)   NOT NULL,   -- EMP_ID (HRA01) or PERSON_NO (HRB02)
    MATCH_RULE_CD          VARCHAR(12)   NOT NULL,   -- SINGLE, NATID_DOB, LINK_KEY, STEWARD
    MATCH_SCORE            DECIMAL(5,2)  NOT NULL,   -- 0 to 100
    MATCH_STATUS_CD        VARCHAR(10)   NOT NULL,   -- AUTO, CONFIRMED, REVIEW
    SURVIVOR_FLG           CHAR(1)       NOT NULL,   -- Y for the record that supplied the surviving name and email
    BATCH_ID               BIGINT        NOT NULL,
    LOAD_TS                TIMESTAMP     NOT NULL,
    CONSTRAINT PK_XREF_PERSON_SOURCE PRIMARY KEY (XREF_SK)
);
