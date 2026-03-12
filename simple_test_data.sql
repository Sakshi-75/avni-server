-- Avni Simple Test Data Script
-- Creates minimal test data using existing default organization

-- Get the default user ID
DO $$
DECLARE
    default_user_id bigint;
    default_org_id integer;
BEGIN
    -- Get default super admin user
    SELECT id INTO default_user_id FROM users WHERE username = 'admin@example' LIMIT 1;
    IF default_user_id IS NULL THEN
        SELECT id INTO default_user_id FROM users ORDER BY id LIMIT 1;
    END IF;
    
    -- Get default organization
    SELECT id INTO default_org_id FROM organisation ORDER BY id LIMIT 1;
    
    RAISE NOTICE 'Using user_id: %, org_id: %', default_user_id, default_org_id;
    
    -- Create test subjects using the default user and org
    INSERT INTO individual (
        uuid, first_name, last_name, date_of_birth, date_of_birth_verified,
        registration_date, organisation_id, is_voided, subject_type_id,
        created_by_id, last_modified_by_id, created_date_time, last_modified_date_time,
        version
    )
    SELECT 
        'test-subject-' || generate_series || '-uuid',
        'TestUser' || generate_series,
        'LastName' || generate_series,
        '1990-01-01'::date + (generate_series || ' days')::interval,
        true,
        CURRENT_DATE - (generate_series || ' days')::interval,
        default_org_id,
        false,
        (SELECT id FROM subject_type WHERE organisation_id = default_org_id ORDER BY id LIMIT 1),
        default_user_id,
        default_user_id,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP,
        1
    FROM generate_series(1, 10)
    ON CONFLICT (uuid) DO NOTHING;
    
    RAISE NOTICE 'Created % test subjects', (SELECT COUNT(*) FROM individual WHERE uuid LIKE 'test-subject-%');
END $$;
