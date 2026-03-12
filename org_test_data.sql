-- Create dummy organisations and organisation groups

DO $$
DECLARE
    default_user_id bigint;
    default_account_id bigint;
    org_category_id bigint;
    org_status_id bigint;
    test_org_id1 bigint;
    test_org_id2 bigint;
    test_org_id3 bigint;
BEGIN
    -- Get defaults
    SELECT id INTO default_user_id FROM users ORDER BY id LIMIT 1;
    SELECT id INTO default_account_id FROM account ORDER BY id LIMIT 1;
    SELECT id INTO org_category_id FROM organisation_category ORDER BY id LIMIT 1;
    SELECT id INTO org_status_id FROM organisation_status ORDER BY id LIMIT 1;
    
    RAISE NOTICE 'Creating test organisations and groups...';
    
    -- Create Organisation Groups
    INSERT INTO organisation_group (uuid, name, db_user, account_id, is_voided)
    SELECT * FROM (VALUES
        ('test-org-group-1-uuid', 'Test Health Network', 'test_health_network', default_account_id, false),
        ('test-org-group-2-uuid', 'Test Education Network', 'test_edu_network', default_account_id, false),
        ('test-org-group-3-uuid', 'Test Community Network', 'test_community_network', default_account_id, false)
    ) AS v(uuid, name, db_user, account_id, is_voided)
    WHERE NOT EXISTS (SELECT 1 FROM organisation_group WHERE organisation_group.uuid = v.uuid);
    
    -- Create Organisations
    INSERT INTO organisation (uuid, name, db_user, username_suffix, account_id, category_id, status_id, is_voided, schema_name)
    SELECT * FROM (VALUES
        ('test-org-1-uuid', 'Test Health Org 1', 'test_health_org1', 'health1', default_account_id, org_category_id, org_status_id, false, 'test_health_org1'),
        ('test-org-2-uuid', 'Test Health Org 2', 'test_health_org2', 'health2', default_account_id, org_category_id, org_status_id, false, 'test_health_org2'),
        ('test-org-3-uuid', 'Test Education Org', 'test_edu_org', 'edu1', default_account_id, org_category_id, org_status_id, false, 'test_edu_org'),
        ('test-org-4-uuid', 'Test Community Org', 'test_community_org', 'community1', default_account_id, org_category_id, org_status_id, false, 'test_community_org'),
        ('test-org-5-uuid', 'Test Rural Health', 'test_rural_health', 'rural1', default_account_id, org_category_id, org_status_id, false, 'test_rural_health')
    ) AS v(uuid, name, db_user, username_suffix, account_id, category_id, status_id, is_voided, schema_name)
    WHERE NOT EXISTS (SELECT 1 FROM organisation WHERE organisation.uuid = v.uuid);
    
    -- Get created org IDs
    SELECT id INTO test_org_id1 FROM organisation WHERE uuid = 'test-org-1-uuid';
    SELECT id INTO test_org_id2 FROM organisation WHERE uuid = 'test-org-2-uuid';
    SELECT id INTO test_org_id3 FROM organisation WHERE uuid = 'test-org-3-uuid';
    
    -- Link organisations to groups
    INSERT INTO organisation_group_organisation (name, organisation_group_id, organisation_id)
    SELECT 
        'Health Network - ' || o.name,
        (SELECT id FROM organisation_group WHERE uuid = 'test-org-group-1-uuid'),
        o.id
    FROM organisation o
    WHERE o.uuid IN ('test-org-1-uuid', 'test-org-2-uuid', 'test-org-5-uuid')
    ON CONFLICT DO NOTHING;
    
    INSERT INTO organisation_group_organisation (name, organisation_group_id, organisation_id)
    SELECT 
        'Education Network - ' || o.name,
        (SELECT id FROM organisation_group WHERE uuid = 'test-org-group-2-uuid'),
        o.id
    FROM organisation o
    WHERE o.uuid = 'test-org-3-uuid'
    ON CONFLICT DO NOTHING;
    
    INSERT INTO organisation_group_organisation (name, organisation_group_id, organisation_id)
    SELECT 
        'Community Network - ' || o.name,
        (SELECT id FROM organisation_group WHERE uuid = 'test-org-group-3-uuid'),
        o.id
    FROM organisation o
    WHERE o.uuid = 'test-org-4-uuid'
    ON CONFLICT DO NOTHING;
    
    RAISE NOTICE 'Test data created successfully!';
    RAISE NOTICE 'Organisation Groups: %', (SELECT COUNT(*) FROM organisation_group WHERE name LIKE 'Test %');
    RAISE NOTICE 'Organisations: %', (SELECT COUNT(*) FROM organisation WHERE name LIKE 'Test %');
    RAISE NOTICE 'Group-Org Links: %', (SELECT COUNT(*) FROM organisation_group_organisation WHERE organisation_group_id IN (SELECT id FROM organisation_group WHERE name LIKE 'Test %'));
END $$;
