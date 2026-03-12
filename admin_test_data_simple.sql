-- Avni Admin Test Data (Simplified)
DO $$
DECLARE
    default_user_id bigint;
    default_org_id integer;
BEGIN
    SELECT id INTO default_user_id FROM users ORDER BY id LIMIT 1;
    SELECT id INTO default_org_id FROM organisation ORDER BY id LIMIT 1;
    
    RAISE NOTICE 'Creating admin test data...';
    
    -- Concepts
    INSERT INTO concept (uuid, name, data_type, organisation_id, is_voided, version, created_by_id, last_modified_by_id, created_date_time, last_modified_date_time)
    SELECT * FROM (VALUES
        ('test-height-' || default_org_id, 'Test Height', 'Numeric', default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        ('test-weight-' || default_org_id, 'Test Weight', 'Numeric', default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        ('test-bp-' || default_org_id, 'Test BP', 'Text', default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    ) AS v(uuid, name, data_type, organisation_id, is_voided, version, created_by_id, last_modified_by_id, created_date_time, last_modified_date_time)
    WHERE NOT EXISTS (SELECT 1 FROM concept WHERE concept.uuid = v.uuid);
    
    -- Subject Type
    INSERT INTO subject_type (uuid, name, organisation_id, is_voided, version, created_by_id, last_modified_by_id, created_date_time, last_modified_date_time, type)
    SELECT 'test-patient-' || default_org_id, 'Test Patient', default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'Person'
    WHERE NOT EXISTS (SELECT 1 FROM subject_type WHERE uuid = 'test-patient-' || default_org_id);
    
    -- Program
    INSERT INTO program (uuid, name, colour, organisation_id, is_voided, version, created_by_id, last_modified_by_id, created_date_time, last_modified_date_time)
    SELECT 'test-program-' || default_org_id, 'Test Health Program', '#FF5733', default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    WHERE NOT EXISTS (SELECT 1 FROM program WHERE uuid = 'test-program-' || default_org_id);
    
    -- Encounter Types
    INSERT INTO encounter_type (uuid, name, organisation_id, is_voided, version, created_by_id, last_modified_by_id, created_date_time, last_modified_date_time)
    SELECT * FROM (VALUES
        ('test-checkup-' || default_org_id, 'Test Checkup', default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        ('test-followup-' || default_org_id, 'Test Follow-up', default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    ) AS v(uuid, name, organisation_id, is_voided, version, created_by_id, last_modified_by_id, created_date_time, last_modified_date_time)
    WHERE NOT EXISTS (SELECT 1 FROM encounter_type WHERE encounter_type.uuid = v.uuid);
    
    -- Address Level Types
    INSERT INTO address_level_type (uuid, name, level, organisation_id, is_voided, version, created_by_id, last_modified_by_id, created_date_time, last_modified_date_time)
    SELECT * FROM (VALUES
        ('test-state-type-' || default_org_id, 'Test State Type', 1, default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        ('test-district-type-' || default_org_id, 'Test District Type', 2, default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    ) AS v(uuid, name, level, organisation_id, is_voided, version, created_by_id, last_modified_by_id, created_date_time, last_modified_date_time)
    WHERE NOT EXISTS (SELECT 1 FROM address_level_type WHERE address_level_type.name = v.name AND address_level_type.organisation_id = v.organisation_id);
    
    -- Address Levels
    INSERT INTO address_level (uuid, title, type_id, organisation_id, is_voided, version, created_by_id, last_modified_by_id, created_date_time, last_modified_date_time)
    SELECT * FROM (VALUES
        ('test-state-' || default_org_id, 'Test State', (SELECT id FROM address_level_type WHERE name = 'Test State Type' AND organisation_id = default_org_id LIMIT 1), default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        ('test-district-' || default_org_id, 'Test District', (SELECT id FROM address_level_type WHERE name = 'Test District Type' AND organisation_id = default_org_id LIMIT 1), default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    ) AS v(uuid, title, type_id, organisation_id, is_voided, version, created_by_id, last_modified_by_id, created_date_time, last_modified_date_time)
    WHERE NOT EXISTS (SELECT 1 FROM address_level WHERE address_level.uuid = v.uuid);
    
    RAISE NOTICE 'Admin test data created!';
    RAISE NOTICE 'Concepts: %', (SELECT COUNT(*) FROM concept WHERE name LIKE 'Test %');
    RAISE NOTICE 'Subject Types: %', (SELECT COUNT(*) FROM subject_type WHERE name LIKE 'Test %');
    RAISE NOTICE 'Programs: %', (SELECT COUNT(*) FROM program WHERE name LIKE 'Test %');
    RAISE NOTICE 'Encounter Types: %', (SELECT COUNT(*) FROM encounter_type WHERE name LIKE 'Test %');
    RAISE NOTICE 'Address Levels: %', (SELECT COUNT(*) FROM address_level WHERE title LIKE 'Test %');
END $$;
