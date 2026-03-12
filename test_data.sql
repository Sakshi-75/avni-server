-- Avni Test Data Setup Script
-- This script creates dummy data for testing the Avni application

BEGIN;

-- 1. Create Address Level Types (Location Hierarchy)
INSERT INTO address_level_type (id, uuid, name, level, audit_id, version, organisation_id, is_voided)
VALUES 
    (100, 'test-state-type-uuid', 'State', 1.0, 1, 1, 1, false),
    (101, 'test-district-type-uuid', 'District', 2.0, 1, 1, 1, false),
    (102, 'test-block-type-uuid', 'Block', 3.0, 1, 1, 1, false),
    (103, 'test-village-type-uuid', 'Village', 4.0, 1, 1, 1, false)
ON CONFLICT (uuid) DO NOTHING;

-- 2. Create Address Levels (Locations)
INSERT INTO address_level (id, uuid, title, level, type_id, audit_id, version, organisation_id, is_voided)
VALUES
    (100, 'test-state-1-uuid', 'Test State', 1.0, 100, 1, 1, 1, false),
    (101, 'test-district-1-uuid', 'Test District', 2.0, 101, 1, 1, 1, false),
    (102, 'test-block-1-uuid', 'Test Block', 3.0, 102, 1, 1, 1, false),
    (103, 'test-village-1-uuid', 'Test Village 1', 4.0, 103, 1, 1, 1, false),
    (104, 'test-village-2-uuid', 'Test Village 2', 4.0, 103, 1, 1, 1, false)
ON CONFLICT (uuid) DO NOTHING;

-- Set parent relationships for locations
UPDATE address_level SET parent_id = 100 WHERE id = 101;
UPDATE address_level SET parent_id = 101 WHERE id = 102;
UPDATE address_level SET parent_id = 102 WHERE id IN (103, 104);

-- 3. Create Catchment
INSERT INTO catchment (id, uuid, name, type, audit_id, version, organisation_id, is_voided)
VALUES (100, 'test-catchment-uuid', 'Test Catchment', 'TypeOfCatchment', 1, 1, 1, false)
ON CONFLICT (uuid) DO NOTHING;

-- Map catchment to locations
INSERT INTO catchment_address_mapping (id, catchment_id, addresslevel_id, audit_id, version, organisation_id, is_voided)
VALUES 
    (100, 100, 102, 1, 1, 1, false),
    (101, 100, 103, 1, 1, 1, false),
    (102, 100, 104, 1, 1, 1, false)
ON CONFLICT DO NOTHING;

-- 4. Create Concepts
INSERT INTO concept (id, uuid, name, data_type, audit_id, version, organisation_id, is_voided)
VALUES
    (100, 'test-concept-name-uuid', 'Name', 'Text', 1, 1, 1, false),
    (101, 'test-concept-age-uuid', 'Age', 'Numeric', 1, 1, 1, false),
    (102, 'test-concept-gender-uuid', 'Gender', 'Coded', 1, 1, 1, false),
    (103, 'test-concept-male-uuid', 'Male', 'NA', 1, 1, 1, false),
    (104, 'test-concept-female-uuid', 'Female', 'NA', 1, 1, 1, false),
    (105, 'test-concept-other-uuid', 'Other', 'NA', 1, 1, 1, false),
    (106, 'test-concept-blood-pressure-uuid', 'Blood Pressure', 'Text', 1, 1, 1, false),
    (107, 'test-concept-weight-uuid', 'Weight', 'Numeric', 1, 1, 1, false)
ON CONFLICT (uuid) DO NOTHING;

-- Create concept answers for Gender
INSERT INTO concept_answer (id, uuid, concept_id, answer_concept_id, answer_order, audit_id, version, organisation_id, is_voided, abnormal)
VALUES
    (100, 'test-gender-male-answer-uuid', 102, 103, 1.0, 1, 1, 1, false, false),
    (101, 'test-gender-female-answer-uuid', 102, 104, 2.0, 1, 1, 1, false, false),
    (102, 'test-gender-other-answer-uuid', 102, 105, 3.0, 1, 1, 1, false, false)
ON CONFLICT (uuid) DO NOTHING;

-- 5. Create Subject Type (e.g., Person, Household)
INSERT INTO subject_type (id, uuid, name, audit_id, version, organisation_id, is_voided, type)
VALUES 
    (100, 'test-person-subject-type-uuid', 'Person', 1, 1, 1, false, 'Person'),
    (101, 'test-household-subject-type-uuid', 'Household', 1, 1, 1, false, 'Household')
ON CONFLICT (uuid) DO NOTHING;

-- 6. Create Form (Registration Form)
INSERT INTO form (id, uuid, name, form_type, audit_id, version, organisation_id, is_voided)
VALUES (100, 'test-registration-form-uuid', 'Person Registration', 'IndividualProfile', 1, 1, 1, false)
ON CONFLICT (uuid) DO NOTHING;

-- 7. Create Form Elements
INSERT INTO form_element_group (id, uuid, name, display_order, form_id, audit_id, version, organisation_id, is_voided)
VALUES (100, 'test-form-element-group-uuid', 'Basic Details', 1.0, 100, 1, 1, 1, false)
ON CONFLICT (uuid) DO NOTHING;

