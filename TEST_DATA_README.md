# Avni Test Data Summary

## Test Data Created

✅ **10 Test Subjects** have been added to your `openchs` database.

### Subject Details

| ID  | UUID                  | First Name | Last Name  | Date of Birth | Registration Date |
|-----|-----------------------|------------|------------|---------------|-------------------|
| 201 | test-subject-1-uuid   | TestUser1  | LastName1  | 1990-01-02    | 2026-03-10        |
| 202 | test-subject-2-uuid   | TestUser2  | LastName2  | 1990-01-03    | 2026-03-09        |
| 203 | test-subject-3-uuid   | TestUser3  | LastName3  | 1990-01-04    | 2026-03-08        |
| 204 | test-subject-4-uuid   | TestUser4  | LastName4  | 1990-01-05    | 2026-03-07        |
| 205 | test-subject-5-uuid   | TestUser5  | LastName5  | 1990-01-06    | 2026-03-06        |
| 206 | test-subject-6-uuid   | TestUser6  | LastName6  | 1990-01-07    | 2026-03-05        |
| 207 | test-subject-7-uuid   | TestUser7  | LastName7  | 1990-01-08    | 2026-03-04        |
| 208 | test-subject-8-uuid   | TestUser8  | LastName8  | 1990-01-09    | 2026-03-03        |
| 209 | test-subject-9-uuid   | TestUser9  | LastName9  | 1990-01-10    | 2026-03-02        |
| 210 | test-subject-10-uuid  | TestUser10 | LastName10 | 1990-01-11    | 2026-03-01        |

## Scripts Available

### 1. `simple_test_data.sql` (✅ Executed Successfully)
- Creates 10 test subjects with realistic data
- Uses existing default organization and user
- Safe to run multiple times (uses ON CONFLICT DO NOTHING)

### 2. `test_data.sql` (⚠️ Complex - Not Used)
- More comprehensive test data including locations, programs, encounters
- Requires schema adjustments
- Use for advanced testing scenarios

## How to Use

### View Test Data
```sql
-- View all test subjects
SELECT * FROM individual WHERE uuid LIKE 'test-subject-%';

-- Count test subjects
SELECT COUNT(*) FROM individual WHERE uuid LIKE 'test-subject-%';
```

### Add More Test Data
```bash
# Run the script again to add more subjects
psql -U openchs -d openchs -f simple_test_data.sql
```

### Clean Up Test Data
```sql
-- Delete all test subjects
DELETE FROM individual WHERE uuid LIKE 'test-subject-%';
```

## Testing with the API

You can now test the avni-server API with these subjects:

```bash
# Get all subjects
curl http://localhost:8021/api/subjects

# Get specific subject
curl http://localhost:8021/api/subject/test-subject-1-uuid
```

## Testing with the Webapp

1. Open http://localhost:6012 in your browser
2. Login with your credentials
3. Navigate to the subjects/individuals section
4. You should see the 10 test subjects listed

## Notes

- All test subjects use the default organization (ID: 1)
- All test subjects use the default subject type from your database
- Test subjects have UUIDs starting with `test-subject-` for easy identification
- Registration dates are staggered over the last 10 days
- Birth dates are staggered starting from 1990-01-02

## Next Steps

If you need more complex test data (programs, encounters, locations), let me know and I can:
1. Fix the comprehensive `test_data.sql` script
2. Create additional test data scripts for specific entities
3. Use the Java test builders to create data programmatically
