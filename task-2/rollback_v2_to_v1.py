#!/usr/bin/env python3
"""
NimbusTech Database Rollback: v2 to v1
Cleanly reverses all changes made by the migration
"""

import os
import sys
import logging
import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class DatabaseRollback:
    """Handles PostgreSQL rollback from v2 to v1 schema"""
    
    def __init__(self):
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
    
    def rollback(self) -> bool:
        """Apply rollback of all changes"""
        logger.info("=" * 50)
        logger.info("ROLLBACK: v2 → v1")
        logger.info("=" * 50)
        
        try:
            self.cursor.execute("BEGIN")
            
            # Step 1: Drop index
            if self.index_exists('orders', 'idx_orders_created_at'):
                logger.info("Dropping idx_orders_created_at...")
                self.cursor.execute("DROP INDEX CONCURRENTLY idx_orders_created_at")
                logger.info("✅ Dropped index")
            else:
                logger.info("⏭️  Index doesn't exist - skipping")
            
            # Step 2: Remove processed_at column
            if self.column_exists('orders', 'processed_at'):
                logger.info("Removing processed_at column from orders...")
                self.cursor.execute("ALTER TABLE orders DROP COLUMN processed_at")
                logger.info("✅ Removed processed_at")
            else:
                logger.info("⏭️  processed_at doesn't exist - skipping")
            
            # Step 3: Remove user_tier column
            if self.column_exists('users', 'user_tier'):
                logger.info("Removing user_tier column from users...")
                self.cursor.execute("ALTER TABLE users DROP COLUMN user_tier")
                logger.info("✅ Removed user_tier")
            else:
                logger.info("⏭️  user_tier doesn't exist - skipping")
            
            self.cursor.execute("COMMIT")
            logger.info("✅ Rollback completed successfully")
            return True
            
        except psycopg2.Error as e:
            logger.error(f"❌ Rollback failed: {e}")
            self.cursor.execute("ROLLBACK")
            return False
    
    def validate_rollback(self) -> bool:
        """Validate that rollback was successful"""
        logger.info("=" * 50)
        logger.info("ROLLBACK VALIDATION")
        logger.info("=" * 50)
        
        try:
            # Verify columns are removed
            if self.column_exists('users', 'user_tier'):
                logger.error("❌ user_tier column still exists")
                return False
            logger.info("✅ user_tier removed")
            
            if self.column_exists('orders', 'processed_at'):
                logger.error("❌ processed_at column still exists")
                return False
            logger.info("✅ processed_at removed")
            
            if self.index_exists('orders', 'idx_orders_created_at'):
                logger.error("❌ idx_orders_created_at still exists")
                return False
            logger.info("✅ idx_orders_created_at removed")
            
            logger.info("✅ Rollback validation passed")
            return True
            
        except psycopg2.Error as e:
            logger.error(f"❌ Validation failed: {e}")
            return False
    
    def run(self) -> bool:
        """Execute the complete rollback process"""
        if not self.connect():
            return False
        
        try:
            if not self.rollback():
                return False
            if not self.validate_rollback():
                return False
            
            logger.info("=" * 50)
            logger.info("✅ ROLLBACK COMPLETED SUCCESSFULLY")
            logger.info("=" * 50)
            return True
        finally:
            self.disconnect()


def main():
    """Main entry point"""
    required_vars = ['PG_DATABASE', 'PG_USER']
    missing_vars = [v for v in required_vars if not os.getenv(v)]
    
    if missing_vars:
        logger.error(f"Missing required environment variables: {', '.join(missing_vars)}")
        sys.exit(1)
    
    # Confirm rollback
    if sys.stdin.isatty():
        response = input("⚠️  WARNING: This will rollback all migration changes. Continue? (y/n): ")
        if response.lower() != 'y':
            logger.info("Rollback cancelled")
            sys.exit(0)
    
    rollback = DatabaseRollback()
    success = rollback.run()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()