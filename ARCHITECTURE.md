# Avni Server Architecture

## Overview

Avni Server is a Spring Boot-based backend API server designed for health and social data collection with sophisticated offline-first synchronization capabilities. It supports multi-tenancy, role-based access control, and integrates with mobile and web clients.

## Technology Stack

- **Framework**: Spring Boot 3.3.5
- **Language**: Java 21
- **Build Tool**: Gradle 8.x
- **Database**: PostgreSQL with extensions (uuid-ossp, ltree, hstore)
- **ORM**: Spring Data JPA (Hibernate 6.5.2)
- **Migration**: Flyway 10.20.1
- **Security**: Spring Security with Keycloak or AWS Cognito
- **Caching**: EHCache 3.10.8
- **Batch Processing**: Spring Batch
- **Rule Engine**: GraalVM JavaScript
- **Cloud**: AWS S3, Cognito
- **Date/Time**: Joda Time

## Project Structure

### Multi-Module Architecture

```
avni-server/
├── avni-server-api/       # REST API, Services, Controllers, DTOs
├── avni-server-data/      # Domain Entities, Repositories
└── avni-rule-server/      # JavaScript Rule Execution Engine
```

### Module Responsibilities

#### avni-server-api
- REST controllers and API endpoints
- Business logic services
- DTO (Data Transfer Objects)
- Mappers (DTO ↔ Entity conversion)
- Flyway database migrations
- Configuration and security

#### avni-server-data
- JPA domain entities
- Repository interfaces
- Database projections
- Shared data layer

#### avni-rule-server
- GraalVM-based JavaScript execution
- Business rule evaluation
- Decision support logic

## Architecture Patterns

### Layered Architecture

```
Controller Layer    → HTTP endpoints, request/response handling
    ↓
Service Layer       → Business logic, transaction management
    ↓
Repository Layer    → Data access, external service calls
    ↓
Database Layer      → PostgreSQL persistence
```

### Component Responsibilities

**Controller:**
- HTTP endpoint handling
- Request validation
- Response formatting
- Delegates to Service layer

**Service:**
- Business logic implementation
- Transaction management
- Orchestration of multiple repositories
- Can use Mapper, Repository, or other Services

**Mapper:**
- Transform between DTOs and Entities
- Uses Repository (not Service)
- Handles data structure conversion

**Repository:**
- Database operations via JPA
- External service calls (S3, Metabase)
- Query optimization

**DTO Types:**
- Request DTO: Input validation
- Response DTO: Output formatting
- Contract DTO: Shared between request/response

### Base Classes

**CHSEntity:**
- Base class for all domain entities
- Audit fields: createdBy, lastModifiedBy, createdDateTime, lastModifiedDateTime
- UUID-based identification
- Soft delete support (isVoided)

**CHSRepository<T>:**
- Base repository interface
- Common CRUD operations
- Sync support methods
- Void-aware queries

**SyncableRepository<T>:**
- Sync-specific operations
- Pagination support
- Change detection

**AbstractController<T>:**
- Common controller functionality
- Standard CRUD endpoints
- Error handling

## Multi-Tenancy Architecture

### Organization-Based Isolation

- Each request scoped to an organization
- JDBC interceptor enforces organization context
- Flyway sets organization context per request
- All queries automatically filtered by organization

### Implementation

```
Request → Security Filter → Set Organisation Context → Query Execution
```

- Organisation ID stored in thread-local storage
- Database queries automatically scoped
- No cross-organization data leakage

## Data Synchronization Architecture

### Key Principles

1. **Offline-First**: Mobile apps work offline, sync when connected
2. **Incremental Sync**: Only changed data transferred
3. **Pagination**: Large datasets split into manageable chunks
4. **Consistency**: Ordered by lastModifiedDateTime + ID
5. **Concurrent Safe**: 10-second buffer for flush delays

### Sync Flow

```
Mobile App → Request Sync → Server Calculates Changes → Paginated Response
    ↓
Apply Changes Locally
    ↓
Request Next Page → Repeat Until Complete
```

### Sync Parameters

