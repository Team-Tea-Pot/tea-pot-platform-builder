-- Initialize database for TeaPot User Service
-- This script runs automatically when the PostgreSQL container starts

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Set timezone
SET timezone = 'UTC';

-- Create users table
-- This is the source of truth for the schema
-- Run `make generate-models` to generate Go models from this schema
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL,
    business_name VARCHAR(200) NOT NULL,
    owner_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    tenant_id VARCHAR(100) NOT NULL,
    farm_size_hectares DECIMAL(10,2),
    location_latitude DOUBLE PRECISION,
    location_longitude DOUBLE PRECISION,
    location_address VARCHAR(500),
    preferred_language VARCHAR(2) DEFAULT 'en',
    is_active BOOLEAN DEFAULT true,
    is_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_users_tenant_id ON users(tenant_id);
CREATE INDEX IF NOT EXISTS idx_users_is_active ON users(is_active);

-- Insert mock data for testing
-- Password for all users: password123
INSERT INTO users (
    username, business_name, owner_name, email, password_hash, 
    phone_number, tenant_id, farm_size_hectares, location_latitude, 
    location_longitude, location_address, preferred_language, 
    is_active, is_verified
) VALUES
(
    'john_tea_farm',
    'Green Leaf Tea Plantation',
    'John Smith',
    'john@greenleaf.com',
    '$2a$10$MRPz0j4Hbju.i/j5NZJXDOaYO9sAFHTOiWDcUla33JbZrJ26cPC42', -- password123
    '+94771234567',
    'tenant_001',
    5.75,
    6.9271,
    79.8612,
    'Kandy District, Central Province, Sri Lanka',
    'en',
    true,
    true
),
(
    'mary_organic_tea',
    'Mary''s Organic Tea Estate',
    'Mary Johnson',
    'mary@organictea.com',
    '$2a$10$MRPz0j4Hbju.i/j5NZJXDOaYO9sAFHTOiWDcUla33JbZrJ26cPC42', -- password123
    '+94772345678',
    'tenant_002',
    12.50,
    7.2906,
    80.6337,
    'Nuwara Eliya District, Central Province, Sri Lanka',
    'en',
    true,
    true
),
(
    'raj_highland_tea',
    'Highland Tea Gardens',
    'Raj Patel',
    'raj@highlandtea.com',
    '$2a$10$MRPz0j4Hbju.i/j5NZJXDOaYO9sAFHTOiWDcUla33JbZrJ26cPC42', -- password123
    '+94773456789',
    'tenant_003',
    8.30,
    6.9497,
    80.7891,
    'Badulla District, Uva Province, Sri Lanka',
    'en',
    true,
    false
),
(
    'sarah_smallholder',
    'Sarah''s Tea Garden',
    'Sarah Williams',
    'sarah@teagarden.com',
    '$2a$10$MRPz0j4Hbju.i/j5NZJXDOaYO9sAFHTOiWDcUla33JbZrJ26cPC42', -- password123
    '+94774567890',
    'tenant_004',
    2.15,
    6.7077,
    79.9105,
    'Colombo District, Western Province, Sri Lanka',
    'en',
    true,
    true
),
(
    'ahmed_premium_tea',
    'Premium Ceylon Tea Co',
    'Ahmed Hassan',
    'ahmed@premiumceylon.com',
    '$2a$10$MRPz0j4Hbju.i/j5NZJXDOaYO9sAFHTOiWDcUla33JbZrJ26cPC42', -- password123
    '+94775678901',
    'tenant_005',
    15.80,
    6.9271,
    80.7718,
    'Matale District, Central Province, Sri Lanka',
    'en',
    false,
    false
)
ON CONFLICT (username) DO NOTHING;

-- Performance tuning
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET maintenance_work_mem = '64MB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET default_statistics_target = 100;
ALTER SYSTEM SET random_page_cost = 1.1;
ALTER SYSTEM SET effective_io_concurrency = 200;
ALTER SYSTEM SET work_mem = '4MB';
ALTER SYSTEM SET min_wal_size = '1GB';
ALTER SYSTEM SET max_wal_size = '4GB';

-- Create a read-only user for analytics (optional)
CREATE USER readonly_user WITH PASSWORD 'readonly_pass';
GRANT CONNECT ON DATABASE teapot_users TO readonly_user;
GRANT USAGE ON SCHEMA public TO readonly_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO readonly_user;

-- Log successful initialization
DO $$
BEGIN
    RAISE NOTICE 'Database initialization completed successfully';
END $$;
