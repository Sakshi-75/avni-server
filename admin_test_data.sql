-- Avni Admin Test Data Script
-- Creates test data for admin functionality

DO $$
DECLARE
    default_user_id bigint;
    default_org_id integer;
    test_concept_id bigint;
    test_subject_type_id bigint;
    test_form_id bigint;
    test_program_id bigint;
    test_encounter_type_id bigint;
BEGIN
    -- Get defaults
    SELECT id INTO default_user_id FROM users ORDER BY id LIMIT 1;
    SELECT id INTO default_org_id FROM organisation ORDER BY id LIMIT 1;
    
    RAISE NOTICE 'Creating admin test data for org: %, user: %', default_org_id, default_user_id;
    
    -- 1. Create test concepts
    INSERT INTO concept (uuid, name, data_type, organisation_id, is_voided, version, created_by_id, last_modified_by_id, created_date_time, last_modified_date_time)
    VALUES 
        ('test-concept-height-uuid', 'Test Height', 'Numeric', default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        ('test-concept-weight-uuid', 'Test Weight', 'Numeric', default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        ('test-concept-bp-uuid', 'Test Blood Pressure', 'Text', default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        ('test-concept-status-uuid', 'Test Status', 'Coded', default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        ('test-concept-active-uuid', 'Active', 'NA', default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        ('test-concept-inactive-uuid', 'Inactive', 'NA', default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    ON CONFLICT (uuid, organisation_id) DO NOTHING;
    
    SELECT id INTO test_concept_id FROM concept WHERE uuid = 'test-concept-status-uuid';
    
    -- Create concept answers
    INSERT INTO concept_answer (uuid, concept_id, answer_concept_id, answer_order, organisation_id, is_voided, version, created_by_id, last_modified_by_id, created_date_time, last_modified_date_time, abnormal)
    VALUES
        ('test-answer-active-uuid', test_concept_id, (SELECT id FROM concept WHERE uuid = 'test-concept-active-uuid'), 1, default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, false),
        ('test-answer-inactive-uuid', test_concept_id, (SELECT id FROM concept WHERE uuid = 'test-concept-inactive-uuid'), 2, default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, false)
    ON CONFLICT (uuid, organisation_id) DO NOTHING;
    
    -- 2. Create test subject type
    INSERT INTO subject_type (uuid, name, organisation_id, is_voided, version, created_by_id, last_modified_by_id, created_date_time, last_modified_date_time, type)
    VALUES ('test-patient-subject-type-uuid', 'Test Patient', default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'Person')
    ON CONFLICT (uuid, organisation_id) DO NOTHING;
    
    SELECT id INTO test_subject_type_id FROM subject_type WHERE uuid = 'test-patient-subject-type-uuid';
    
    -- 3. Create test form
    INSERT INTO form (uuid, name, form_type, organisation_id, is_voided, version, created_by_id, last_modified_by_id, created_date_time, last_modified_date_time)
    VALUES ('test-registration-form-uuid', 'Test Registration Form', 'IndividualProfile', default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    ON CONFLICT (uuid, organisation_id) DO NOTHING;
    
    SELECT id INTO test_form_id FROM form WHERE uuid = 'test-registration-form-uuid';
    
    -- Create form element group
    INSERT INTO form_element_group (uuid, name, display_order, form_id, organisation_id, is_voided, version, created_by_id, last_modified_by_id, created_date_time, last_modified_date_time)
    VALUES ('test-form-group-uuid', 'Test Basic Info', 1, test_form_id, default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    ON CONFLICT (uuid, organisation_id) DO NOTHING;
    
    -- Create form elements
    INSERT INTO form_element (uuid, name, display_order, is_mandatory, concept_id, form_element_group_id, organisation_id, is_voided, version, created_by_id, last_modified_by_id, created_date_time, last_modified_date_time, type)
    VALUES
        ('test-form-element-height-uuid', 'Height', 1, false, (SELECT id FROM concept WHERE uuid = 'test-concept-height-uuid'), (SELECT id FROM form_element_group WHERE uuid = 'test-form-group-uuid'), default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'Numeric'),
        ('test-form-element-weight-uuid', 'Weight', 2, false, (SELECT id FROM concept WHERE uuid = 'test-concept-weight-uuid'), (SELECT id FROM form_element_group WHERE uuid = 'test-form-group-uuid'), default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'Numeric')
    ON CONFLICT (uuid, organisation_id) DO NOTHING;
    
    -- 4. Create test program
    INSERT INTO program (uuid, name, colour, organisation_id, is_voided, version, created_by_id, last_modified_by_id, created_date_time, last_modified_date_time)
    VALUES ('test-health-program-uuid', 'Test Health Program', '#FF5733', default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    ON CONFLICT (uuid, organisation_id) DO NOTHING;
    
    SELECT id INTO test_program_id FROM program WHERE uuid = 'test-health-program-uuid';
    
    -- 5. Create test encounter type
    INSERT INTO encounter_type (uuid, name, organisation_id, is_voided, version, created_by_id, last_modified_by_id, created_date_time, last_modified_date_time)
    VALUES 
        ('test-checkup-encounter-uuid', 'Test Health Checkup', default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        ('test-followup-encounter-uuid', 'Test Follow-up', default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    ON CONFLICT (uuid, organisation_id) DO NOTHING;
    
    -- 6. Create test address level types
    INSERT INTO address_level_type (uuid, name, level, organisation_id, is_voided, version, created_by_id, last_modified_by_id, created_date_time, last_modified_date_time)
    VALUES
        ('test-state-type-uuid', 'Test State', 1, default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        ('test-district-type-uuid', 'Test District', 2, default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        ('test-village-type-uuid', 'Test Village', 3, default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    ON CONFLICT (uuid, organisation_id) DO NOTHING;
    
    -- 7. Create test address levels
    INSERT INTO address_level (uuid, title, type_id, organisation_id, is_voided, version, created_by_id, last_modified_by_id, created_date_time, last_modified_date_time)
    VALUES
        ('test-state-1-uuid', 'Test State 1', (SELECT id FROM address_level_type WHERE uuid = 'test-state-type-uuid'), default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        ('test-district-1-uuid', 'Test District 1', (SELECT id FROM address_level_type WHERE uuid = 'test-district-type-uuid'), default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        ('test-village-1-uuid', 'Test Village 1', (SELECT id FROM address_level_type WHERE uuid = 'test-village-type-uuid'), default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        ('test-village-2-uuid', 'Test Village 2', (SELECT id FROM address_level_type WHERE uuid = 'test-village-type-uuid'), default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    ON CONFLICT (uuid, organisation_id) DO NOTHING;
    
    -- Set parent relationships
    UPDATE address_level SET parent_id = (SELECT id FROM address_level WHERE uuid = 'test-state-1-uuid') WHERE uuid = 'test-district-1-uuid';
    UPDATE address_level SET parent_id = (SELECT id FROM address_level WHERE uuid = 'test-district-1-uuid') WHERE uuid IN ('test-village-1-uuid', 'test-village-2-uuid');
    
    -- 8. Create test catchment
    INSERT INTO catchment (uuid, name, type, organisation_id, is_voided, version, created_by_id, last_modified_by_id, created_date_time, last_modified_date_time)
    VALUES ('test-catchment-uuid', 'Test Catchment Area', 'TypeOfCatchment', default_org_id, false, 1, default_user_id, default_user_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    ON CONFLICT (uuid, organisation_id) DO NOTHING;
    
    -- Map catchment to locations
    INSERT INTO catchment_address_mapping (catchment_id, addresslevel_id, version, organisation_id, is_voided, created_by_id, last_modified_by_id, created_date_time, last_modified_date_time)
    SELECT 
        (SELECT id FROM catchment WHERE uuid = 'test-catchment-uuid'),
        id,
        1,
        default_org_id,
        false,
        default_user_id,
        default_user_id,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    FROM address_level WHERE uuid IN ('test-village-1-uuid', 'test-village-2-uuid')
    ON CONFLICT DO NOTHING;
    
    RAISE NOTICE 'Admin test data created successfully!';
    RAISE NOTICE 'Concepts: %', (SELECT COUNT(*) FROM concept WHERE uuid LIKE 'test-concept-%');
    RAISE NOTICE 'Subject Types: %', (SELECT COUNT(*) FROM subject_type WHERE uuid LIKE 'test-%');
    RAISE NOTICE 'Forms: %', (SELECT COUNT(*) FROM form WHERE uuid LIKE 'test-%');
    RAISE NOTICE 'Programs: %', (SELECT COUNT(*) FROM program WHERE uuid LIKE 'test-%');
    RAISE NOTICE 'Encounter Types: %', (SELECT COUNT(*) FROM encounter_type WHERE uuid LIKE 'test-%');
    RAISE NOTICE 'Address Levels: %', (SELECT COUNT(*) FROM address_level WHERE uuid LIKE 'test-%');
    RAISE NOTICE 'Catchments: %', (SELECT COUNT(*) FROM catchment WHERE uuid LIKE 'test-%');
END $$;
