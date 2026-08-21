NimbusTech Database Migration: v1 to v2

Overview
This migration adds new schema elements and backfills data for the NimbusTech PostgreSQL database.

Changes Applied
- users table: Adds user_tier VARCHAR(20) column with default 'free'
- orders table: Adds processed_at TIMESTAMP column (nullable)
- orders table: Creates index on created_at column
- Data backfill: Sets processed_at = created_at + 2 hours for completed orders

Prerequisites

System Requirements
- Python 3.8+
- PostgreSQL 12+
- psycopg2-binary package

Environment Variables
- PG_HOST: PostgreSQL host; default localhost; not required
- PG_PORT: PostgreSQL port; default 5432; not required
- PG_DATABASE: Database name; default nimbustech; required
- PG_USER: Database user; default postgres; required
- PG_PASSWORD: Database password; default empty; not required

Installation
Install Python dependencies
pip install psycopg2-binary
