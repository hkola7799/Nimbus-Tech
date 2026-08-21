#!/usr/bin/env python3
"""
NimbusTech Database Migration: v1 to v2
Idempotent migration script for PostgreSQL schema upgrade
"""

import os
import sys
import time
import logging
from typing import Dict, Any
import psycopg2
from psycopg2 import sql, extras
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)


class DatabaseMigration:
    """Handles PostgreSQL migration from v1 to v2 schema"""
    
    def __init__(self):
        """Initialize database connection from environment variables"""
        self.conn_params = {
            'host': os.getenv('PG_HOST', 'localhost'),
            'port': os.getenv('PG_PORT', '5432'),
            'database': os.getenv('PG_DATABASE', 'nimbustech'),
            'user': os.getenv('PG_USER', 'postgres'),
            'password': os.getenv('PG_PASSWORD', '')
        }
        self.conn = None
        self.cursor = None
        
    def connect(self):
        """Establish database connection"""
        try:
            self.conn = psycopg2.connect(**self.conn_params)
            self.conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
            self.cursor = self.conn.cursor()
            logger.info(f"Connected to database: {self.conn_params['database']}")
            return True
        except psycopg2.Error as e:
            logger.error(f"Database connection failed: {e}")
            return False
    
    def disconnect(self):
        """Close database connection"""
        if self.cursor:
            self.cursor.close()
        if self.conn:
            self.conn.close()
            logger.info("Database connection closed")
    
    def column_exists(self, table: str, column: str) -> bool:
        """Check if a column exists in a table"""
        query = """
            SELECT EXISTS (
                SELECT 1 
                FROM information_schema.columns 
                WHERE table_name = %s 
                AND column_name = %s
            )
        """
        self.cursor.execute(query, (table, column))
        return self.cursor.fetchone()[0]
    
    def index_exists(self, table: str, index_name: str) -> bool:
        """Check if an index exists"""
        query = """
            SELECT EXISTS (
                SELECT 1 
                FROM pg_indexes 
                WHERE tablename = %s 
                AND indexname = %s
            )
        """
        self.cursor.execute(query, (table, index_name))
        return self.cursor.fetchone()[0]
    
    def get_row_count(self, table: str, where_clause: str = None) -> int:
        """Get row count for a table with optional where clause"""
        query = f"SELECT COUNT(*) FROM {table}"
        if where_clause:
            query += f" WHERE {where_clause}"
        self.cursor.execute(query)
        return self.cursor.fetchone()[0]
    
    def pre_validation(self) -> bool:
        """Validate pre-migration state"""
        logger.info("=" * 50)
        logger.info("PRE-MIGRATION VALIDATION")
        logger.info("=" * 50)
        
        try:
            # Check if migration already applied
            if self.column_exists('users', 'user_tier'):
                logger.warning("Column 'user_tier' already exists - migration may have been applied")
                if not self.ask_confirmation("Continue with migration anyway?"):
                    return False
            
            # Get baseline counts
            users_count = self.get_row_count('users')
            orders_count = self.get_row_count('orders')
            completed_orders = self.get_row_count('orders', "status = 'completed'")
            
            logger.info(f"✅ Users table row count: {users_count:,}")
            logger.info(f"✅ Orders table row count: {orders_count:,}")
            logger.info(f"✅ Completed orders: {completed_orders:,}")
            
            # Check for existing index
            if self.index_exists('orders', 'idx_orders_created_at'):
                logger.info("⚠️  Index 'idx_orders_created_at' already exists")
            
            logger.info("✅ Pre-validation passed\n")
            return True
            
        except psycopg2.Error as e:
            logger.error(f"❌ Pre-validation failed: {e}")
            return False
    
    def apply_migration(self) -> bool:
        """Apply the v1 to v2 migration"""
        logger.info("=" * 50)
        logger.info("APPLYING MIGRATION")
        logger.info("=" * 50)
        
        try:
            # Begin transaction
            self.cursor.execute("BEGIN")
            
            # Step 1: Add user_tier column to users table
            if not self.column_exists('users', 'user_tier'):
                logger.info("Adding 'user_tier' column to users table...")
                self.cursor.execute("""
                    ALTER TABLE users 
                    ADD COLUMN user_tier VARCHAR(20) DEFAULT 'free'
                """)
                logger.info("✅ Added user_tier column")
            else:
                logger.info("⏭️  user_tier column already exists - skipping")
            
            # Step 2: Add processed_at column to orders table
            if not self.column_exists('orders', 'processed_at'):
                logger.info("Adding 'processed_at' column to orders table...")
                self.cursor.execute("""
                    ALTER TABLE orders 
                    ADD COLUMN processed_at TIMESTAMP WITHOUT TIME ZONE
                """)
                logger.info("✅ Added processed_at column")
            else:
                logger.info("⏭️  processed_at column already exists - skipping")
            
            # Step 3: Backfill processed_at for completed orders
            logger.info("Backfilling processed_at for completed orders...")
            
            # First, check how many rows need updating
            rows_to_update = self.get_row_count('orders', "status = 'completed' AND processed_at IS NULL")
            logger.info(f"Rows to backfill: {rows_to_update:,}")
            
            if rows_to_update > 0:
                # Use batch processing for large datasets
                batch_size = 10000
                total_updated = 0
                
                logger.info(f"Processing in batches of {batch_size:,} rows...")
                start_time = time.time()
                
                while True:
                    update_query = """
                        UPDATE orders 
                        SET processed_at = created_at + INTERVAL '2 hours'
                        WHERE id IN (
                            SELECT id FROM orders 
                            WHERE status = 'completed' 
                            AND processed_at IS NULL 
                            LIMIT %s
                        )
                    """
                    self.cursor.execute(update_query, (batch_size,))
                    updated = self.cursor.rowcount
                    total_updated += updated
                    
                    if updated > 0:
                        logger.info(f"  Updated {total_updated:,} rows so far...")
                    
                    if updated < batch_size:
                        break
                
                elapsed = time.time() - start_time
                logger.info(f"✅ Backfilled {total_updated:,} rows in {elapsed:.2f} seconds")
            else:
                logger.info("⏭️  No rows need backfilling")
            
            # Step 4: Create index on orders(created_at)
            if not self.index_exists('orders', 'idx_orders_created_at'):
                logger.info("Creating index on orders(created_at)...")
                self.cursor.execute("""
                    CREATE INDEX CONCURRENTLY idx_orders_created_at 
                    ON orders(created_at)
                """)
                logger.info("✅ Created idx_orders_created_at")
            else:
                logger.info("⏭️  idx_orders_created_at already exists - skipping")
            
            # Commit transaction
            self.cursor.execute("COMMIT")
            logger.info("✅ Migration committed successfully")
            return True
            
        except psycopg2.Error as e:
            logger.error(f"❌ Migration failed: {e}")
            self.cursor.execute("ROLLBACK")
            return False
    
    def post_validation(self) -> bool:
        """Validate post-migration state"""
        logger.info("=" * 50)
        logger.info("POST-MIGRATION VALIDATION")
        logger.info("=" * 50)
        
        try:
            # Verify columns exist
            if not self.column_exists('users', 'user_tier'):
                logger.error("❌ user_tier column missing after migration")
                return False
            logger.info("✅ user_tier column exists")
            
            if not self.column_exists('orders', 'processed_at'):
                logger.error("❌ processed_at column missing after migration")
                return False
            logger.info("✅ processed_at column exists")
            
            # Verify index exists
            if not self.index_exists('orders', 'idx_orders_created_at'):
                logger.warning("⚠️  idx_orders_created_at index missing")
            else:
                logger.info("✅ idx_orders_created_at index exists")
            
            # Verify backfill
            null_count = self.get_row_count('orders', "status = 'completed' AND processed_at IS NULL")
            if null_count > 0:
                logger.warning(f"⚠️  {null_count:,} completed orders still have NULL processed_at")
            else:
                logger.info("✅ All completed orders have processed_at populated")
            
            # Get final counts
            users_count = self.get_row_count('users')
            orders_count = self.get_row_count('orders')
            tier_counts = self.cursor.execute("""
                SELECT user_tier, COUNT(*) 
                FROM users 
                GROUP BY user_tier
            """)
            tier_results = self.cursor.fetchall()
            
            logger.info(f"✅ Users table row count: {users_count:,}")
            logger.info(f"✅ Orders table row count: {orders_count:,}")
            logger.info("User tier distribution:")
            for tier, count in tier_results:
                logger.info(f"  - {tier}: {count:,}")
            
            logger.info("✅ Post-validation passed\n")
            return True
            
        except psycopg2.Error as e:
            logger.error(f"❌ Post-validation failed: {e}")
            return False
    
    def ask_confirmation(self, message: str) -> bool:
        """Ask for user confirmation"""
        response = input(f"{message} (y/n): ").strip().lower()
        return response == 'y'
    
    def run(self) -> bool:
        """Execute the complete migration process"""
        logger.info("=" * 50)
        logger.info("NIMBUS TECH DATABASE MIGRATION v1 → v2")
        logger.info("=" * 50)
        
        if not self.connect():
            return False
        
        try:
            # Pre-validation
            if not self.pre_validation():
                return False
            
            # Ask for confirmation if in interactive mode
            if sys.stdin.isatty():
                if not self.ask_confirmation("Proceed with migration?"):
                    logger.info("Migration cancelled")
                    return False
            
            # Apply migration
            if not self.apply_migration():
                return False
            
            # Post-validation
            if not self.post_validation():
                return False
            
            logger.info("=" * 50)
            logger.info("✅ MIGRATION COMPLETED SUCCESSFULLY")
            logger.info("=" * 50)
            return True
            
        finally:
            self.disconnect()


def main():
    """Main entry point"""
    # Required environment variables check
    required_vars = ['PG_DATABASE', 'PG_USER']
    missing_vars = [v for v in required_vars if not os.getenv(v)]
    
    if missing_vars:
        logger.error(f"Missing required environment variables: {', '.join(missing_vars)}")
        logger.error("Please set: PG_HOST, PG_PORT, PG_DATABASE, PG_USER, PG_PASSWORD")
        sys.exit(1)
    
    migration = DatabaseMigration()
    success = migration.run()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()