INSERT INTO form_element (id, uuid, name, display_order, is_mandatory, concept_id, form_element_group_id, audit_id, version, organisation_id, is_voided, type)
VALUES
    (100, 'test-form-element-name-uuid', 'Name', 1.0, true, 100, 100, 1, 1, 1, false, 'SingleSelect'),
    (101, 'test-form-element-age-uuid', 'Age', 2.0, true, 101, 100, 1, 1, 1, false, 'Numeric'),
    (102, 'test-form-element-gender-uuid', 'Gender', 3.0, true, 102, 100, 1, 1, 1, false, 'SingleSelect')
ON CONFLICT (uuid) DO NOTHING;

-- 8. Create Encounter Type
INSERT INTO encounter_type (id, uuid, name, audit_id, version, organisation_id, is_voided)
VALUES (100, 'test-health-checkup-encounter-uuid', 'Health Checkup', 1, 1, 1, false)
ON CONFLICT (uuid) DO NOTHING;

-- 9. Create Program
INSERT INTO program (id, uuid, name, colour, audit_id, version, organisation_id, is_voided)
VALUES (100, 'test-health-program-uuid', 'Health Monitoring Program', '#FF5733', 1, 1, 1, false)
ON CONFLICT (uuid) DO NOTHING;

-- 10. Create Test Subjects (Individuals)
INSERT INTO individual (id, uuid, first_name, last_name, date_of_birth, gender_id, address_level_id, subject_type_id, audit_id, version, organisation_id, is_voided, registration_date)
VALUES
    (100, 'test-individual-1-uuid', 'John', 'Doe', '1990-01-15', 103, 103, 100, 1, 1, 1, false, '2024-01-01'),
    (101, 'test-individual-2-uuid', 'Jane', 'Smith', '1985-05-20', 104, 103, 100, 1, 1, 1, false, '2024-01-02'),
    (102, 'test-individual-3-uuid', 'Bob', 'Johnson', '1995-08-10', 103, 104, 100, 1, 1, 1, false, '2024-01-03'),
    (103, 'test-individual-4-uuid', 'Alice', 'Williams', '1992-12-25', 104, 104, 100, 1, 1, 1, false, '2024-01-04')
ON CONFLICT (uuid) DO NOTHING;

-- 11. Create Program Enrolments
INSERT INTO program_enrolment (id, uuid, individual_id, program_id, enrolment_date_time, audit_id, version, organisation_id, is_voided)
VALUES
    (100, 'test-enrolment-1-uuid', 100, 100, '2024-01-10 10:00:00', 1, 1, 1, false),
    (101, 'test-enrolment-2-uuid', 101, 100, '2024-01-11 11:00:00', 1, 1, 1, false),
    (102, 'test-enrolment-3-uuid', 102, 100, '2024-01-12 09:00:00', 1, 1, 1, false)
ON CONFLICT (uuid) DO NOTHING;

-- 12. Create Encounters
INSERT INTO encounter (id, uuid, encounter_type_id, individual_id, encounter_date_time, audit_id, version, organisation_id, is_voided)
VALUES
    (100, 'test-encounter-1-uuid', 100, 100, '2024-02-01 10:00:00', 1, 1, 1, false),
    (101, 'test-encounter-2-uuid', 100, 101, '2024-02-02 11:00:00', 1, 1, 1, false),
    (102, 'test-encounter-3-uuid', 100, 102, '2024-02-03 09:00:00', 1, 1, 1, false)
ON CONFLICT (uuid) DO NOTHING;

-- 13. Create Program Encounters
INSERT INTO program_encounter (id, uuid, program_enrolment_id, encounter_type_id, encounter_date_time, audit_id, version, organisation_id, is_voided)
VALUES
    (100, 'test-program-encounter-1-uuid', 100, 100, '2024-02-15 10:00:00', 1, 1, 1, false),
    (101, 'test-program-encounter-2-uuid', 101, 100, '2024-02-16 11:00:00', 1, 1, 1, false)
ON CONFLICT (uuid) DO NOTHING;

-- Update sequences to avoid conflicts
SELECT setval('address_level_type_id_seq', 200);
SELECT setval('address_level_id_seq', 200);
SELECT setval('catchment_id_seq', 200);
SELECT setval('catchment_address_mapping_id_seq', 200);
SELECT setval('concept_id_seq', 200);
SELECT setval('concept_answer_id_seq', 200);
SELECT setval('subject_type_id_seq', 200);
SELECT setval('form_id_seq', 200);
SELECT setval('form_element_group_id_seq', 200);
SELECT setval('form_element_id_seq', 200);
SELECT setval('encounter_type_id_seq', 200);
SELECT setval('program_id_seq', 200);
SELECT setval('individual_id_seq', 200);
SELECT setval('program_enrolment_id_seq', 200);
SELECT setval('encounter_id_seq', 200);
SELECT setval('program_encounter_id_seq', 200);

-- Verify data
SELECT 'Address Levels Created:' as info, COUNT(*) as count FROM address_level WHERE id >= 100 AND id < 200;
SELECT 'Subjects Created:' as info, COUNT(*) as count FROM individual WHERE id >= 100 AND id < 200;
SELECT 'Program Enrolments Created:' as info, COUNT(*) as count FROM program_enrolment WHERE id >= 100 AND id < 200;
SELECT 'Encounters Created:' as info, COUNT(*) as count FROM encounter WHERE id >= 100 AND id < 200;

COMMIT;
