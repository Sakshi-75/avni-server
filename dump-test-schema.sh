#!/bin/bash
# Script to dump PostgreSQL schema after migrations for CI testing

set -e

cd "$(dirname "$0")"

# Check PostgreSQL
if ! pg_isready -h localhost -p 5432 > /dev/null 2>&1; then
    echo "Error: PostgreSQL not running on localhost:5432"
    exit 1
fi

# Recreate database for clean state
echo "Recreating openchs_test database..."
PGPASSWORD=password psql -h localhost -U openchs -d postgres -c "DROP DATABASE IF EXISTS openchs_test;"
PGPASSWORD=password psql -h localhost -U openchs -d postgres -c "CREATE DATABASE openchs_test;"

# Run bootstrap fix to create initial user before migrations
echo "Running bootstrap fix..."
PGPASSWORD=password psql -h localhost -U openchs -d openchs_test -f bootstrap-fix.sql

# Run integration test to trigger Flyway migrations
echo "Running integration test to trigger Flyway migrations..."
./gradlew :avni-server-api:integrationTest --tests "GlificRestClientTest.shouldAuthenticateWithGlific" -x test || true

# Check if migrations ran
TABLE_COUNT=$(PGPASSWORD=password psql -h localhost -U openchs -d openchs_test -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';")

if [ "$TABLE_COUNT" -lt 10 ]; then
    echo "Error: Migrations did not run successfully (only $TABLE_COUNT tables found)"
    exit 1
fi

# Dump schema
echo "Dumping schema from openchs_test ($TABLE_COUNT tables found)..."
PGPASSWORD=password pg_dump -h localhost -U openchs -d openchs_test \
    --schema-only \
    --no-owner \
    --no-privileges \
    -f avni-server-api/src/test/resources/schema_dump.sql

FILE_SIZE=$(wc -c < avni-server-api/src/test/resources/schema_dump.sql)
echo "Done! Schema saved to avni-server-api/src/test/resources/schema_dump.sql ($FILE_SIZE bytes)"
echo ""
echo "Next steps:"
echo "1. Review the schema_dump.sql file"
echo "2. Commit it to the repository"
echo "3. Update .github/workflows/backend-build.yml to load this schema"