- **lastModifiedDateTime**: Timestamp of last sync
- **pageSize**: Number of records per page
- **catchmentId**: Geographic scope filter
- **subjectTypeUUID**: Subject type filter
- **syncWindow**: (lastModifiedDateTime, now - 10 seconds)

### Sync Services

**ScopeBasedSyncService<T>:**
- For data filtered by catchment and subject type
- Geographic and type-based scoping
- Used for subjects, encounters, programs

**NonScopeAwareService:**
- For reference data (no filtering)
- Used for metadata, forms, concepts

**DeviceAwareService:**
- Device-specific sync handling
- User-specific data filtering

### Sync Controllers

- **SyncController**: Central sync coordination
- **SyncSubjectController**: Individual subject sync
- **ResetSyncController**: Sync reset operations

## Domain Model

### Core Entities

**Subject:**
- Individual, Household, or Group
- Subject type defines structure
- Location-based (catchment)
- Audit trail

**Encounter:**
- Interaction with subject
- Encounter type defines structure
- Form-based data collection
- Scheduled or unscheduled

**Program:**
- Enrollment of subject in program
- Program-specific workflows
- Entry/exit criteria

**Form:**
- Form elements and structure
- Validation rules
- Skip logic
- Decision support

**Concept:**
- Data dictionary
- Coded values
- Numeric ranges
- Date constraints

**Location:**
- Hierarchical structure (ltree)
- Catchment areas
- Address levels

**User:**
- Authentication and authorization
- Role-based access
- Catchment assignment

## Security Architecture

### Authentication

**Two Modes:**

1. **Keycloak** (On-Premise)
   - Self-hosted identity provider
   - OIDC/OAuth2
   - JWT tokens

2. **AWS Cognito** (Cloud)
   - Managed identity service
   - JWT tokens
   - User pools

### Authorization

**Role-Based Access Control (RBAC):**
- Admin: Full system access
- Organisation Admin: Organisation-level access
- User: Data entry and viewing
- Custom roles: Configurable permissions

**Method-Level Security:**
```java
@PreAuthorize("hasAnyAuthority('Admin', 'Organisation_Admin')")
public ResponseEntity<?> createOrganisation() { ... }
```

### Data Security

- Organisation-based data isolation
- Catchment-based data filtering
- Audit logging
- Soft deletes (no hard deletes)

## Database Architecture

### PostgreSQL Extensions

- **uuid-ossp**: UUID generation
- **ltree**: Hierarchical location data
- **hstore**: Key-value storage

### Migration Strategy

**Flyway:**
- Version-controlled migrations
- Naming: `V{version}__{description}.sql`
- Repeatable migrations for views/functions
- Rollback support

### Indexing Strategy

- UUID indexes for lookups
- Composite indexes for sync queries
- lastModifiedDateTime indexes for pagination
- ltree indexes for location hierarchy

### Audit Trail

All entities track:
- Created by (user)
- Created date/time
- Last modified by (user)
- Last modified date/time
- Voided status

## API Design

### RESTful Endpoints

```
GET    /api/{resource}           # List all
GET    /api/{resource}/{id}      # Get by ID
POST   /api/{resource}           # Create
PUT    /api/{resource}/{id}      # Update
DELETE /api/{resource}/{id}      # Soft delete
```

### Sync Endpoints

```
GET /api/sync                    # Full sync
GET /api/{resource}/sync         # Resource-specific sync
POST /api/sync/reset             # Reset sync
```

### Response Format

```json
{
  "content": [...],
  "page": {
    "size": 100,
    "totalElements": 1000,
    "totalPages": 10,
    "number": 0
  }
}
```

## Business Rules Engine

### GraalVM JavaScript Execution

- Rules written in JavaScript
- Executed server-side
- Sandboxed environment
- Performance optimized

### Rule Types

1. **Validation Rules**: Data validation
2. **Decision Support**: Clinical decision support
3. **Visit Schedule**: Automated visit scheduling
4. **Checklists**: Dynamic checklist generation

### Rule Execution Flow

```
Data Entry → Trigger Rule → Execute JavaScript → Return Result → Apply Logic
```

