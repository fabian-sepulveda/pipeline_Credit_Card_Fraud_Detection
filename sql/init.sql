-- =========================
-- Schema: fintech fraud batch
-- =========================

CREATE SCHEMA IF NOT EXISTS analytics;

-- 1) Staging (raw/clean)
CREATE TABLE IF NOT EXISTS analytics.staging_transactions (
    tx_id TEXT PRIMARY KEY,
    event_time TIMESTAMP NOT NULL,
    amount NUMERIC(12,2) NOT NULL,
    is_fraud BOOLEAN NOT NULL,

    -- Segmentación "fintech" (enriquecido por tu ingesta)
    user_id TEXT NOT NULL,
    merchant_id TEXT NOT NULL,
    country TEXT NOT NULL,
    channel TEXT NOT NULL,      -- e.g. web | mobile | pos
    device_id TEXT,             -- opcional
    ingested_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_stg_event_time ON analytics.staging_transactions (event_time);
CREATE INDEX IF NOT EXISTS idx_stg_merchant_time ON analytics.staging_transactions (merchant_id, event_time);
CREATE INDEX IF NOT EXISTS idx_stg_user_time ON analytics.staging_transactions (user_id, event_time);
CREATE INDEX IF NOT EXISTS idx_stg_is_fraud_time ON analytics.staging_transactions (is_fraud, event_time);

-- 2) Alertas (para fase streaming o batch rules)
CREATE TABLE IF NOT EXISTS analytics.fraud_alerts (
    alert_id BIGSERIAL PRIMARY KEY,
    tx_id TEXT NOT NULL REFERENCES analytics.staging_transactions(tx_id) ON DELETE CASCADE,
    alert_type TEXT NOT NULL,       -- rule_velocity | rule_amount | rule_geo | etc.
    severity TEXT NOT NULL,         -- low | medium | high
    reason TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_alerts_created_at ON analytics.fraud_alerts (created_at);
CREATE INDEX IF NOT EXISTS idx_alerts_type ON analytics.fraud_alerts (alert_type);

-- 3) KPIs diarios (gold)
CREATE TABLE IF NOT EXISTS analytics.kpi_daily (
    date DATE NOT NULL,
    merchant_id TEXT NOT NULL,
    country TEXT NOT NULL,
    channel TEXT NOT NULL,

    tx_count INT NOT NULL,
    fraud_count INT NOT NULL,
    fraud_rate NUMERIC(7,6) NOT NULL,
    fraud_amount NUMERIC(14,2) NOT NULL,

    created_at TIMESTAMP NOT NULL DEFAULT now(),
    PRIMARY KEY (date, merchant_id, country, channel)
);

CREATE INDEX IF NOT EXISTS idx_kpi_daily_date ON analytics.kpi_daily (date);

-- 4) KPIs por minuto (para fase streaming, pero lo dejamos creado)
CREATE TABLE IF NOT EXISTS analytics.kpi_minute (
    minute_ts TIMESTAMP NOT NULL,  -- trunc a minuto
    merchant_id TEXT NOT NULL,
    country TEXT NOT NULL,
    channel TEXT NOT NULL,

    tx_count INT NOT NULL,
    fraud_count INT NOT NULL,
    fraud_rate NUMERIC(7,6) NOT NULL,
    fraud_amount NUMERIC(14,2) NOT NULL,

    created_at TIMESTAMP NOT NULL DEFAULT now(),
    PRIMARY KEY (minute_ts, merchant_id, country, channel)
);

CREATE INDEX IF NOT EXISTS idx_kpi_minute_ts ON analytics.kpi_minute (minute_ts);

-- 5) Observabilidad del pipeline (Airflow lo llenará después)
CREATE TABLE IF NOT EXISTS analytics.pipeline_runs (
    run_id BIGSERIAL PRIMARY KEY,
    pipeline_name TEXT NOT NULL,     -- ingest_batch | dbt_run | etc.
    status TEXT NOT NULL,            -- success | failed | running
    started_at TIMESTAMP NOT NULL,
    finished_at TIMESTAMP,
    rows_processed INT,
    error_message TEXT
);

CREATE INDEX IF NOT EXISTS idx_runs_pipeline_started ON analytics.pipeline_runs (pipeline_name, started_at);
