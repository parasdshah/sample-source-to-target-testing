-- Target model (DW schema). Fictional.
CREATE TABLE DW.DIM_EMAIL_ADDRESS (                  -- SCD type 1
    EMAIL_ADDRESS_SK       BIGINT        NOT NULL,   -- surrogate key
    EMAIL_ADDRESS          VARCHAR(254)  NOT NULL,   -- business key, lower-cased and trimmed
    EMAIL_LOCAL_PART       VARCHAR(64)   NOT NULL,
    EMAIL_DOMAIN_NAME      VARCHAR(190)  NOT NULL,
    INTERNAL_FLG           CHAR(1)       NOT NULL,   -- Y when domain is a company-owned domain
    SRC_SYSTEM_CD          VARCHAR(10)   NOT NULL,
    BATCH_ID               BIGINT        NOT NULL,
    LOAD_TS                TIMESTAMP     NOT NULL,
    CONSTRAINT PK_DIM_EMAIL_ADDRESS PRIMARY KEY (EMAIL_ADDRESS_SK)
);

CREATE TABLE DW.DIM_MAILBOX (                        -- SCD type 1
    MAILBOX_SK             BIGINT        NOT NULL,
    MAILBOX_ID             VARCHAR(10)   NOT NULL,   -- business key
    EMAIL_ADDRESS_SK       BIGINT        NOT NULL,   -- FK to DIM_EMAIL_ADDRESS
    MAILBOX_TYPE_CD        VARCHAR(8)    NOT NULL,   -- PERSONAL, SHARED, DISTLIST, GROUP, UNKNOWN
    DEPARTMENT_CD          VARCHAR(6)    NULL,
    ACTIVE_FLG             CHAR(1)       NOT NULL,   -- Y/N
    SRC_SYSTEM_CD          VARCHAR(10)   NOT NULL,
    BATCH_ID               BIGINT        NOT NULL,
    LOAD_TS                TIMESTAMP     NOT NULL,
    CONSTRAINT PK_DIM_MAILBOX PRIMARY KEY (MAILBOX_SK)
);

CREATE TABLE DW.FACT_EMAIL_MESSAGE (
    MESSAGE_SK                  BIGINT        NOT NULL,
    MESSAGE_ID                  VARCHAR(12)   NOT NULL,   -- business key
    THREAD_ID                   VARCHAR(12)   NULL,
    SENDER_EMAIL_ADDRESS_SK     BIGINT        NOT NULL,   -- FK to DIM_EMAIL_ADDRESS
    SENDER_DISPLAY_NAME         VARCHAR(100)  NULL,
    MAILBOX_SK                  BIGINT        NOT NULL,   -- FK to DIM_MAILBOX
    SUBJECT_TXT                 VARCHAR(500)  NULL,
    SENT_TS_UTC                 TIMESTAMP     NOT NULL,
    RECEIVED_DT                 DATE          NULL,
    MESSAGE_SIZE_BYTES          INTEGER       NOT NULL,
    DIRECTION_CD                VARCHAR(8)    NOT NULL,   -- INBOUND, OUTBOUND, INTERNAL
    PRIORITY_CD                 VARCHAR(7)    NOT NULL,   -- HIGH, NORMAL, LOW, UNKNOWN
    ATTACHMENT_CNT              SMALLINT      NOT NULL,
    SPAM_SCORE                  DECIMAL(5,2)  NULL,
    SPAM_FLG                    CHAR(1)       NOT NULL,   -- Y/N
    DELETED_FLG                 CHAR(1)       NOT NULL,   -- Y/N
    SRC_SYSTEM_CD               VARCHAR(10)   NOT NULL,
    BATCH_ID                    BIGINT        NOT NULL,
    LOAD_TS                     TIMESTAMP     NOT NULL,
    CONSTRAINT PK_FACT_EMAIL_MESSAGE PRIMARY KEY (MESSAGE_SK)
);

CREATE TABLE DW.BRIDGE_EMAIL_RECIPIENT (
    MESSAGE_SK                  BIGINT        NOT NULL,   -- FK to FACT_EMAIL_MESSAGE
    RECIPIENT_SEQ               SMALLINT      NOT NULL,
    RECIPIENT_EMAIL_ADDRESS_SK  BIGINT        NOT NULL,   -- FK to DIM_EMAIL_ADDRESS
    RECIPIENT_TYPE_CD           VARCHAR(3)    NOT NULL,   -- TO, CC, BCC
    DELIVERY_STATUS_CD          VARCHAR(10)   NOT NULL,   -- SENT, DELIVERED, DEFERRED, BOUNCED, UNKNOWN
    READ_FLG                    CHAR(1)       NOT NULL,   -- Y/N/U (unknown)
    READ_TS_UTC                 TIMESTAMP     NULL,
    DELETED_FLG                 CHAR(1)       NOT NULL,
    SRC_SYSTEM_CD               VARCHAR(10)   NOT NULL,
    BATCH_ID                    BIGINT        NOT NULL,
    LOAD_TS                     TIMESTAMP     NOT NULL,
    CONSTRAINT PK_BRIDGE_EMAIL_RECIPIENT PRIMARY KEY (MESSAGE_SK, RECIPIENT_SEQ)
);