## Integration Points

### AWS S3
- Media file storage
- Bulk upload files
- Export files
- Backup storage

### Metabase
- Embedded analytics
- Report generation
- Dashboard creation
- JWT-based authentication

### External APIs
- SMS gateways
- WhatsApp integration
- Payment gateways
- Third-party data sources

## Performance Optimization

### Caching Strategy

**EHCache:**
- Metadata caching (forms, concepts)
- User session caching
- Organisation configuration caching
- TTL-based expiration

### Query Optimization

- Pagination for large datasets
- Lazy loading for relationships
- Projection queries for specific fields
- Index optimization

### Connection Pooling

- HikariCP for connection management
- Configurable pool size
- Connection timeout handling

## Batch Processing

### Spring Batch

**Use Cases:**
- Bulk data import
- Report generation
- Data cleanup
- Scheduled tasks

**Job Structure:**
```
Job → Step → Reader → Processor → Writer
```

## Testing Strategy

### Test Types

**Unit Tests:**
- JUnit 4
- Mockito for mocking
- Test business logic in isolation

**Integration Tests:**
- Spring Boot Test
- Test database (openchs_test)
- Full application context
- Database transactions

**External Tests:**
- Test external integrations
- Metabase, S3, etc.
- Separate test suite

### Test Database

- Automatically managed
- Flyway migrations applied
- Test data setup via @Sql annotations
- Rollback after each test

## Deployment Architecture

### Build Process

```bash
./gradlew clean build
# Output: avni-server-api/build/libs/avni-server-0.0.1-SNAPSHOT.jar
```

### Docker Support

```dockerfile
FROM openjdk:21-jdk-slim
COPY avni-server-api/build/libs/*.jar app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]
```

### Environment Configuration

**Required:**
- `OPENCHS_DATABASE`: Database name
- `AVNI_IDP_TYPE`: Identity provider (keycloak/cognito/none)

**Optional:**
- `OPENCHS_DATABASE_HOST`: Database host
- `OPENCHS_DATABASE_PORT`: Database port
- `OPENCHS_MODE`: Deployment mode (live/on-premise)
- `OPENCHS_CLIENT_ID`: Cognito client ID
- `OPENCHS_USER_POOL`: Cognito user pool ID

## Monitoring and Logging

### Logging

- SLF4J with Logback
- Structured logging
- Log levels: DEBUG, INFO, WARN, ERROR
- Request/response logging

### Metrics

- Spring Boot Actuator
- Health checks
- Performance metrics
- Custom metrics

### Error Handling

- Global exception handler
- Standardized error responses
- Error logging
- Client-friendly error messages

## Development Workflow

### Adding New Entity

1. Create entity in `avni-server-data/domain/`
2. Extend `CHSEntity`
3. Create repository in `avni-server-data/dao/`
4. Add Flyway migration
5. Create service in `avni-server-api/service/`
6. Create DTOs and mappers
7. Create controller in `avni-server-api/web/`
8. Add tests

### Adding API Endpoint

1. Add method to controller
2. Use `@PreAuthorize` for access control
3. Create request/response DTOs
4. Delegate to service layer
5. Add integration test

### Database Migration

1. Create migration file in `db/migration/`
2. Name: `V{version}__{description}.sql`
3. Test locally: `make deploy_schema`
4. Commit with code changes

## Code Conventions

### Naming Conventions

- **Entities**: Singular noun (Subject, Encounter)
- **Repositories**: EntityRepository (SubjectRepository)
- **Services**: EntityService (SubjectService)
- **Controllers**: EntityController (SubjectController)
- **DTOs**: EntityRequest/Response/Contract

### Code Style

- **Indentation**: 4 spaces
- **Line Length**: 120 characters
- **Comments**: Only when necessary
- **JavaDocs**: For public APIs

### Method Placement

- Always add new methods at end of file
- Group related methods together
- Public methods before private

## Future Enhancements

- GraphQL API support
- Real-time sync via WebSockets
- Event sourcing for audit trail
- Microservices architecture
- Kubernetes deployment
- Advanced analytics engine
