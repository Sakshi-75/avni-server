#!/bin/bash
# Script to dump PostgreSQL schema after migrations for CI testing

set -e

cd "$(dirname "$0")"

# Check PostgreSQL
if ! pg_isready -h localhost -p 5432 > /dev/null 2>&1; then
    echo "Error: PostgreSQL not running on localhost:5432"
    exit 1
fi

# Recreate database
echo "Recreating openchs_test database..."
PGPASSWORD=password psql -h localhost -U openchs -d postgres -c "DROP DATABASE IF EXISTS openchs_test;"
PGPASSWORD=password psql -h localhost -U openchs -d postgres -c "CREATE DATABASE openchs_test;"

# Run integration test to trigger migrations
echo "Running integration test to trigger Flyway migrations..."
./gradlew :avni-server-api:integrationTest --tests "GlificRestClientTest.shouldAuthenticateWithGlific" || true

# Dump schema
echo "Dumping schema..."
PGPASSWORD=password pg_dump -h localhost -U openchs -d openchs_test \
    --schema-only \
    --no-owner \
    --no-privileges \
    -f avni-server-api/src/test/resources/schema_dump.sql

echo "Done! Schema saved to avni-server-api/src/test/resources/schema_dump.sql"
