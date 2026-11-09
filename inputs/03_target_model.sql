-- Target model (DW schema). Fictional.
CREATE TABLE DW.DIM_CUSTOMER (
    CUSTOMER_SK            BIGINT        NOT NULL,   -- surrogate key (system generated)
    CUSTOMER_ID            VARCHAR(10)   NOT NULL,   -- business key
    CUSTOMER_NAME          VARCHAR(100)  NOT NULL,
    CUSTOMER_TYPE_CD       VARCHAR(3)    NOT NULL,   -- IND, CRP, UNK
    CUSTOMER_SEGMENT_CD    VARCHAR(5)    NOT NULL,   -- MASS, AFFL, PRIV, SME, CORP
    BIRTH_DT               DATE          NULL,
    COUNTRY_CD             CHAR(2)       NOT NULL,   -- ISO 3166-1 alpha-2
    MOBILE_NO              VARCHAR(20)   NULL,       -- E.164
    EMAIL_ADDR             VARCHAR(100)  NULL,
    KYC_STATUS_CD          VARCHAR(10)   NOT NULL,   -- VERIFIED, PENDING, REJECTED, UNKNOWN
    HOME_BRANCH_CD         VARCHAR(4)    NOT NULL,
    RELATIONSHIP_MGR_ID    VARCHAR(8)    NULL,
    CUSTOMER_OPEN_DT       DATE          NOT NULL,
    ACTIVE_FLG             CHAR(1)       NOT NULL,   -- Y/N
    EFF_FROM_TS            TIMESTAMP     NOT NULL,   -- SCD2
    EFF_TO_TS              TIMESTAMP     NOT NULL,   -- 9999-12-31 for current
    CURRENT_FLG            CHAR(1)       NOT NULL,
    SRC_SYSTEM_CD          VARCHAR(10)   NOT NULL,
    BATCH_ID               BIGINT        NOT NULL,
    LOAD_TS                TIMESTAMP     NOT NULL,
    CONSTRAINT PK_DIM_CUSTOMER PRIMARY KEY (CUSTOMER_SK)
);

CREATE TABLE DW.DIM_ACCOUNT (                        -- SCD type 1
    ACCOUNT_SK             BIGINT        NOT NULL,
    ACCOUNT_NO             VARCHAR(12)   NOT NULL,   -- business key
    CUSTOMER_SK            BIGINT        NOT NULL,   -- FK to DIM_CUSTOMER (current row at load)
    ACCOUNT_TYPE_CD        VARCHAR(5)    NOT NULL,   -- SAV, CUR, TDP, LON, CCD, OTH
    PRODUCT_CATEGORY_CD    VARCHAR(5)    NOT NULL,   -- DEP, LND, CRD
    OPEN_DT                DATE          NOT NULL,
    CLOSE_DT               DATE          NULL,       -- null while open
    CURRENCY_CD            CHAR(3)       NOT NULL,   -- ISO 4217
    ACCOUNT_STATUS_CD      VARCHAR(10)   NOT NULL,   -- ACTIVE, CLOSED, DORMANT, SUSPENDED
    INTEREST_RATE_PCT      DECIMAL(7,4)  NULL,       -- percent, e.g. 6.2500
    OVERDRAFT_LIMIT_AMT    DECIMAL(18,2) NOT NULL,   -- 0 when none
    OWNING_BRANCH_CD       VARCHAR(4)    NOT NULL,
    SRC_SYSTEM_CD          VARCHAR(10)   NOT NULL,
    BATCH_ID               BIGINT        NOT NULL,
    LOAD_TS                TIMESTAMP     NOT NULL,
    CONSTRAINT PK_DIM_ACCOUNT PRIMARY KEY (ACCOUNT_SK),
    CONSTRAINT UK_DIM_ACCOUNT UNIQUE (ACCOUNT_NO)
);

CREATE TABLE DW.FCT_ACCOUNT_BALANCE_DAILY (          -- grain: one row per account per day
    ACCOUNT_SK             BIGINT        NOT NULL,
    BALANCE_DT             DATE          NOT NULL,   -- snapshot (business) date
    LEDGER_BALANCE_AMT     DECIMAL(18,2) NOT NULL,
    AVAILABLE_BALANCE_AMT  DECIMAL(18,2) NOT NULL,
    CURRENCY_CD            CHAR(3)       NOT NULL,
    SRC_SYSTEM_CD          VARCHAR(10)   NOT NULL,
    BATCH_ID               BIGINT        NOT NULL,
    LOAD_TS                TIMESTAMP     NOT NULL,
    CONSTRAINT PK_FCT_ACCT_BAL PRIMARY KEY (ACCOUNT_SK, BALANCE_DT)
);
