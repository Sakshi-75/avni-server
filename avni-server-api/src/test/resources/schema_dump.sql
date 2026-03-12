--
-- PostgreSQL database dump
--

\restrict mbQK4hFzgbubanh0VeOdKAIisfdgQNaxyxVA6Dn3aRFCxrcEHXL87qwZd5sdwhM

-- Dumped from database version 14.22 (Homebrew)
-- Dumped by pg_dump version 14.22 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: hstore; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS hstore WITH SCHEMA public;


--
-- Name: EXTENSION hstore; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION hstore IS 'data type for storing sets of (key, value) pairs';


--
-- Name: ltree; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS ltree WITH SCHEMA public;


--
-- Name: EXTENSION ltree; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION ltree IS 'data type for hierarchical tree-like structures';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: append_manual_update_history(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.append_manual_update_history(current_value text, text_to_be_added text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
    if current_value is null or trim(current_value) = '' then
        RETURN concat(to_char(current_timestamp, 'DD/MM/YYYY hh:mm:ss'), ' - ', text_to_be_added);
    else
        RETURN concat(to_char(current_timestamp, 'DD/MM/YYYY hh:mm:ss'), ' - ', text_to_be_added, ' || ',
                      current_value);
    end if;
END
$$;


--
-- Name: archive_sync_telemetry(date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.archive_sync_telemetry(olderthan date) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
    archived_row_count bigint;
BEGIN
    CREATE TABLE IF NOT EXISTS public.sync_telemetry_history
    (
        LIKE public.sync_telemetry INCLUDING ALL
    );
    PERFORM enable_rls_on_tx_table('sync_telemetry_history');
    INSERT INTO public.sync_telemetry_history SELECT * from public.sync_telemetry WHERE sync_start_time < olderthan;
    DELETE FROM public.sync_telemetry WHERE sync_start_time < olderthan;
    GET DIAGNOSTICS archived_row_count = ROW_COUNT;
    RETURN archived_row_count;
END;
$$;


--
-- Name: assert_one_of_subjects_with_sync_disabled(boolean, bigint, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.assert_one_of_subjects_with_sync_disabled(syncdisabled boolean, subjectid1 bigint, subjectid2 bigint) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
begin
    raise notice 'Checking sync disabled value: %, for subject ids: %, %', syncDisabled, subjectId1, subjectId2;
    if (select count(id) from public.individual subject where ((syncDisabled = false and subject.sync_disabled = false) or syncDisabled)
                                                          and subject.id in (subjectId1, subjectId2)) < 2 then
        raise 'Sync can be enabled only if both the subjects have sync enabled. Subject ids: %, %. Sync disabled: %',
            subjectId1, subjectId2, syncDisabled;
    end if;
    return true;
end
$$;


--
-- Name: assert_subject_with_same_sync_disabled(boolean, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.assert_subject_with_same_sync_disabled(syncdisabled boolean, subjectid bigint) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
begin
    raise notice 'Checking sync disabled value: %, for subject id: %', syncDisabled, subjectId;
    if exists(select id from public.individual subject where subject.sync_disabled <> syncDisabled and subjectId = subject.id) then
        raise 'Sync disabled value cannot be different from individual. For individual id: %, sync disabled: %',
            subjectId, syncDisabled;
    end if;
    return true;
end
$$;


--
-- Name: audit_table_trigger(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.audit_table_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    audit_id INTEGER;
BEGIN
    IF NEW.audit_id is null THEN
        audit_id = nextval('audit_id_seq');
        NEW.audit_id = audit_id;
        RAISE NOTICE 'setting value of audit to %', NEW.audit_id ;
        insert into audit (id, uuid, created_by_id, last_modified_by_id, created_date_time, last_modified_date_time)
        values (audit_id, uuid_generate_v4(), NEW.created_by_id, NEW.last_modified_by_id, NEW.created_date_time,
                NEW.last_modified_date_time);
    else
        update audit
        set last_modified_date_time = NEW.last_modified_date_time,
            last_modified_by_id     = NEW.last_modified_by_id
        where id = NEW.audit_id;
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: check_form_mapping_uniqueness(integer, integer, bigint, integer, integer, bigint, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_form_mapping_uniqueness(organisationid integer, subjecttypeid integer, entityid bigint, observationstypeentityid integer, tasktypeid integer, formid bigint, formmappingid integer, implversion integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
begin
    if exists (select form_mapping.*
               from public.form
                        inner join public.form_mapping on form_mapping.form_id = form.id
               where form_mapping.organisation_id = organisationId
                 and form_mapping.subject_type_id = subjectTypeId
                 and (form_mapping.entity_id = entityId or (form_mapping.entity_id is null and entityId is null))
                 and (form_mapping.observations_type_entity_id = observationsTypeEntityId or
                      (form_mapping.observations_type_entity_id is null and observationsTypeEntityId is null))
                 and (form_mapping.task_type_id = taskTypeId or (form_mapping.task_type_id is null and taskTypeId is null))
                 and form_mapping.impl_version = 1
                 and implVersion = 1
                 and form.form_type = (select public.form.form_type from form where id = formId)
                 and form_mapping.id <> formMappingId) then
        raise 'Duplicate form mapping exists for: organisation_id: %, subject_type_id: %, entity_id: %, observations_type_entity_id: %, task_type_id: %. Using formId: %, formMappingId: %.', organisationId, subjectTypeId, entityId, observationsTypeEntityId, taskTypeId, formId, formMappingId;
    end if;

    return true;
end
$$;


--
-- Name: check_form_mapping_uniqueness(integer, integer, bigint, integer, integer, bigint, integer, integer, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_form_mapping_uniqueness(organisationid integer, subjecttypeid integer, entityid bigint, observationstypeentityid integer, tasktypeid integer, formid bigint, formmappingid integer, implversion integer, formmappingisvoided boolean) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
    mapping_exists boolean;
begin
    -- Skip validation if mapping is voided
    if formMappingIsVoided = true then
        return true;
    end if;
    
    -- Check form type consistency
    select exists(
        select 1
        from public.form f
        where f.id = formId
          and (
              (f.form_type = 'IndividualProfile' and
               (entityId is not null or observationsTypeEntityId is not null))
                  or
              (f.form_type = 'ProgramEnrolment' and
               (entityId is null or observationsTypeEntityId is not null))
                  or
              (f.form_type = 'ProgramExit' and
               (entityId is null or observationsTypeEntityId is not null))
                  or
              (f.form_type = 'ProgramEncounter' and
               (entityId is null or observationsTypeEntityId is null))
                  or
              (f.form_type = 'ProgramEncounterCancellation' and
               (entityId is null or observationsTypeEntityId is null))
                  or
              (f.form_type = 'Encounter' and
               (entityId is not null or observationsTypeEntityId is null))
                  or
              (f.form_type = 'IndividualEncounterCancellation' and
               (entityId is not null or observationsTypeEntityId is null))
              )
    ) into mapping_exists;
    
    if mapping_exists then
        raise EXCEPTION 'Invalid form mapping(uuid: %): Form(uuid: %) is of type % and hence cannot be mapped % and %.',
               (select fm.uuid from form_mapping fm where fm.id = formMappingId),
               (select f.uuid from form f where f.id = formId),
               (select f.form_type from form f where f.id = formId),
               case when entityId is not null then 'with program' else 'without program' end,
               case when observationsTypeEntityId is not null then 'with encounter type' else 'without encounter type' end
        USING HINT = 'Form type rules: IndividualProfile - no program, no encounter type | ' ||
                   'ProgramEnrolment/Exit - with program, no encounter type | ' ||
                   'ProgramEncounter/Cancellation - with program and encounter type | ' ||
                   'Encounter/IndividualCancellation - no program, with encounter type';
    end if;

    -- Check for duplicate mappings
    select exists(
        select form_mapping.*
        from public.form
                 inner join form_mapping on form_mapping.form_id = form.id
        where form_mapping.organisation_id = organisationId
          and form_mapping.subject_type_id = subjectTypeId
          and (form_mapping.entity_id = entityId or (form_mapping.entity_id is null and entityId is null))
          and (form_mapping.observations_type_entity_id = observationsTypeEntityId or
               (form_mapping.observations_type_entity_id is null and observationsTypeEntityId is null))
          and (form_mapping.task_type_id = taskTypeId or
               (form_mapping.task_type_id is null and taskTypeId is null))
          and form_mapping.impl_version = 1
          and implVersion = 1
          and form.form_type = (select public.form.form_type from form where id = formId)
          and form_mapping.id <> formMappingId
    ) into mapping_exists;
    
    if mapping_exists then
        raise 'Duplicate form mapping exists for: organisation_id: %, subject_type_id: %, entity_id: %, observations_type_entity_id: %, task_type_id: %. Using formId: %, formMappingId: %.',
              organisationId, subjectTypeId, entityId, observationsTypeEntityId, taskTypeId, formId, formMappingId;
    end if;
    
    return true;
end
$$;


--
-- Name: check_group_privilege_uniqueness(integer, integer, integer, integer, integer, integer, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_group_privilege_uniqueness(groupprivilegeid integer, groupid integer, privilegeid integer, subjecttypeid integer, programid integer, programencountertypeid integer, encountertypeid integer, checklistdetailid integer, implversion integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
begin
  if exists (select gp.*
             from public.group_privilege gp
             where gp.group_id = groupId
               and gp.privilege_id = privilegeId
               and (gp.subject_type_id = subjectTypeId or (gp.subject_type_id is null and subjectTypeId is null))
               and (gp.program_id = programId or (gp.program_id is null and programId is null))
               and (gp.program_encounter_type_id = programEncounterTypeId or (gp.program_encounter_type_id is null and programEncounterTypeId is null))
               and (gp.encounter_type_id = encounterTypeId or (gp.encounter_type_id is null and encounterTypeId is null))
               and (gp.checklist_detail_id = checklistDetailId or (gp.checklist_detail_id is null and checklistDetailId is null))
               and gp.id <> groupPrivilegeId
               and gp.impl_version = 1
               and implVersion = 1
               ) then
    raise 'Duplicate group privilege exists for: id: %, group_id: %, privilege_id: % subject_type_id: %, program_id: %, program_encounter_type_id: %, encounter_type_id: %, checklist_detail_id: %', groupPrivilegeId, groupId, privilegeId, subjectTypeId, programId, programEncounterTypeId, encounterTypeId, checklistDetailId;
  end if;

  return true;
end
$$;


--
-- Name: checklist_item_sync_disabled_same_as_individual(boolean, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.checklist_item_sync_disabled_same_as_individual(syncdisabled boolean, checklistid bigint) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
begin
    if exists(select subject.id
              from public.individual subject
                       join program_enrolment pe on pe.individual_id = subject.id
                       join checklist c on c.program_enrolment_id = pe.id
              where subject.sync_disabled <> syncDisabled
                and c.id = checklistId)
    then
        raise 'Sync disabled value cannot be different from individual. For checklist id: %, sync disabled: %',
            checklistId, syncDisabled;
    end if;

    return true;
end
$$;


--
-- Name: checklist_sync_disabled_same_as_individual(boolean, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.checklist_sync_disabled_same_as_individual(syncdisabled boolean, programenrolmentid bigint) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
begin
    if exists(select subject.id
              from public.individual subject
                       join program_enrolment pe on pe.individual_id = subject.id
              where subject.sync_disabled <> syncDisabled
                and pe.id = programEnrolmentId) then
        raise 'Sync disabled value cannot be different from individual. For program enrolment id: %, sync disabled: %',
            programEnrolmentId, syncDisabled;
    end if;

    return true;
end
$$;


--
-- Name: comment_thread_sync_disabled_same_as_individual(boolean, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.comment_thread_sync_disabled_same_as_individual(syncdisabled boolean, commentthreadid bigint) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
begin
    if exists(select subject.id
              from public.individual subject
                       join comment c on c.subject_id = subject.id
                       join comment_thread ct on ct.id = c.comment_thread_id
              where subject.sync_disabled <> syncDisabled
                and ct.id = commentThreadId)
    then
        raise 'Sync disabled value cannot be different from individual. For comment thread id: %, sync disabled: %',
            commentThreadId, syncDisabled;
    end if;

    return true;
end
$$;


--
-- Name: concept_name(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.concept_name(text) RETURNS text
    LANGUAGE sql STABLE STRICT
    AS $_$
SELECT name
FROM concept
WHERE uuid = $1;
$_$;


--
-- Name: create_audit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_audit() RETURNS integer
    LANGUAGE sql
    AS $$select create_audit(1)$$;


--
-- Name: create_audit(numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_audit(user_id numeric) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    result INTEGER;
BEGIN
    INSERT INTO audit(created_by_id, last_modified_by_id, created_date_time, last_modified_date_time)
    VALUES (user_id, user_id, now(), now())
    RETURNING id into result;
    RETURN result;
END
$$;


--
-- Name: create_audit_columns(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_audit_columns(table_name text) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    execute 'alter table ' || table_name || '
        add column created_by_id           bigint,
        add column last_modified_by_id     bigint,
        add column created_date_time       timestamp(3) with time zone,
        add column last_modified_date_time timestamp(3) with time zone;';
    RAISE NOTICE 'added columns to %', table_name ;
END
$$;


--
-- Name: create_db_user(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_db_user(inrolname text, inpassword text) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NOT EXISTS(SELECT rolname FROM pg_roles WHERE rolname = inrolname)
    THEN
        EXECUTE 'CREATE ROLE ' || quote_ident(inrolname) || ' NOINHERIT LOGIN PASSWORD ' || quote_literal(inpassword);
    END IF;
    EXECUTE 'GRANT ' || quote_ident(inrolname) || ' TO openchs';
    PERFORM grant_all_on_all(inrolname);
    RETURN 1;
END
$$;


--
-- Name: create_implementation_schema(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_implementation_schema(schema_name text, db_user text) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
BEGIN
    EXECUTE 'CREATE SCHEMA IF NOT EXISTS "' || schema_name || '" AUTHORIZATION "' || db_user || '"';
    EXECUTE 'GRANT ALL PRIVILEGES ON SCHEMA "' || schema_name || '" TO "' || db_user || '"';
    RETURN 1;
END
$$;


--
-- Name: create_view(text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_view(schema_name text, view_name text, sql_query text) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
BEGIN
    --     EXECUTE 'set search_path = ' || ;
    EXECUTE 'DROP VIEW IF EXISTS ' || schema_name || '.' || view_name;
    EXECUTE 'CREATE OR REPLACE VIEW ' || schema_name || '.' || view_name || ' AS ' || sql_query;
    RETURN 1;
END
$$;


--
-- Name: delete_etl_metadata_for_org(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_etl_metadata_for_org(in_impl_schema text, in_db_user text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
    EXECUTE 'set role openchs;';
    execute 'drop schema "' || in_impl_schema || '" cascade;';
    execute 'delete from entity_sync_status where db_user = ''' || in_db_user || ''';';
    execute 'delete from entity_sync_status where schema_name = ''' || in_impl_schema || ''';';
    execute 'delete from index_metadata where table_metadata_id in (select id from table_metadata where schema_name = ''' ||
            in_impl_schema || ''');';
    execute 'delete from column_metadata where table_id in (select id from table_metadata where schema_name = ''' ||
            in_impl_schema || ''');';
    execute 'delete from table_metadata where schema_name = ''' || in_impl_schema || ''';';
    execute 'delete from post_etl_sync_status where db_user = ''' || in_db_user || ''';';
    return true;
END
$$;


--
-- Name: delete_etl_metadata_for_schema(text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_etl_metadata_for_schema(in_impl_schema text, in_db_user text, in_db_owner text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
    execute 'set role "' || in_db_owner || '";';
    execute 'drop schema if exists "' || in_impl_schema || '" cascade;';
    execute 'delete from entity_sync_status where db_user = ''' || in_db_user || ''';';
    execute 'delete from entity_sync_status where schema_name = ''' || in_impl_schema || ''';';
    execute 'delete from index_metadata where table_metadata_id in (select id from table_metadata where schema_name = ''' ||
            in_impl_schema || ''');';
    execute 'delete from column_metadata where table_id in (select id from table_metadata where schema_name = ''' ||
            in_impl_schema || ''');';
    execute 'delete from table_metadata where schema_name = ''' || in_impl_schema || ''';';
    execute 'delete from post_etl_sync_status where db_user = ''' || in_db_user || ''';';
    return true;
END
$$;


--
-- Name: delete_etl_table_metadata(text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_etl_table_metadata(in_impl_schema text, in_db_owner text, in_table_name text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
    execute 'set role "' || in_db_owner || '";';
    execute 'delete from entity_sync_status where table_metadata_id = (select id from table_metadata where name = ''' ||
            in_table_name || ''' and schema_name = ''' || in_impl_schema || ''');';
    execute 'delete from index_metadata where table_metadata_id = (select id from table_metadata where name = ''' ||
            in_table_name || ''' and schema_name = ''' || in_impl_schema || ''');';
    execute 'delete from column_metadata where table_id = (select id from table_metadata where name = ''' ||
            in_table_name || ''' and schema_name = ''' || in_impl_schema || ''');';
    execute 'delete from table_metadata where name = ''' || in_table_name || ''' and schema_name = ''' ||
            in_impl_schema || ''';';
    execute 'drop table if exists "' || in_impl_schema || '"."' || in_table_name || '"';
    return true;
END
$$;


--
-- Name: deps_restore_dependencies(character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.deps_restore_dependencies(p_view_schema character varying, p_view_name character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
    v_curr record;
begin
    for v_curr in
        (
            select deps_ddl_to_run
            from deps_saved_ddl
            where deps_view_schema = p_view_schema
              and deps_view_name = p_view_name
            order by deps_id desc
        )
        loop
            execute v_curr.deps_ddl_to_run;
        end loop;
    delete
    from deps_saved_ddl
    where deps_view_schema = p_view_schema
      and deps_view_name = p_view_name;
end;
$$;


--
-- Name: deps_save_and_drop_dependencies(character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.deps_save_and_drop_dependencies(p_view_schema character varying, p_view_name character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
    v_curr record;
begin
    for v_curr in
        (
            select obj_schema, obj_name, obj_type
            from (
                     with recursive recursive_deps(obj_schema, obj_name, obj_type, depth) as
                                        (
                                            select p_view_schema COLLATE "C", p_view_name COLLATE "C", null::varchar, 0
                                            union
                                            select dep_schema::varchar,
                                                   dep_name::varchar,
                                                   dep_type::varchar,
                                                   recursive_deps.depth + 1
                                            from (
                                                     select ref_nsp.nspname ref_schema,
                                                            ref_cl.relname  ref_name,
                                                            rwr_cl.relkind  dep_type,
                                                            rwr_nsp.nspname dep_schema,
                                                            rwr_cl.relname  dep_name
                                                     from pg_depend dep
                                                              join pg_class ref_cl on dep.refobjid = ref_cl.oid
                                                              join pg_namespace ref_nsp on ref_cl.relnamespace = ref_nsp.oid
                                                              join pg_rewrite rwr on dep.objid = rwr.oid
                                                              join pg_class rwr_cl on rwr.ev_class = rwr_cl.oid
                                                              join pg_namespace rwr_nsp on rwr_cl.relnamespace = rwr_nsp.oid
                                                     where dep.deptype = 'n'
                                                       and dep.classid = 'pg_rewrite'::regclass
                                                 ) deps
                                                     join recursive_deps
                                                          on deps.ref_schema = recursive_deps.obj_schema and
                                                             deps.ref_name = recursive_deps.obj_name
                                            where (deps.ref_schema != deps.dep_schema or deps.ref_name != deps.dep_name)
                                        )
                     select obj_schema, obj_name, obj_type, depth
                     from recursive_deps
                     where depth > 0
                 ) t
            group by obj_schema, obj_name, obj_type
            order by max(depth) desc
        )
        loop

            insert into deps_saved_ddl(deps_view_schema, deps_view_name, deps_ddl_to_run)
            select p_view_schema,
                   p_view_name,
                   'COMMENT ON ' ||
                   case
                       when c.relkind = 'v' then 'VIEW'
                       when c.relkind = 'm' then 'MATERIALIZED VIEW'
                       else ''
                       end
                       || ' ' || n.nspname || '.' || c.relname || ' IS ''' || replace(d.description, '''', '''''') ||
                   ''';'
            from pg_class c
                     join pg_namespace n on n.oid = c.relnamespace
                     join pg_description d on d.objoid = c.oid and d.objsubid = 0
            where n.nspname = v_curr.obj_schema
              and c.relname = v_curr.obj_name
              and d.description is not null;

            insert into deps_saved_ddl(deps_view_schema, deps_view_name, deps_ddl_to_run)
            select p_view_schema,
                   p_view_name,
                   'COMMENT ON COLUMN ' || n.nspname || '.' || c.relname || '.' || a.attname || ' IS ''' ||
                   replace(d.description, '''', '''''') || ''';'
            from pg_class c
                     join pg_attribute a on c.oid = a.attrelid
                     join pg_namespace n on n.oid = c.relnamespace
                     join pg_description d on d.objoid = c.oid and d.objsubid = a.attnum
            where n.nspname = v_curr.obj_schema
              and c.relname = v_curr.obj_name
              and d.description is not null;

            insert into deps_saved_ddl(deps_view_schema, deps_view_name, deps_ddl_to_run)
            select p_view_schema,
                   p_view_name,
                   'GRANT ' || privilege_type || ' ON ' || table_schema || '.' || table_name || ' TO ' || '"' ||
                   grantee || '"'
            from information_schema.role_table_grants
            where table_schema = v_curr.obj_schema
              and table_name = v_curr.obj_name;

            if v_curr.obj_type = 'v' then
                insert into deps_saved_ddl(deps_view_schema, deps_view_name, deps_ddl_to_run)
                select p_view_schema,
                       p_view_name,
                       'CREATE VIEW ' || v_curr.obj_schema || '.' || v_curr.obj_name || ' AS ' || view_definition
                from information_schema.views
                where table_schema = v_curr.obj_schema
                  and table_name = v_curr.obj_name;
            elsif v_curr.obj_type = 'm' then
                insert into deps_saved_ddl(deps_view_schema, deps_view_name, deps_ddl_to_run)
                select p_view_schema,
                       p_view_name,
                       'CREATE MATERIALIZED VIEW ' || v_curr.obj_schema || '.' || v_curr.obj_name || ' AS ' ||
                       definition
                from pg_matviews
                where schemaname = v_curr.obj_schema
                  and matviewname = v_curr.obj_name;
            end if;

            execute 'DROP ' ||
                    case
                        when v_curr.obj_type = 'v' then 'VIEW'
                        when v_curr.obj_type = 'm' then 'MATERIALIZED VIEW'
                        end
                        || ' ' || v_curr.obj_schema || '.' || v_curr.obj_name;

        end loop;
end;
$$;


--
-- Name: drop_view(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.drop_view(schema_name text, view_name text) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
BEGIN
    EXECUTE 'set search_path = ' || schema_name;
    EXECUTE 'DROP VIEW IF EXISTS ' || view_name;
    EXECUTE 'reset search_path';
    RETURN 1;
END
$$;


--
-- Name: enable_rls_on_ref_table(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enable_rls_on_ref_table(tablename text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    tabl   TEXT := quote_ident(tablename);
    polisy TEXT := quote_ident(tablename || '_orgs') || ' ON ' || tabl || ' ';
BEGIN
    EXECUTE 'DROP POLICY IF EXISTS ' || polisy;
    EXECUTE 'CREATE POLICY ' || polisy || '
            USING (organisation_id IN (SELECT id FROM org_ids UNION SELECT organisation_id from organisation_group_organisation)
            OR organisation_id IN (SELECT organisation_id from organisation_group_organisation))
  WITH CHECK ((organisation_id = (select id
                                  from organisation
                                  where db_user = current_user)))';
    EXECUTE 'ALTER TABLE ' || tabl || ' ENABLE ROW LEVEL SECURITY';
    RETURN 'CREATED POLICY ' || polisy;
END
$$;


--
-- Name: enable_rls_on_tx_table(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enable_rls_on_tx_table(tablename text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    tabl   TEXT := quote_ident(tablename);
    polisy TEXT := quote_ident(tablename || '_orgs') || ' ON ' || tabl || ' ';
BEGIN
    EXECUTE 'DROP POLICY IF EXISTS ' || polisy;
    EXECUTE 'CREATE POLICY ' || polisy || '
            USING ((organisation_id = (select id from organisation where db_user = current_user)
            OR organisation_id IN (SELECT organisation_id from organisation_group_organisation)))
    WITH CHECK ((organisation_id = (select id from organisation where db_user = current_user)))';
    EXECUTE 'ALTER TABLE ' || tabl || ' ENABLE ROW LEVEL SECURITY';
    RETURN 'CREATED POLICY ' || polisy;
END
$$;


--
-- Name: encounter_sync_disabled_same_as_individual(boolean, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.encounter_sync_disabled_same_as_individual(syncdisabled boolean, encounterid bigint) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
begin
    raise 'Not Implemented.';
end
$$;


--
-- Name: frequency_and_percentage(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.frequency_and_percentage(frequency_query text) RETURNS TABLE(total bigint, percentage double precision, gender character varying, address_type character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE separator TEXT;
BEGIN
  SELECT md5(random() :: TEXT) :: TEXT
      INTO separator;
  EXECUTE format('CREATE TEMPORARY TABLE query_output_%s (
    uuid         VARCHAR,
    gender_name  VARCHAR,
    address_type VARCHAR,
    address_name VARCHAR
  ) ON COMMIT DROP', separator);

  EXECUTE format('CREATE TEMPORARY TABLE aggregates_%s (
    total        BIGINT,
    percentage   FLOAT,
    gender       VARCHAR,
    address_type VARCHAR
  ) ON COMMIT DROP', separator);

  -- Store filtered query into a temporary variable


  EXECUTE FORMAT('INSERT INTO query_output_%s (uuid, gender_name, address_type, address_name) %s', separator,
                 frequency_query);

  EXECUTE format('INSERT INTO aggregates_%s (total, gender, address_type)
    SELECT
      count(qo.uuid)  total,
      qo.gender_name  gender,
      qo.address_type address_type
    FROM query_output_%s qo
    GROUP BY qo.gender_name, qo.address_type', separator, separator);


  EXECUTE format('INSERT INTO aggregates_%s (total, gender, address_type)
    SELECT
      count(qo.uuid)  total,
      ''Total''         gender,
      qo.address_type address_type
    FROM query_output_%s qo
    GROUP BY qo.address_type', separator, separator);

  EXECUTE format('INSERT INTO aggregates_%s (total, gender, address_type)
    SELECT
      count(qo.uuid)  total,
      qo.gender_name  gender,
      ''All'' address_type
    FROM query_output_%s qo
    GROUP BY qo.gender_name', separator, separator);

  EXECUTE format('INSERT INTO aggregates_%s (total, gender, address_type)
    SELECT
      count(qo.uuid) total,
      ''Total''        gender,
      ''All''          address_type
    FROM query_output_%s qo', separator, separator);

  EXECUTE format('UPDATE aggregates_%s ag1
  SET percentage = coalesce(round(((ag1.total / (SELECT sum(ag2.total)
                                                 FROM aggregates_%s ag2
                                                 WHERE (ag2.address_type = ag1.address_type AND ag2.gender != ''Total'')))
                                   * 100), 2), 100)', separator, separator);

  EXECUTE FORMAT('INSERT INTO aggregates_%s (total, percentage, address_type, gender)
                        SELECT 0, 0, atname, gname from (
                            SELECT DISTINCT type atname,
                            name gname
                          FROM address_level_type_view, gender
                          WHERE name != ''Other''
                          UNION ALL
                          SELECT
                            ''All'' atname,
                            name gname
                          FROM gender
                          WHERE name != ''Other''
                          UNION ALL
                          SELECT DISTINCT
                            type atname,
                            ''Total'' gname
                          FROM address_level_type_view
                          UNION ALL
                          SELECT
                            ''All'' atname,
                            ''Total'' gname) as agt where (atname, gname) not in (select address_type, gender from aggregates_%s)',
                 separator, separator);

  RETURN QUERY EXECUTE format('SELECT *
               FROM aggregates_%s order by address_type, gender', separator);
END
$$;


--
-- Name: frequency_and_percentage(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.frequency_and_percentage(frequency_query text, denominator_query text) RETURNS TABLE(total bigint, percentage double precision, gender character varying, address_type character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE separator TEXT;
BEGIN
  SELECT md5(random() :: TEXT) :: TEXT
      INTO separator;
  EXECUTE FORMAT('CREATE TEMPORARY TABLE query_output_%s (
    uuid         VARCHAR,
    gender_name  VARCHAR,
    address_type VARCHAR,
    address_name VARCHAR
  ) ON COMMIT DROP', separator);

  EXECUTE FORMAT('CREATE TEMPORARY TABLE denominator_query_output_%s (
    uuid         VARCHAR,
    gender_name  VARCHAR,
    address_type VARCHAR,
    address_name VARCHAR
  ) ON COMMIT DROP', separator);

  EXECUTE format('CREATE TEMPORARY TABLE aggregates_%s (
    total        BIGINT,
    percentage   FLOAT,
    gender       VARCHAR,
    address_type VARCHAR
  ) ON COMMIT DROP', separator);

  EXECUTE FORMAT('CREATE TEMPORARY TABLE denominator_aggregates_%s (
    total        BIGINT,
    gender       VARCHAR,
    address_type VARCHAR
  ) ON COMMIT DROP', separator);
  -- Store filtered query into a temporary variable

  EXECUTE FORMAT('INSERT INTO query_output_%s (uuid, gender_name, address_type, address_name) %s', separator,
                 frequency_query);

  EXECUTE FORMAT('INSERT INTO denominator_query_output_%s (uuid, gender_name, address_type, address_name) %s',
                 separator,
                 denominator_query);

  EXECUTE format('INSERT INTO aggregates_%s (total, gender, address_type)
    SELECT
      count(qo.uuid)  total,
      qo.gender_name  gender,
      qo.address_type address_type
    FROM query_output_%s qo
    GROUP BY qo.gender_name, qo.address_type', separator, separator);

  EXECUTE format('INSERT INTO denominator_aggregates_%s (total, gender, address_type)
    SELECT
      count(qo.uuid)  total,
      qo.gender_name  gender,
      qo.address_type address_type
    FROM denominator_query_output_%s qo
    GROUP BY qo.gender_name, qo.address_type', separator, separator);


  EXECUTE format('INSERT INTO aggregates_%s (total, gender, address_type)
    SELECT
      count(qo.uuid)  total,
      ''Total''         gender,
      qo.address_type address_type
    FROM query_output_%s qo
    GROUP BY qo.address_type', separator, separator);

  EXECUTE format('INSERT INTO denominator_aggregates_%s (total, gender, address_type)
    SELECT
      count(qo.uuid)  total,
      ''Total''         gender,
      qo.address_type address_type
    FROM denominator_query_output_%s qo
    GROUP BY qo.address_type', separator, separator);

  EXECUTE format('INSERT INTO aggregates_%s (total, gender, address_type)
    SELECT
      count(qo.uuid)  total,
      qo.gender_name  gender,
      ''All'' address_type
    FROM query_output_%s qo
    GROUP BY qo.gender_name', separator, separator);

  EXECUTE format('INSERT INTO denominator_aggregates_%s (total, gender, address_type)
    SELECT
      count(qo.uuid)  total,
      qo.gender_name  gender,
      ''All'' address_type
    FROM denominator_query_output_%s qo
    GROUP BY qo.gender_name', separator, separator);

  EXECUTE format('INSERT INTO aggregates_%s (total, gender, address_type)
    SELECT
      count(qo.uuid) total,
      ''Total''        gender,
      ''All''          address_type
    FROM query_output_%s qo', separator, separator);

  EXECUTE format('INSERT INTO denominator_aggregates_%s (total, gender, address_type)
    SELECT
      count(qo.uuid) total,
      ''Total''        gender,
      ''All''          address_type
    FROM denominator_query_output_%s qo', separator, separator);

  EXECUTE FORMAT('UPDATE aggregates_%s ag1
  SET percentage = (SELECT coalesce(round(((ag2.total :: FLOAT / dag1.total) * 100) :: NUMERIC, 2), 100)
                    FROM aggregates_%s ag2
                      INNER JOIN denominator_aggregates_%s dag1
                        ON ag2.address_type = dag1.address_type AND ag2.gender = dag1.gender
                    WHERE ag2.address_type = ag1.address_type AND ag2.gender = ag1.gender
                    LIMIT 1)', separator, separator, separator);

  EXECUTE FORMAT('INSERT INTO aggregates_%s (total, percentage, address_type, gender)
                        SELECT 0, 0, atname, gname from (
                            SELECT DISTINCT type atname,
                            name gname
                          FROM address_level_type_view, gender
                          WHERE name != ''Other''
                          UNION ALL
                          SELECT
                            ''All'' atname,
                            name gname
                          FROM gender
                          WHERE name != ''Other''
                          UNION ALL
                          SELECT DISTINCT
                            type atname,
                            ''Total'' gname
                          FROM address_level_type_view
                          UNION ALL
                          SELECT
                            ''All'' atname,
                            ''Total'' gname) as agt where (atname, gname) not in (select address_type, gender from aggregates_%s)',
                 separator, separator);

  RETURN QUERY EXECUTE format('SELECT *
               FROM aggregates_%s order by address_type, gender', separator);
END
$$;


--
-- Name: get_coded_string_value(jsonb, public.hstore); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_coded_string_value(obs jsonb, obs_store public.hstore) RETURNS character varying
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    result VARCHAR;
BEGIN
    BEGIN
        IF JSONB_TYPEOF(obs) = 'array'
        THEN
            select STRING_AGG(obs_store -> OB.UUID, ', ')
            from JSONB_ARRAY_ELEMENTS_TEXT(obs) AS OB (UUID)
            INTO RESULT;
        ELSE
            SELECT obs_store -> (obs ->> 0) INTO RESULT;
        END IF;
        RETURN RESULT;
    EXCEPTION
        WHEN OTHERS
            THEN
                RAISE NOTICE 'Failed while processing get_coded_string_value(''%'')', obs :: TEXT;
                RAISE NOTICE '% %', SQLERRM, SQLSTATE;
    END;
END
$$;


--
-- Name: get_fiscal_year_range(date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_fiscal_year_range(input_date date) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
    RETURN TO_CHAR(
                   MAKE_DATE(
                               EXTRACT(YEAR FROM input_date)::INT -
                               CASE WHEN EXTRACT(MONTH FROM input_date) < 4 THEN 1 ELSE 0 END,
                               4, 1
                       ), 'Mon YYYY'
               )
               || ' - ' ||
           TO_CHAR(
                   MAKE_DATE(
                               EXTRACT(YEAR FROM input_date)::INT +
                               CASE WHEN EXTRACT(MONTH FROM input_date) < 4 THEN 0 ELSE 1 END,
                               3, 1
                       ), 'Mon YYYY'
               );
END;
$$;


--
-- Name: grant_all_on_all(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.grant_all_on_all(rolename text) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
    EXECUTE (SELECT 'GRANT ALL ON TABLE '
                        || string_agg(format('%I.%I', table_schema, table_name), ',')
                        || ' TO ' || quote_ident(rolename) || ''
             FROM information_schema.tables
             WHERE table_schema = 'public'
               AND table_type = 'BASE TABLE');

    EXECUTE (SELECT 'GRANT SELECT ON '
                        || string_agg(format('%I.%I', schemaname, viewname), ',')
                        || ' TO ' || quote_ident(rolename) || ''
             FROM pg_catalog.pg_views
             WHERE schemaname = 'public'
               and viewowner in ('openchs'));

    EXECUTE 'GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO ' || quote_ident(rolename) || '';
    EXECUTE 'GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO ' || quote_ident(rolename) || '';
    RETURN 'ALL PERMISSIONS GRANTED TO ' || quote_ident(rolename);
END;
$$;


--
-- Name: grant_all_on_table(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.grant_all_on_table(rolename text, tablename text) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
    EXECUTE (SELECT 'GRANT ALL ON TABLE '
                        || tablename
                        || ' TO ' || quote_ident(rolename));

    EXECUTE (SELECT 'GRANT SELECT ON '
                        || tablename
                        || ' TO ' || quote_ident(rolename));

    EXECUTE 'GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO ' || quote_ident(rolename) || '';
    RETURN 'ALL PERMISSIONS GRANTED TO ' || quote_ident(rolename);
END;
$$;


--
-- Name: grant_all_on_views(text[], text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.grant_all_on_views(view_names text[], role text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    view_names_string text;
BEGIN
    view_names_string := array_to_string(view_names, ',');
    EXECUTE 'GRANT ALL ON ' || view_names_string || ' TO ' || quote_ident(role) || '';
    RETURN 'EXECUTE GRANT ALL ON ' || view_names_string || ' TO ' || quote_ident(role) || '';
END;
$$;


--
-- Name: grant_permission_on_account_admin(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.grant_permission_on_account_admin(rolename text) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
    EXECUTE 'GRANT ALL ON TABLE account_admin TO ' || quote_ident(rolename) || '';
    RETURN 'PERMISSIONS GRANTED FOR account_admin TO ' || quote_ident(rolename);
END;
$$;


--
-- Name: jsonb_object_values_contain(jsonb, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.jsonb_object_values_contain(obs jsonb, pattern text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
    return EXISTS (select true from jsonb_each_text(obs) where value ilike pattern);
END;
$$;


--
-- Name: multi_select_coded(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.multi_select_coded(obs jsonb) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
    result VARCHAR;
BEGIN
    BEGIN
        IF JSONB_TYPEOF(obs) = 'array'
        THEN
            SELECT STRING_AGG(C.NAME, ' ,')
            FROM JSONB_ARRAY_ELEMENTS_TEXT(obs) AS OB (UUID)
                     JOIN CONCEPT C ON C.UUID = OB.UUID
            INTO RESULT;
        ELSE
            SELECT SINGLE_SELECT_CODED(obs) INTO RESULT;
        END IF;
        RETURN RESULT;
    EXCEPTION
        WHEN OTHERS
            THEN
                RAISE NOTICE 'Failed while processing multi_select_coded(''%'')', obs :: TEXT;
                RAISE NOTICE '% %', SQLERRM, SQLSTATE;
    END;
END
$$;


--
-- Name: no_op(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.no_op() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN NULL;
END;
$$;


--
-- Name: program_encounter_sync_disabled_same_as_individual(boolean, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.program_encounter_sync_disabled_same_as_individual(syncdisabled boolean, programenrolmentid bigint) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
begin
    if exists(select subject.id
              from public.individual subject
                       join program_enrolment pe on pe.individual_id = subject.id
                       join program_encounter penc on penc.program_enrolment_id = pe.id
              where subject.sync_disabled <> syncDisabled
                and pe.id = programEnrolmentId)
    then
        raise 'Sync disabled value cannot be different from individual. For program enrolment id: %, sync disabled: %',
            programEnrolmentId, syncDisabled;
    end if;

    return true;
end
$$;


--
-- Name: revoke_permissions_on_account(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.revoke_permissions_on_account(rolename text) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
    EXECUTE 'REVOKE ALL ON TABLE account FROM ' || quote_ident(rolename) || '';
    RETURN 'ALL ACCOUNT PERMISSIONS REVOKED FROM ' || quote_ident(rolename);
END;
$$;


--
-- Name: single_select_coded(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.single_select_coded(obs jsonb) RETURNS character varying
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    result VARCHAR;
BEGIN
    BEGIN
        IF JSONB_TYPEOF(obs) = 'array'
        THEN
            SELECT name FROM concept WHERE (obs ->> 0) = uuid INTO result;
        ELSEIF JSONB_TYPEOF(obs) = 'string'
        THEN
            select name from concept where (array_to_json(array [obs]) ->> 0) = uuid into result;
        END IF;
        RETURN result;
    END;
END
$$;


--
-- Name: single_select_coded(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.single_select_coded(obs text) RETURNS character varying
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    result VARCHAR;
BEGIN
    BEGIN
        SELECT name
        FROM concept
        WHERE uuid = obs
        INTO result;
        RETURN result;
    END;
END
$$;


--
-- Name: solidify_audit_columns(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.solidify_audit_columns(table_name text) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    execute 'alter table ' || table_name || '
        alter column created_by_id set not null,
        alter column last_modified_by_id set not null,
        alter column created_date_time set not null,
        alter column last_modified_date_time set not null;';
    RAISE NOTICE 'set audit fields to non-null %', table_name ;

    execute ' drop index if exists ' || table_name || '_last_modified_time_idx';
    execute 'CREATE INDEX ' || table_name || '_last_modified_time_idx
        ON ' || table_name || '(last_modified_date_time);';
    RAISE NOTICE 'create index on last_modified_date_time %', table_name ;

    execute 'drop trigger if exists ' || table_name ||   '_update_audit_before_insert on ' || table_name ;
    execute 'CREATE TRIGGER ' || table_name ||  '_update_audit_before_insert
            BEFORE INSERT
            ON ' || table_name || '
            FOR EACH ROW
        EXECUTE PROCEDURE audit_table_trigger();';
    RAISE NOTICE 'create trigger on insert %', table_name ;

    execute 'drop trigger if exists ' || table_name ||   '_update_audit_before_update on ' || table_name ;
    execute 'CREATE TRIGGER ' || table_name ||  '_update_audit_before_update
            BEFORE UPDATE
            ON ' || table_name || '
            FOR EACH ROW
        EXECUTE PROCEDURE audit_table_trigger();';
    RAISE NOTICE 'create trigger on update %', table_name ;
END
$$;


--
-- Name: title_lineage_locations_function(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.title_lineage_locations_function(addressid bigint) RETURNS TABLE(lowestpoint_id integer, title_lineage text)
    LANGUAGE sql
    AS $$
select al.id lowestpoint_id, string_agg(alevel_in_lineage.title, ', ' order by lineage.level) title_lineage
from address_level al
         join regexp_split_to_table(al.lineage :: text, '[.]') with ordinality lineage (point_id, level) ON TRUE
         join address_level alevel_in_lineage on alevel_in_lineage.id = lineage.point_id :: int
where case when addressId isnull then true else al.id = addressId end
group by al.id
$$;


--
-- Name: update_audit_columns_from_audit_table(text); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.update_audit_columns_from_audit_table(IN table_name text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    execute 'update ' || table_name || '
        set created_by_id           = a.created_by_id,
            last_modified_by_id     = a.last_modified_by_id,
            created_date_time       = a.created_date_time,
            last_modified_date_time = a.last_modified_date_time
        from audit a
        where ' || table_name || '.audit_id = a.id;';
    RAISE NOTICE 'updated values of audit fields in %', table_name;
END
$$;


--
-- Name: virtual_catchment_address_mapping_table_function(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.virtual_catchment_address_mapping_table_function() RETURNS TABLE(id bigint, catchment_id integer, addresslevel_id integer, type_id integer)
    LANGUAGE sql
    AS $$
select row_number() OVER ()  AS id,
       cam.catchment_id::int AS catchment_id,
       al.id                 AS addresslevel_id,
       al.type_id            AS type_id
from address_level al
         left outer join regexp_split_to_table((al.lineage)::text, '[.]'::text) WITH ORDINALITY lineage(point_id, level)
                         ON (true)
         left outer join catchment_address_mapping cam on cam.addresslevel_id = point_id::int
where catchment_id notnull
group by 2, 3
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: account; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    region character varying(255) DEFAULT 'IN'::character varying NOT NULL
);


--
-- Name: account_admin; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account_admin (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    account_id integer NOT NULL,
    admin_id integer NOT NULL
);


--
-- Name: account_admin_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.account_admin_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: account_admin_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.account_admin_id_seq OWNED BY public.account_admin.id;


--
-- Name: account_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.account_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: account_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.account_id_seq OWNED BY public.account.id;


--
-- Name: address_level; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.address_level (
    id integer NOT NULL,
    title character varying(255) NOT NULL,
    uuid character varying(255) NOT NULL,
    version integer NOT NULL,
    organisation_id integer DEFAULT 1 NOT NULL,
    audit_id integer,
    is_voided boolean DEFAULT false NOT NULL,
    type_id integer,
    lineage public.ltree,
    parent_id integer,
    gps_coordinates point,
    location_properties jsonb,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    legacy_id character varying,
    CONSTRAINT lineage_parent_consistency CHECK ((((parent_id IS NOT NULL) AND (public.subltree(lineage, 0, public.nlevel(lineage)) OPERATOR(public.~) (concat('*.', parent_id, '.', id))::public.lquery)) OR ((parent_id IS NULL) AND (lineage OPERATOR(public.~) (concat('', id))::public.lquery))))
);


--
-- Name: address_level_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.address_level_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: address_level_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.address_level_id_seq OWNED BY public.address_level.id;


--
-- Name: address_level_type; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.address_level_type (
    id integer NOT NULL,
    uuid character varying(255) DEFAULT public.uuid_generate_v4() NOT NULL,
    name character varying(255) NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    organisation_id integer NOT NULL,
    version integer NOT NULL,
    audit_id integer,
    level double precision DEFAULT 0,
    parent_id integer,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: address_level_type_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.address_level_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: address_level_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.address_level_type_id_seq OWNED BY public.address_level_type.id;


--
-- Name: organisation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organisation (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    db_user character varying(255) NOT NULL,
    uuid character varying(255) NOT NULL,
    parent_organisation_id integer,
    is_voided boolean DEFAULT false NOT NULL,
    media_directory text,
    username_suffix text,
    account_id integer DEFAULT 1 NOT NULL,
    schema_name character varying(255) NOT NULL,
    category_id integer NOT NULL,
    status_id integer NOT NULL
);


--
-- Name: address_level_type_view; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.address_level_type_view AS
 WITH RECURSIVE list_of_orgs(id, parent_organisation_id) AS (
         SELECT organisation.id,
            organisation.parent_organisation_id
           FROM public.organisation
          WHERE ((organisation.db_user)::text = CURRENT_USER)
        UNION ALL
         SELECT o.id,
            o.parent_organisation_id
           FROM public.organisation o,
            list_of_orgs log
          WHERE (o.id = log.parent_organisation_id)
        )
 SELECT al.id,
    al.title,
    al.uuid,
    alt.level,
    al.version,
    al.organisation_id,
    al.audit_id,
    al.is_voided,
    al.type_id,
    alt.name AS type
   FROM ((public.address_level al
     JOIN public.address_level_type alt ON ((al.type_id = alt.id)))
     JOIN list_of_orgs loo ON ((loo.id = al.organisation_id)))
  WHERE (alt.is_voided IS NOT TRUE);


--
-- Name: form; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.form (
    id integer NOT NULL,
    name character varying(255),
    form_type character varying(255) NOT NULL,
    uuid character varying(255) NOT NULL,
    version integer NOT NULL,
    organisation_id integer DEFAULT 1 NOT NULL,
    audit_id integer,
    is_voided boolean DEFAULT false NOT NULL,
    decision_rule text,
    validation_rule text,
    visit_schedule_rule text,
    checklists_rule text,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    validation_declarative_rule jsonb,
    decision_declarative_rule jsonb,
    visit_schedule_declarative_rule jsonb,
    task_schedule_declarative_rule text,
    task_schedule_rule text,
    edit_form_rule text
);


--
-- Name: form_mapping; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.form_mapping (
    id integer NOT NULL,
    form_id bigint,
    uuid character varying(255) NOT NULL,
    version integer NOT NULL,
    entity_id bigint,
    observations_type_entity_id integer,
    organisation_id integer DEFAULT 1 NOT NULL,
    audit_id integer,
    is_voided boolean DEFAULT false NOT NULL,
    subject_type_id integer,
    enable_approval boolean DEFAULT false NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    task_type_id integer,
    impl_version integer DEFAULT 1 NOT NULL,
    CONSTRAINT check_form_mapping_unique CHECK (public.check_form_mapping_uniqueness(organisation_id, subject_type_id, entity_id, observations_type_entity_id, task_type_id, form_id, id, impl_version, is_voided)),
    CONSTRAINT subject_type_check CHECK (((subject_type_id IS NOT NULL) OR (task_type_id IS NOT NULL)))
);


--
-- Name: operational_encounter_type; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operational_encounter_type (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    organisation_id integer NOT NULL,
    encounter_type_id integer NOT NULL,
    version integer NOT NULL,
    audit_id integer,
    name character varying(255),
    is_voided boolean DEFAULT false NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: operational_program; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operational_program (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    organisation_id integer NOT NULL,
    program_id integer NOT NULL,
    version integer NOT NULL,
    audit_id integer,
    name character varying(255),
    is_voided boolean DEFAULT false NOT NULL,
    program_subject_label text,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: all_forms; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.all_forms AS
 SELECT DISTINCT x.organisation_id,
    x.form_id,
    x.form_name
   FROM ( SELECT form.id AS form_id,
            form.name AS form_name,
            m2.organisation_id
           FROM (public.form
             JOIN public.form_mapping m2 ON ((form.id = m2.form_id)))
          WHERE ((NOT form.is_voided) OR (NOT m2.is_voided))
        UNION
         SELECT form.id AS form_id,
            form.name AS form_name,
            oet.organisation_id
           FROM ((public.form
             JOIN public.form_mapping m2 ON (((form.id = m2.form_id) AND (m2.organisation_id = 1))))
             JOIN public.operational_encounter_type oet ON ((oet.encounter_type_id = m2.observations_type_entity_id)))
          WHERE ((NOT form.is_voided) OR (NOT m2.is_voided) OR (NOT oet.is_voided))
        UNION
         SELECT form.id AS form_id,
            form.name AS form_name,
            op.organisation_id
           FROM ((public.form
             JOIN public.form_mapping m2 ON (((form.id = m2.form_id) AND (m2.organisation_id = 1))))
             JOIN public.operational_program op ON ((op.program_id = m2.entity_id)))
          WHERE ((NOT form.is_voided) OR (NOT m2.is_voided) OR (NOT op.is_voided))) x;


--
-- Name: concept; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.concept (
    id integer NOT NULL,
    data_type character varying(255) NOT NULL,
    high_absolute double precision,
    high_normal double precision,
    low_absolute double precision,
    low_normal double precision,
    name character varying(255) NOT NULL,
    uuid character varying(255) NOT NULL,
    version integer NOT NULL,
    unit character varying(50),
    organisation_id integer DEFAULT 1 NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    audit_id integer,
    key_values jsonb,
    active boolean DEFAULT true NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    media jsonb
);


--
-- Name: concept_answer; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.concept_answer (
    id integer NOT NULL,
    concept_id bigint NOT NULL,
    answer_concept_id bigint NOT NULL,
    uuid character varying(255) NOT NULL,
    version integer NOT NULL,
    answer_order double precision NOT NULL,
    organisation_id integer DEFAULT 1 NOT NULL,
    abnormal boolean DEFAULT false NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    uniq boolean DEFAULT false NOT NULL,
    audit_id integer,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: form_element; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.form_element (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    display_order double precision NOT NULL,
    is_mandatory boolean DEFAULT false NOT NULL,
    key_values jsonb,
    concept_id bigint NOT NULL,
    form_element_group_id bigint NOT NULL,
    uuid character varying(255) NOT NULL,
    version integer NOT NULL,
    organisation_id integer DEFAULT 1 NOT NULL,
    type character varying(1024) DEFAULT NULL::character varying,
    valid_format_regex character varying(255),
    valid_format_description_key character varying(255),
    audit_id integer,
    is_voided boolean DEFAULT false NOT NULL,
    rule text,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    declarative_rule jsonb,
    group_id integer,
    documentation_id integer,
    CONSTRAINT valid_format_check CHECK ((((valid_format_regex IS NULL) AND (valid_format_description_key IS NULL)) OR ((valid_format_regex IS NOT NULL) AND (valid_format_description_key IS NOT NULL))))
);


--
-- Name: form_element_group; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.form_element_group (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    form_id bigint NOT NULL,
    uuid character varying(255) NOT NULL,
    version integer NOT NULL,
    display_order double precision DEFAULT '-1'::integer NOT NULL,
    organisation_id integer DEFAULT 1 NOT NULL,
    audit_id integer,
    is_voided boolean DEFAULT false NOT NULL,
    rule text,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    declarative_rule jsonb,
    start_time integer,
    stay_time integer,
    is_timed boolean DEFAULT false,
    text_colour character varying(20),
    background_colour character varying(20)
);


--
-- Name: all_concept_answers; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.all_concept_answers AS
 SELECT DISTINCT all_forms.organisation_id,
    c3.name AS answer_concept_name
   FROM ((((((public.form_element
     JOIN public.form_element_group ON ((form_element.form_element_group_id = form_element_group.id)))
     JOIN public.form ON ((form_element_group.form_id = form.id)))
     JOIN public.concept c2 ON ((form_element.concept_id = c2.id)))
     JOIN public.concept_answer a ON ((c2.id = a.concept_id)))
     JOIN public.concept c3 ON ((a.answer_concept_id = c3.id)))
     JOIN public.all_forms ON ((all_forms.form_id = form.id)))
  WHERE ((NOT form_element.is_voided) OR (NOT form_element_group.is_voided) OR (NOT form.is_voided) OR (NOT c2.is_voided) OR (NOT c2.is_voided) OR (NOT c3.is_voided));


--
-- Name: all_concepts; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.all_concepts AS
 SELECT DISTINCT all_forms.organisation_id,
    c2.name AS concept_name
   FROM ((((public.form_element
     JOIN public.form_element_group ON ((form_element.form_element_group_id = form_element_group.id)))
     JOIN public.form ON ((form_element_group.form_id = form.id)))
     JOIN public.concept c2 ON ((form_element.concept_id = c2.id)))
     JOIN public.all_forms ON ((all_forms.form_id = form.id)))
  WHERE ((NOT form_element.is_voided) OR (NOT form_element_group.is_voided) OR (NOT form.is_voided) OR (NOT c2.is_voided));


--
-- Name: encounter_type; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.encounter_type (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    concept_id bigint,
    uuid character varying(255) NOT NULL,
    version integer NOT NULL,
    organisation_id integer DEFAULT 1 NOT NULL,
    audit_id integer,
    is_voided boolean DEFAULT false NOT NULL,
    encounter_eligibility_check_rule text,
    active boolean DEFAULT true NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    encounter_eligibility_check_declarative_rule jsonb,
    is_immutable boolean DEFAULT false
);


--
-- Name: all_encounter_types; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.all_encounter_types AS
 SELECT DISTINCT operational_encounter_type.organisation_id,
    et.name AS encounter_type_name
   FROM (public.operational_encounter_type
     JOIN public.encounter_type et ON ((operational_encounter_type.encounter_type_id = et.id)))
  WHERE ((NOT operational_encounter_type.is_voided) OR (NOT et.is_voided));


--
-- Name: all_form_element_groups; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.all_form_element_groups AS
 SELECT DISTINCT all_forms.organisation_id,
    form_element_group.name AS form_element_group_name
   FROM ((public.form_element_group
     JOIN public.form ON ((form_element_group.form_id = form.id)))
     JOIN public.all_forms ON ((all_forms.form_id = form.id)))
  WHERE ((NOT form_element_group.is_voided) OR (NOT form.is_voided));


--
-- Name: all_form_elements; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.all_form_elements AS
 SELECT DISTINCT all_forms.organisation_id,
    form_element.name AS form_element_name
   FROM (((public.form_element
     JOIN public.form_element_group ON ((form_element.form_element_group_id = form_element_group.id)))
     JOIN public.form ON ((form_element_group.form_id = form.id)))
     JOIN public.all_forms ON ((all_forms.form_id = form.id)))
  WHERE ((NOT form_element.is_voided) OR (NOT form_element_group.is_voided));


--
-- Name: all_operational_encounter_types; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.all_operational_encounter_types AS
 SELECT DISTINCT operational_encounter_type.organisation_id,
    operational_encounter_type.name AS operational_encounter_type_name
   FROM (public.operational_encounter_type
     JOIN public.encounter_type et ON ((operational_encounter_type.encounter_type_id = et.id)))
  WHERE ((NOT operational_encounter_type.is_voided) OR (NOT et.is_voided));


--
-- Name: program; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.program (
    id smallint NOT NULL,
    uuid character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    version integer NOT NULL,
    colour character varying(20),
    organisation_id integer DEFAULT 1 NOT NULL,
    audit_id integer,
    is_voided boolean DEFAULT false NOT NULL,
    enrolment_summary_rule text,
    enrolment_eligibility_check_rule text,
    active boolean DEFAULT true NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    enrolment_eligibility_check_declarative_rule jsonb,
    manual_eligibility_check_required boolean DEFAULT false NOT NULL,
    manual_enrolment_eligibility_check_rule text,
    manual_enrolment_eligibility_check_declarative_rule text,
    allow_multiple_enrolments boolean DEFAULT false NOT NULL,
    show_growth_chart boolean DEFAULT false NOT NULL
);


--
-- Name: all_operational_programs; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.all_operational_programs AS
 SELECT DISTINCT operational_program.organisation_id,
    operational_program.name AS operational_program_name
   FROM (public.operational_program
     JOIN public.program p ON ((p.id = operational_program.program_id)))
  WHERE ((NOT operational_program.is_voided) OR (NOT p.is_voided));


--
-- Name: all_programs; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.all_programs AS
 SELECT DISTINCT operational_program.organisation_id,
    p.name AS program_name
   FROM (public.operational_program
     JOIN public.program p ON ((p.id = operational_program.program_id)))
  WHERE ((NOT operational_program.is_voided) OR (NOT p.is_voided));


--
-- Name: answer_concept_migration; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.answer_concept_migration (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    concept_id integer NOT NULL,
    old_answer_concept_name character varying(255) NOT NULL,
    new_answer_concept_name character varying(255) NOT NULL,
    organisation_id integer NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    version integer NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: answer_concept_migration_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.answer_concept_migration_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: answer_concept_migration_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.answer_concept_migration_id_seq OWNED BY public.answer_concept_migration.id;


--
-- Name: approval_status; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.approval_status (
    id integer NOT NULL,
    uuid text NOT NULL,
    status text NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    created_date_time timestamp with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: approval_status_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.approval_status_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: approval_status_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.approval_status_id_seq OWNED BY public.approval_status.id;


--
-- Name: storage_management_config; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.storage_management_config (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    sql_query text NOT NULL,
    realm_query text,
    batch_size integer,
    organisation_id integer NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    version bigint DEFAULT 0 NOT NULL
);


--
-- Name: archival_config_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.archival_config_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: archival_config_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.archival_config_id_seq OWNED BY public.storage_management_config.id;


--
-- Name: audit; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit (
    id integer NOT NULL,
    uuid character varying(255),
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: audit_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audit_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.audit_id_seq OWNED BY public.audit.id;


--
-- Name: batch_job_execution; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.batch_job_execution (
    job_execution_id bigint NOT NULL,
    version bigint,
    job_instance_id bigint NOT NULL,
    create_time timestamp without time zone NOT NULL,
    start_time timestamp without time zone,
    end_time timestamp without time zone,
    status character varying(10),
    exit_code character varying(2500),
    exit_message character varying(2500),
    last_updated timestamp without time zone
);


--
-- Name: batch_job_execution_context; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.batch_job_execution_context (
    job_execution_id bigint NOT NULL,
    short_context character varying(2500) NOT NULL,
    serialized_context text
);


--
-- Name: batch_job_execution_params; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.batch_job_execution_params (
    job_execution_id bigint NOT NULL,
    parameter_name character varying(100) NOT NULL,
    parameter_type character varying(100) NOT NULL,
    parameter_value character varying(2500),
    identifying character(1) NOT NULL
);


--
-- Name: batch_job_execution_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.batch_job_execution_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: batch_job_instance; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.batch_job_instance (
    job_instance_id bigint NOT NULL,
    version bigint,
    job_name character varying(100) NOT NULL,
    job_key character varying(32) NOT NULL
);


--
-- Name: batch_job_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.batch_job_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: batch_step_execution; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.batch_step_execution (
    step_execution_id bigint NOT NULL,
    version bigint NOT NULL,
    step_name character varying(100) NOT NULL,
    job_execution_id bigint NOT NULL,
    create_time timestamp without time zone NOT NULL,
    start_time timestamp without time zone,
    end_time timestamp without time zone,
    status character varying(10),
    commit_count bigint,
    read_count bigint,
    filter_count bigint,
    write_count bigint,
    read_skip_count bigint,
    write_skip_count bigint,
    process_skip_count bigint,
    rollback_count bigint,
    exit_code character varying(2500),
    exit_message character varying(2500),
    last_updated timestamp without time zone
);


--
-- Name: batch_step_execution_context; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.batch_step_execution_context (
    step_execution_id bigint NOT NULL,
    short_context character varying(2500) NOT NULL,
    serialized_context text
);


--
-- Name: batch_step_execution_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.batch_step_execution_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: catchment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.catchment (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    uuid character varying(255) NOT NULL,
    version integer NOT NULL,
    organisation_id integer DEFAULT 1 NOT NULL,
    type character varying(1024) DEFAULT 'Villages'::character varying NOT NULL,
    audit_id integer,
    is_voided boolean DEFAULT false NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: catchment_address_mapping; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.catchment_address_mapping (
    id integer NOT NULL,
    catchment_id bigint NOT NULL,
    addresslevel_id bigint NOT NULL
);


--
-- Name: catchment_address_mapping_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.catchment_address_mapping_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: catchment_address_mapping_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.catchment_address_mapping_id_seq OWNED BY public.catchment_address_mapping.id;


--
-- Name: catchment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.catchment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: catchment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.catchment_id_seq OWNED BY public.catchment.id;


--
-- Name: checklist; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.checklist (
    id integer NOT NULL,
    program_enrolment_id bigint NOT NULL,
    uuid character varying(255) NOT NULL,
    version integer NOT NULL,
    base_date timestamp with time zone NOT NULL,
    organisation_id integer DEFAULT 1 NOT NULL,
    audit_id integer,
    is_voided boolean DEFAULT false NOT NULL,
    checklist_detail_id integer,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    manual_update_history text,
    sync_disabled boolean DEFAULT false,
    sync_disabled_date_time timestamp without time zone
);


--
-- Name: checklist_detail; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.checklist_detail (
    id smallint NOT NULL,
    uuid character varying(255) NOT NULL,
    version integer NOT NULL,
    audit_id integer NOT NULL,
    name character varying NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    organisation_id integer NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: checklist_detail_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.checklist_detail_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: checklist_detail_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.checklist_detail_id_seq OWNED BY public.checklist_detail.id;


--
-- Name: checklist_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.checklist_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: checklist_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.checklist_id_seq OWNED BY public.checklist.id;


--
-- Name: checklist_item; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.checklist_item (
    id integer NOT NULL,
    completion_date timestamp with time zone,
    checklist_id bigint NOT NULL,
    uuid character varying(255) NOT NULL,
    version integer NOT NULL,
    organisation_id integer DEFAULT 1 NOT NULL,
    audit_id integer,
    is_voided boolean DEFAULT false NOT NULL,
    observations jsonb,
    checklist_item_detail_id integer,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    manual_update_history text,
    sync_disabled boolean DEFAULT false,
    sync_disabled_date_time timestamp without time zone
);


--
-- Name: checklist_item_detail; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.checklist_item_detail (
    id smallint NOT NULL,
    uuid character varying(255) NOT NULL,
    version integer NOT NULL,
    audit_id integer NOT NULL,
    form_id integer NOT NULL,
    concept_id integer NOT NULL,
    checklist_detail_id integer NOT NULL,
    status jsonb DEFAULT '{}'::jsonb NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    organisation_id integer NOT NULL,
    dependent_on integer,
    schedule_on_expiry_of_dependency boolean DEFAULT false NOT NULL,
    min_days_from_start_date smallint,
    min_days_from_dependent integer,
    expires_after integer,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: checklist_item_detail_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.checklist_item_detail_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: checklist_item_detail_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.checklist_item_detail_id_seq OWNED BY public.checklist_item_detail.id;


--
-- Name: checklist_item_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.checklist_item_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: checklist_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.checklist_item_id_seq OWNED BY public.checklist_item.id;


--
-- Name: column_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.column_metadata (
    id integer NOT NULL,
    table_id integer,
    name text,
    type text,
    concept_id integer,
    concept_type text,
    concept_uuid character varying(255),
    schema_name text,
    parent_concept_uuid character varying(255),
    concept_voided boolean DEFAULT false
);


--
-- Name: column_metadata_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.column_metadata_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: column_metadata_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.column_metadata_id_seq OWNED BY public.column_metadata.id;


--
-- Name: comment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comment (
    id integer NOT NULL,
    organisation_id bigint NOT NULL,
    uuid character varying(255) NOT NULL,
    text text NOT NULL,
    subject_id bigint NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    audit_id bigint NOT NULL,
    version bigint DEFAULT 0 NOT NULL,
    comment_thread_id bigint,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    sync_disabled boolean DEFAULT false,
    sync_disabled_date_time timestamp without time zone
);


--
-- Name: comment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.comment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.comment_id_seq OWNED BY public.comment.id;


--
-- Name: comment_thread; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comment_thread (
    id integer NOT NULL,
    organisation_id bigint NOT NULL,
    uuid character varying(255) NOT NULL,
    status text NOT NULL,
    open_date_time timestamp with time zone,
    resolved_date_time timestamp with time zone,
    is_voided boolean DEFAULT false NOT NULL,
    audit_id bigint NOT NULL,
    version bigint DEFAULT 0 NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    sync_disabled boolean DEFAULT false,
    sync_disabled_date_time timestamp without time zone
);


--
-- Name: comment_thread_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.comment_thread_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comment_thread_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.comment_thread_id_seq OWNED BY public.comment_thread.id;


--
-- Name: concept_answer_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.concept_answer_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: concept_answer_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.concept_answer_id_seq OWNED BY public.concept_answer.id;


--
-- Name: concept_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.concept_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: concept_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.concept_id_seq OWNED BY public.concept.id;


--
-- Name: custom_query; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.custom_query (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    name text NOT NULL,
    query text NOT NULL,
    organisation_id integer NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    version integer NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: custom_query_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.custom_query_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: custom_query_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.custom_query_id_seq OWNED BY public.custom_query.id;


--
-- Name: dashboard; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dashboard (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    is_voided boolean DEFAULT false NOT NULL,
    version integer,
    organisation_id integer NOT NULL,
    audit_id integer,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: dashboard_card_mapping; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dashboard_card_mapping (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    dashboard_id bigint NOT NULL,
    card_id bigint NOT NULL,
    display_order double precision DEFAULT '-1'::integer NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    version integer,
    organisation_id integer NOT NULL,
    audit_id integer,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: dashboard_card_mapping_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dashboard_card_mapping_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dashboard_card_mapping_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dashboard_card_mapping_id_seq OWNED BY public.dashboard_card_mapping.id;


--
-- Name: dashboard_filter; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dashboard_filter (
    id integer NOT NULL,
    dashboard_id integer NOT NULL,
    filter_config jsonb NOT NULL,
    uuid character varying(255) NOT NULL,
    organisation_id integer NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    version integer NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    name character varying(255) NOT NULL
);


--
-- Name: dashboard_filter_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dashboard_filter_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dashboard_filter_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dashboard_filter_id_seq OWNED BY public.dashboard_filter.id;


--
-- Name: dashboard_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dashboard_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dashboard_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dashboard_id_seq OWNED BY public.dashboard.id;


--
-- Name: dashboard_section; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dashboard_section (
    id integer NOT NULL,
    uuid text NOT NULL,
    name text,
    description text,
    dashboard_id bigint NOT NULL,
    view_type text NOT NULL,
    display_order double precision DEFAULT '-1'::integer NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    version integer,
    organisation_id bigint NOT NULL,
    audit_id bigint,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    CONSTRAINT dashboard_section_check CHECK ((((name IS NOT NULL) AND (description IS NOT NULL)) OR (view_type = 'Default'::text)))
);


--
-- Name: dashboard_section_card_mapping; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dashboard_section_card_mapping (
    id integer NOT NULL,
    uuid text NOT NULL,
    dashboard_section_id bigint NOT NULL,
    card_id bigint NOT NULL,
    display_order double precision DEFAULT '-1'::integer NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    version integer,
    organisation_id bigint NOT NULL,
    audit_id bigint,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: dashboard_section_card_mapping_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dashboard_section_card_mapping_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dashboard_section_card_mapping_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dashboard_section_card_mapping_id_seq OWNED BY public.dashboard_section_card_mapping.id;


--
-- Name: dashboard_section_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dashboard_section_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dashboard_section_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dashboard_section_id_seq OWNED BY public.dashboard_section.id;


--
-- Name: decision_concept; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.decision_concept (
    id integer NOT NULL,
    concept_id bigint NOT NULL,
    form_id bigint NOT NULL
);


--
-- Name: decision_concept_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.decision_concept_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: decision_concept_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.decision_concept_id_seq OWNED BY public.decision_concept.id;


--
-- Name: deps_saved_ddl; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.deps_saved_ddl (
    deps_id integer NOT NULL,
    deps_view_schema character varying(255),
    deps_view_name character varying(255),
    deps_ddl_to_run text
);


--
-- Name: deps_saved_ddl_deps_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.deps_saved_ddl_deps_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: deps_saved_ddl_deps_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.deps_saved_ddl_deps_id_seq OWNED BY public.deps_saved_ddl.deps_id;


--
-- Name: documentation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.documentation (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    name text NOT NULL,
    organisation_id integer NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    version integer NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    parent_id integer
);


--
-- Name: documentation_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.documentation_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: documentation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.documentation_id_seq OWNED BY public.documentation.id;


--
-- Name: documentation_item; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.documentation_item (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    documentation_id integer NOT NULL,
    language text NOT NULL,
    content text NOT NULL,
    contenthtml text NOT NULL,
    organisation_id integer NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    version integer NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: documentation_item_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.documentation_item_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: documentation_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.documentation_item_id_seq OWNED BY public.documentation_item.id;


--
-- Name: encounter; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.encounter (
    id integer NOT NULL,
    observations jsonb NOT NULL,
    encounter_date_time timestamp with time zone,
    encounter_type_id integer NOT NULL,
    individual_id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    version integer NOT NULL,
    organisation_id integer DEFAULT 1 NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    audit_id integer,
    encounter_location point,
    earliest_visit_date_time timestamp with time zone,
    max_visit_date_time timestamp with time zone,
    cancel_date_time timestamp with time zone,
    cancel_observations jsonb,
    cancel_location point,
    name text,
    legacy_id character varying,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    address_id bigint,
    sync_concept_1_value text,
    sync_concept_2_value text,
    manual_update_history text,
    filled_by_id integer,
    sync_disabled boolean DEFAULT false,
    sync_disabled_date_time timestamp without time zone
);


--
-- Name: encounter_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.encounter_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: encounter_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.encounter_id_seq OWNED BY public.encounter.id;


--
-- Name: encounter_type_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.encounter_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: encounter_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.encounter_type_id_seq OWNED BY public.encounter_type.id;


--
-- Name: entity_approval_status; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entity_approval_status (
    id integer NOT NULL,
    uuid text NOT NULL,
    entity_id bigint NOT NULL,
    entity_type text NOT NULL,
    approval_status_id bigint NOT NULL,
    approval_status_comment text,
    organisation_id bigint NOT NULL,
    auto_approved boolean DEFAULT false NOT NULL,
    audit_id bigint NOT NULL,
    version bigint DEFAULT 0 NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    status_date_time timestamp with time zone NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    entity_type_uuid text DEFAULT ''::text NOT NULL,
    address_id bigint,
    individual_id bigint DEFAULT 1 NOT NULL,
    sync_concept_1_value text,
    sync_concept_2_value text,
    sync_disabled boolean DEFAULT false,
    sync_disabled_date_time timestamp without time zone,
    CONSTRAINT entity_approval_status_check CHECK (((entity_type <> 'Subject'::text) OR (entity_id = individual_id)))
);


--
-- Name: entity_approval_status_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.entity_approval_status_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entity_approval_status_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.entity_approval_status_id_seq OWNED BY public.entity_approval_status.id;


--
-- Name: entity_sync_status; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entity_sync_status (
    id integer NOT NULL,
    db_user text,
    table_metadata_id integer,
    last_sync_time timestamp(3) with time zone,
    sync_status text,
    schema_name text NOT NULL
);


--
-- Name: entity_sync_status_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.entity_sync_status_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entity_sync_status_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.entity_sync_status_id_seq OWNED BY public.entity_sync_status.id;


--
-- Name: export_job_parameters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.export_job_parameters (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    user_id integer NOT NULL,
    report_format jsonb NOT NULL,
    timezone text NOT NULL,
    organisation_id integer NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    version integer NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: export_job_parameters_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.export_job_parameters_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: export_job_parameters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.export_job_parameters_id_seq OWNED BY public.export_job_parameters.id;


--
-- Name: external_system_config; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.external_system_config (
    id integer NOT NULL,
    organisation_id integer NOT NULL,
    uuid character varying(255) DEFAULT public.uuid_generate_v4() NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    version integer NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    system_name character varying(255) NOT NULL,
    config jsonb NOT NULL
);


--
-- Name: external_system_config_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.external_system_config_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: external_system_config_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.external_system_config_id_seq OWNED BY public.external_system_config.id;


--
-- Name: facility; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.facility (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    address_id bigint,
    is_voided boolean DEFAULT false NOT NULL,
    organisation_id integer NOT NULL,
    version integer NOT NULL,
    audit_id integer,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: facility_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.facility_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: facility_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.facility_id_seq OWNED BY public.facility.id;


--
-- Name: flow_request_queue; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.flow_request_queue (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    organisation_id integer NOT NULL,
    message_receiver_id bigint NOT NULL,
    flow_id text NOT NULL,
    request_date_time timestamp(3) with time zone NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    delivery_status character varying(255) DEFAULT 'NotSent'::character varying NOT NULL
);


--
-- Name: flow_request_queue_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.flow_request_queue_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: flow_request_queue_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.flow_request_queue_id_seq OWNED BY public.flow_request_queue.id;


--
-- Name: flyway_schema_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.flyway_schema_history (
    installed_rank integer NOT NULL,
    version character varying(50),
    description character varying(200) NOT NULL,
    type character varying(20) NOT NULL,
    script character varying(1000) NOT NULL,
    checksum integer,
    installed_by character varying(100) NOT NULL,
    installed_on timestamp without time zone DEFAULT now() NOT NULL,
    execution_time integer NOT NULL,
    success boolean NOT NULL
);


--
-- Name: form_element_group_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.form_element_group_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: form_element_group_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.form_element_group_id_seq OWNED BY public.form_element_group.id;


--
-- Name: form_element_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.form_element_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: form_element_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.form_element_id_seq OWNED BY public.form_element.id;


--
-- Name: form_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.form_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: form_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.form_id_seq OWNED BY public.form.id;


--
-- Name: form_mapping_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.form_mapping_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: form_mapping_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.form_mapping_id_seq OWNED BY public.form_mapping.id;


--
-- Name: gender; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gender (
    id smallint NOT NULL,
    uuid character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    concept_id bigint,
    version integer NOT NULL,
    audit_id integer,
    is_voided boolean DEFAULT false NOT NULL,
    organisation_id integer NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: gender_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.gender_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: gender_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.gender_id_seq OWNED BY public.gender.id;


--
-- Name: group_dashboard; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_dashboard (
    id integer NOT NULL,
    uuid text NOT NULL,
    organisation_id bigint NOT NULL,
    is_primary_dashboard boolean DEFAULT false NOT NULL,
    audit_id bigint NOT NULL,
    version bigint DEFAULT 0 NOT NULL,
    group_id bigint NOT NULL,
    dashboard_id bigint NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    is_secondary_dashboard boolean DEFAULT false NOT NULL
);


--
-- Name: group_dashboard_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.group_dashboard_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: group_dashboard_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.group_dashboard_id_seq OWNED BY public.group_dashboard.id;


--
-- Name: group_privilege; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_privilege (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    group_id integer NOT NULL,
    privilege_id integer NOT NULL,
    subject_type_id integer,
    program_id integer,
    program_encounter_type_id integer,
    encounter_type_id integer,
    checklist_detail_id integer,
    allow boolean DEFAULT false NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    version integer,
    organisation_id integer NOT NULL,
    audit_id integer,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    impl_version integer DEFAULT 1 NOT NULL,
    CONSTRAINT check_group_privilege_unique CHECK (public.check_group_privilege_uniqueness(id, group_id, privilege_id, subject_type_id, program_id, program_encounter_type_id, encounter_type_id, checklist_detail_id, impl_version))
);


--
-- Name: group_privilege_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.group_privilege_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: group_privilege_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.group_privilege_id_seq OWNED BY public.group_privilege.id;


--
-- Name: group_role; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_role (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    group_subject_type_id integer NOT NULL,
    role text,
    member_subject_type_id integer NOT NULL,
    is_primary boolean DEFAULT false NOT NULL,
    maximum_number_of_members integer NOT NULL,
    minimum_number_of_members integer NOT NULL,
    organisation_id integer NOT NULL,
    audit_id integer,
    is_voided boolean DEFAULT false NOT NULL,
    version integer,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: group_role_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.group_role_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: group_role_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.group_role_id_seq OWNED BY public.group_role.id;


--
-- Name: group_subject; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_subject (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    group_subject_id integer NOT NULL,
    member_subject_id integer NOT NULL,
    group_role_id integer NOT NULL,
    membership_start_date timestamp with time zone,
    membership_end_date timestamp with time zone,
    organisation_id integer NOT NULL,
    audit_id integer,
    is_voided boolean DEFAULT false NOT NULL,
    version integer,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    member_subject_address_id bigint NOT NULL,
    group_subject_address_id bigint NOT NULL,
    group_subject_sync_concept_1_value text,
    group_subject_sync_concept_2_value text,
    sync_disabled boolean DEFAULT false,
    sync_disabled_date_time timestamp without time zone
);


--
-- Name: group_subject_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.group_subject_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: group_subject_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.group_subject_id_seq OWNED BY public.group_subject.id;


--
-- Name: groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.groups (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    version integer,
    organisation_id integer NOT NULL,
    audit_id integer,
    has_all_privileges boolean DEFAULT false NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.groups_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.groups_id_seq OWNED BY public.groups.id;


--
-- Name: identifier_assignment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.identifier_assignment (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    identifier_source_id integer NOT NULL,
    identifier text NOT NULL,
    assignment_order integer NOT NULL,
    assigned_to_user_id integer NOT NULL,
    individual_id integer,
    program_enrolment_id integer,
    version integer NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    organisation_id integer DEFAULT 1 NOT NULL,
    audit_id integer NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    used boolean DEFAULT false NOT NULL,
    device_id character varying
);


--
-- Name: identifier_assignment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.identifier_assignment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: identifier_assignment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.identifier_assignment_id_seq OWNED BY public.identifier_assignment.id;


--
-- Name: identifier_source; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.identifier_source (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    type text NOT NULL,
    catchment_id integer,
    minimum_balance integer DEFAULT 20 NOT NULL,
    batch_generation_size integer DEFAULT 100 NOT NULL,
    options jsonb DEFAULT '{}'::jsonb NOT NULL,
    version integer NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    organisation_id integer DEFAULT 1 NOT NULL,
    audit_id integer NOT NULL,
    min_length integer DEFAULT 0 NOT NULL,
    max_length integer DEFAULT 0 NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: identifier_source_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.identifier_source_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: identifier_source_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.identifier_source_id_seq OWNED BY public.identifier_source.id;


--
-- Name: identifier_user_assignment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.identifier_user_assignment (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    identifier_source_id integer NOT NULL,
    assigned_to_user_id integer NOT NULL,
    identifier_start text NOT NULL,
    identifier_end text NOT NULL,
    last_assigned_identifier text,
    version integer NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    organisation_id integer DEFAULT 1 NOT NULL,
    audit_id integer NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: identifier_user_assignment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.identifier_user_assignment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: identifier_user_assignment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.identifier_user_assignment_id_seq OWNED BY public.identifier_user_assignment.id;


--
-- Name: index_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.index_metadata (
    id integer NOT NULL,
    table_metadata_id integer,
    column_id integer,
    name text
);


--
-- Name: index_metadata_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.index_metadata_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: index_metadata_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.index_metadata_id_seq OWNED BY public.index_metadata.id;


--
-- Name: individual; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.individual (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    address_id bigint,
    observations jsonb,
    version integer NOT NULL,
    date_of_birth date,
    date_of_birth_verified boolean NOT NULL,
    gender_id bigint,
    registration_date date DEFAULT '2017-01-01'::date NOT NULL,
    organisation_id integer DEFAULT 1 NOT NULL,
    first_name character varying(256),
    last_name character varying(256),
    is_voided boolean DEFAULT false NOT NULL,
    audit_id integer,
    facility_id bigint,
    registration_location point,
    subject_type_id integer NOT NULL,
    legacy_id character varying,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    sync_concept_1_value text,
    sync_concept_2_value text,
    profile_picture text,
    middle_name character varying(255),
    manual_update_history text,
    sync_disabled boolean DEFAULT false,
    sync_disabled_date_time timestamp without time zone,
    subject_location jsonb
);


--
-- Name: individual_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.individual_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: individual_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.individual_id_seq OWNED BY public.individual.id;


--
-- Name: program_enrolment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.program_enrolment (
    id integer NOT NULL,
    program_id smallint NOT NULL,
    individual_id bigint NOT NULL,
    program_outcome_id smallint,
    observations jsonb,
    program_exit_observations jsonb,
    enrolment_date_time timestamp with time zone NOT NULL,
    program_exit_date_time timestamp with time zone,
    uuid character varying(255) NOT NULL,
    version integer NOT NULL,
    organisation_id integer DEFAULT 1 NOT NULL,
    audit_id integer,
    is_voided boolean DEFAULT false NOT NULL,
    enrolment_location point,
    exit_location point,
    legacy_id character varying,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    address_id bigint,
    sync_concept_1_value text,
    sync_concept_2_value text,
    manual_update_history text,
    sync_disabled boolean DEFAULT false,
    sync_disabled_date_time timestamp without time zone
);


--
-- Name: individual_program_enrolment_search_view; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.individual_program_enrolment_search_view AS
 SELECT progralalise.individual_id,
    string_agg(progralalise.programname, ','::text) AS program_name
   FROM ( SELECT pe.individual_id,
            concat(op.name, ':', prog.colour) AS programname
           FROM ((public.program_enrolment pe
             JOIN public.program prog ON ((prog.id = pe.program_id)))
             JOIN public.operational_program op ON (((prog.id = op.program_id) AND (pe.organisation_id = op.organisation_id))))
          WHERE ((pe.program_exit_date_time IS NULL) AND (pe.is_voided = false))
          GROUP BY pe.individual_id, op.name, prog.colour) progralalise
  GROUP BY progralalise.individual_id;


--
-- Name: individual_relation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.individual_relation (
    id smallint NOT NULL,
    uuid character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    organisation_id integer NOT NULL,
    version integer NOT NULL,
    audit_id integer,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: individual_relation_gender_mapping; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.individual_relation_gender_mapping (
    id smallint NOT NULL,
    uuid character varying(255) NOT NULL,
    relation_id smallint NOT NULL,
    gender_id smallint NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    organisation_id integer NOT NULL,
    version integer NOT NULL,
    audit_id integer,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: individual_relation_gender_mapping_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.individual_relation_gender_mapping_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: individual_relation_gender_mapping_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.individual_relation_gender_mapping_id_seq OWNED BY public.individual_relation_gender_mapping.id;


--
-- Name: individual_relation_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.individual_relation_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: individual_relation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.individual_relation_id_seq OWNED BY public.individual_relation.id;


--
-- Name: individual_relationship; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.individual_relationship (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    individual_a_id bigint NOT NULL,
    individual_b_id bigint NOT NULL,
    relationship_type_id smallint NOT NULL,
    enter_date_time timestamp with time zone,
    exit_date_time timestamp with time zone,
    exit_observations jsonb,
    is_voided boolean DEFAULT false NOT NULL,
    organisation_id integer NOT NULL,
    version integer NOT NULL,
    audit_id integer,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    sync_disabled boolean DEFAULT false,
    sync_disabled_date_time timestamp without time zone
);


--
-- Name: individual_relationship_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.individual_relationship_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: individual_relationship_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.individual_relationship_id_seq OWNED BY public.individual_relationship.id;


--
-- Name: individual_relationship_type; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.individual_relationship_type (
    id smallint NOT NULL,
    uuid character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    individual_a_is_to_b_relation_id smallint NOT NULL,
    individual_b_is_to_a_relation_id smallint NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    organisation_id integer NOT NULL,
    version integer NOT NULL,
    audit_id integer,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: individual_relationship_type_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.individual_relationship_type_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: individual_relationship_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.individual_relationship_type_id_seq OWNED BY public.individual_relationship_type.id;


--
-- Name: individual_relative; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.individual_relative (
    id smallint NOT NULL,
    uuid character varying(255) NOT NULL,
    individual_id bigint NOT NULL,
    relative_individual_id bigint NOT NULL,
    relation_id smallint NOT NULL,
    enter_date_time timestamp with time zone,
    exit_date_time timestamp with time zone,
    is_voided boolean DEFAULT false NOT NULL,
    organisation_id integer NOT NULL,
    version integer NOT NULL,
    audit_id integer,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: individual_relative_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.individual_relative_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: individual_relative_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.individual_relative_id_seq OWNED BY public.individual_relative.id;


--
-- Name: location_location_mapping; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.location_location_mapping (
    id integer NOT NULL,
    location_id bigint,
    parent_location_id bigint,
    version integer NOT NULL,
    audit_id bigint,
    uuid character varying(255) NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    organisation_id bigint,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: location_location_mapping_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.location_location_mapping_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: location_location_mapping_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.location_location_mapping_id_seq OWNED BY public.location_location_mapping.id;


--
-- Name: manual_message; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.manual_message (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    organisation_id integer NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    message_template_id text NOT NULL,
    parameters text[],
    version integer NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    next_trigger_details json
);


--
-- Name: manual_message_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.manual_message_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: manual_message_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.manual_message_id_seq OWNED BY public.manual_message.id;


--
-- Name: menu_item; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.menu_item (
    id integer NOT NULL,
    organisation_id integer NOT NULL,
    uuid character varying(255) DEFAULT public.uuid_generate_v4() NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    version integer NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    display_key character varying(255) NOT NULL,
    type character varying(100) NOT NULL,
    menu_group character varying(255) NOT NULL,
    icon character varying(255),
    link_function character varying(10000)
);


--
-- Name: menu_item_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.menu_item_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: menu_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.menu_item_id_seq OWNED BY public.menu_item.id;


--
-- Name: message_receiver; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.message_receiver (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    receiver_type text NOT NULL,
    organisation_id integer NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    external_id text,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    version integer NOT NULL,
    receiver_id integer
);


--
-- Name: message_receiver_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.message_receiver_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: message_receiver_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.message_receiver_id_seq OWNED BY public.message_receiver.id;


--
-- Name: message_request_queue; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.message_request_queue (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    organisation_id integer NOT NULL,
    message_rule_id bigint,
    message_receiver_id bigint NOT NULL,
    scheduled_date_time timestamp(3) with time zone NOT NULL,
    delivered_date_time timestamp(3) with time zone,
    delivery_status text NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    version integer NOT NULL,
    entity_id integer,
    manual_message_id bigint
);


--
-- Name: message_request_queue_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.message_request_queue_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: message_request_queue_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.message_request_queue_id_seq OWNED BY public.message_request_queue.id;


--
-- Name: message_rule; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.message_rule (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    name text NOT NULL,
    message_rule text,
    schedule_rule text,
    organisation_id integer NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    entity_type text NOT NULL,
    message_template_id text NOT NULL,
    version integer NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    entity_type_id integer NOT NULL,
    receiver_type text DEFAULT 'Subject'::text NOT NULL
);


--
-- Name: message_rule_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.message_rule_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: message_rule_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.message_rule_id_seq OWNED BY public.message_rule.id;


--
-- Name: msg91_config; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.msg91_config (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    auth_key character varying(255) NOT NULL,
    otp_sms_template_id character varying(255) NOT NULL,
    otp_length smallint,
    organisation_id integer NOT NULL,
    audit_id integer,
    is_voided boolean DEFAULT false NOT NULL,
    version integer,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: msg91_config_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.msg91_config_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: msg91_config_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.msg91_config_id_seq OWNED BY public.msg91_config.id;


--
-- Name: news; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.news (
    id integer NOT NULL,
    organisation_id bigint NOT NULL,
    uuid character varying(255) NOT NULL,
    title text NOT NULL,
    content text,
    contenthtml text,
    hero_image text,
    published_date timestamp with time zone,
    is_voided boolean DEFAULT false NOT NULL,
    audit_id bigint NOT NULL,
    version bigint DEFAULT 0 NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: news_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.news_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: news_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.news_id_seq OWNED BY public.news.id;


--
-- Name: non_applicable_form_element; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.non_applicable_form_element (
    id integer NOT NULL,
    organisation_id bigint,
    form_element_id bigint,
    is_voided boolean DEFAULT false NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    audit_id integer,
    uuid character varying(255) NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: non_applicable_form_element_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.non_applicable_form_element_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: non_applicable_form_element_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.non_applicable_form_element_id_seq OWNED BY public.non_applicable_form_element.id;


--
-- Name: operational_encounter_type_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operational_encounter_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operational_encounter_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operational_encounter_type_id_seq OWNED BY public.operational_encounter_type.id;


--
-- Name: operational_program_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operational_program_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operational_program_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operational_program_id_seq OWNED BY public.operational_program.id;


--
-- Name: operational_subject_type; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operational_subject_type (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    subject_type_id integer NOT NULL,
    organisation_id bigint NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    audit_id bigint NOT NULL,
    version integer DEFAULT 1,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: operational_subject_type_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.operational_subject_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operational_subject_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.operational_subject_type_id_seq OWNED BY public.operational_subject_type.id;


--
-- Name: org_ids; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.org_ids WITH (security_barrier='true') AS
 WITH RECURSIVE list_of_orgs(id, parent_organisation_id) AS (
         SELECT organisation.id,
            organisation.parent_organisation_id
           FROM public.organisation
          WHERE ((organisation.db_user)::text = CURRENT_USER)
        UNION ALL
         SELECT o.id,
            o.parent_organisation_id
           FROM public.organisation o,
            list_of_orgs log
          WHERE (o.id = log.parent_organisation_id)
        )
 SELECT list_of_orgs.id
   FROM list_of_orgs;


--
-- Name: organisation_category; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organisation_category (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    name character varying(255) NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    created_by_id integer NOT NULL,
    last_modified_by_id integer NOT NULL,
    version integer DEFAULT 1 NOT NULL
);


--
-- Name: organisation_category_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.organisation_category_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: organisation_category_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.organisation_category_id_seq OWNED BY public.organisation_category.id;


--
-- Name: organisation_config; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organisation_config (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    organisation_id bigint NOT NULL,
    settings jsonb,
    audit_id bigint,
    version integer DEFAULT 1,
    is_voided boolean DEFAULT false,
    worklist_updation_rule text,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    export_settings jsonb DEFAULT '{}'::jsonb
);


--
-- Name: organisation_config_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.organisation_config_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: organisation_config_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.organisation_config_id_seq OWNED BY public.organisation_config.id;


--
-- Name: organisation_group; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organisation_group (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    db_user character varying(255) NOT NULL,
    account_id integer NOT NULL,
    schema_name text,
    uuid character varying(255) DEFAULT public.uuid_generate_v4() NOT NULL,
    is_voided boolean DEFAULT false NOT NULL
);


--
-- Name: organisation_group_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.organisation_group_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: organisation_group_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.organisation_group_id_seq OWNED BY public.organisation_group.id;


--
-- Name: organisation_group_organisation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organisation_group_organisation (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    organisation_group_id integer NOT NULL,
    organisation_id integer NOT NULL
);


--
-- Name: organisation_group_organisation_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.organisation_group_organisation_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: organisation_group_organisation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.organisation_group_organisation_id_seq OWNED BY public.organisation_group_organisation.id;


--
-- Name: organisation_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.organisation_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: organisation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.organisation_id_seq OWNED BY public.organisation.id;


--
-- Name: organisation_status; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organisation_status (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    name character varying(255) NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    created_by_id integer NOT NULL,
    last_modified_by_id integer NOT NULL,
    version integer DEFAULT 1 NOT NULL
);


--
-- Name: organisation_status_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.organisation_status_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: organisation_status_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.organisation_status_id_seq OWNED BY public.organisation_status.id;


--
-- Name: platform_translation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.platform_translation (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    translation_json jsonb NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    platform character varying(255) NOT NULL,
    language character varying(255),
    version integer NOT NULL,
    audit_id integer NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: platform_translation_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.platform_translation_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: platform_translation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.platform_translation_id_seq OWNED BY public.platform_translation.id;


--
-- Name: post_etl_sync_status; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_etl_sync_status (
    id integer NOT NULL,
    cutoff_datetime timestamp with time zone NOT NULL,
    db_user text NOT NULL
);


--
-- Name: post_etl_sync_status_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_etl_sync_status_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_etl_sync_status_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_etl_sync_status_id_seq OWNED BY public.post_etl_sync_status.id;


--
-- Name: privilege; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.privilege (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    entity_type character varying(255) NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    created_date_time timestamp with time zone,
    last_modified_date_time timestamp(3) with time zone,
    type character varying(100) NOT NULL
);


--
-- Name: privilege_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.privilege_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: privilege_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.privilege_id_seq OWNED BY public.privilege.id;


--
-- Name: program_encounter; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.program_encounter (
    id integer NOT NULL,
    observations jsonb NOT NULL,
    earliest_visit_date_time timestamp with time zone,
    encounter_date_time timestamp with time zone,
    program_enrolment_id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    version integer NOT NULL,
    encounter_type_id integer DEFAULT 1 NOT NULL,
    name character varying(255),
    max_visit_date_time timestamp with time zone,
    organisation_id integer DEFAULT 1 NOT NULL,
    cancel_date_time timestamp with time zone,
    cancel_observations jsonb,
    audit_id integer,
    is_voided boolean DEFAULT false NOT NULL,
    encounter_location point,
    cancel_location point,
    legacy_id character varying,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    address_id bigint,
    individual_id bigint NOT NULL,
    sync_concept_1_value text,
    sync_concept_2_value text,
    manual_update_history text,
    filled_by_id integer,
    sync_disabled boolean DEFAULT false,
    sync_disabled_date_time timestamp without time zone,
    CONSTRAINT program_encounter_cannot_cancel_and_perform_check CHECK (((encounter_date_time IS NULL) OR (cancel_date_time IS NULL)))
);


--
-- Name: program_encounter_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.program_encounter_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: program_encounter_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.program_encounter_id_seq OWNED BY public.program_encounter.id;


--
-- Name: program_enrolment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.program_enrolment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: program_enrolment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.program_enrolment_id_seq OWNED BY public.program_enrolment.id;


--
-- Name: program_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.program_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: program_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.program_id_seq OWNED BY public.program.id;


--
-- Name: program_outcome; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.program_outcome (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    version integer NOT NULL,
    organisation_id integer DEFAULT 1 NOT NULL,
    audit_id integer,
    is_voided boolean DEFAULT false NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: program_outcome_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.program_outcome_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: program_outcome_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.program_outcome_id_seq OWNED BY public.program_outcome.id;


--
-- Name: qrtz_blob_triggers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.qrtz_blob_triggers (
    sched_name character varying(120) NOT NULL,
    trigger_name character varying(150) NOT NULL,
    trigger_group character varying(150) NOT NULL,
    blob_data bytea
);


--
-- Name: qrtz_calendars; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.qrtz_calendars (
    sched_name character varying(120) NOT NULL,
    calendar_name character varying(200) NOT NULL,
    calendar bytea NOT NULL
);


--
-- Name: qrtz_cron_triggers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.qrtz_cron_triggers (
    sched_name character varying(120) NOT NULL,
    trigger_name character varying(150) NOT NULL,
    trigger_group character varying(150) NOT NULL,
    cron_expression character varying(250) NOT NULL,
    time_zone_id character varying(80)
);


--
-- Name: qrtz_fired_triggers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.qrtz_fired_triggers (
    sched_name character varying(120) NOT NULL,
    entry_id character varying(140) NOT NULL,
    trigger_name character varying(150) NOT NULL,
    trigger_group character varying(150) NOT NULL,
    instance_name character varying(200) NOT NULL,
    fired_time bigint NOT NULL,
    sched_time bigint NOT NULL,
    priority integer NOT NULL,
    state character varying(16) NOT NULL,
    job_name character varying(200),
    job_group character varying(200),
    is_nonconcurrent boolean NOT NULL,
    requests_recovery boolean
);


--
-- Name: qrtz_job_details; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.qrtz_job_details (
    sched_name character varying(120) NOT NULL,
    job_name character varying(200) NOT NULL,
    job_group character varying(200) NOT NULL,
    description character varying(250),
    job_class_name character varying(250) NOT NULL,
    is_durable boolean NOT NULL,
    is_nonconcurrent boolean NOT NULL,
    is_update_data boolean NOT NULL,
    requests_recovery boolean NOT NULL,
    job_data bytea
);


--
-- Name: qrtz_locks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.qrtz_locks (
    sched_name character varying(120) NOT NULL,
    lock_name character varying(40) NOT NULL
);


--
-- Name: qrtz_paused_trigger_grps; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.qrtz_paused_trigger_grps (
    sched_name character varying(120) NOT NULL,
    trigger_group character varying(150) NOT NULL
);


--
-- Name: qrtz_scheduler_state; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.qrtz_scheduler_state (
    sched_name character varying(120) NOT NULL,
    instance_name character varying(200) NOT NULL,
    last_checkin_time bigint NOT NULL,
    checkin_interval bigint NOT NULL
);


--
-- Name: qrtz_simple_triggers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.qrtz_simple_triggers (
    sched_name character varying(120) NOT NULL,
    trigger_name character varying(150) NOT NULL,
    trigger_group character varying(150) NOT NULL,
    repeat_count bigint NOT NULL,
    repeat_interval bigint NOT NULL,
    times_triggered bigint NOT NULL
);


--
-- Name: qrtz_simprop_triggers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.qrtz_simprop_triggers (
    sched_name character varying(120) NOT NULL,
    trigger_name character varying(150) NOT NULL,
    trigger_group character varying(150) NOT NULL,
    str_prop_1 character varying(512),
    str_prop_2 character varying(512),
    str_prop_3 character varying(512),
    int_prop_1 integer,
    int_prop_2 integer,
    long_prop_1 bigint,
    long_prop_2 bigint,
    dec_prop_1 numeric,
    dec_prop_2 numeric,
    bool_prop_1 boolean,
    bool_prop_2 boolean,
    time_zone_id character varying(80)
);


--
-- Name: qrtz_triggers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.qrtz_triggers (
    sched_name character varying(120) NOT NULL,
    trigger_name character varying(150) NOT NULL,
    trigger_group character varying(150) NOT NULL,
    job_name character varying(200) NOT NULL,
    job_group character varying(200) NOT NULL,
    description character varying(250),
    next_fire_time bigint,
    prev_fire_time bigint,
    priority integer,
    trigger_state character varying(16) NOT NULL,
    trigger_type character varying(8) NOT NULL,
    start_time bigint NOT NULL,
    end_time bigint,
    calendar_name character varying(200),
    misfire_instr smallint,
    job_data bytea
);


--
-- Name: report_card; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.report_card (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    query text,
    description text,
    colour character varying(20),
    is_voided boolean DEFAULT false NOT NULL,
    version integer,
    organisation_id integer NOT NULL,
    audit_id integer,
    standard_report_card_type_id bigint,
    icon_file_s3_key text,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    nested boolean DEFAULT false,
    count_of_cards smallint DEFAULT 1 NOT NULL,
    standard_report_card_input jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT report_card_optional_standard_report_card_type CHECK (((standard_report_card_type_id IS NOT NULL) OR (query IS NOT NULL)))
);


--
-- Name: report_card_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.report_card_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: report_card_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.report_card_id_seq OWNED BY public.report_card.id;


--
-- Name: reset_sync; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reset_sync (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    user_id integer,
    subject_type_id integer,
    organisation_id integer NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    version integer NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: reset_sync_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.reset_sync_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reset_sync_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.reset_sync_id_seq OWNED BY public.reset_sync.id;


--
-- Name: rule; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rule (
    id smallint NOT NULL,
    uuid character varying(255) NOT NULL,
    version integer NOT NULL,
    audit_id integer NOT NULL,
    type character varying NOT NULL,
    rule_dependency_id integer,
    name character varying NOT NULL,
    fn_name character varying NOT NULL,
    data jsonb,
    organisation_id integer NOT NULL,
    execution_order double precision DEFAULT 10000.0 NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    entity jsonb NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: rule_dependency; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rule_dependency (
    id smallint NOT NULL,
    uuid character varying(255) NOT NULL,
    version integer NOT NULL,
    audit_id integer NOT NULL,
    checksum character varying NOT NULL,
    code text NOT NULL,
    organisation_id integer NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: rule_dependency_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rule_dependency_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rule_dependency_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rule_dependency_id_seq OWNED BY public.rule_dependency.id;


--
-- Name: rule_failure_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rule_failure_log (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    form_id character varying(255) NOT NULL,
    rule_type character varying(255) NOT NULL,
    entity_type character varying(255) NOT NULL,
    entity_id character varying(255) NOT NULL,
    error_message character varying(255) NOT NULL,
    stacktrace text NOT NULL,
    source character varying(255) NOT NULL,
    audit_id integer,
    is_voided boolean DEFAULT false NOT NULL,
    version integer NOT NULL,
    organisation_id bigint NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    is_closed boolean,
    closed_date_time timestamp without time zone
);


--
-- Name: rule_failure_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rule_failure_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rule_failure_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rule_failure_log_id_seq OWNED BY public.rule_failure_log.id;


--
-- Name: rule_failure_telemetry; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rule_failure_telemetry (
    id integer NOT NULL,
    user_id integer NOT NULL,
    organisation_id bigint NOT NULL,
    version integer DEFAULT 1,
    rule_uuid character varying(255),
    individual_uuid character varying(255) NOT NULL,
    error_message text NOT NULL,
    stacktrace text NOT NULL,
    error_date_time timestamp with time zone,
    closed_date_time timestamp with time zone,
    is_closed boolean DEFAULT false NOT NULL,
    audit_id bigint,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    source_type character varying(255),
    source_id character varying(255),
    entity_type character varying(255),
    entity_id character varying(255),
    app_type character varying(255)
);


--
-- Name: rule_failure_telemetry_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rule_failure_telemetry_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rule_failure_telemetry_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rule_failure_telemetry_id_seq OWNED BY public.rule_failure_telemetry.id;


--
-- Name: rule_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rule_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rule_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rule_id_seq OWNED BY public.rule.id;


--
-- Name: scheduled_job_run; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.scheduled_job_run (
    id integer NOT NULL,
    job_name character varying(255) NOT NULL,
    started_at timestamp(3) with time zone NOT NULL,
    ended_at timestamp(3) with time zone,
    error_message text,
    success boolean
);


--
-- Name: scheduled_job_run_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.scheduled_job_run_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: scheduled_job_run_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.scheduled_job_run_id_seq OWNED BY public.scheduled_job_run.id;


--
-- Name: standard_report_card_type; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.standard_report_card_type (
    id integer NOT NULL,
    uuid text NOT NULL,
    name text NOT NULL,
    description text,
    is_voided boolean DEFAULT false NOT NULL,
    created_date_time timestamp with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    type character varying(100) NOT NULL
);


--
-- Name: standard_report_card_type_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.standard_report_card_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: standard_report_card_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.standard_report_card_type_id_seq OWNED BY public.standard_report_card_type.id;


--
-- Name: subject_migration; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subject_migration (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    individual_id integer NOT NULL,
    old_address_level_id integer,
    new_address_level_id integer,
    organisation_id integer NOT NULL,
    audit_id integer NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    version integer NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    old_sync_concept_1_value text,
    new_sync_concept_1_value text,
    old_sync_concept_2_value text,
    new_sync_concept_2_value text,
    subject_type_id integer NOT NULL,
    manual_update_history text,
    sync_disabled boolean DEFAULT false,
    sync_disabled_date_time timestamp without time zone
);


--
-- Name: subject_migration_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.subject_migration_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: subject_migration_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.subject_migration_id_seq OWNED BY public.subject_migration.id;


--
-- Name: subject_program_eligibility; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subject_program_eligibility (
    id integer NOT NULL,
    organisation_id integer NOT NULL,
    uuid character varying(255) DEFAULT public.uuid_generate_v4() NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    version integer NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    subject_id bigint NOT NULL,
    program_id integer NOT NULL,
    is_eligible boolean NOT NULL,
    check_date timestamp with time zone NOT NULL,
    observations jsonb,
    sync_disabled boolean DEFAULT false,
    sync_disabled_date_time timestamp without time zone
);


--
-- Name: subject_program_eligibility_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.subject_program_eligibility_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: subject_program_eligibility_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.subject_program_eligibility_id_seq OWNED BY public.subject_program_eligibility.id;


--
-- Name: subject_type; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subject_type (
    id integer NOT NULL,
    uuid character varying(255),
    name character varying(255) NOT NULL,
    organisation_id bigint NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    audit_id bigint NOT NULL,
    version integer DEFAULT 1,
    is_group boolean DEFAULT false NOT NULL,
    is_household boolean DEFAULT false NOT NULL,
    active boolean DEFAULT true NOT NULL,
    type character varying(255),
    subject_summary_rule text,
    allow_empty_location boolean DEFAULT false NOT NULL,
    unique_name boolean DEFAULT false NOT NULL,
    valid_first_name_regex text,
    valid_first_name_description_key text,
    valid_last_name_regex text,
    valid_last_name_description_key text,
    icon_file_s3_key text,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    directly_assignable boolean DEFAULT false,
    should_sync_by_location boolean DEFAULT true,
    sync_registration_concept_1 character varying(255),
    sync_registration_concept_2 character varying(255),
    sync_registration_concept_1_usable boolean,
    sync_registration_concept_2_usable boolean,
    name_help_text text,
    allow_profile_picture boolean DEFAULT false NOT NULL,
    valid_middle_name_regex text,
    valid_middle_name_description_key text,
    allow_middle_name boolean DEFAULT false,
    program_eligibility_check_rule text,
    program_eligibility_check_declarative_rule text,
    last_name_optional boolean DEFAULT false,
    settings jsonb,
    member_addition_eligibility_check_rule text
);


--
-- Name: subject_type_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.subject_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: subject_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.subject_type_id_seq OWNED BY public.subject_type.id;


--
-- Name: sync_telemetry; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sync_telemetry (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    user_id integer NOT NULL,
    organisation_id bigint NOT NULL,
    version integer DEFAULT 1,
    sync_status character varying(255) NOT NULL,
    sync_start_time timestamp with time zone NOT NULL,
    sync_end_time timestamp with time zone,
    entity_status jsonb,
    device_name character varying(255),
    android_version character varying(255),
    app_version character varying(255),
    device_info jsonb,
    sync_source text,
    created_by_id bigint,
    last_modified_by_id bigint,
    is_voided boolean DEFAULT false NOT NULL,
    created_date_time timestamp(3) with time zone,
    last_modified_date_time timestamp(3) with time zone,
    app_info jsonb
);


--
-- Name: sync_telemetry_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sync_telemetry_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sync_telemetry_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sync_telemetry_id_seq OWNED BY public.sync_telemetry.id;


--
-- Name: table_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.table_metadata (
    id integer NOT NULL,
    name text,
    type text,
    schema_name text,
    subject_type_uuid character varying(255),
    program_uuid character varying(255),
    encounter_type_uuid character varying(255),
    form_uuid character varying(255),
    group_subject_type_uuid character varying(255),
    member_subject_type_uuid character varying(255),
    repeatable_question_group_concept_uuid character varying(255)
);


--
-- Name: table_metadata_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.table_metadata_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: table_metadata_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.table_metadata_id_seq OWNED BY public.table_metadata.id;


--
-- Name: task; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task (
    id integer NOT NULL,
    organisation_id integer NOT NULL,
    uuid character varying(255) DEFAULT public.uuid_generate_v4() NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    version integer NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    legacy_id character varying,
    name text NOT NULL,
    task_status_id integer NOT NULL,
    scheduled_on timestamp without time zone NOT NULL,
    completed_on timestamp without time zone,
    assigned_user_id integer,
    metadata jsonb NOT NULL,
    subject_id bigint,
    observations jsonb NOT NULL,
    task_type_id integer,
    manual_update_history text
);


--
-- Name: task_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.task_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: task_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.task_id_seq OWNED BY public.task.id;


--
-- Name: task_status; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_status (
    id integer NOT NULL,
    organisation_id integer NOT NULL,
    uuid character varying(255) DEFAULT public.uuid_generate_v4() NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    version integer NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    name text NOT NULL,
    task_type_id integer NOT NULL,
    is_terminal boolean NOT NULL
);


--
-- Name: task_status_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.task_status_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: task_status_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.task_status_id_seq OWNED BY public.task_status.id;


--
-- Name: task_type; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_type (
    id integer NOT NULL,
    organisation_id integer NOT NULL,
    uuid character varying(255) DEFAULT public.uuid_generate_v4() NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    version integer NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    name text NOT NULL,
    type text NOT NULL,
    metadata_search_fields text[]
);


--
-- Name: task_type_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.task_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: task_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.task_type_id_seq OWNED BY public.task_type.id;


--
-- Name: task_unassignment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_unassignment (
    id integer NOT NULL,
    organisation_id integer NOT NULL,
    uuid character varying(255) DEFAULT public.uuid_generate_v4() NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    version integer NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    task_id bigint NOT NULL,
    unassigned_user_id integer NOT NULL
);


--
-- Name: task_unassignment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.task_unassignment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: task_unassignment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.task_unassignment_id_seq OWNED BY public.task_unassignment.id;


--
-- Name: template_organisation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.template_organisation (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    summary text,
    active boolean DEFAULT true NOT NULL,
    organisation_id integer NOT NULL,
    created_by_id integer,
    last_modified_by_id integer,
    created_date_time timestamp with time zone,
    last_modified_date_time timestamp with time zone,
    is_voided boolean DEFAULT false NOT NULL,
    version integer DEFAULT 0 NOT NULL
);


--
-- Name: template_organisation_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.template_organisation ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.template_organisation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: title_lineage_locations_view; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.title_lineage_locations_view AS
 SELECT title_lineage_locations_function.lowestpoint_id,
    title_lineage_locations_function.title_lineage
   FROM public.title_lineage_locations_function(NULL::bigint) title_lineage_locations_function(lowestpoint_id, title_lineage);


--
-- Name: translation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.translation (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    organisation_id bigint NOT NULL,
    audit_id bigint NOT NULL,
    version integer DEFAULT 1,
    translation_json jsonb NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    language character varying(255),
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: translation_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.translation_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: translation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.translation_id_seq OWNED BY public.translation.id;


--
-- Name: user_group; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_group (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    user_id integer NOT NULL,
    group_id integer NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    version integer,
    organisation_id integer NOT NULL,
    audit_id integer,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    manual_update_history text
);


--
-- Name: user_group_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_group_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_group_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_group_id_seq OWNED BY public.user_group.id;


--
-- Name: user_subject; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_subject (
    id integer NOT NULL,
    organisation_id integer,
    uuid character varying(255) NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    created_by_id integer NOT NULL,
    last_modified_by_id integer NOT NULL,
    user_id integer NOT NULL,
    subject_id integer NOT NULL,
    version integer DEFAULT 1 NOT NULL
);


--
-- Name: user_subject_assignment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_subject_assignment (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    user_id integer NOT NULL,
    subject_id integer NOT NULL,
    organisation_id integer NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    version integer NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL,
    sync_disabled boolean DEFAULT false,
    sync_disabled_date_time timestamp without time zone
);


--
-- Name: user_subject_assignment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_subject_assignment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_subject_assignment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_subject_assignment_id_seq OWNED BY public.user_subject_assignment.id;


--
-- Name: user_subject_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_subject_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_subject_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_subject_id_seq OWNED BY public.user_subject.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id integer NOT NULL,
    uuid character varying(255) NOT NULL,
    username character varying(255) NOT NULL,
    organisation_id integer,
    created_by_id bigint DEFAULT 1 NOT NULL,
    last_modified_by_id bigint DEFAULT 1 NOT NULL,
    created_date_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    last_modified_date_time timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    catchment_id integer,
    is_org_admin boolean DEFAULT false NOT NULL,
    operating_individual_scope character varying(255) NOT NULL,
    settings jsonb,
    email character varying(320),
    phone_number character varying(32),
    disabled_in_cognito boolean DEFAULT false,
    name character varying(255) NOT NULL,
    sync_settings jsonb DEFAULT '{}'::jsonb,
    ignore_sync_settings_in_dea boolean DEFAULT false NOT NULL,
    last_activated_date_time timestamp(3) with time zone DEFAULT NULL::timestamp with time zone,
    CONSTRAINT users_check CHECK ((((operating_individual_scope)::text <> 'ByCatchment'::text) OR (catchment_id IS NOT NULL)))
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: video; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.video (
    id integer NOT NULL,
    version integer DEFAULT 1,
    audit_id bigint NOT NULL,
    uuid character varying(255),
    organisation_id bigint NOT NULL,
    title character varying(255) NOT NULL,
    file_path character varying(255) NOT NULL,
    description character varying(255),
    duration integer,
    is_voided boolean DEFAULT false NOT NULL,
    created_by_id bigint NOT NULL,
    last_modified_by_id bigint NOT NULL,
    created_date_time timestamp(3) with time zone NOT NULL,
    last_modified_date_time timestamp(3) with time zone NOT NULL
);


--
-- Name: video_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.video_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: video_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.video_id_seq OWNED BY public.video.id;


--
-- Name: video_telemetric; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.video_telemetric (
    id integer NOT NULL,
    uuid character varying(255),
    video_start_time double precision NOT NULL,
    video_end_time double precision NOT NULL,
    player_open_time timestamp with time zone NOT NULL,
    player_close_time timestamp with time zone NOT NULL,
    video_id integer NOT NULL,
    user_id integer NOT NULL,
    created_datetime timestamp with time zone NOT NULL,
    organisation_id integer NOT NULL,
    is_voided boolean DEFAULT false NOT NULL
);


--
-- Name: video_telemetric_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.video_telemetric_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: video_telemetric_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.video_telemetric_id_seq OWNED BY public.video_telemetric.id;


--
-- Name: virtual_catchment_address_mapping_table; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.virtual_catchment_address_mapping_table AS
 SELECT virtual_catchment_address_mapping_table_function.id,
    virtual_catchment_address_mapping_table_function.catchment_id,
    virtual_catchment_address_mapping_table_function.addresslevel_id,
    virtual_catchment_address_mapping_table_function.type_id
   FROM public.virtual_catchment_address_mapping_table_function() virtual_catchment_address_mapping_table_function(id, catchment_id, addresslevel_id, type_id);


--
-- Name: account id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account ALTER COLUMN id SET DEFAULT nextval('public.account_id_seq'::regclass);


--
-- Name: account_admin id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_admin ALTER COLUMN id SET DEFAULT nextval('public.account_admin_id_seq'::regclass);


--
-- Name: address_level id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.address_level ALTER COLUMN id SET DEFAULT nextval('public.address_level_id_seq'::regclass);


--
-- Name: address_level_type id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.address_level_type ALTER COLUMN id SET DEFAULT nextval('public.address_level_type_id_seq'::regclass);


--
-- Name: answer_concept_migration id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.answer_concept_migration ALTER COLUMN id SET DEFAULT nextval('public.answer_concept_migration_id_seq'::regclass);


--
-- Name: approval_status id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_status ALTER COLUMN id SET DEFAULT nextval('public.approval_status_id_seq'::regclass);


--
-- Name: audit id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit ALTER COLUMN id SET DEFAULT nextval('public.audit_id_seq'::regclass);


--
-- Name: catchment id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catchment ALTER COLUMN id SET DEFAULT nextval('public.catchment_id_seq'::regclass);


--
-- Name: catchment_address_mapping id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catchment_address_mapping ALTER COLUMN id SET DEFAULT nextval('public.catchment_address_mapping_id_seq'::regclass);


--
-- Name: checklist id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist ALTER COLUMN id SET DEFAULT nextval('public.checklist_id_seq'::regclass);


--
-- Name: checklist_detail id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist_detail ALTER COLUMN id SET DEFAULT nextval('public.checklist_detail_id_seq'::regclass);


--
-- Name: checklist_item id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist_item ALTER COLUMN id SET DEFAULT nextval('public.checklist_item_id_seq'::regclass);


--
-- Name: checklist_item_detail id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist_item_detail ALTER COLUMN id SET DEFAULT nextval('public.checklist_item_detail_id_seq'::regclass);


--
-- Name: column_metadata id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.column_metadata ALTER COLUMN id SET DEFAULT nextval('public.column_metadata_id_seq'::regclass);


--
-- Name: comment id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment ALTER COLUMN id SET DEFAULT nextval('public.comment_id_seq'::regclass);


--
-- Name: comment_thread id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment_thread ALTER COLUMN id SET DEFAULT nextval('public.comment_thread_id_seq'::regclass);


--
-- Name: concept id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concept ALTER COLUMN id SET DEFAULT nextval('public.concept_id_seq'::regclass);


--
-- Name: concept_answer id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concept_answer ALTER COLUMN id SET DEFAULT nextval('public.concept_answer_id_seq'::regclass);


--
-- Name: custom_query id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_query ALTER COLUMN id SET DEFAULT nextval('public.custom_query_id_seq'::regclass);


--
-- Name: dashboard id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard ALTER COLUMN id SET DEFAULT nextval('public.dashboard_id_seq'::regclass);


--
-- Name: dashboard_card_mapping id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_card_mapping ALTER COLUMN id SET DEFAULT nextval('public.dashboard_card_mapping_id_seq'::regclass);


--
-- Name: dashboard_filter id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_filter ALTER COLUMN id SET DEFAULT nextval('public.dashboard_filter_id_seq'::regclass);


--
-- Name: dashboard_section id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_section ALTER COLUMN id SET DEFAULT nextval('public.dashboard_section_id_seq'::regclass);


--
-- Name: dashboard_section_card_mapping id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_section_card_mapping ALTER COLUMN id SET DEFAULT nextval('public.dashboard_section_card_mapping_id_seq'::regclass);


--
-- Name: decision_concept id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decision_concept ALTER COLUMN id SET DEFAULT nextval('public.decision_concept_id_seq'::regclass);


--
-- Name: deps_saved_ddl deps_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deps_saved_ddl ALTER COLUMN deps_id SET DEFAULT nextval('public.deps_saved_ddl_deps_id_seq'::regclass);


--
-- Name: documentation id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documentation ALTER COLUMN id SET DEFAULT nextval('public.documentation_id_seq'::regclass);


--
-- Name: documentation_item id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documentation_item ALTER COLUMN id SET DEFAULT nextval('public.documentation_item_id_seq'::regclass);


--
-- Name: encounter id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.encounter ALTER COLUMN id SET DEFAULT nextval('public.encounter_id_seq'::regclass);


--
-- Name: encounter_type id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.encounter_type ALTER COLUMN id SET DEFAULT nextval('public.encounter_type_id_seq'::regclass);


--
-- Name: entity_approval_status id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_approval_status ALTER COLUMN id SET DEFAULT nextval('public.entity_approval_status_id_seq'::regclass);


--
-- Name: entity_sync_status id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_sync_status ALTER COLUMN id SET DEFAULT nextval('public.entity_sync_status_id_seq'::regclass);


--
-- Name: export_job_parameters id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.export_job_parameters ALTER COLUMN id SET DEFAULT nextval('public.export_job_parameters_id_seq'::regclass);


--
-- Name: external_system_config id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_system_config ALTER COLUMN id SET DEFAULT nextval('public.external_system_config_id_seq'::regclass);


--
-- Name: facility id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.facility ALTER COLUMN id SET DEFAULT nextval('public.facility_id_seq'::regclass);


--
-- Name: flow_request_queue id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flow_request_queue ALTER COLUMN id SET DEFAULT nextval('public.flow_request_queue_id_seq'::regclass);


--
-- Name: form id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form ALTER COLUMN id SET DEFAULT nextval('public.form_id_seq'::regclass);


--
-- Name: form_element id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_element ALTER COLUMN id SET DEFAULT nextval('public.form_element_id_seq'::regclass);


--
-- Name: form_element_group id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_element_group ALTER COLUMN id SET DEFAULT nextval('public.form_element_group_id_seq'::regclass);


--
-- Name: form_mapping id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_mapping ALTER COLUMN id SET DEFAULT nextval('public.form_mapping_id_seq'::regclass);


--
-- Name: gender id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gender ALTER COLUMN id SET DEFAULT nextval('public.gender_id_seq'::regclass);


--
-- Name: group_dashboard id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_dashboard ALTER COLUMN id SET DEFAULT nextval('public.group_dashboard_id_seq'::regclass);


--
-- Name: group_privilege id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_privilege ALTER COLUMN id SET DEFAULT nextval('public.group_privilege_id_seq'::regclass);


--
-- Name: group_role id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_role ALTER COLUMN id SET DEFAULT nextval('public.group_role_id_seq'::regclass);


--
-- Name: group_subject id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_subject ALTER COLUMN id SET DEFAULT nextval('public.group_subject_id_seq'::regclass);


--
-- Name: groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groups ALTER COLUMN id SET DEFAULT nextval('public.groups_id_seq'::regclass);


--
-- Name: identifier_assignment id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifier_assignment ALTER COLUMN id SET DEFAULT nextval('public.identifier_assignment_id_seq'::regclass);


--
-- Name: identifier_source id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifier_source ALTER COLUMN id SET DEFAULT nextval('public.identifier_source_id_seq'::regclass);


--
-- Name: identifier_user_assignment id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifier_user_assignment ALTER COLUMN id SET DEFAULT nextval('public.identifier_user_assignment_id_seq'::regclass);


--
-- Name: index_metadata id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.index_metadata ALTER COLUMN id SET DEFAULT nextval('public.index_metadata_id_seq'::regclass);


--
-- Name: individual id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual ALTER COLUMN id SET DEFAULT nextval('public.individual_id_seq'::regclass);


--
-- Name: individual_relation id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_relation ALTER COLUMN id SET DEFAULT nextval('public.individual_relation_id_seq'::regclass);


--
-- Name: individual_relation_gender_mapping id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_relation_gender_mapping ALTER COLUMN id SET DEFAULT nextval('public.individual_relation_gender_mapping_id_seq'::regclass);


--
-- Name: individual_relationship id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_relationship ALTER COLUMN id SET DEFAULT nextval('public.individual_relationship_id_seq'::regclass);


--
-- Name: individual_relationship_type id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_relationship_type ALTER COLUMN id SET DEFAULT nextval('public.individual_relationship_type_id_seq'::regclass);


--
-- Name: individual_relative id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_relative ALTER COLUMN id SET DEFAULT nextval('public.individual_relative_id_seq'::regclass);


--
-- Name: location_location_mapping id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.location_location_mapping ALTER COLUMN id SET DEFAULT nextval('public.location_location_mapping_id_seq'::regclass);


--
-- Name: manual_message id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manual_message ALTER COLUMN id SET DEFAULT nextval('public.manual_message_id_seq'::regclass);


--
-- Name: menu_item id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_item ALTER COLUMN id SET DEFAULT nextval('public.menu_item_id_seq'::regclass);


--
-- Name: message_receiver id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_receiver ALTER COLUMN id SET DEFAULT nextval('public.message_receiver_id_seq'::regclass);


--
-- Name: message_request_queue id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_request_queue ALTER COLUMN id SET DEFAULT nextval('public.message_request_queue_id_seq'::regclass);


--
-- Name: message_rule id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_rule ALTER COLUMN id SET DEFAULT nextval('public.message_rule_id_seq'::regclass);


--
-- Name: msg91_config id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msg91_config ALTER COLUMN id SET DEFAULT nextval('public.msg91_config_id_seq'::regclass);


--
-- Name: news id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news ALTER COLUMN id SET DEFAULT nextval('public.news_id_seq'::regclass);


--
-- Name: non_applicable_form_element id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.non_applicable_form_element ALTER COLUMN id SET DEFAULT nextval('public.non_applicable_form_element_id_seq'::regclass);


--
-- Name: operational_encounter_type id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operational_encounter_type ALTER COLUMN id SET DEFAULT nextval('public.operational_encounter_type_id_seq'::regclass);


--
-- Name: operational_program id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operational_program ALTER COLUMN id SET DEFAULT nextval('public.operational_program_id_seq'::regclass);


--
-- Name: operational_subject_type id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operational_subject_type ALTER COLUMN id SET DEFAULT nextval('public.operational_subject_type_id_seq'::regclass);


--
-- Name: organisation id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organisation ALTER COLUMN id SET DEFAULT nextval('public.organisation_id_seq'::regclass);


--
-- Name: organisation_category id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organisation_category ALTER COLUMN id SET DEFAULT nextval('public.organisation_category_id_seq'::regclass);


--
-- Name: organisation_config id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organisation_config ALTER COLUMN id SET DEFAULT nextval('public.organisation_config_id_seq'::regclass);


--
-- Name: organisation_group id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organisation_group ALTER COLUMN id SET DEFAULT nextval('public.organisation_group_id_seq'::regclass);


--
-- Name: organisation_group_organisation id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organisation_group_organisation ALTER COLUMN id SET DEFAULT nextval('public.organisation_group_organisation_id_seq'::regclass);


--
-- Name: organisation_status id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organisation_status ALTER COLUMN id SET DEFAULT nextval('public.organisation_status_id_seq'::regclass);


--
-- Name: platform_translation id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.platform_translation ALTER COLUMN id SET DEFAULT nextval('public.platform_translation_id_seq'::regclass);


--
-- Name: post_etl_sync_status id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_etl_sync_status ALTER COLUMN id SET DEFAULT nextval('public.post_etl_sync_status_id_seq'::regclass);


--
-- Name: privilege id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.privilege ALTER COLUMN id SET DEFAULT nextval('public.privilege_id_seq'::regclass);


--
-- Name: program id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.program ALTER COLUMN id SET DEFAULT nextval('public.program_id_seq'::regclass);


--
-- Name: program_encounter id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.program_encounter ALTER COLUMN id SET DEFAULT nextval('public.program_encounter_id_seq'::regclass);


--
-- Name: program_enrolment id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.program_enrolment ALTER COLUMN id SET DEFAULT nextval('public.program_enrolment_id_seq'::regclass);


--
-- Name: program_outcome id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.program_outcome ALTER COLUMN id SET DEFAULT nextval('public.program_outcome_id_seq'::regclass);


--
-- Name: report_card id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_card ALTER COLUMN id SET DEFAULT nextval('public.report_card_id_seq'::regclass);


--
-- Name: reset_sync id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reset_sync ALTER COLUMN id SET DEFAULT nextval('public.reset_sync_id_seq'::regclass);


--
-- Name: rule id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule ALTER COLUMN id SET DEFAULT nextval('public.rule_id_seq'::regclass);


--
-- Name: rule_dependency id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_dependency ALTER COLUMN id SET DEFAULT nextval('public.rule_dependency_id_seq'::regclass);


--
-- Name: rule_failure_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_failure_log ALTER COLUMN id SET DEFAULT nextval('public.rule_failure_log_id_seq'::regclass);


--
-- Name: rule_failure_telemetry id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_failure_telemetry ALTER COLUMN id SET DEFAULT nextval('public.rule_failure_telemetry_id_seq'::regclass);


--
-- Name: scheduled_job_run id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scheduled_job_run ALTER COLUMN id SET DEFAULT nextval('public.scheduled_job_run_id_seq'::regclass);


--
-- Name: standard_report_card_type id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.standard_report_card_type ALTER COLUMN id SET DEFAULT nextval('public.standard_report_card_type_id_seq'::regclass);


--
-- Name: storage_management_config id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.storage_management_config ALTER COLUMN id SET DEFAULT nextval('public.archival_config_id_seq'::regclass);


--
-- Name: subject_migration id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subject_migration ALTER COLUMN id SET DEFAULT nextval('public.subject_migration_id_seq'::regclass);


--
-- Name: subject_program_eligibility id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subject_program_eligibility ALTER COLUMN id SET DEFAULT nextval('public.subject_program_eligibility_id_seq'::regclass);


--
-- Name: subject_type id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subject_type ALTER COLUMN id SET DEFAULT nextval('public.subject_type_id_seq'::regclass);


--
-- Name: sync_telemetry id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sync_telemetry ALTER COLUMN id SET DEFAULT nextval('public.sync_telemetry_id_seq'::regclass);


--
-- Name: table_metadata id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.table_metadata ALTER COLUMN id SET DEFAULT nextval('public.table_metadata_id_seq'::regclass);


--
-- Name: task id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task ALTER COLUMN id SET DEFAULT nextval('public.task_id_seq'::regclass);


--
-- Name: task_status id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_status ALTER COLUMN id SET DEFAULT nextval('public.task_status_id_seq'::regclass);


--
-- Name: task_type id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_type ALTER COLUMN id SET DEFAULT nextval('public.task_type_id_seq'::regclass);


--
-- Name: task_unassignment id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_unassignment ALTER COLUMN id SET DEFAULT nextval('public.task_unassignment_id_seq'::regclass);


--
-- Name: translation id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.translation ALTER COLUMN id SET DEFAULT nextval('public.translation_id_seq'::regclass);


--
-- Name: user_group id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_group ALTER COLUMN id SET DEFAULT nextval('public.user_group_id_seq'::regclass);


--
-- Name: user_subject id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subject ALTER COLUMN id SET DEFAULT nextval('public.user_subject_id_seq'::regclass);


--
-- Name: user_subject_assignment id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subject_assignment ALTER COLUMN id SET DEFAULT nextval('public.user_subject_assignment_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: video id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.video ALTER COLUMN id SET DEFAULT nextval('public.video_id_seq'::regclass);


--
-- Name: video_telemetric id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.video_telemetric ALTER COLUMN id SET DEFAULT nextval('public.video_telemetric_id_seq'::regclass);


--
-- Name: account_admin account_admin_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_admin
    ADD CONSTRAINT account_admin_pkey PRIMARY KEY (id);


--
-- Name: account account_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account
    ADD CONSTRAINT account_pkey PRIMARY KEY (id);


--
-- Name: address_level address_level_legacy_id_organisation_id_uniq_idx; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.address_level
    ADD CONSTRAINT address_level_legacy_id_organisation_id_uniq_idx UNIQUE (legacy_id, organisation_id);


--
-- Name: address_level address_level_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.address_level
    ADD CONSTRAINT address_level_pkey PRIMARY KEY (id);


--
-- Name: address_level_type address_level_type_name_organisation_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.address_level_type
    ADD CONSTRAINT address_level_type_name_organisation_id_unique UNIQUE (name, organisation_id);


--
-- Name: address_level_type address_level_type_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.address_level_type
    ADD CONSTRAINT address_level_type_pkey PRIMARY KEY (id);


--
-- Name: address_level address_level_uuid_org_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.address_level
    ADD CONSTRAINT address_level_uuid_org_id_key UNIQUE (uuid, organisation_id);


--
-- Name: answer_concept_migration answer_concept_migration_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.answer_concept_migration
    ADD CONSTRAINT answer_concept_migration_pkey PRIMARY KEY (id);


--
-- Name: answer_concept_migration answer_concept_migration_uuid_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.answer_concept_migration
    ADD CONSTRAINT answer_concept_migration_uuid_organisation_id_key UNIQUE (uuid, organisation_id);


--
-- Name: approval_status approval_status_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_status
    ADD CONSTRAINT approval_status_pkey PRIMARY KEY (id);


--
-- Name: storage_management_config archival_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.storage_management_config
    ADD CONSTRAINT archival_config_pkey PRIMARY KEY (id);


--
-- Name: storage_management_config archival_config_uuid_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.storage_management_config
    ADD CONSTRAINT archival_config_uuid_organisation_id_key UNIQUE (uuid, organisation_id);


--
-- Name: audit audit_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit
    ADD CONSTRAINT audit_pkey PRIMARY KEY (id);


--
-- Name: batch_job_execution_context batch_job_execution_context_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_job_execution_context
    ADD CONSTRAINT batch_job_execution_context_pkey PRIMARY KEY (job_execution_id);


--
-- Name: batch_job_execution batch_job_execution_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_job_execution
    ADD CONSTRAINT batch_job_execution_pkey PRIMARY KEY (job_execution_id);


--
-- Name: batch_job_instance batch_job_instance_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_job_instance
    ADD CONSTRAINT batch_job_instance_pkey PRIMARY KEY (job_instance_id);


--
-- Name: batch_step_execution_context batch_step_execution_context_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_step_execution_context
    ADD CONSTRAINT batch_step_execution_context_pkey PRIMARY KEY (step_execution_id);


--
-- Name: batch_step_execution batch_step_execution_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_step_execution
    ADD CONSTRAINT batch_step_execution_pkey PRIMARY KEY (step_execution_id);


--
-- Name: report_card card_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_card
    ADD CONSTRAINT card_pkey PRIMARY KEY (id);


--
-- Name: report_card card_uuid_org_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_card
    ADD CONSTRAINT card_uuid_org_id_key UNIQUE (uuid, organisation_id);


--
-- Name: catchment_address_mapping catchment_address_mapping_catchment_id_address_level_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catchment_address_mapping
    ADD CONSTRAINT catchment_address_mapping_catchment_id_address_level_id_unique UNIQUE (catchment_id, addresslevel_id);


--
-- Name: catchment_address_mapping catchment_address_mapping_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catchment_address_mapping
    ADD CONSTRAINT catchment_address_mapping_pkey PRIMARY KEY (id);


--
-- Name: catchment catchment_name_organisation_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catchment
    ADD CONSTRAINT catchment_name_organisation_id_unique UNIQUE (name, organisation_id);


--
-- Name: catchment catchment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catchment
    ADD CONSTRAINT catchment_pkey PRIMARY KEY (id);


--
-- Name: catchment catchment_uuid_org_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catchment
    ADD CONSTRAINT catchment_uuid_org_id_key UNIQUE (uuid, organisation_id);


--
-- Name: checklist checklist_checklist_detail_id_program_enrolment_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist
    ADD CONSTRAINT checklist_checklist_detail_id_program_enrolment_id_unique UNIQUE (checklist_detail_id, program_enrolment_id);


--
-- Name: checklist_detail checklist_detail_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist_detail
    ADD CONSTRAINT checklist_detail_pkey PRIMARY KEY (id);


--
-- Name: checklist_detail checklist_detail_uuid_org_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist_detail
    ADD CONSTRAINT checklist_detail_uuid_org_id_key UNIQUE (uuid, organisation_id);


--
-- Name: checklist_item_detail checklist_item_detail_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist_item_detail
    ADD CONSTRAINT checklist_item_detail_pkey PRIMARY KEY (id);


--
-- Name: checklist_item_detail checklist_item_detail_uuid_org_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist_item_detail
    ADD CONSTRAINT checklist_item_detail_uuid_org_id_key UNIQUE (uuid, organisation_id);


--
-- Name: checklist_item checklist_item_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist_item
    ADD CONSTRAINT checklist_item_pkey PRIMARY KEY (id);


--
-- Name: checklist_item checklist_item_uuid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist_item
    ADD CONSTRAINT checklist_item_uuid_key UNIQUE (uuid);


--
-- Name: checklist checklist_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist
    ADD CONSTRAINT checklist_pkey PRIMARY KEY (id);


--
-- Name: checklist checklist_uuid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist
    ADD CONSTRAINT checklist_uuid_key UNIQUE (uuid);


--
-- Name: column_metadata column_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.column_metadata
    ADD CONSTRAINT column_metadata_pkey PRIMARY KEY (id);


--
-- Name: comment comment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment
    ADD CONSTRAINT comment_pkey PRIMARY KEY (id);


--
-- Name: comment_thread comment_thread_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment_thread
    ADD CONSTRAINT comment_thread_pkey PRIMARY KEY (id);


--
-- Name: comment_thread comment_thread_uuid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment_thread
    ADD CONSTRAINT comment_thread_uuid_key UNIQUE (uuid);


--
-- Name: comment comment_uuid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment
    ADD CONSTRAINT comment_uuid_key UNIQUE (uuid);


--
-- Name: concept_answer concept_answer_concept_id_answer_concept_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concept_answer
    ADD CONSTRAINT concept_answer_concept_id_answer_concept_id_key UNIQUE (concept_id, answer_concept_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: concept_answer concept_answer_concept_id_answer_concept_id_organisation_id_uni; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concept_answer
    ADD CONSTRAINT concept_answer_concept_id_answer_concept_id_organisation_id_uni UNIQUE (concept_id, answer_concept_id, organisation_id);


--
-- Name: concept_answer concept_answer_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concept_answer
    ADD CONSTRAINT concept_answer_pkey PRIMARY KEY (id);


--
-- Name: concept_answer concept_answer_uuid_org_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concept_answer
    ADD CONSTRAINT concept_answer_uuid_org_id_key UNIQUE (uuid, organisation_id);


--
-- Name: concept concept_name_orgid; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concept
    ADD CONSTRAINT concept_name_orgid UNIQUE (name, organisation_id);


--
-- Name: concept concept_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concept
    ADD CONSTRAINT concept_pkey PRIMARY KEY (id);


--
-- Name: concept concept_uuid_org_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concept
    ADD CONSTRAINT concept_uuid_org_id_key UNIQUE (uuid, organisation_id);


--
-- Name: individual_relationship const_individual_relationship_sync_disabled_same_as_ind_a; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.individual_relationship
    ADD CONSTRAINT const_individual_relationship_sync_disabled_same_as_ind_a CHECK (public.assert_one_of_subjects_with_sync_disabled(sync_disabled, individual_a_id, individual_b_id)) NOT VALID;


--
-- Name: subject_program_eligibility const_subject_program_eligibility_sync_disabled_same_as_ind; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.subject_program_eligibility
    ADD CONSTRAINT const_subject_program_eligibility_sync_disabled_same_as_ind CHECK (public.assert_subject_with_same_sync_disabled(sync_disabled, subject_id)) NOT VALID;


--
-- Name: checklist_item constraint_checklist_item_sync_disabled_same_as_individual; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.checklist_item
    ADD CONSTRAINT constraint_checklist_item_sync_disabled_same_as_individual CHECK (public.checklist_item_sync_disabled_same_as_individual(sync_disabled, checklist_id)) NOT VALID;


--
-- Name: checklist constraint_checklist_sync_disabled_same_as_individual; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.checklist
    ADD CONSTRAINT constraint_checklist_sync_disabled_same_as_individual CHECK (public.checklist_sync_disabled_same_as_individual(sync_disabled, program_enrolment_id)) NOT VALID;


--
-- Name: comment constraint_comment_sync_disabled_same_as_individual; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.comment
    ADD CONSTRAINT constraint_comment_sync_disabled_same_as_individual CHECK (public.assert_subject_with_same_sync_disabled(sync_disabled, subject_id)) NOT VALID;


--
-- Name: comment_thread constraint_comment_thread_sync_disabled_same_as_individual; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.comment_thread
    ADD CONSTRAINT constraint_comment_thread_sync_disabled_same_as_individual CHECK (public.comment_thread_sync_disabled_same_as_individual(sync_disabled, (id)::bigint)) NOT VALID;


--
-- Name: encounter constraint_encounter_sync_disabled_same_as_individual; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.encounter
    ADD CONSTRAINT constraint_encounter_sync_disabled_same_as_individual CHECK (public.assert_subject_with_same_sync_disabled(sync_disabled, (id)::bigint)) NOT VALID;


--
-- Name: entity_approval_status constraint_entity_approval_status_sync_disabled_same_as_ind; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.entity_approval_status
    ADD CONSTRAINT constraint_entity_approval_status_sync_disabled_same_as_ind CHECK (public.assert_subject_with_same_sync_disabled(sync_disabled, individual_id)) NOT VALID;


--
-- Name: group_subject constraint_group_subject_status_sync_disabled_same_as_ind; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.group_subject
    ADD CONSTRAINT constraint_group_subject_status_sync_disabled_same_as_ind CHECK (public.assert_one_of_subjects_with_sync_disabled(sync_disabled, (group_subject_id)::bigint, (member_subject_id)::bigint)) NOT VALID;


--
-- Name: program_encounter constraint_program_encounter_sync_disabled_same_as_individual; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.program_encounter
    ADD CONSTRAINT constraint_program_encounter_sync_disabled_same_as_individual CHECK (public.program_encounter_sync_disabled_same_as_individual(sync_disabled, (program_enrolment_id)::bigint)) NOT VALID;


--
-- Name: program_enrolment constraint_program_enrolment_sync_disabled_same_as_individual; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.program_enrolment
    ADD CONSTRAINT constraint_program_enrolment_sync_disabled_same_as_individual CHECK (public.assert_subject_with_same_sync_disabled(sync_disabled, individual_id)) NOT VALID;


--
-- Name: subject_migration constraint_subject_migration_sync_disabled_same_as_individual; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.subject_migration
    ADD CONSTRAINT constraint_subject_migration_sync_disabled_same_as_individual CHECK (public.assert_subject_with_same_sync_disabled(sync_disabled, (individual_id)::bigint)) NOT VALID;


--
-- Name: user_subject_assignment constraint_user_subject_assignment_sync_disabled_same_as_ind; Type: CHECK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.user_subject_assignment
    ADD CONSTRAINT constraint_user_subject_assignment_sync_disabled_same_as_ind CHECK (public.assert_subject_with_same_sync_disabled(sync_disabled, (subject_id)::bigint)) NOT VALID;


--
-- Name: custom_query custom_query_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_query
    ADD CONSTRAINT custom_query_pkey PRIMARY KEY (id);


--
-- Name: custom_query custom_query_uuid_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_query
    ADD CONSTRAINT custom_query_uuid_organisation_id_key UNIQUE (uuid, organisation_id);


--
-- Name: dashboard_card_mapping dashboard_card_mapping_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_card_mapping
    ADD CONSTRAINT dashboard_card_mapping_pkey PRIMARY KEY (id);


--
-- Name: dashboard_card_mapping dashboard_card_uuid_org_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_card_mapping
    ADD CONSTRAINT dashboard_card_uuid_org_id_key UNIQUE (uuid, organisation_id);


--
-- Name: dashboard_filter dashboard_filter_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_filter
    ADD CONSTRAINT dashboard_filter_pkey PRIMARY KEY (id);


--
-- Name: dashboard_filter dashboard_filter_uuid_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_filter
    ADD CONSTRAINT dashboard_filter_uuid_organisation_id_key UNIQUE (uuid, organisation_id);


--
-- Name: dashboard dashboard_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard
    ADD CONSTRAINT dashboard_pkey PRIMARY KEY (id);


--
-- Name: dashboard_section_card_mapping dashboard_section_card_mapping_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_section_card_mapping
    ADD CONSTRAINT dashboard_section_card_mapping_pkey PRIMARY KEY (id);


--
-- Name: dashboard_section_card_mapping dashboard_section_card_mapping_uuid_org_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_section_card_mapping
    ADD CONSTRAINT dashboard_section_card_mapping_uuid_org_id_key UNIQUE (uuid, organisation_id);


--
-- Name: dashboard_section dashboard_section_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_section
    ADD CONSTRAINT dashboard_section_pkey PRIMARY KEY (id);


--
-- Name: dashboard_section dashboard_section_uuid_org_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_section
    ADD CONSTRAINT dashboard_section_uuid_org_id_key UNIQUE (uuid, organisation_id);


--
-- Name: dashboard dashboard_uuid_org_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard
    ADD CONSTRAINT dashboard_uuid_org_id_key UNIQUE (uuid, organisation_id);


--
-- Name: decision_concept decision_concept_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decision_concept
    ADD CONSTRAINT decision_concept_pkey PRIMARY KEY (id);


--
-- Name: deps_saved_ddl deps_saved_ddl_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deps_saved_ddl
    ADD CONSTRAINT deps_saved_ddl_pkey PRIMARY KEY (deps_id);


--
-- Name: documentation_item documentation_item_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documentation_item
    ADD CONSTRAINT documentation_item_pkey PRIMARY KEY (id);


--
-- Name: documentation_item documentation_item_uuid_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documentation_item
    ADD CONSTRAINT documentation_item_uuid_organisation_id_key UNIQUE (uuid, organisation_id);


--
-- Name: documentation documentation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documentation
    ADD CONSTRAINT documentation_pkey PRIMARY KEY (id);


--
-- Name: documentation documentation_uuid_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documentation
    ADD CONSTRAINT documentation_uuid_organisation_id_key UNIQUE (uuid, organisation_id);


--
-- Name: encounter encounter_legacy_id_organisation_id_uniq_idx; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.encounter
    ADD CONSTRAINT encounter_legacy_id_organisation_id_uniq_idx UNIQUE (legacy_id, organisation_id);


--
-- Name: encounter encounter_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.encounter
    ADD CONSTRAINT encounter_pkey PRIMARY KEY (id);


--
-- Name: encounter_type encounter_type_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.encounter_type
    ADD CONSTRAINT encounter_type_pkey PRIMARY KEY (id);


--
-- Name: encounter_type encounter_type_uuid_org_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.encounter_type
    ADD CONSTRAINT encounter_type_uuid_org_id_key UNIQUE (uuid, organisation_id);


--
-- Name: encounter encounter_uuid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.encounter
    ADD CONSTRAINT encounter_uuid_key UNIQUE (uuid);


--
-- Name: entity_approval_status entity_approval_status_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_approval_status
    ADD CONSTRAINT entity_approval_status_pkey PRIMARY KEY (id);


--
-- Name: entity_approval_status entity_approval_status_uuid_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_approval_status
    ADD CONSTRAINT entity_approval_status_uuid_organisation_id_key UNIQUE (uuid, organisation_id);


--
-- Name: entity_sync_status entity_sync_status_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_sync_status
    ADD CONSTRAINT entity_sync_status_pkey PRIMARY KEY (id);


--
-- Name: export_job_parameters export_job_parameters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.export_job_parameters
    ADD CONSTRAINT export_job_parameters_pkey PRIMARY KEY (id);


--
-- Name: export_job_parameters export_job_parameters_uuid_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.export_job_parameters
    ADD CONSTRAINT export_job_parameters_uuid_organisation_id_key UNIQUE (uuid, organisation_id);


--
-- Name: external_system_config external_system_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_system_config
    ADD CONSTRAINT external_system_config_pkey PRIMARY KEY (id);


--
-- Name: external_system_config external_system_config_uuid_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_system_config
    ADD CONSTRAINT external_system_config_uuid_organisation_id_key UNIQUE (uuid, organisation_id);


--
-- Name: facility facility_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.facility
    ADD CONSTRAINT facility_pkey PRIMARY KEY (id);


--
-- Name: form_element fe_feg_id_display_order_org_id_is_voided_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_element
    ADD CONSTRAINT fe_feg_id_display_order_org_id_is_voided_key UNIQUE (form_element_group_id, display_order, organisation_id, is_voided) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: form_element_group feg_f_id_display_order_org_id_is_voided_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_element_group
    ADD CONSTRAINT feg_f_id_display_order_org_id_is_voided_key UNIQUE (form_id, display_order, organisation_id, is_voided) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flow_request_queue flow_request_queue_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flow_request_queue
    ADD CONSTRAINT flow_request_queue_pkey PRIMARY KEY (id);


--
-- Name: flow_request_queue flow_request_queue_uuid_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flow_request_queue
    ADD CONSTRAINT flow_request_queue_uuid_organisation_id_key UNIQUE (uuid, organisation_id);


--
-- Name: flyway_schema_history flyway_schema_history_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flyway_schema_history
    ADD CONSTRAINT flyway_schema_history_pk PRIMARY KEY (installed_rank);


--
-- Name: form_element_group form_element_group_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_element_group
    ADD CONSTRAINT form_element_group_pkey PRIMARY KEY (id);


--
-- Name: form_element_group form_element_group_uuid_org_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_element_group
    ADD CONSTRAINT form_element_group_uuid_org_id_key UNIQUE (uuid, organisation_id);


--
-- Name: form_element form_element_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_element
    ADD CONSTRAINT form_element_pkey PRIMARY KEY (id);


--
-- Name: form_element form_element_uuid_org_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_element
    ADD CONSTRAINT form_element_uuid_org_id_key UNIQUE (uuid, organisation_id);


--
-- Name: form_mapping form_mapping_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_mapping
    ADD CONSTRAINT form_mapping_pkey PRIMARY KEY (id);


--
-- Name: form_mapping form_mapping_uuid_org_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_mapping
    ADD CONSTRAINT form_mapping_uuid_org_id_key UNIQUE (uuid, organisation_id);


--
-- Name: form form_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form
    ADD CONSTRAINT form_pkey PRIMARY KEY (id);


--
-- Name: form form_uuid_org_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form
    ADD CONSTRAINT form_uuid_org_id_key UNIQUE (uuid, organisation_id);


--
-- Name: gender gender_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gender
    ADD CONSTRAINT gender_pkey PRIMARY KEY (id);


--
-- Name: gender gender_uuid_org_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gender
    ADD CONSTRAINT gender_uuid_org_id_key UNIQUE (uuid, organisation_id);


--
-- Name: group_dashboard group_dashboard_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_dashboard
    ADD CONSTRAINT group_dashboard_pkey PRIMARY KEY (id);


--
-- Name: group_dashboard group_dashboard_uuid_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_dashboard
    ADD CONSTRAINT group_dashboard_uuid_organisation_id_key UNIQUE (uuid, organisation_id);


--
-- Name: group_privilege group_privilege_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_privilege
    ADD CONSTRAINT group_privilege_pkey PRIMARY KEY (id);


--
-- Name: group_privilege group_privilege_uuid_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_privilege
    ADD CONSTRAINT group_privilege_uuid_organisation_id_key UNIQUE (uuid, organisation_id);


--
-- Name: group_role group_role_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_role
    ADD CONSTRAINT group_role_pkey PRIMARY KEY (id);


--
-- Name: group_role group_role_uuid_org_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_role
    ADD CONSTRAINT group_role_uuid_org_id_key UNIQUE (uuid, organisation_id);


--
-- Name: group_subject group_subject_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_subject
    ADD CONSTRAINT group_subject_pkey PRIMARY KEY (id);


--
-- Name: group_subject group_subject_uuid_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_subject
    ADD CONSTRAINT group_subject_uuid_organisation_id_key UNIQUE (uuid, organisation_id);


--
-- Name: groups groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT groups_pkey PRIMARY KEY (id);


--
-- Name: groups groups_uuid_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT groups_uuid_organisation_id_key UNIQUE (uuid, organisation_id);


--
-- Name: identifier_assignment identifier_assignment_identifier_source_id_identifier_organ_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifier_assignment
    ADD CONSTRAINT identifier_assignment_identifier_source_id_identifier_organ_key UNIQUE (identifier_source_id, identifier, organisation_id);


--
-- Name: identifier_assignment identifier_assignment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifier_assignment
    ADD CONSTRAINT identifier_assignment_pkey PRIMARY KEY (id);


--
-- Name: identifier_assignment identifier_assignment_uuid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifier_assignment
    ADD CONSTRAINT identifier_assignment_uuid_key UNIQUE (uuid);


--
-- Name: identifier_source identifier_source_name_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifier_source
    ADD CONSTRAINT identifier_source_name_organisation_id_key UNIQUE (name, organisation_id);


--
-- Name: identifier_source identifier_source_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifier_source
    ADD CONSTRAINT identifier_source_pkey PRIMARY KEY (id);


--
-- Name: identifier_source identifier_source_uuid_org_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifier_source
    ADD CONSTRAINT identifier_source_uuid_org_id_key UNIQUE (uuid, organisation_id);


--
-- Name: identifier_user_assignment identifier_user_assignment_identifier_source_id_assigned_to_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifier_user_assignment
    ADD CONSTRAINT identifier_user_assignment_identifier_source_id_assigned_to_key UNIQUE (identifier_source_id, assigned_to_user_id, identifier_start);


--
-- Name: identifier_user_assignment identifier_user_assignment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifier_user_assignment
    ADD CONSTRAINT identifier_user_assignment_pkey PRIMARY KEY (id);


--
-- Name: identifier_user_assignment identifier_user_assignment_uuid_org_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifier_user_assignment
    ADD CONSTRAINT identifier_user_assignment_uuid_org_id_key UNIQUE (uuid, organisation_id);


--
-- Name: index_metadata index_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.index_metadata
    ADD CONSTRAINT index_metadata_pkey PRIMARY KEY (id);


--
-- Name: individual individual_legacy_id_organisation_id_uniq_idx; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual
    ADD CONSTRAINT individual_legacy_id_organisation_id_uniq_idx UNIQUE (legacy_id, organisation_id);


--
-- Name: individual individual_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual
    ADD CONSTRAINT individual_pkey PRIMARY KEY (id);


--
-- Name: individual_relation_gender_mapping individual_relation_gender_mapping_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_relation_gender_mapping
    ADD CONSTRAINT individual_relation_gender_mapping_pkey PRIMARY KEY (id);


--
-- Name: individual_relation_gender_mapping individual_relation_gender_mapping_uuid_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_relation_gender_mapping
    ADD CONSTRAINT individual_relation_gender_mapping_uuid_organisation_id_key UNIQUE (uuid, organisation_id);


--
-- Name: individual_relation individual_relation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_relation
    ADD CONSTRAINT individual_relation_pkey PRIMARY KEY (id);


--
-- Name: individual_relation individual_relation_uuid_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_relation
    ADD CONSTRAINT individual_relation_uuid_organisation_id_key UNIQUE (uuid, organisation_id);


--
-- Name: individual_relationship individual_relationship_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_relationship
    ADD CONSTRAINT individual_relationship_pkey PRIMARY KEY (id);


--
-- Name: individual_relationship_type individual_relationship_type_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_relationship_type
    ADD CONSTRAINT individual_relationship_type_pkey PRIMARY KEY (id);


--
-- Name: individual_relationship_type individual_relationship_type_uuid_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_relationship_type
    ADD CONSTRAINT individual_relationship_type_uuid_organisation_id_key UNIQUE (uuid, organisation_id);


--
-- Name: individual_relationship individual_relationship_uuid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_relationship
    ADD CONSTRAINT individual_relationship_uuid_key UNIQUE (uuid);


--
-- Name: individual_relative individual_relative_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_relative
    ADD CONSTRAINT individual_relative_pkey PRIMARY KEY (id);


--
-- Name: individual individual_uuid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual
    ADD CONSTRAINT individual_uuid_key UNIQUE (uuid);


--
-- Name: batch_job_instance job_inst_un; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_job_instance
    ADD CONSTRAINT job_inst_un UNIQUE (job_name, job_key);


--
-- Name: location_location_mapping location_location_mapping_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.location_location_mapping
    ADD CONSTRAINT location_location_mapping_pkey PRIMARY KEY (id);


--
-- Name: location_location_mapping location_location_mapping_uuid_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.location_location_mapping
    ADD CONSTRAINT location_location_mapping_uuid_organisation_id_key UNIQUE (uuid, organisation_id);


--
-- Name: manual_message manual_broadcast_message_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manual_message
    ADD CONSTRAINT manual_broadcast_message_pkey PRIMARY KEY (id);


--
-- Name: manual_message manual_broadcast_message_uuid_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manual_message
    ADD CONSTRAINT manual_broadcast_message_uuid_organisation_id_key UNIQUE (uuid, organisation_id);


--
-- Name: menu_item menu_item_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_item
    ADD CONSTRAINT menu_item_pkey PRIMARY KEY (id);


--
-- Name: menu_item menu_item_uuid_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_item
    ADD CONSTRAINT menu_item_uuid_organisation_id_key UNIQUE (uuid, organisation_id);


--
-- Name: message_receiver message_receiver_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_receiver
    ADD CONSTRAINT message_receiver_pkey PRIMARY KEY (id);


--
-- Name: message_receiver message_receiver_receiver_id_receiver_type_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_receiver
    ADD CONSTRAINT message_receiver_receiver_id_receiver_type_organisation_id_key UNIQUE (receiver_id, receiver_type, organisation_id);


--
-- Name: message_receiver message_receiver_uuid_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_receiver
    ADD CONSTRAINT message_receiver_uuid_organisation_id_key UNIQUE (uuid, organisation_id);


--
-- Name: message_request_queue message_request_queue_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_request_queue
    ADD CONSTRAINT message_request_queue_pkey PRIMARY KEY (id);


--
-- Name: message_request_queue message_request_queue_uuid_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_request_queue
    ADD CONSTRAINT message_request_queue_uuid_organisation_id_key UNIQUE (uuid, organisation_id);


--
-- Name: message_rule message_rule_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_rule
    ADD CONSTRAINT message_rule_pkey PRIMARY KEY (id);


--
-- Name: message_rule message_rule_uuid_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_rule
    ADD CONSTRAINT message_rule_uuid_organisation_id_key UNIQUE (uuid, organisation_id);


--
-- Name: msg91_config msg91_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msg91_config
    ADD CONSTRAINT msg91_config_pkey PRIMARY KEY (id);


--
-- Name: msg91_config msg91_config_uuid_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msg91_config
    ADD CONSTRAINT msg91_config_uuid_organisation_id_key UNIQUE (uuid, organisation_id);


--
-- Name: news news_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news
    ADD CONSTRAINT news_pkey PRIMARY KEY (id);


--
-- Name: news news_uuid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news
    ADD CONSTRAINT news_uuid_key UNIQUE (uuid);


--
-- Name: non_applicable_form_element non_applicable_form_element_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.non_applicable_form_element
    ADD CONSTRAINT non_applicable_form_element_pkey PRIMARY KEY (id);


--
-- Name: operational_encounter_type operational_encounter_type_encounter_type_organisation_id_uniqu; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operational_encounter_type
    ADD CONSTRAINT operational_encounter_type_encounter_type_organisation_id_uniqu UNIQUE (encounter_type_id, organisation_id);


--
-- Name: operational_encounter_type operational_encounter_type_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operational_encounter_type
    ADD CONSTRAINT operational_encounter_type_pkey PRIMARY KEY (id);


--
-- Name: operational_program operational_program_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operational_program
    ADD CONSTRAINT operational_program_pkey PRIMARY KEY (id);


--
-- Name: operational_program operational_program_program_id_organisation_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operational_program
    ADD CONSTRAINT operational_program_program_id_organisation_id_unique UNIQUE (program_id, organisation_id);


--
-- Name: operational_subject_type operational_subject_type_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operational_subject_type
    ADD CONSTRAINT operational_subject_type_pkey PRIMARY KEY (id);


--
-- Name: operational_subject_type operational_subject_type_uuid_org_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operational_subject_type
    ADD CONSTRAINT operational_subject_type_uuid_org_id_key UNIQUE (uuid, organisation_id);


--
-- Name: organisation_category organisation_category_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organisation_category
    ADD CONSTRAINT organisation_category_pkey PRIMARY KEY (id);


--
-- Name: organisation_config organisation_config_organisation_id_is_voided_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organisation_config
    ADD CONSTRAINT organisation_config_organisation_id_is_voided_key UNIQUE (organisation_id, is_voided);


--
-- Name: organisation_config organisation_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organisation_config
    ADD CONSTRAINT organisation_config_pkey PRIMARY KEY (id);


--
-- Name: organisation_config organisation_config_uuid_org_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organisation_config
    ADD CONSTRAINT organisation_config_uuid_org_id_key UNIQUE (uuid, organisation_id);


--
-- Name: organisation organisation_db_user_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organisation
    ADD CONSTRAINT organisation_db_user_key UNIQUE (db_user);


--
-- Name: organisation_group_organisation organisation_group_organisation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organisation_group_organisation
    ADD CONSTRAINT organisation_group_organisation_pkey PRIMARY KEY (id);


--
-- Name: organisation_group organisation_group_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organisation_group
    ADD CONSTRAINT organisation_group_pkey PRIMARY KEY (id);


--
-- Name: organisation organisation_media_directory_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organisation
    ADD CONSTRAINT organisation_media_directory_key UNIQUE (media_directory);


--
-- Name: organisation organisation_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organisation
    ADD CONSTRAINT organisation_name_key UNIQUE (name);


--
-- Name: organisation organisation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organisation
    ADD CONSTRAINT organisation_pkey PRIMARY KEY (id);


--
-- Name: organisation_status organisation_status_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organisation_status
    ADD CONSTRAINT organisation_status_pkey PRIMARY KEY (id);


--
-- Name: organisation organisation_uuid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organisation
    ADD CONSTRAINT organisation_uuid_key UNIQUE (uuid);


--
-- Name: platform_translation platform_translation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.platform_translation
    ADD CONSTRAINT platform_translation_pkey PRIMARY KEY (id);


--
-- Name: post_etl_sync_status post_etl_sync_status_db_user_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_etl_sync_status
    ADD CONSTRAINT post_etl_sync_status_db_user_key UNIQUE (db_user);


--
-- Name: post_etl_sync_status post_etl_sync_status_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_etl_sync_status
    ADD CONSTRAINT post_etl_sync_status_pkey PRIMARY KEY (id);


--
-- Name: privilege privilege_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.privilege
    ADD CONSTRAINT privilege_pkey PRIMARY KEY (id);


--
-- Name: program_encounter program_encounter_legacy_id_organisation_id_uniq_idx; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.program_encounter
    ADD CONSTRAINT program_encounter_legacy_id_organisation_id_uniq_idx UNIQUE (legacy_id, organisation_id);


--
-- Name: program_encounter program_encounter_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.program_encounter
    ADD CONSTRAINT program_encounter_pkey PRIMARY KEY (id);


--
-- Name: program_encounter program_encounter_uuid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.program_encounter
    ADD CONSTRAINT program_encounter_uuid_key UNIQUE (uuid);


--
-- Name: program_enrolment program_enrolment_legacy_id_organisation_id_uniq_idx; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.program_enrolment
    ADD CONSTRAINT program_enrolment_legacy_id_organisation_id_uniq_idx UNIQUE (legacy_id, organisation_id);


--
-- Name: program_enrolment program_enrolment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.program_enrolment
    ADD CONSTRAINT program_enrolment_pkey PRIMARY KEY (id);


--
-- Name: program_enrolment program_enrolment_uuid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.program_enrolment
    ADD CONSTRAINT program_enrolment_uuid_key UNIQUE (uuid);


--
-- Name: program_outcome program_outcome_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.program_outcome
    ADD CONSTRAINT program_outcome_pkey PRIMARY KEY (id);


--
-- Name: program_outcome program_outcome_uuid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.program_outcome
    ADD CONSTRAINT program_outcome_uuid_key UNIQUE (uuid);


--
-- Name: program program_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.program
    ADD CONSTRAINT program_pkey PRIMARY KEY (id);


--
-- Name: program program_uuid_org_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.program
    ADD CONSTRAINT program_uuid_org_id_key UNIQUE (uuid, organisation_id);


--
-- Name: qrtz_blob_triggers qrtz_blob_triggers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qrtz_blob_triggers
    ADD CONSTRAINT qrtz_blob_triggers_pkey PRIMARY KEY (sched_name, trigger_name, trigger_group);


--
-- Name: qrtz_calendars qrtz_calendars_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qrtz_calendars
    ADD CONSTRAINT qrtz_calendars_pkey PRIMARY KEY (sched_name, calendar_name);


--
-- Name: qrtz_cron_triggers qrtz_cron_triggers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qrtz_cron_triggers
    ADD CONSTRAINT qrtz_cron_triggers_pkey PRIMARY KEY (sched_name, trigger_name, trigger_group);


--
-- Name: qrtz_fired_triggers qrtz_fired_triggers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qrtz_fired_triggers
    ADD CONSTRAINT qrtz_fired_triggers_pkey PRIMARY KEY (sched_name, entry_id);


--
-- Name: qrtz_job_details qrtz_job_details_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qrtz_job_details
    ADD CONSTRAINT qrtz_job_details_pkey PRIMARY KEY (sched_name, job_name, job_group);


--
-- Name: qrtz_locks qrtz_locks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qrtz_locks
    ADD CONSTRAINT qrtz_locks_pkey PRIMARY KEY (sched_name, lock_name);


--
-- Name: qrtz_paused_trigger_grps qrtz_paused_trigger_grps_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qrtz_paused_trigger_grps
    ADD CONSTRAINT qrtz_paused_trigger_grps_pkey PRIMARY KEY (sched_name, trigger_group);


--
-- Name: qrtz_scheduler_state qrtz_scheduler_state_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qrtz_scheduler_state
    ADD CONSTRAINT qrtz_scheduler_state_pkey PRIMARY KEY (sched_name, instance_name);


--
-- Name: qrtz_simple_triggers qrtz_simple_triggers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qrtz_simple_triggers
    ADD CONSTRAINT qrtz_simple_triggers_pkey PRIMARY KEY (sched_name, trigger_name, trigger_group);


--
-- Name: qrtz_simprop_triggers qrtz_simprop_triggers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qrtz_simprop_triggers
    ADD CONSTRAINT qrtz_simprop_triggers_pkey PRIMARY KEY (sched_name, trigger_name, trigger_group);


--
-- Name: qrtz_triggers qrtz_triggers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qrtz_triggers
    ADD CONSTRAINT qrtz_triggers_pkey PRIMARY KEY (sched_name, trigger_name, trigger_group);


--
-- Name: report_card report_card_name_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_card
    ADD CONSTRAINT report_card_name_unique UNIQUE (name, organisation_id);


--
-- Name: reset_sync reset_sync_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reset_sync
    ADD CONSTRAINT reset_sync_pkey PRIMARY KEY (id);


--
-- Name: reset_sync reset_sync_uuid_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reset_sync
    ADD CONSTRAINT reset_sync_uuid_organisation_id_key UNIQUE (uuid, organisation_id);


--
-- Name: rule_dependency rule_dependency_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_dependency
    ADD CONSTRAINT rule_dependency_pkey PRIMARY KEY (id);


--
-- Name: rule_dependency rule_dependency_uuid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_dependency
    ADD CONSTRAINT rule_dependency_uuid_key UNIQUE (uuid);


--
-- Name: rule_failure_log rule_failure_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_failure_log
    ADD CONSTRAINT rule_failure_log_pkey PRIMARY KEY (id);


--
-- Name: rule_failure_log rule_failure_log_uuid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_failure_log
    ADD CONSTRAINT rule_failure_log_uuid_key UNIQUE (uuid);


--
-- Name: rule_failure_telemetry rule_failure_telemetry_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_failure_telemetry
    ADD CONSTRAINT rule_failure_telemetry_pkey PRIMARY KEY (id);


--
-- Name: rule rule_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule
    ADD CONSTRAINT rule_pkey PRIMARY KEY (id);


--
-- Name: rule rule_uuid_org_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule
    ADD CONSTRAINT rule_uuid_org_id_key UNIQUE (uuid, organisation_id);


--
-- Name: scheduled_job_run scheduled_job_run_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scheduled_job_run
    ADD CONSTRAINT scheduled_job_run_pkey PRIMARY KEY (id);


--
-- Name: standard_report_card_type standard_report_card_type_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.standard_report_card_type
    ADD CONSTRAINT standard_report_card_type_pkey PRIMARY KEY (id);


--
-- Name: subject_migration subject_migration_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subject_migration
    ADD CONSTRAINT subject_migration_pkey PRIMARY KEY (id);


--
-- Name: subject_migration subject_migration_uuid_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subject_migration
    ADD CONSTRAINT subject_migration_uuid_organisation_id_key UNIQUE (uuid, organisation_id);


--
-- Name: subject_program_eligibility subject_program_eligibility_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subject_program_eligibility
    ADD CONSTRAINT subject_program_eligibility_pkey PRIMARY KEY (id);


--
-- Name: subject_program_eligibility subject_program_eligibility_uuid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subject_program_eligibility
    ADD CONSTRAINT subject_program_eligibility_uuid_key UNIQUE (uuid);


--
-- Name: subject_type subject_type_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subject_type
    ADD CONSTRAINT subject_type_pkey PRIMARY KEY (id);


--
-- Name: subject_type subject_type_uuid_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subject_type
    ADD CONSTRAINT subject_type_uuid_organisation_id_key UNIQUE (uuid, organisation_id);


--
-- Name: sync_telemetry sync_telemetry_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sync_telemetry
    ADD CONSTRAINT sync_telemetry_pkey PRIMARY KEY (id);


--
-- Name: table_metadata table_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.table_metadata
    ADD CONSTRAINT table_metadata_pkey PRIMARY KEY (id);


--
-- Name: task task_legacy_id_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task
    ADD CONSTRAINT task_legacy_id_organisation_id_key UNIQUE (legacy_id, organisation_id);


--
-- Name: task task_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task
    ADD CONSTRAINT task_pkey PRIMARY KEY (id);


--
-- Name: task_status task_status_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_status
    ADD CONSTRAINT task_status_pkey PRIMARY KEY (id);


--
-- Name: task_status task_status_uuid_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_status
    ADD CONSTRAINT task_status_uuid_organisation_id_key UNIQUE (uuid, organisation_id);


--
-- Name: task_type task_type_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_type
    ADD CONSTRAINT task_type_pkey PRIMARY KEY (id);


--
-- Name: task_type task_type_uuid_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_type
    ADD CONSTRAINT task_type_uuid_organisation_id_key UNIQUE (uuid, organisation_id);


--
-- Name: task_unassignment task_unassignment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_unassignment
    ADD CONSTRAINT task_unassignment_pkey PRIMARY KEY (id);


--
-- Name: task_unassignment task_unassignment_uuid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_unassignment
    ADD CONSTRAINT task_unassignment_uuid_key UNIQUE (uuid);


--
-- Name: task task_uuid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task
    ADD CONSTRAINT task_uuid_key UNIQUE (uuid);


--
-- Name: template_organisation template_organisation_name_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.template_organisation
    ADD CONSTRAINT template_organisation_name_uniq UNIQUE (name);


--
-- Name: template_organisation template_organisation_organisation_id_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.template_organisation
    ADD CONSTRAINT template_organisation_organisation_id_uniq UNIQUE (organisation_id);


--
-- Name: template_organisation template_organisation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.template_organisation
    ADD CONSTRAINT template_organisation_pkey PRIMARY KEY (id);


--
-- Name: template_organisation template_organisation_uuid_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.template_organisation
    ADD CONSTRAINT template_organisation_uuid_uniq UNIQUE (uuid);


--
-- Name: translation translation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.translation
    ADD CONSTRAINT translation_pkey PRIMARY KEY (id);


--
-- Name: translation translation_uuid_org_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.translation
    ADD CONSTRAINT translation_uuid_org_id_key UNIQUE (uuid, organisation_id);


--
-- Name: rule unique_fn_rule_name; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule
    ADD CONSTRAINT unique_fn_rule_name UNIQUE (organisation_id, fn_name);


--
-- Name: address_level unique_name_per_level; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.address_level
    ADD CONSTRAINT unique_name_per_level UNIQUE (title, type_id, parent_id, organisation_id);


--
-- Name: rule unique_rule_name; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule
    ADD CONSTRAINT unique_rule_name UNIQUE (organisation_id, name);


--
-- Name: user_group user_group_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_group
    ADD CONSTRAINT user_group_pkey PRIMARY KEY (id);


--
-- Name: user_group user_group_uuid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_group
    ADD CONSTRAINT user_group_uuid_key UNIQUE (uuid);


--
-- Name: user_subject_assignment user_subject_assignment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subject_assignment
    ADD CONSTRAINT user_subject_assignment_pkey PRIMARY KEY (id);


--
-- Name: user_subject_assignment user_subject_assignment_subject_id_user_id_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subject_assignment
    ADD CONSTRAINT user_subject_assignment_subject_id_user_id_organisation_id_key UNIQUE (subject_id, user_id, organisation_id);


--
-- Name: user_subject_assignment user_subject_assignment_uuid_organisation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subject_assignment
    ADD CONSTRAINT user_subject_assignment_uuid_organisation_id_key UNIQUE (uuid, organisation_id);


--
-- Name: user_subject user_subject_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subject
    ADD CONSTRAINT user_subject_pkey PRIMARY KEY (id);


--
-- Name: user_subject user_subject_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subject
    ADD CONSTRAINT user_subject_subject_id_key UNIQUE (subject_id);


--
-- Name: user_subject user_subject_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subject
    ADD CONSTRAINT user_subject_user_id_key UNIQUE (user_id);


--
-- Name: user_subject user_subject_uuid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subject
    ADD CONSTRAINT user_subject_uuid_key UNIQUE (uuid);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_uuid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_uuid_key UNIQUE (uuid);


--
-- Name: video video_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.video
    ADD CONSTRAINT video_pkey PRIMARY KEY (id);


--
-- Name: video_telemetric video_telemetric_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.video_telemetric
    ADD CONSTRAINT video_telemetric_pkey PRIMARY KEY (id);


--
-- Name: video video_uuid_org_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.video
    ADD CONSTRAINT video_uuid_org_id_key UNIQUE (uuid, organisation_id);


--
-- Name: address_level_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX address_level_last_modified_time_idx ON public.address_level USING btree (last_modified_date_time);


--
-- Name: address_level_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX address_level_organisation_id__index ON public.address_level USING btree (organisation_id);


--
-- Name: address_level_type_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX address_level_type_last_modified_time_idx ON public.address_level_type USING btree (last_modified_date_time);


--
-- Name: address_level_type_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX address_level_type_organisation_id__index ON public.address_level_type USING btree (organisation_id);


--
-- Name: catchment_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX catchment_last_modified_time_idx ON public.catchment USING btree (last_modified_date_time);


--
-- Name: catchment_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX catchment_organisation_id__index ON public.catchment USING btree (organisation_id);


--
-- Name: checklist_checklist_detail_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX checklist_checklist_detail_id_index ON public.checklist USING btree (checklist_detail_id);


--
-- Name: checklist_detail_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX checklist_detail_last_modified_time_idx ON public.checklist_detail USING btree (last_modified_date_time);


--
-- Name: checklist_detail_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX checklist_detail_organisation_id__index ON public.checklist_detail USING btree (organisation_id);


--
-- Name: checklist_item_checklist_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX checklist_item_checklist_id_index ON public.checklist_item USING btree (checklist_id);


--
-- Name: checklist_item_checklist_item_detail_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX checklist_item_checklist_item_detail_id_index ON public.checklist_item USING btree (checklist_item_detail_id);


--
-- Name: checklist_item_detail_checklist_detail_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX checklist_item_detail_checklist_detail_id_index ON public.checklist_item_detail USING btree (checklist_detail_id);


--
-- Name: checklist_item_detail_concept_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX checklist_item_detail_concept_id_index ON public.checklist_item_detail USING btree (concept_id);


--
-- Name: checklist_item_detail_dependent_on_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX checklist_item_detail_dependent_on_index ON public.checklist_item_detail USING btree (dependent_on);


--
-- Name: checklist_item_detail_form_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX checklist_item_detail_form_id_index ON public.checklist_item_detail USING btree (form_id);


--
-- Name: checklist_item_detail_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX checklist_item_detail_last_modified_time_idx ON public.checklist_item_detail USING btree (last_modified_date_time);


--
-- Name: checklist_item_detail_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX checklist_item_detail_organisation_id__index ON public.checklist_item_detail USING btree (organisation_id);


--
-- Name: checklist_item_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX checklist_item_last_modified_time_idx ON public.checklist_item USING btree (last_modified_date_time);


--
-- Name: checklist_item_obs_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX checklist_item_obs_idx ON public.checklist_item USING gin (observations jsonb_path_ops);


--
-- Name: checklist_item_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX checklist_item_organisation_id__index ON public.checklist_item USING btree (organisation_id);


--
-- Name: checklist_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX checklist_last_modified_time_idx ON public.checklist USING btree (last_modified_date_time);


--
-- Name: checklist_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX checklist_organisation_id__index ON public.checklist USING btree (organisation_id);


--
-- Name: checklist_program_enrolment_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX checklist_program_enrolment_id_index ON public.checklist USING btree (program_enrolment_id);


--
-- Name: comment_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX comment_last_modified_time_idx ON public.comment USING btree (last_modified_date_time);


--
-- Name: comment_subject_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX comment_subject_id_index ON public.comment USING btree (subject_id);


--
-- Name: comment_thread_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX comment_thread_last_modified_time_idx ON public.comment_thread USING btree (last_modified_date_time);


--
-- Name: comment_thread_uuid_organisation_id_uniq_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX comment_thread_uuid_organisation_id_uniq_idx ON public.comment USING btree (uuid, organisation_id);


--
-- Name: comment_uuid_organisation_id_uniq_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX comment_uuid_organisation_id_uniq_idx ON public.comment USING btree (uuid, organisation_id);


--
-- Name: concept_answer_answer_concept_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX concept_answer_answer_concept_id_index ON public.concept_answer USING btree (answer_concept_id);


--
-- Name: concept_answer_concept_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX concept_answer_concept_id_index ON public.concept_answer USING btree (concept_id);


--
-- Name: concept_answer_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX concept_answer_last_modified_time_idx ON public.concept_answer USING btree (last_modified_date_time);


--
-- Name: concept_answer_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX concept_answer_organisation_id__index ON public.concept_answer USING btree (organisation_id);


--
-- Name: concept_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX concept_last_modified_time_idx ON public.concept USING btree (last_modified_date_time);


--
-- Name: concept_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX concept_organisation_id__index ON public.concept USING btree (organisation_id);


--
-- Name: dashboard_card_mapping_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX dashboard_card_mapping_last_modified_time_idx ON public.dashboard_card_mapping USING btree (last_modified_date_time);


--
-- Name: dashboard_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX dashboard_last_modified_time_idx ON public.dashboard USING btree (last_modified_date_time);


--
-- Name: dashboard_section_card_mapping_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX dashboard_section_card_mapping_last_modified_time_idx ON public.dashboard_section_card_mapping USING btree (last_modified_date_time);


--
-- Name: dashboard_section_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX dashboard_section_last_modified_time_idx ON public.dashboard_section USING btree (last_modified_date_time);


--
-- Name: documentation_item_documentation_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX documentation_item_documentation_id_index ON public.documentation_item USING btree (documentation_id);


--
-- Name: documentation_item_organisation_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX documentation_item_organisation_id_index ON public.documentation_item USING btree (organisation_id);


--
-- Name: documentation_organisation_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX documentation_organisation_id_index ON public.documentation USING btree (organisation_id);


--
-- Name: encounter_cancel_obs_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX encounter_cancel_obs_idx ON public.encounter USING gin (cancel_observations jsonb_path_ops);


--
-- Name: encounter_encounter_type_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX encounter_encounter_type_id_index ON public.encounter USING btree (encounter_type_id);


--
-- Name: encounter_individual_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX encounter_individual_id_index ON public.encounter USING btree (individual_id);


--
-- Name: encounter_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX encounter_last_modified_time_idx ON public.encounter USING btree (last_modified_date_time);


--
-- Name: encounter_legacy_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX encounter_legacy_id_index ON public.encounter USING btree (legacy_id);


--
-- Name: encounter_obs_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX encounter_obs_idx ON public.encounter USING gin (observations jsonb_path_ops);


--
-- Name: encounter_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX encounter_organisation_id__index ON public.encounter USING btree (organisation_id);


--
-- Name: encounter_type_concept_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX encounter_type_concept_id_index ON public.encounter_type USING btree (concept_id);


--
-- Name: encounter_type_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX encounter_type_last_modified_time_idx ON public.encounter_type USING btree (last_modified_date_time);


--
-- Name: encounter_type_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX encounter_type_organisation_id__index ON public.encounter_type USING btree (organisation_id);


--
-- Name: entity_approval_status_approval_status_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX entity_approval_status_approval_status_id_index ON public.entity_approval_status USING btree (approval_status_id);


--
-- Name: entity_approval_status_entity_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX entity_approval_status_entity_id_index ON public.entity_approval_status USING btree (entity_id);


--
-- Name: entity_approval_status_entity_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX entity_approval_status_entity_type_index ON public.entity_approval_status USING btree (entity_type);


--
-- Name: entity_approval_status_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX entity_approval_status_last_modified_time_idx ON public.entity_approval_status USING btree (last_modified_date_time);


--
-- Name: entity_approval_status_sync_1_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX entity_approval_status_sync_1_index ON public.entity_approval_status USING btree (address_id, last_modified_date_time, organisation_id, entity_type, entity_type_uuid);


--
-- Name: entity_approval_status_sync_2_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX entity_approval_status_sync_2_index ON public.entity_approval_status USING btree (individual_id, last_modified_date_time, organisation_id, entity_type, entity_type_uuid);


--
-- Name: entity_approval_status_sync_3_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX entity_approval_status_sync_3_index ON public.entity_approval_status USING btree (sync_concept_1_value, last_modified_date_time, organisation_id, entity_type, entity_type_uuid);


--
-- Name: entity_approval_status_sync_4_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX entity_approval_status_sync_4_index ON public.entity_approval_status USING btree (sync_concept_1_value, sync_concept_2_value, last_modified_date_time, organisation_id, entity_type, entity_type_uuid);


--
-- Name: entity_approval_status_sync_5_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX entity_approval_status_sync_5_index ON public.entity_approval_status USING btree (address_id, individual_id, sync_concept_1_value, sync_concept_2_value, last_modified_date_time, organisation_id, entity_type, entity_type_uuid);


--
-- Name: facility_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX facility_last_modified_time_idx ON public.facility USING btree (last_modified_date_time);


--
-- Name: facility_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX facility_organisation_id__index ON public.facility USING btree (organisation_id);


--
-- Name: flyway_schema_history_s_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX flyway_schema_history_s_idx ON public.flyway_schema_history USING btree (success);


--
-- Name: form_element_concept_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX form_element_concept_id_index ON public.form_element USING btree (concept_id);


--
-- Name: form_element_form_element_group_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX form_element_form_element_group_id_index ON public.form_element USING btree (form_element_group_id);


--
-- Name: form_element_group_form_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX form_element_group_form_id_index ON public.form_element_group USING btree (form_id);


--
-- Name: form_element_group_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX form_element_group_last_modified_time_idx ON public.form_element_group USING btree (last_modified_date_time);


--
-- Name: form_element_group_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX form_element_group_organisation_id__index ON public.form_element_group USING btree (organisation_id);


--
-- Name: form_element_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX form_element_last_modified_time_idx ON public.form_element USING btree (last_modified_date_time);


--
-- Name: form_element_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX form_element_organisation_id__index ON public.form_element USING btree (organisation_id);


--
-- Name: form_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX form_last_modified_time_idx ON public.form USING btree (last_modified_date_time);


--
-- Name: form_mapping_form_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX form_mapping_form_id_index ON public.form_mapping USING btree (form_id);


--
-- Name: form_mapping_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX form_mapping_last_modified_time_idx ON public.form_mapping USING btree (last_modified_date_time);


--
-- Name: form_mapping_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX form_mapping_organisation_id__index ON public.form_mapping USING btree (organisation_id);


--
-- Name: form_mapping_subject_type_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX form_mapping_subject_type_id_index ON public.form_mapping USING btree (subject_type_id);


--
-- Name: form_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX form_organisation_id__index ON public.form USING btree (organisation_id);


--
-- Name: gender_concept_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX gender_concept_id_index ON public.gender USING btree (concept_id);


--
-- Name: gender_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX gender_last_modified_time_idx ON public.gender USING btree (last_modified_date_time);


--
-- Name: gender_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX gender_organisation_id__index ON public.gender USING btree (organisation_id);


--
-- Name: group_dashboard_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX group_dashboard_last_modified_time_idx ON public.group_dashboard USING btree (last_modified_date_time);


--
-- Name: group_privilege_checklist_detail_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX group_privilege_checklist_detail_id_index ON public.group_privilege USING btree (checklist_detail_id);


--
-- Name: group_privilege_encounter_type_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX group_privilege_encounter_type_id_index ON public.group_privilege USING btree (encounter_type_id);


--
-- Name: group_privilege_group_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX group_privilege_group_id_index ON public.group_privilege USING btree (group_id);


--
-- Name: group_privilege_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX group_privilege_last_modified_time_idx ON public.group_privilege USING btree (last_modified_date_time);


--
-- Name: group_privilege_program_encounter_type_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX group_privilege_program_encounter_type_id_index ON public.group_privilege USING btree (program_encounter_type_id);


--
-- Name: group_privilege_program_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX group_privilege_program_id_index ON public.group_privilege USING btree (program_id);


--
-- Name: group_privilege_subject_type_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX group_privilege_subject_type_id_index ON public.group_privilege USING btree (subject_type_id);


--
-- Name: group_role_group_subject_type_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX group_role_group_subject_type_id_index ON public.group_role USING btree (group_subject_type_id);


--
-- Name: group_role_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX group_role_last_modified_time_idx ON public.group_role USING btree (last_modified_date_time);


--
-- Name: group_role_member_subject_type_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX group_role_member_subject_type_id_index ON public.group_role USING btree (member_subject_type_id);


--
-- Name: group_subject_group_role_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX group_subject_group_role_id_index ON public.group_subject USING btree (group_role_id);


--
-- Name: group_subject_group_subject_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX group_subject_group_subject_id_index ON public.group_subject USING btree (group_subject_id);


--
-- Name: group_subject_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX group_subject_last_modified_time_idx ON public.group_subject USING btree (last_modified_date_time);


--
-- Name: group_subject_member_subject_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX group_subject_member_subject_id_index ON public.group_subject USING btree (member_subject_id);


--
-- Name: groups_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX groups_last_modified_time_idx ON public.groups USING btree (last_modified_date_time);


--
-- Name: identifier_assignment_identifier_source_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX identifier_assignment_identifier_source_id_index ON public.identifier_assignment USING btree (identifier_source_id);


--
-- Name: identifier_assignment_individual_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX identifier_assignment_individual_id_index ON public.identifier_assignment USING btree (individual_id);


--
-- Name: identifier_assignment_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX identifier_assignment_last_modified_time_idx ON public.identifier_assignment USING btree (last_modified_date_time);


--
-- Name: identifier_assignment_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX identifier_assignment_organisation_id__index ON public.identifier_assignment USING btree (organisation_id);


--
-- Name: identifier_assignment_program_enrolment_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX identifier_assignment_program_enrolment_id_index ON public.identifier_assignment USING btree (program_enrolment_id);


--
-- Name: identifier_source_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX identifier_source_last_modified_time_idx ON public.identifier_source USING btree (last_modified_date_time);


--
-- Name: identifier_source_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX identifier_source_organisation_id__index ON public.identifier_source USING btree (organisation_id);


--
-- Name: identifier_user_assignment_identifier_source_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX identifier_user_assignment_identifier_source_id_index ON public.identifier_user_assignment USING btree (identifier_source_id);


--
-- Name: identifier_user_assignment_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX identifier_user_assignment_last_modified_time_idx ON public.identifier_user_assignment USING btree (last_modified_date_time);


--
-- Name: identifier_user_assignment_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX identifier_user_assignment_organisation_id__index ON public.identifier_user_assignment USING btree (organisation_id);


--
-- Name: idx_individual_obs; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_individual_obs ON public.individual USING gin (observations jsonb_path_ops);


--
-- Name: idx_program_encounter_obs; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_program_encounter_obs ON public.program_encounter USING gin (observations jsonb_path_ops);


--
-- Name: idx_program_enrolment_obs; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_program_enrolment_obs ON public.program_enrolment USING gin (observations jsonb_path_ops);


--
-- Name: idx_qrtz_ft_job_group; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_qrtz_ft_job_group ON public.qrtz_fired_triggers USING btree (job_group);


--
-- Name: idx_qrtz_ft_job_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_qrtz_ft_job_name ON public.qrtz_fired_triggers USING btree (job_name);


--
-- Name: idx_qrtz_ft_job_req_recovery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_qrtz_ft_job_req_recovery ON public.qrtz_fired_triggers USING btree (requests_recovery);


--
-- Name: idx_qrtz_ft_trig_group; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_qrtz_ft_trig_group ON public.qrtz_fired_triggers USING btree (trigger_group);


--
-- Name: idx_qrtz_ft_trig_inst_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_qrtz_ft_trig_inst_name ON public.qrtz_fired_triggers USING btree (instance_name);


--
-- Name: idx_qrtz_ft_trig_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_qrtz_ft_trig_name ON public.qrtz_fired_triggers USING btree (trigger_name);


--
-- Name: idx_qrtz_ft_trig_nm_gp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_qrtz_ft_trig_nm_gp ON public.qrtz_fired_triggers USING btree (sched_name, trigger_name, trigger_group);


--
-- Name: idx_qrtz_j_req_recovery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_qrtz_j_req_recovery ON public.qrtz_job_details USING btree (requests_recovery);


--
-- Name: idx_qrtz_t_next_fire_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_qrtz_t_next_fire_time ON public.qrtz_triggers USING btree (next_fire_time);


--
-- Name: idx_qrtz_t_nft_st; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_qrtz_t_nft_st ON public.qrtz_triggers USING btree (next_fire_time, trigger_state);


--
-- Name: idx_qrtz_t_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_qrtz_t_state ON public.qrtz_triggers USING btree (trigger_state);


--
-- Name: idx_scheduled_job_run_job_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_scheduled_job_run_job_name ON public.scheduled_job_run USING btree (job_name);


--
-- Name: individual_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX individual_last_modified_time_idx ON public.individual USING btree (last_modified_date_time);


--
-- Name: individual_legacy_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX individual_legacy_id_index ON public.individual USING btree (legacy_id);


--
-- Name: individual_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX individual_organisation_id__index ON public.individual USING btree (organisation_id);


--
-- Name: individual_relation_gender_mapping_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX individual_relation_gender_mapping_last_modified_time_idx ON public.individual_relation_gender_mapping USING btree (last_modified_date_time);


--
-- Name: individual_relation_gender_mapping_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX individual_relation_gender_mapping_organisation_id__index ON public.individual_relation_gender_mapping USING btree (organisation_id);


--
-- Name: individual_relation_gender_mapping_relation_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX individual_relation_gender_mapping_relation_id_index ON public.individual_relation_gender_mapping USING btree (relation_id);


--
-- Name: individual_relation_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX individual_relation_last_modified_time_idx ON public.individual_relation USING btree (last_modified_date_time);


--
-- Name: individual_relation_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX individual_relation_organisation_id__index ON public.individual_relation USING btree (organisation_id);


--
-- Name: individual_relationship_individual_a_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX individual_relationship_individual_a_id_index ON public.individual_relationship USING btree (individual_a_id);


--
-- Name: individual_relationship_individual_b_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX individual_relationship_individual_b_id_index ON public.individual_relationship USING btree (individual_b_id);


--
-- Name: individual_relationship_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX individual_relationship_last_modified_time_idx ON public.individual_relationship USING btree (last_modified_date_time);


--
-- Name: individual_relationship_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX individual_relationship_organisation_id__index ON public.individual_relationship USING btree (organisation_id);


--
-- Name: individual_relationship_relationship_type_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX individual_relationship_relationship_type_id_index ON public.individual_relationship USING btree (relationship_type_id);


--
-- Name: individual_relationship_type_individual_a_is_to_b_relation_id_i; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX individual_relationship_type_individual_a_is_to_b_relation_id_i ON public.individual_relationship_type USING btree (individual_a_is_to_b_relation_id);


--
-- Name: individual_relationship_type_individual_b_is_to_a_relation_id_i; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX individual_relationship_type_individual_b_is_to_a_relation_id_i ON public.individual_relationship_type USING btree (individual_b_is_to_a_relation_id);


--
-- Name: individual_relationship_type_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX individual_relationship_type_last_modified_time_idx ON public.individual_relationship_type USING btree (last_modified_date_time);


--
-- Name: individual_relationship_type_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX individual_relationship_type_organisation_id__index ON public.individual_relationship_type USING btree (organisation_id);


--
-- Name: individual_relative_individual_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX individual_relative_individual_id_index ON public.individual_relative USING btree (individual_id);


--
-- Name: individual_relative_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX individual_relative_last_modified_time_idx ON public.individual_relative USING btree (last_modified_date_time);


--
-- Name: individual_relative_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX individual_relative_organisation_id__index ON public.individual_relative USING btree (organisation_id);


--
-- Name: individual_relative_relative_individual_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX individual_relative_relative_individual_id_index ON public.individual_relative USING btree (relative_individual_id);


--
-- Name: individual_subject_type_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX individual_subject_type_id_index ON public.individual USING btree (subject_type_id);


--
-- Name: location_location_mapping_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX location_location_mapping_last_modified_time_idx ON public.location_location_mapping USING btree (last_modified_date_time);


--
-- Name: location_location_mapping_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX location_location_mapping_organisation_id__index ON public.location_location_mapping USING btree (organisation_id);


--
-- Name: msg91_config_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX msg91_config_last_modified_time_idx ON public.msg91_config USING btree (last_modified_date_time);


--
-- Name: news_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX news_last_modified_time_idx ON public.news USING btree (last_modified_date_time);


--
-- Name: news_published_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX news_published_date_idx ON public.news USING btree (organisation_id, published_date);


--
-- Name: news_uuid_organisation_id_uniq_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX news_uuid_organisation_id_uniq_idx ON public.news USING btree (uuid, organisation_id);


--
-- Name: non_applicable_form_element_form_element_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX non_applicable_form_element_form_element_id_index ON public.non_applicable_form_element USING btree (form_element_id);


--
-- Name: non_applicable_form_element_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX non_applicable_form_element_last_modified_time_idx ON public.non_applicable_form_element USING btree (last_modified_date_time);


--
-- Name: non_applicable_form_element_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX non_applicable_form_element_organisation_id__index ON public.non_applicable_form_element USING btree (organisation_id);


--
-- Name: operational_encounter_type_encounter_type_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX operational_encounter_type_encounter_type_id_index ON public.operational_encounter_type USING btree (encounter_type_id);


--
-- Name: operational_encounter_type_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX operational_encounter_type_last_modified_time_idx ON public.operational_encounter_type USING btree (last_modified_date_time);


--
-- Name: operational_encounter_type_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX operational_encounter_type_organisation_id__index ON public.operational_encounter_type USING btree (organisation_id);


--
-- Name: operational_program_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX operational_program_last_modified_time_idx ON public.operational_program USING btree (last_modified_date_time);


--
-- Name: operational_program_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX operational_program_organisation_id__index ON public.operational_program USING btree (organisation_id);


--
-- Name: operational_program_program_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX operational_program_program_id_index ON public.operational_program USING btree (program_id);


--
-- Name: operational_subject_type_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX operational_subject_type_last_modified_time_idx ON public.operational_subject_type USING btree (last_modified_date_time);


--
-- Name: operational_subject_type_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX operational_subject_type_organisation_id__index ON public.operational_subject_type USING btree (organisation_id);


--
-- Name: operational_subject_type_subject_type_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX operational_subject_type_subject_type_id_index ON public.operational_subject_type USING btree (subject_type_id);


--
-- Name: organisation_config_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX organisation_config_last_modified_time_idx ON public.organisation_config USING btree (last_modified_date_time);


--
-- Name: platform_translation_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX platform_translation_last_modified_time_idx ON public.platform_translation USING btree (last_modified_date_time);


--
-- Name: post_etl_sync_status_db_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX post_etl_sync_status_db_user_idx ON public.post_etl_sync_status USING btree (db_user);


--
-- Name: program_encounter_cancel_obs_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX program_encounter_cancel_obs_idx ON public.program_encounter USING gin (cancel_observations jsonb_path_ops);


--
-- Name: program_encounter_encounter_type_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX program_encounter_encounter_type_id_index ON public.program_encounter USING btree (encounter_type_id);


--
-- Name: program_encounter_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX program_encounter_last_modified_time_idx ON public.program_encounter USING btree (last_modified_date_time);


--
-- Name: program_encounter_legacy_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX program_encounter_legacy_id_index ON public.program_encounter USING btree (legacy_id);


--
-- Name: program_encounter_obs_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX program_encounter_obs_idx ON public.program_encounter USING gin (observations jsonb_path_ops);


--
-- Name: program_encounter_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX program_encounter_organisation_id__index ON public.program_encounter USING btree (organisation_id);


--
-- Name: program_encounter_program_enrolment_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX program_encounter_program_enrolment_id_index ON public.program_encounter USING btree (program_enrolment_id);


--
-- Name: program_enrolment_exit_obs_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX program_enrolment_exit_obs_idx ON public.program_enrolment USING gin (program_exit_observations jsonb_path_ops);


--
-- Name: program_enrolment_individual_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX program_enrolment_individual_id_index ON public.program_enrolment USING btree (individual_id);


--
-- Name: program_enrolment_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX program_enrolment_last_modified_time_idx ON public.program_enrolment USING btree (last_modified_date_time);


--
-- Name: program_enrolment_legacy_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX program_enrolment_legacy_id_index ON public.program_enrolment USING btree (legacy_id);


--
-- Name: program_enrolment_obs_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX program_enrolment_obs_idx ON public.program_enrolment USING gin (observations jsonb_path_ops);


--
-- Name: program_enrolment_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX program_enrolment_organisation_id__index ON public.program_enrolment USING btree (organisation_id);


--
-- Name: program_enrolment_program_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX program_enrolment_program_id_index ON public.program_enrolment USING btree (program_id);


--
-- Name: program_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX program_last_modified_time_idx ON public.program USING btree (last_modified_date_time);


--
-- Name: program_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX program_organisation_id__index ON public.program USING btree (organisation_id);


--
-- Name: program_outcome_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX program_outcome_last_modified_time_idx ON public.program_outcome USING btree (last_modified_date_time);


--
-- Name: program_outcome_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX program_outcome_organisation_id__index ON public.program_outcome USING btree (organisation_id);


--
-- Name: report_card_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX report_card_last_modified_time_idx ON public.report_card USING btree (last_modified_date_time);


--
-- Name: reset_sync_subject_type_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reset_sync_subject_type_id_index ON public.reset_sync USING btree (subject_type_id);


--
-- Name: reset_sync_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reset_sync_user_id_index ON public.reset_sync USING btree (user_id);


--
-- Name: rule_dependency_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rule_dependency_last_modified_time_idx ON public.rule_dependency USING btree (last_modified_date_time);


--
-- Name: rule_dependency_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rule_dependency_organisation_id__index ON public.rule_dependency USING btree (organisation_id);


--
-- Name: rule_failure_log_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rule_failure_log_last_modified_time_idx ON public.rule_failure_log USING btree (last_modified_date_time);


--
-- Name: rule_failure_telemetry_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rule_failure_telemetry_last_modified_time_idx ON public.rule_failure_telemetry USING btree (last_modified_date_time);


--
-- Name: rule_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rule_last_modified_time_idx ON public.rule USING btree (last_modified_date_time);


--
-- Name: rule_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rule_organisation_id__index ON public.rule USING btree (organisation_id);


--
-- Name: subject_migration_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX subject_migration_last_modified_time_idx ON public.subject_migration USING btree (last_modified_date_time);


--
-- Name: subject_migration_sync_fields_1_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX subject_migration_sync_fields_1_idx ON public.subject_migration USING btree (last_modified_date_time, subject_type_id, old_sync_concept_1_value, new_sync_concept_1_value, old_address_level_id, new_address_level_id, organisation_id);


--
-- Name: subject_migration_sync_fields_2_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX subject_migration_sync_fields_2_idx ON public.subject_migration USING btree (last_modified_date_time, subject_type_id, old_address_level_id, new_address_level_id, organisation_id);


--
-- Name: subject_type_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX subject_type_last_modified_time_idx ON public.subject_type USING btree (last_modified_date_time);


--
-- Name: subject_type_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX subject_type_organisation_id__index ON public.subject_type USING btree (organisation_id);


--
-- Name: sync_telemetry_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sync_telemetry_last_modified_time_idx ON public.sync_telemetry USING btree (last_modified_date_time);


--
-- Name: sync_telemetry_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sync_telemetry_organisation_id__index ON public.sync_telemetry USING btree (organisation_id);


--
-- Name: sync_telemetry_sync_start_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sync_telemetry_sync_start_time_idx ON public.sync_telemetry USING btree (sync_start_time);


--
-- Name: sync_telemetry_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sync_telemetry_user_id_idx ON public.sync_telemetry USING btree (user_id);


--
-- Name: table_metadata_table_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX table_metadata_table_id_idx ON public.column_metadata USING btree (table_id);


--
-- Name: task_metadata_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_metadata_idx ON public.task USING gin (metadata jsonb_path_ops);


--
-- Name: task_observations_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX task_observations_idx ON public.task USING gin (observations jsonb_path_ops);


--
-- Name: translation_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX translation_last_modified_time_idx ON public.translation USING btree (last_modified_date_time);


--
-- Name: user_group_group_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_group_group_id_index ON public.user_group USING btree (group_id);


--
-- Name: user_group_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_group_last_modified_time_idx ON public.user_group USING btree (last_modified_date_time);


--
-- Name: user_subject_assignment_subject_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_subject_assignment_subject_id_index ON public.user_subject_assignment USING btree (subject_id);


--
-- Name: user_subject_assignment_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_subject_assignment_user_id_index ON public.user_subject_assignment USING btree (user_id);


--
-- Name: users_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_organisation_id__index ON public.users USING btree (organisation_id);


--
-- Name: users_username_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_username_idx ON public.users USING btree (username);


--
-- Name: video_last_modified_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX video_last_modified_time_idx ON public.video USING btree (last_modified_date_time);


--
-- Name: video_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX video_organisation_id__index ON public.video USING btree (organisation_id);


--
-- Name: video_telemetric_organisation_id__index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX video_telemetric_organisation_id__index ON public.video_telemetric USING btree (organisation_id);


--
-- Name: address_level_type address_level_type_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER address_level_type_update_audit_before_insert BEFORE INSERT ON public.address_level_type FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: address_level_type address_level_type_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER address_level_type_update_audit_before_update BEFORE UPDATE ON public.address_level_type FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: address_level address_level_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER address_level_update_audit_before_insert BEFORE INSERT ON public.address_level FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: address_level address_level_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER address_level_update_audit_before_update BEFORE UPDATE ON public.address_level FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: catchment catchment_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER catchment_update_audit_before_insert BEFORE INSERT ON public.catchment FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: catchment catchment_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER catchment_update_audit_before_update BEFORE UPDATE ON public.catchment FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: checklist_detail checklist_detail_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER checklist_detail_update_audit_before_insert BEFORE INSERT ON public.checklist_detail FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: checklist_detail checklist_detail_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER checklist_detail_update_audit_before_update BEFORE UPDATE ON public.checklist_detail FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: checklist_item_detail checklist_item_detail_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER checklist_item_detail_update_audit_before_insert BEFORE INSERT ON public.checklist_item_detail FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: checklist_item_detail checklist_item_detail_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER checklist_item_detail_update_audit_before_update BEFORE UPDATE ON public.checklist_item_detail FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: checklist_item checklist_item_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER checklist_item_update_audit_before_insert BEFORE INSERT ON public.checklist_item FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: checklist_item checklist_item_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER checklist_item_update_audit_before_update BEFORE UPDATE ON public.checklist_item FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: checklist checklist_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER checklist_update_audit_before_insert BEFORE INSERT ON public.checklist FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: checklist checklist_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER checklist_update_audit_before_update BEFORE UPDATE ON public.checklist FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: comment_thread comment_thread_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER comment_thread_update_audit_before_insert BEFORE INSERT ON public.comment_thread FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: comment_thread comment_thread_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER comment_thread_update_audit_before_update BEFORE UPDATE ON public.comment_thread FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: comment comment_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER comment_update_audit_before_insert BEFORE INSERT ON public.comment FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: comment comment_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER comment_update_audit_before_update BEFORE UPDATE ON public.comment FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: concept_answer concept_answer_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER concept_answer_update_audit_before_insert BEFORE INSERT ON public.concept_answer FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: concept_answer concept_answer_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER concept_answer_update_audit_before_update BEFORE UPDATE ON public.concept_answer FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: concept concept_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER concept_update_audit_before_insert BEFORE INSERT ON public.concept FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: concept concept_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER concept_update_audit_before_update BEFORE UPDATE ON public.concept FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: dashboard_card_mapping dashboard_card_mapping_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER dashboard_card_mapping_update_audit_before_insert BEFORE INSERT ON public.dashboard_card_mapping FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: dashboard_card_mapping dashboard_card_mapping_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER dashboard_card_mapping_update_audit_before_update BEFORE UPDATE ON public.dashboard_card_mapping FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: dashboard_section_card_mapping dashboard_section_card_mapping_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER dashboard_section_card_mapping_update_audit_before_insert BEFORE INSERT ON public.dashboard_section_card_mapping FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: dashboard_section_card_mapping dashboard_section_card_mapping_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER dashboard_section_card_mapping_update_audit_before_update BEFORE UPDATE ON public.dashboard_section_card_mapping FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: dashboard_section dashboard_section_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER dashboard_section_update_audit_before_insert BEFORE INSERT ON public.dashboard_section FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: dashboard_section dashboard_section_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER dashboard_section_update_audit_before_update BEFORE UPDATE ON public.dashboard_section FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: dashboard dashboard_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER dashboard_update_audit_before_insert BEFORE INSERT ON public.dashboard FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: dashboard dashboard_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER dashboard_update_audit_before_update BEFORE UPDATE ON public.dashboard FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: virtual_catchment_address_mapping_table delete_on_virtual_catchment_address_mapping; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER delete_on_virtual_catchment_address_mapping INSTEAD OF DELETE ON public.virtual_catchment_address_mapping_table FOR EACH ROW EXECUTE FUNCTION public.no_op();


--
-- Name: encounter_type encounter_type_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER encounter_type_update_audit_before_insert BEFORE INSERT ON public.encounter_type FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: encounter_type encounter_type_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER encounter_type_update_audit_before_update BEFORE UPDATE ON public.encounter_type FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: encounter encounter_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER encounter_update_audit_before_insert BEFORE INSERT ON public.encounter FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: encounter encounter_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER encounter_update_audit_before_update BEFORE UPDATE ON public.encounter FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: entity_approval_status entity_approval_status_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER entity_approval_status_update_audit_before_insert BEFORE INSERT ON public.entity_approval_status FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: entity_approval_status entity_approval_status_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER entity_approval_status_update_audit_before_update BEFORE UPDATE ON public.entity_approval_status FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: facility facility_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER facility_update_audit_before_insert BEFORE INSERT ON public.facility FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: facility facility_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER facility_update_audit_before_update BEFORE UPDATE ON public.facility FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: form_element_group form_element_group_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER form_element_group_update_audit_before_insert BEFORE INSERT ON public.form_element_group FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: form_element_group form_element_group_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER form_element_group_update_audit_before_update BEFORE UPDATE ON public.form_element_group FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: form_element form_element_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER form_element_update_audit_before_insert BEFORE INSERT ON public.form_element FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: form_element form_element_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER form_element_update_audit_before_update BEFORE UPDATE ON public.form_element FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: form_mapping form_mapping_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER form_mapping_update_audit_before_insert BEFORE INSERT ON public.form_mapping FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: form_mapping form_mapping_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER form_mapping_update_audit_before_update BEFORE UPDATE ON public.form_mapping FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: form form_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER form_update_audit_before_insert BEFORE INSERT ON public.form FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: form form_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER form_update_audit_before_update BEFORE UPDATE ON public.form FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: gender gender_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER gender_update_audit_before_insert BEFORE INSERT ON public.gender FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: gender gender_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER gender_update_audit_before_update BEFORE UPDATE ON public.gender FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: group_dashboard group_dashboard_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER group_dashboard_update_audit_before_insert BEFORE INSERT ON public.group_dashboard FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: group_dashboard group_dashboard_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER group_dashboard_update_audit_before_update BEFORE UPDATE ON public.group_dashboard FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: group_privilege group_privilege_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER group_privilege_update_audit_before_insert BEFORE INSERT ON public.group_privilege FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: group_privilege group_privilege_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER group_privilege_update_audit_before_update BEFORE UPDATE ON public.group_privilege FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: group_role group_role_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER group_role_update_audit_before_insert BEFORE INSERT ON public.group_role FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: group_role group_role_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER group_role_update_audit_before_update BEFORE UPDATE ON public.group_role FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: group_subject group_subject_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER group_subject_update_audit_before_insert BEFORE INSERT ON public.group_subject FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: group_subject group_subject_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER group_subject_update_audit_before_update BEFORE UPDATE ON public.group_subject FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: groups groups_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER groups_update_audit_before_insert BEFORE INSERT ON public.groups FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: groups groups_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER groups_update_audit_before_update BEFORE UPDATE ON public.groups FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: identifier_assignment identifier_assignment_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER identifier_assignment_update_audit_before_insert BEFORE INSERT ON public.identifier_assignment FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: identifier_assignment identifier_assignment_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER identifier_assignment_update_audit_before_update BEFORE UPDATE ON public.identifier_assignment FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: identifier_source identifier_source_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER identifier_source_update_audit_before_insert BEFORE INSERT ON public.identifier_source FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: identifier_source identifier_source_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER identifier_source_update_audit_before_update BEFORE UPDATE ON public.identifier_source FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: identifier_user_assignment identifier_user_assignment_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER identifier_user_assignment_update_audit_before_insert BEFORE INSERT ON public.identifier_user_assignment FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: identifier_user_assignment identifier_user_assignment_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER identifier_user_assignment_update_audit_before_update BEFORE UPDATE ON public.identifier_user_assignment FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: individual_relation_gender_mapping individual_relation_gender_mapping_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER individual_relation_gender_mapping_update_audit_before_insert BEFORE INSERT ON public.individual_relation_gender_mapping FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: individual_relation_gender_mapping individual_relation_gender_mapping_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER individual_relation_gender_mapping_update_audit_before_update BEFORE UPDATE ON public.individual_relation_gender_mapping FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: individual_relation individual_relation_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER individual_relation_update_audit_before_insert BEFORE INSERT ON public.individual_relation FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: individual_relation individual_relation_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER individual_relation_update_audit_before_update BEFORE UPDATE ON public.individual_relation FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: individual_relationship_type individual_relationship_type_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER individual_relationship_type_update_audit_before_insert BEFORE INSERT ON public.individual_relationship_type FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: individual_relationship_type individual_relationship_type_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER individual_relationship_type_update_audit_before_update BEFORE UPDATE ON public.individual_relationship_type FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: individual_relationship individual_relationship_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER individual_relationship_update_audit_before_insert BEFORE INSERT ON public.individual_relationship FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: individual_relationship individual_relationship_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER individual_relationship_update_audit_before_update BEFORE UPDATE ON public.individual_relationship FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: individual_relative individual_relative_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER individual_relative_update_audit_before_insert BEFORE INSERT ON public.individual_relative FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: individual_relative individual_relative_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER individual_relative_update_audit_before_update BEFORE UPDATE ON public.individual_relative FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: individual individual_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER individual_update_audit_before_insert BEFORE INSERT ON public.individual FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: individual individual_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER individual_update_audit_before_update BEFORE UPDATE ON public.individual FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: location_location_mapping location_location_mapping_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER location_location_mapping_update_audit_before_insert BEFORE INSERT ON public.location_location_mapping FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: location_location_mapping location_location_mapping_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER location_location_mapping_update_audit_before_update BEFORE UPDATE ON public.location_location_mapping FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: msg91_config msg91_config_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER msg91_config_update_audit_before_insert BEFORE INSERT ON public.msg91_config FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: msg91_config msg91_config_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER msg91_config_update_audit_before_update BEFORE UPDATE ON public.msg91_config FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: news news_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER news_update_audit_before_insert BEFORE INSERT ON public.news FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: news news_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER news_update_audit_before_update BEFORE UPDATE ON public.news FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: non_applicable_form_element non_applicable_form_element_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER non_applicable_form_element_update_audit_before_insert BEFORE INSERT ON public.non_applicable_form_element FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: non_applicable_form_element non_applicable_form_element_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER non_applicable_form_element_update_audit_before_update BEFORE UPDATE ON public.non_applicable_form_element FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: operational_encounter_type operational_encounter_type_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER operational_encounter_type_update_audit_before_insert BEFORE INSERT ON public.operational_encounter_type FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: operational_encounter_type operational_encounter_type_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER operational_encounter_type_update_audit_before_update BEFORE UPDATE ON public.operational_encounter_type FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: operational_program operational_program_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER operational_program_update_audit_before_insert BEFORE INSERT ON public.operational_program FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: operational_program operational_program_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER operational_program_update_audit_before_update BEFORE UPDATE ON public.operational_program FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: operational_subject_type operational_subject_type_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER operational_subject_type_update_audit_before_insert BEFORE INSERT ON public.operational_subject_type FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: operational_subject_type operational_subject_type_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER operational_subject_type_update_audit_before_update BEFORE UPDATE ON public.operational_subject_type FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: organisation_config organisation_config_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER organisation_config_update_audit_before_insert BEFORE INSERT ON public.organisation_config FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: organisation_config organisation_config_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER organisation_config_update_audit_before_update BEFORE UPDATE ON public.organisation_config FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: platform_translation platform_translation_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER platform_translation_update_audit_before_insert BEFORE INSERT ON public.platform_translation FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: platform_translation platform_translation_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER platform_translation_update_audit_before_update BEFORE UPDATE ON public.platform_translation FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: program_encounter program_encounter_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER program_encounter_update_audit_before_insert BEFORE INSERT ON public.program_encounter FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: program_encounter program_encounter_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER program_encounter_update_audit_before_update BEFORE UPDATE ON public.program_encounter FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: program_enrolment program_enrolment_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER program_enrolment_update_audit_before_insert BEFORE INSERT ON public.program_enrolment FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: program_enrolment program_enrolment_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER program_enrolment_update_audit_before_update BEFORE UPDATE ON public.program_enrolment FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: program_outcome program_outcome_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER program_outcome_update_audit_before_insert BEFORE INSERT ON public.program_outcome FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: program_outcome program_outcome_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER program_outcome_update_audit_before_update BEFORE UPDATE ON public.program_outcome FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: program program_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER program_update_audit_before_insert BEFORE INSERT ON public.program FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: program program_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER program_update_audit_before_update BEFORE UPDATE ON public.program FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: report_card report_card_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER report_card_update_audit_before_insert BEFORE INSERT ON public.report_card FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: report_card report_card_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER report_card_update_audit_before_update BEFORE UPDATE ON public.report_card FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: rule_dependency rule_dependency_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER rule_dependency_update_audit_before_insert BEFORE INSERT ON public.rule_dependency FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: rule_dependency rule_dependency_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER rule_dependency_update_audit_before_update BEFORE UPDATE ON public.rule_dependency FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: rule_failure_log rule_failure_log_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER rule_failure_log_update_audit_before_insert BEFORE INSERT ON public.rule_failure_log FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: rule_failure_log rule_failure_log_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER rule_failure_log_update_audit_before_update BEFORE UPDATE ON public.rule_failure_log FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: rule_failure_telemetry rule_failure_telemetry_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER rule_failure_telemetry_update_audit_before_insert BEFORE INSERT ON public.rule_failure_telemetry FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: rule_failure_telemetry rule_failure_telemetry_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER rule_failure_telemetry_update_audit_before_update BEFORE UPDATE ON public.rule_failure_telemetry FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: rule rule_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER rule_update_audit_before_insert BEFORE INSERT ON public.rule FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: rule rule_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER rule_update_audit_before_update BEFORE UPDATE ON public.rule FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: subject_migration subject_migration_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER subject_migration_update_audit_before_insert BEFORE INSERT ON public.subject_migration FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: subject_migration subject_migration_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER subject_migration_update_audit_before_update BEFORE UPDATE ON public.subject_migration FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: subject_type subject_type_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER subject_type_update_audit_before_insert BEFORE INSERT ON public.subject_type FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: subject_type subject_type_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER subject_type_update_audit_before_update BEFORE UPDATE ON public.subject_type FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: translation translation_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER translation_update_audit_before_insert BEFORE INSERT ON public.translation FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: translation translation_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER translation_update_audit_before_update BEFORE UPDATE ON public.translation FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: user_group user_group_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER user_group_update_audit_before_insert BEFORE INSERT ON public.user_group FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: user_group user_group_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER user_group_update_audit_before_update BEFORE UPDATE ON public.user_group FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: video video_update_audit_before_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER video_update_audit_before_insert BEFORE INSERT ON public.video FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: video video_update_audit_before_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER video_update_audit_before_update BEFORE UPDATE ON public.video FOR EACH ROW EXECUTE FUNCTION public.audit_table_trigger();


--
-- Name: account_admin account_admin_account; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_admin
    ADD CONSTRAINT account_admin_account FOREIGN KEY (account_id) REFERENCES public.account(id);


--
-- Name: account_admin account_admin_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_admin
    ADD CONSTRAINT account_admin_user FOREIGN KEY (admin_id) REFERENCES public.users(id);


--
-- Name: address_level address_level_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.address_level
    ADD CONSTRAINT address_level_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: address_level address_level_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.address_level
    ADD CONSTRAINT address_level_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: address_level address_level_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.address_level
    ADD CONSTRAINT address_level_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.address_level(id);


--
-- Name: address_level address_level_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.address_level
    ADD CONSTRAINT address_level_type_id_fkey FOREIGN KEY (type_id) REFERENCES public.address_level_type(id);


--
-- Name: address_level_type address_level_type_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.address_level_type
    ADD CONSTRAINT address_level_type_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.address_level_type(id);


--
-- Name: answer_concept_migration answer_concept_migration_concept_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.answer_concept_migration
    ADD CONSTRAINT answer_concept_migration_concept_id_fkey FOREIGN KEY (concept_id) REFERENCES public.concept(id);


--
-- Name: storage_management_config archival_config_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.storage_management_config
    ADD CONSTRAINT archival_config_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: storage_management_config archival_config_last_modified_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.storage_management_config
    ADD CONSTRAINT archival_config_last_modified_by_id_fkey FOREIGN KEY (last_modified_by_id) REFERENCES public.users(id);


--
-- Name: storage_management_config archival_config_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.storage_management_config
    ADD CONSTRAINT archival_config_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: report_card card_master_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_card
    ADD CONSTRAINT card_master_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: report_card card_organisation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_card
    ADD CONSTRAINT card_organisation FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: catchment_address_mapping catchment_address_mapping_address; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catchment_address_mapping
    ADD CONSTRAINT catchment_address_mapping_address FOREIGN KEY (addresslevel_id) REFERENCES public.address_level(id);


--
-- Name: catchment_address_mapping catchment_address_mapping_catchment; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catchment_address_mapping
    ADD CONSTRAINT catchment_address_mapping_catchment FOREIGN KEY (catchment_id) REFERENCES public.catchment(id);


--
-- Name: catchment catchment_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catchment
    ADD CONSTRAINT catchment_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: catchment catchment_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catchment
    ADD CONSTRAINT catchment_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: checklist checklist_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist
    ADD CONSTRAINT checklist_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: checklist checklist_checklist_detail_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist
    ADD CONSTRAINT checklist_checklist_detail_id_fkey FOREIGN KEY (checklist_detail_id) REFERENCES public.checklist_detail(id);


--
-- Name: checklist_detail checklist_detail_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist_detail
    ADD CONSTRAINT checklist_detail_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: checklist_item checklist_item_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist_item
    ADD CONSTRAINT checklist_item_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: checklist_item checklist_item_checklist; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist_item
    ADD CONSTRAINT checklist_item_checklist FOREIGN KEY (checklist_id) REFERENCES public.checklist(id);


--
-- Name: checklist_item checklist_item_checklist_item_detail_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist_item
    ADD CONSTRAINT checklist_item_checklist_item_detail_id_fkey FOREIGN KEY (checklist_item_detail_id) REFERENCES public.checklist_item_detail(id);


--
-- Name: checklist_item_detail checklist_item_detail_audit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist_item_detail
    ADD CONSTRAINT checklist_item_detail_audit_id_fkey FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: checklist_item_detail checklist_item_detail_checklist_detail_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist_item_detail
    ADD CONSTRAINT checklist_item_detail_checklist_detail_id_fkey FOREIGN KEY (checklist_detail_id) REFERENCES public.checklist_detail(id);


--
-- Name: checklist_item_detail checklist_item_detail_concept_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist_item_detail
    ADD CONSTRAINT checklist_item_detail_concept_id_fkey FOREIGN KEY (concept_id) REFERENCES public.concept(id);


--
-- Name: checklist_item_detail checklist_item_detail_dependent_on_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist_item_detail
    ADD CONSTRAINT checklist_item_detail_dependent_on_fkey FOREIGN KEY (dependent_on) REFERENCES public.checklist_item_detail(id);


--
-- Name: checklist_item_detail checklist_item_detail_form_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist_item_detail
    ADD CONSTRAINT checklist_item_detail_form_id_fkey FOREIGN KEY (form_id) REFERENCES public.form(id);


--
-- Name: checklist_item_detail checklist_item_detail_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist_item_detail
    ADD CONSTRAINT checklist_item_detail_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: checklist_item checklist_item_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist_item
    ADD CONSTRAINT checklist_item_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: checklist checklist_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist
    ADD CONSTRAINT checklist_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: checklist checklist_program_enrolment; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist
    ADD CONSTRAINT checklist_program_enrolment FOREIGN KEY (program_enrolment_id) REFERENCES public.program_enrolment(id);


--
-- Name: column_metadata column_metadata_concept_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.column_metadata
    ADD CONSTRAINT column_metadata_concept_id_fkey FOREIGN KEY (concept_id) REFERENCES public.concept(id);


--
-- Name: column_metadata column_metadata_table_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.column_metadata
    ADD CONSTRAINT column_metadata_table_id_fkey FOREIGN KEY (table_id) REFERENCES public.table_metadata(id);


--
-- Name: comment comment_audit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment
    ADD CONSTRAINT comment_audit_id_fkey FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: comment comment_comment_thread_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment
    ADD CONSTRAINT comment_comment_thread_id_fkey FOREIGN KEY (comment_thread_id) REFERENCES public.comment_thread(id);


--
-- Name: comment comment_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment
    ADD CONSTRAINT comment_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: comment comment_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment
    ADD CONSTRAINT comment_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.individual(id);


--
-- Name: comment_thread comment_thread_audit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment_thread
    ADD CONSTRAINT comment_thread_audit_id_fkey FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: comment_thread comment_thread_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment_thread
    ADD CONSTRAINT comment_thread_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: concept_answer concept_answer_answer_concept; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concept_answer
    ADD CONSTRAINT concept_answer_answer_concept FOREIGN KEY (answer_concept_id) REFERENCES public.concept(id);


--
-- Name: concept_answer concept_answer_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concept_answer
    ADD CONSTRAINT concept_answer_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: concept_answer concept_answer_concept; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concept_answer
    ADD CONSTRAINT concept_answer_concept FOREIGN KEY (concept_id) REFERENCES public.concept(id);


--
-- Name: concept_answer concept_answer_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concept_answer
    ADD CONSTRAINT concept_answer_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: concept concept_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concept
    ADD CONSTRAINT concept_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: concept concept_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concept
    ADD CONSTRAINT concept_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: custom_query custom_query_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_query
    ADD CONSTRAINT custom_query_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: custom_query custom_query_last_modified_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_query
    ADD CONSTRAINT custom_query_last_modified_by_id_fkey FOREIGN KEY (last_modified_by_id) REFERENCES public.users(id);


--
-- Name: custom_query custom_query_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_query
    ADD CONSTRAINT custom_query_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: dashboard_card_mapping dashboard_card_card; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_card_mapping
    ADD CONSTRAINT dashboard_card_card FOREIGN KEY (card_id) REFERENCES public.report_card(id);


--
-- Name: dashboard_card_mapping dashboard_card_dashboard; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_card_mapping
    ADD CONSTRAINT dashboard_card_dashboard FOREIGN KEY (dashboard_id) REFERENCES public.dashboard(id);


--
-- Name: dashboard_card_mapping dashboard_card_master_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_card_mapping
    ADD CONSTRAINT dashboard_card_master_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: dashboard_card_mapping dashboard_card_organisation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_card_mapping
    ADD CONSTRAINT dashboard_card_organisation FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: dashboard_filter dashboard_filter_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_filter
    ADD CONSTRAINT dashboard_filter_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: dashboard_filter dashboard_filter_dashboard_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_filter
    ADD CONSTRAINT dashboard_filter_dashboard_id_fkey FOREIGN KEY (dashboard_id) REFERENCES public.dashboard(id);


--
-- Name: dashboard_filter dashboard_filter_last_modified_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_filter
    ADD CONSTRAINT dashboard_filter_last_modified_by_id_fkey FOREIGN KEY (last_modified_by_id) REFERENCES public.users(id);


--
-- Name: dashboard_filter dashboard_filter_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_filter
    ADD CONSTRAINT dashboard_filter_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: dashboard dashboard_master_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard
    ADD CONSTRAINT dashboard_master_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: dashboard dashboard_organisation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard
    ADD CONSTRAINT dashboard_organisation FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: dashboard_section dashboard_section_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_section
    ADD CONSTRAINT dashboard_section_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: dashboard_section_card_mapping dashboard_section_card_mapping_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_section_card_mapping
    ADD CONSTRAINT dashboard_section_card_mapping_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: dashboard_section_card_mapping dashboard_section_card_mapping_card; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_section_card_mapping
    ADD CONSTRAINT dashboard_section_card_mapping_card FOREIGN KEY (card_id) REFERENCES public.report_card(id);


--
-- Name: dashboard_section_card_mapping dashboard_section_card_mapping_dashboard; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_section_card_mapping
    ADD CONSTRAINT dashboard_section_card_mapping_dashboard FOREIGN KEY (dashboard_section_id) REFERENCES public.dashboard_section(id);


--
-- Name: dashboard_section_card_mapping dashboard_section_card_mapping_organisation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_section_card_mapping
    ADD CONSTRAINT dashboard_section_card_mapping_organisation FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: dashboard_section dashboard_section_dashboard; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_section
    ADD CONSTRAINT dashboard_section_dashboard FOREIGN KEY (dashboard_id) REFERENCES public.dashboard(id);


--
-- Name: dashboard_section dashboard_section_organisation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_section
    ADD CONSTRAINT dashboard_section_organisation FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: decision_concept decision_concept_concept; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decision_concept
    ADD CONSTRAINT decision_concept_concept FOREIGN KEY (concept_id) REFERENCES public.concept(id);


--
-- Name: decision_concept decision_concept_form; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decision_concept
    ADD CONSTRAINT decision_concept_form FOREIGN KEY (form_id) REFERENCES public.form(id);


--
-- Name: documentation_item documentation_item_documentation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documentation_item
    ADD CONSTRAINT documentation_item_documentation_id_fkey FOREIGN KEY (documentation_id) REFERENCES public.documentation(id);


--
-- Name: documentation_item documentation_item_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documentation_item
    ADD CONSTRAINT documentation_item_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: documentation documentation_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documentation
    ADD CONSTRAINT documentation_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: documentation documentation_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documentation
    ADD CONSTRAINT documentation_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.documentation(id);


--
-- Name: encounter encounter_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.encounter
    ADD CONSTRAINT encounter_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: encounter encounter_encounter_type; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.encounter
    ADD CONSTRAINT encounter_encounter_type FOREIGN KEY (encounter_type_id) REFERENCES public.encounter_type(id);


--
-- Name: encounter encounter_filled_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.encounter
    ADD CONSTRAINT encounter_filled_by_id_fkey FOREIGN KEY (filled_by_id) REFERENCES public.users(id);


--
-- Name: encounter encounter_individual; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.encounter
    ADD CONSTRAINT encounter_individual FOREIGN KEY (individual_id) REFERENCES public.individual(id);


--
-- Name: encounter encounter_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.encounter
    ADD CONSTRAINT encounter_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: encounter_type encounter_type_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.encounter_type
    ADD CONSTRAINT encounter_type_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: encounter_type encounter_type_concept; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.encounter_type
    ADD CONSTRAINT encounter_type_concept FOREIGN KEY (concept_id) REFERENCES public.concept(id);


--
-- Name: encounter_type encounter_type_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.encounter_type
    ADD CONSTRAINT encounter_type_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: entity_approval_status entity_approval_status_address_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_approval_status
    ADD CONSTRAINT entity_approval_status_address_id FOREIGN KEY (address_id) REFERENCES public.address_level(id);


--
-- Name: entity_approval_status entity_approval_status_approval_status; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_approval_status
    ADD CONSTRAINT entity_approval_status_approval_status FOREIGN KEY (approval_status_id) REFERENCES public.approval_status(id);


--
-- Name: entity_approval_status entity_approval_status_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_approval_status
    ADD CONSTRAINT entity_approval_status_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: entity_approval_status entity_approval_status_individual_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_approval_status
    ADD CONSTRAINT entity_approval_status_individual_id FOREIGN KEY (individual_id) REFERENCES public.individual(id);


--
-- Name: entity_approval_status entity_approval_status_organisation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_approval_status
    ADD CONSTRAINT entity_approval_status_organisation FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: entity_sync_status entity_sync_status_table_metadata_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_sync_status
    ADD CONSTRAINT entity_sync_status_table_metadata_id_fkey FOREIGN KEY (table_metadata_id) REFERENCES public.table_metadata(id);


--
-- Name: export_job_parameters export_job_parameters_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.export_job_parameters
    ADD CONSTRAINT export_job_parameters_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: export_job_parameters export_job_parameters_last_modified_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.export_job_parameters
    ADD CONSTRAINT export_job_parameters_last_modified_by_id_fkey FOREIGN KEY (last_modified_by_id) REFERENCES public.users(id);


--
-- Name: export_job_parameters export_job_parameters_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.export_job_parameters
    ADD CONSTRAINT export_job_parameters_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: export_job_parameters export_job_parameters_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.export_job_parameters
    ADD CONSTRAINT export_job_parameters_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: external_system_config external_system_config_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_system_config
    ADD CONSTRAINT external_system_config_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: external_system_config external_system_config_last_modified_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_system_config
    ADD CONSTRAINT external_system_config_last_modified_by_id_fkey FOREIGN KEY (last_modified_by_id) REFERENCES public.users(id);


--
-- Name: external_system_config external_system_config_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_system_config
    ADD CONSTRAINT external_system_config_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: facility facility_address; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.facility
    ADD CONSTRAINT facility_address FOREIGN KEY (address_id) REFERENCES public.address_level(id);


--
-- Name: flow_request_queue flow_request_queue_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flow_request_queue
    ADD CONSTRAINT flow_request_queue_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: flow_request_queue flow_request_queue_last_modified_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flow_request_queue
    ADD CONSTRAINT flow_request_queue_last_modified_by_id_fkey FOREIGN KEY (last_modified_by_id) REFERENCES public.users(id);


--
-- Name: flow_request_queue flow_request_queue_message_receiver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flow_request_queue
    ADD CONSTRAINT flow_request_queue_message_receiver_id_fkey FOREIGN KEY (message_receiver_id) REFERENCES public.message_receiver(id);


--
-- Name: flow_request_queue flow_request_queue_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flow_request_queue
    ADD CONSTRAINT flow_request_queue_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: form form_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form
    ADD CONSTRAINT form_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: form_element form_element_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_element
    ADD CONSTRAINT form_element_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: form_element form_element_concept; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_element
    ADD CONSTRAINT form_element_concept FOREIGN KEY (concept_id) REFERENCES public.concept(id);


--
-- Name: form_element form_element_documentation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_element
    ADD CONSTRAINT form_element_documentation_id_fkey FOREIGN KEY (documentation_id) REFERENCES public.documentation(id);


--
-- Name: form_element form_element_form_element_group; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_element
    ADD CONSTRAINT form_element_form_element_group FOREIGN KEY (form_element_group_id) REFERENCES public.form_element_group(id);


--
-- Name: form_element_group form_element_group_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_element_group
    ADD CONSTRAINT form_element_group_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: form_element_group form_element_group_form; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_element_group
    ADD CONSTRAINT form_element_group_form FOREIGN KEY (form_id) REFERENCES public.form(id);


--
-- Name: form_element form_element_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_element
    ADD CONSTRAINT form_element_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.form_element(id);


--
-- Name: form_element_group form_element_group_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_element_group
    ADD CONSTRAINT form_element_group_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: form_element form_element_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_element
    ADD CONSTRAINT form_element_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: form_mapping form_mapping_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_mapping
    ADD CONSTRAINT form_mapping_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: form_mapping form_mapping_form; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_mapping
    ADD CONSTRAINT form_mapping_form FOREIGN KEY (form_id) REFERENCES public.form(id);


--
-- Name: form_mapping form_mapping_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_mapping
    ADD CONSTRAINT form_mapping_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: form_mapping form_mapping_subject_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_mapping
    ADD CONSTRAINT form_mapping_subject_type_id_fkey FOREIGN KEY (subject_type_id) REFERENCES public.subject_type(id);


--
-- Name: form_mapping form_mapping_task_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_mapping
    ADD CONSTRAINT form_mapping_task_type_id_fkey FOREIGN KEY (task_type_id) REFERENCES public.task_type(id);


--
-- Name: form form_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form
    ADD CONSTRAINT form_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: gender gender_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gender
    ADD CONSTRAINT gender_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: gender gender_concept; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gender
    ADD CONSTRAINT gender_concept FOREIGN KEY (concept_id) REFERENCES public.concept(id);


--
-- Name: gender gender_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gender
    ADD CONSTRAINT gender_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: group_dashboard group_dashboard_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_dashboard
    ADD CONSTRAINT group_dashboard_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: group_dashboard group_dashboard_dashboard; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_dashboard
    ADD CONSTRAINT group_dashboard_dashboard FOREIGN KEY (dashboard_id) REFERENCES public.dashboard(id);


--
-- Name: group_dashboard group_dashboard_group; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_dashboard
    ADD CONSTRAINT group_dashboard_group FOREIGN KEY (group_id) REFERENCES public.groups(id);


--
-- Name: group_dashboard group_dashboard_organisation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_dashboard
    ADD CONSTRAINT group_dashboard_organisation FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: groups group_master_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT group_master_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: groups group_organisation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT group_organisation FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: group_privilege group_privilege_checklist_detail_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_privilege
    ADD CONSTRAINT group_privilege_checklist_detail_id FOREIGN KEY (checklist_detail_id) REFERENCES public.checklist_detail(id);


--
-- Name: group_privilege group_privilege_encounter_type_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_privilege
    ADD CONSTRAINT group_privilege_encounter_type_id FOREIGN KEY (encounter_type_id) REFERENCES public.encounter_type(id);


--
-- Name: group_privilege group_privilege_group_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_privilege
    ADD CONSTRAINT group_privilege_group_id FOREIGN KEY (group_id) REFERENCES public.groups(id);


--
-- Name: group_privilege group_privilege_master_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_privilege
    ADD CONSTRAINT group_privilege_master_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: group_privilege group_privilege_organisation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_privilege
    ADD CONSTRAINT group_privilege_organisation FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: group_privilege group_privilege_program_encounter_type_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_privilege
    ADD CONSTRAINT group_privilege_program_encounter_type_id FOREIGN KEY (program_encounter_type_id) REFERENCES public.encounter_type(id);


--
-- Name: group_privilege group_privilege_program_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_privilege
    ADD CONSTRAINT group_privilege_program_id FOREIGN KEY (program_id) REFERENCES public.program(id);


--
-- Name: group_privilege group_privilege_subject_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_privilege
    ADD CONSTRAINT group_privilege_subject_id FOREIGN KEY (subject_type_id) REFERENCES public.subject_type(id);


--
-- Name: group_role group_role_group_subject_type; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_role
    ADD CONSTRAINT group_role_group_subject_type FOREIGN KEY (group_subject_type_id) REFERENCES public.subject_type(id);


--
-- Name: group_role group_role_master_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_role
    ADD CONSTRAINT group_role_master_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: group_role group_role_member_subject_type; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_role
    ADD CONSTRAINT group_role_member_subject_type FOREIGN KEY (member_subject_type_id) REFERENCES public.subject_type(id);


--
-- Name: group_role group_role_organisation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_role
    ADD CONSTRAINT group_role_organisation FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: group_subject group_subject_group_role; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_subject
    ADD CONSTRAINT group_subject_group_role FOREIGN KEY (group_role_id) REFERENCES public.group_role(id);


--
-- Name: group_subject group_subject_group_subject; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_subject
    ADD CONSTRAINT group_subject_group_subject FOREIGN KEY (group_subject_id) REFERENCES public.individual(id);


--
-- Name: group_subject group_subject_master_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_subject
    ADD CONSTRAINT group_subject_master_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: group_subject group_subject_member_subject; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_subject
    ADD CONSTRAINT group_subject_member_subject FOREIGN KEY (member_subject_id) REFERENCES public.individual(id);


--
-- Name: group_subject group_subject_organisation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_subject
    ADD CONSTRAINT group_subject_organisation FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: identifier_assignment identifier_assignment_assigned_to_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifier_assignment
    ADD CONSTRAINT identifier_assignment_assigned_to_user_id_fkey FOREIGN KEY (assigned_to_user_id) REFERENCES public.users(id);


--
-- Name: identifier_assignment identifier_assignment_audit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifier_assignment
    ADD CONSTRAINT identifier_assignment_audit_id_fkey FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: identifier_assignment identifier_assignment_identifier_source_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifier_assignment
    ADD CONSTRAINT identifier_assignment_identifier_source_id_fkey FOREIGN KEY (identifier_source_id) REFERENCES public.identifier_source(id);


--
-- Name: identifier_assignment identifier_assignment_individual_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifier_assignment
    ADD CONSTRAINT identifier_assignment_individual_id_fkey FOREIGN KEY (individual_id) REFERENCES public.individual(id);


--
-- Name: identifier_assignment identifier_assignment_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifier_assignment
    ADD CONSTRAINT identifier_assignment_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: identifier_assignment identifier_assignment_program_enrolment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifier_assignment
    ADD CONSTRAINT identifier_assignment_program_enrolment_id_fkey FOREIGN KEY (program_enrolment_id) REFERENCES public.program_enrolment(id);


--
-- Name: identifier_source identifier_source_audit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifier_source
    ADD CONSTRAINT identifier_source_audit_id_fkey FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: identifier_source identifier_source_catchment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifier_source
    ADD CONSTRAINT identifier_source_catchment_id_fkey FOREIGN KEY (catchment_id) REFERENCES public.catchment(id);


--
-- Name: identifier_source identifier_source_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifier_source
    ADD CONSTRAINT identifier_source_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: identifier_user_assignment identifier_user_assignment_assigned_to_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifier_user_assignment
    ADD CONSTRAINT identifier_user_assignment_assigned_to_user_id_fkey FOREIGN KEY (assigned_to_user_id) REFERENCES public.users(id);


--
-- Name: identifier_user_assignment identifier_user_assignment_audit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifier_user_assignment
    ADD CONSTRAINT identifier_user_assignment_audit_id_fkey FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: identifier_user_assignment identifier_user_assignment_identifier_source_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifier_user_assignment
    ADD CONSTRAINT identifier_user_assignment_identifier_source_id_fkey FOREIGN KEY (identifier_source_id) REFERENCES public.identifier_source(id);


--
-- Name: identifier_user_assignment identifier_user_assignment_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifier_user_assignment
    ADD CONSTRAINT identifier_user_assignment_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: index_metadata index_metadata_column_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.index_metadata
    ADD CONSTRAINT index_metadata_column_id_fkey FOREIGN KEY (column_id) REFERENCES public.column_metadata(id);


--
-- Name: index_metadata index_metadata_table_metadata_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.index_metadata
    ADD CONSTRAINT index_metadata_table_metadata_id_fkey FOREIGN KEY (table_metadata_id) REFERENCES public.table_metadata(id);


--
-- Name: individual individual_address; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual
    ADD CONSTRAINT individual_address FOREIGN KEY (address_id) REFERENCES public.address_level(id);


--
-- Name: individual individual_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual
    ADD CONSTRAINT individual_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: individual individual_facility; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual
    ADD CONSTRAINT individual_facility FOREIGN KEY (facility_id) REFERENCES public.facility(id);


--
-- Name: individual individual_gender; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual
    ADD CONSTRAINT individual_gender FOREIGN KEY (gender_id) REFERENCES public.gender(id);


--
-- Name: individual individual_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual
    ADD CONSTRAINT individual_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: individual_relation individual_relation_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_relation
    ADD CONSTRAINT individual_relation_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: individual_relative individual_relation_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_relative
    ADD CONSTRAINT individual_relation_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: individual_relation_gender_mapping individual_relation_gender_mapping_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_relation_gender_mapping
    ADD CONSTRAINT individual_relation_gender_mapping_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: individual_relation_gender_mapping individual_relation_gender_mapping_gender; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_relation_gender_mapping
    ADD CONSTRAINT individual_relation_gender_mapping_gender FOREIGN KEY (gender_id) REFERENCES public.gender(id);


--
-- Name: individual_relation_gender_mapping individual_relation_gender_mapping_relation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_relation_gender_mapping
    ADD CONSTRAINT individual_relation_gender_mapping_relation FOREIGN KEY (relation_id) REFERENCES public.individual_relation(id);


--
-- Name: individual_relationship individual_relationship_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_relationship
    ADD CONSTRAINT individual_relationship_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: individual_relationship individual_relationship_individual_a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_relationship
    ADD CONSTRAINT individual_relationship_individual_a FOREIGN KEY (individual_a_id) REFERENCES public.individual(id);


--
-- Name: individual_relationship individual_relationship_individual_b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_relationship
    ADD CONSTRAINT individual_relationship_individual_b FOREIGN KEY (individual_b_id) REFERENCES public.individual(id);


--
-- Name: individual_relationship individual_relationship_relation_type; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_relationship
    ADD CONSTRAINT individual_relationship_relation_type FOREIGN KEY (relationship_type_id) REFERENCES public.individual_relationship_type(id);


--
-- Name: individual_relationship_type individual_relationship_type_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_relationship_type
    ADD CONSTRAINT individual_relationship_type_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: individual_relationship_type individual_relationship_type_individual_a_relation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_relationship_type
    ADD CONSTRAINT individual_relationship_type_individual_a_relation FOREIGN KEY (individual_a_is_to_b_relation_id) REFERENCES public.individual_relation(id);


--
-- Name: individual_relationship_type individual_relationship_type_individual_b_relation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_relationship_type
    ADD CONSTRAINT individual_relationship_type_individual_b_relation FOREIGN KEY (individual_b_is_to_a_relation_id) REFERENCES public.individual_relation(id);


--
-- Name: individual_relative individual_relative_individual; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_relative
    ADD CONSTRAINT individual_relative_individual FOREIGN KEY (individual_id) REFERENCES public.individual(id);


--
-- Name: individual_relative individual_relative_relative_individual; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual_relative
    ADD CONSTRAINT individual_relative_relative_individual FOREIGN KEY (relative_individual_id) REFERENCES public.individual(id);


--
-- Name: individual individual_subject_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.individual
    ADD CONSTRAINT individual_subject_type_id_fkey FOREIGN KEY (subject_type_id) REFERENCES public.subject_type(id);


--
-- Name: batch_job_execution_context job_exec_ctx_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_job_execution_context
    ADD CONSTRAINT job_exec_ctx_fk FOREIGN KEY (job_execution_id) REFERENCES public.batch_job_execution(job_execution_id);


--
-- Name: batch_job_execution_params job_exec_params_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_job_execution_params
    ADD CONSTRAINT job_exec_params_fk FOREIGN KEY (job_execution_id) REFERENCES public.batch_job_execution(job_execution_id);


--
-- Name: batch_step_execution job_exec_step_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_step_execution
    ADD CONSTRAINT job_exec_step_fk FOREIGN KEY (job_execution_id) REFERENCES public.batch_job_execution(job_execution_id);


--
-- Name: batch_job_execution job_inst_exec_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_job_execution
    ADD CONSTRAINT job_inst_exec_fk FOREIGN KEY (job_instance_id) REFERENCES public.batch_job_instance(job_instance_id);


--
-- Name: location_location_mapping location_location_mapping_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.location_location_mapping
    ADD CONSTRAINT location_location_mapping_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: location_location_mapping location_location_mapping_location; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.location_location_mapping
    ADD CONSTRAINT location_location_mapping_location FOREIGN KEY (location_id) REFERENCES public.address_level(id);


--
-- Name: location_location_mapping location_location_mapping_organisation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.location_location_mapping
    ADD CONSTRAINT location_location_mapping_organisation FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: location_location_mapping location_location_mapping_parent_location; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.location_location_mapping
    ADD CONSTRAINT location_location_mapping_parent_location FOREIGN KEY (parent_location_id) REFERENCES public.address_level(id);


--
-- Name: manual_message manual_broadcast_message_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manual_message
    ADD CONSTRAINT manual_broadcast_message_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: manual_message manual_broadcast_message_last_modified_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manual_message
    ADD CONSTRAINT manual_broadcast_message_last_modified_by_id_fkey FOREIGN KEY (last_modified_by_id) REFERENCES public.users(id);


--
-- Name: manual_message manual_broadcast_message_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manual_message
    ADD CONSTRAINT manual_broadcast_message_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: menu_item menu_item_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_item
    ADD CONSTRAINT menu_item_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: menu_item menu_item_last_modified_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_item
    ADD CONSTRAINT menu_item_last_modified_by_id_fkey FOREIGN KEY (last_modified_by_id) REFERENCES public.users(id);


--
-- Name: menu_item menu_item_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_item
    ADD CONSTRAINT menu_item_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: message_receiver message_receiver_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_receiver
    ADD CONSTRAINT message_receiver_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: message_receiver message_receiver_last_modified_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_receiver
    ADD CONSTRAINT message_receiver_last_modified_by_id_fkey FOREIGN KEY (last_modified_by_id) REFERENCES public.users(id);


--
-- Name: message_receiver message_receiver_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_receiver
    ADD CONSTRAINT message_receiver_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: message_request_queue message_request_queue_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_request_queue
    ADD CONSTRAINT message_request_queue_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: message_request_queue message_request_queue_last_modified_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_request_queue
    ADD CONSTRAINT message_request_queue_last_modified_by_id_fkey FOREIGN KEY (last_modified_by_id) REFERENCES public.users(id);


--
-- Name: message_request_queue message_request_queue_manual_broadcast_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_request_queue
    ADD CONSTRAINT message_request_queue_manual_broadcast_message_id_fkey FOREIGN KEY (manual_message_id) REFERENCES public.manual_message(id);


--
-- Name: message_request_queue message_request_queue_message_receiver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_request_queue
    ADD CONSTRAINT message_request_queue_message_receiver_id_fkey FOREIGN KEY (message_receiver_id) REFERENCES public.message_receiver(id);


--
-- Name: message_request_queue message_request_queue_message_rule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_request_queue
    ADD CONSTRAINT message_request_queue_message_rule_id_fkey FOREIGN KEY (message_rule_id) REFERENCES public.message_rule(id);


--
-- Name: message_request_queue message_request_queue_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_request_queue
    ADD CONSTRAINT message_request_queue_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: message_rule message_rule_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_rule
    ADD CONSTRAINT message_rule_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: message_rule message_rule_last_modified_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_rule
    ADD CONSTRAINT message_rule_last_modified_by_id_fkey FOREIGN KEY (last_modified_by_id) REFERENCES public.users(id);


--
-- Name: message_rule message_rule_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_rule
    ADD CONSTRAINT message_rule_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: msg91_config msg91_config_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msg91_config
    ADD CONSTRAINT msg91_config_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: msg91_config msg91_config_organisation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.msg91_config
    ADD CONSTRAINT msg91_config_organisation FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: news news_audit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news
    ADD CONSTRAINT news_audit_id_fkey FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: news news_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news
    ADD CONSTRAINT news_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: non_applicable_form_element non_applicable_form_element_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.non_applicable_form_element
    ADD CONSTRAINT non_applicable_form_element_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: non_applicable_form_element non_applicable_form_element_form_element_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.non_applicable_form_element
    ADD CONSTRAINT non_applicable_form_element_form_element_id_fkey FOREIGN KEY (form_element_id) REFERENCES public.form_element(id);


--
-- Name: non_applicable_form_element non_applicable_form_element_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.non_applicable_form_element
    ADD CONSTRAINT non_applicable_form_element_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: operational_encounter_type operational_encounter_type_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operational_encounter_type
    ADD CONSTRAINT operational_encounter_type_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: operational_encounter_type operational_encounter_type_encounter_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operational_encounter_type
    ADD CONSTRAINT operational_encounter_type_encounter_type_id_fkey FOREIGN KEY (encounter_type_id) REFERENCES public.encounter_type(id);


--
-- Name: operational_encounter_type operational_encounter_type_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operational_encounter_type
    ADD CONSTRAINT operational_encounter_type_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: operational_program operational_program_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operational_program
    ADD CONSTRAINT operational_program_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: operational_program operational_program_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operational_program
    ADD CONSTRAINT operational_program_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: operational_program operational_program_program_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operational_program
    ADD CONSTRAINT operational_program_program_id_fkey FOREIGN KEY (program_id) REFERENCES public.program(id);


--
-- Name: operational_subject_type operational_subject_type_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operational_subject_type
    ADD CONSTRAINT operational_subject_type_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: operational_subject_type operational_subject_type_organisation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operational_subject_type
    ADD CONSTRAINT operational_subject_type_organisation FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: operational_subject_type operational_subject_type_subject_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operational_subject_type
    ADD CONSTRAINT operational_subject_type_subject_type_id_fkey FOREIGN KEY (subject_type_id) REFERENCES public.subject_type(id);


--
-- Name: organisation organisation_account; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organisation
    ADD CONSTRAINT organisation_account FOREIGN KEY (account_id) REFERENCES public.account(id);


--
-- Name: organisation_config organisation_config_master_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organisation_config
    ADD CONSTRAINT organisation_config_master_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: organisation_config organisation_config_organisation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organisation_config
    ADD CONSTRAINT organisation_config_organisation FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: organisation_group organisation_group_account; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organisation_group
    ADD CONSTRAINT organisation_group_account FOREIGN KEY (account_id) REFERENCES public.account(id);


--
-- Name: organisation_group_organisation organisation_group_organisation_organisation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organisation_group_organisation
    ADD CONSTRAINT organisation_group_organisation_organisation FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: organisation_group_organisation organisation_group_organisation_organisation_group; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organisation_group_organisation
    ADD CONSTRAINT organisation_group_organisation_organisation_group FOREIGN KEY (organisation_group_id) REFERENCES public.organisation_group(id);


--
-- Name: organisation organisation_parent_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organisation
    ADD CONSTRAINT organisation_parent_organisation_id_fkey FOREIGN KEY (parent_organisation_id) REFERENCES public.organisation(id);


--
-- Name: platform_translation platform_translation_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.platform_translation
    ADD CONSTRAINT platform_translation_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: program program_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.program
    ADD CONSTRAINT program_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: program_encounter program_encounter_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.program_encounter
    ADD CONSTRAINT program_encounter_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: program_encounter program_encounter_encounter_type; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.program_encounter
    ADD CONSTRAINT program_encounter_encounter_type FOREIGN KEY (encounter_type_id) REFERENCES public.encounter_type(id);


--
-- Name: program_encounter program_encounter_filled_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.program_encounter
    ADD CONSTRAINT program_encounter_filled_by_id_fkey FOREIGN KEY (filled_by_id) REFERENCES public.users(id);


--
-- Name: program_encounter program_encounter_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.program_encounter
    ADD CONSTRAINT program_encounter_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: program_encounter program_encounter_program_enrolment; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.program_encounter
    ADD CONSTRAINT program_encounter_program_enrolment FOREIGN KEY (program_enrolment_id) REFERENCES public.program_enrolment(id);


--
-- Name: program_enrolment program_enrolment_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.program_enrolment
    ADD CONSTRAINT program_enrolment_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: program_enrolment program_enrolment_individual; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.program_enrolment
    ADD CONSTRAINT program_enrolment_individual FOREIGN KEY (individual_id) REFERENCES public.individual(id);


--
-- Name: program_enrolment program_enrolment_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.program_enrolment
    ADD CONSTRAINT program_enrolment_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: program_enrolment program_enrolment_program; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.program_enrolment
    ADD CONSTRAINT program_enrolment_program FOREIGN KEY (program_id) REFERENCES public.program(id);


--
-- Name: program program_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.program
    ADD CONSTRAINT program_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: program_outcome program_outcome_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.program_outcome
    ADD CONSTRAINT program_outcome_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: program_outcome program_outcome_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.program_outcome
    ADD CONSTRAINT program_outcome_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: qrtz_blob_triggers qrtz_blob_triggers_sched_name_trigger_name_trigger_group_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qrtz_blob_triggers
    ADD CONSTRAINT qrtz_blob_triggers_sched_name_trigger_name_trigger_group_fkey FOREIGN KEY (sched_name, trigger_name, trigger_group) REFERENCES public.qrtz_triggers(sched_name, trigger_name, trigger_group) ON DELETE CASCADE;


--
-- Name: qrtz_cron_triggers qrtz_cron_triggers_sched_name_trigger_name_trigger_group_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qrtz_cron_triggers
    ADD CONSTRAINT qrtz_cron_triggers_sched_name_trigger_name_trigger_group_fkey FOREIGN KEY (sched_name, trigger_name, trigger_group) REFERENCES public.qrtz_triggers(sched_name, trigger_name, trigger_group) ON DELETE CASCADE;


--
-- Name: qrtz_simple_triggers qrtz_simple_triggers_sched_name_trigger_name_trigger_group_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qrtz_simple_triggers
    ADD CONSTRAINT qrtz_simple_triggers_sched_name_trigger_name_trigger_group_fkey FOREIGN KEY (sched_name, trigger_name, trigger_group) REFERENCES public.qrtz_triggers(sched_name, trigger_name, trigger_group) ON DELETE CASCADE;


--
-- Name: qrtz_simprop_triggers qrtz_simprop_triggers_sched_name_trigger_name_trigger_grou_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qrtz_simprop_triggers
    ADD CONSTRAINT qrtz_simprop_triggers_sched_name_trigger_name_trigger_grou_fkey FOREIGN KEY (sched_name, trigger_name, trigger_group) REFERENCES public.qrtz_triggers(sched_name, trigger_name, trigger_group) ON DELETE CASCADE;


--
-- Name: qrtz_triggers qrtz_triggers_sched_name_job_name_job_group_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qrtz_triggers
    ADD CONSTRAINT qrtz_triggers_sched_name_job_name_job_group_fkey FOREIGN KEY (sched_name, job_name, job_group) REFERENCES public.qrtz_job_details(sched_name, job_name, job_group);


--
-- Name: report_card report_card_standard_report_card_type; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_card
    ADD CONSTRAINT report_card_standard_report_card_type FOREIGN KEY (standard_report_card_type_id) REFERENCES public.standard_report_card_type(id);


--
-- Name: reset_sync reset_sync_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reset_sync
    ADD CONSTRAINT reset_sync_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: reset_sync reset_sync_subject_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reset_sync
    ADD CONSTRAINT reset_sync_subject_type_id_fkey FOREIGN KEY (subject_type_id) REFERENCES public.subject_type(id);


--
-- Name: reset_sync reset_sync_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reset_sync
    ADD CONSTRAINT reset_sync_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: rule rule_audit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule
    ADD CONSTRAINT rule_audit_id_fkey FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: rule_dependency rule_dependency_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_dependency
    ADD CONSTRAINT rule_dependency_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: rule_failure_telemetry rule_failure_telemetry_master_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_failure_telemetry
    ADD CONSTRAINT rule_failure_telemetry_master_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: rule_failure_telemetry rule_failure_telemetry_organisation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_failure_telemetry
    ADD CONSTRAINT rule_failure_telemetry_organisation FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: rule_failure_telemetry rule_failure_telemetry_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_failure_telemetry
    ADD CONSTRAINT rule_failure_telemetry_user FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: rule rule_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule
    ADD CONSTRAINT rule_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: rule rule_rule_dependency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule
    ADD CONSTRAINT rule_rule_dependency_id_fkey FOREIGN KEY (rule_dependency_id) REFERENCES public.rule_dependency(id);


--
-- Name: batch_step_execution_context step_exec_ctx_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_step_execution_context
    ADD CONSTRAINT step_exec_ctx_fk FOREIGN KEY (step_execution_id) REFERENCES public.batch_step_execution(step_execution_id);


--
-- Name: subject_migration subject_migration_audit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subject_migration
    ADD CONSTRAINT subject_migration_audit_id_fkey FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: subject_migration subject_migration_individual_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subject_migration
    ADD CONSTRAINT subject_migration_individual_id_fkey FOREIGN KEY (individual_id) REFERENCES public.individual(id);


--
-- Name: subject_migration subject_migration_new_address_level_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subject_migration
    ADD CONSTRAINT subject_migration_new_address_level_id_fkey FOREIGN KEY (new_address_level_id) REFERENCES public.address_level(id);


--
-- Name: subject_migration subject_migration_old_address_level_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subject_migration
    ADD CONSTRAINT subject_migration_old_address_level_id_fkey FOREIGN KEY (old_address_level_id) REFERENCES public.address_level(id);


--
-- Name: subject_migration subject_migration_subject_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subject_migration
    ADD CONSTRAINT subject_migration_subject_type_id_fkey FOREIGN KEY (subject_type_id) REFERENCES public.subject_type(id);


--
-- Name: subject_program_eligibility subject_program_eligibility_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subject_program_eligibility
    ADD CONSTRAINT subject_program_eligibility_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: subject_program_eligibility subject_program_eligibility_last_modified_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subject_program_eligibility
    ADD CONSTRAINT subject_program_eligibility_last_modified_by_id_fkey FOREIGN KEY (last_modified_by_id) REFERENCES public.users(id);


--
-- Name: subject_program_eligibility subject_program_eligibility_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subject_program_eligibility
    ADD CONSTRAINT subject_program_eligibility_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: subject_program_eligibility subject_program_eligibility_program_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subject_program_eligibility
    ADD CONSTRAINT subject_program_eligibility_program_id_fkey FOREIGN KEY (program_id) REFERENCES public.program(id);


--
-- Name: subject_program_eligibility subject_program_eligibility_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subject_program_eligibility
    ADD CONSTRAINT subject_program_eligibility_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.individual(id);


--
-- Name: subject_type subject_type_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subject_type
    ADD CONSTRAINT subject_type_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: subject_type subject_type_organisation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subject_type
    ADD CONSTRAINT subject_type_organisation FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: sync_telemetry sync_telemetry_organisation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sync_telemetry
    ADD CONSTRAINT sync_telemetry_organisation FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: sync_telemetry sync_telemetry_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sync_telemetry
    ADD CONSTRAINT sync_telemetry_user FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: task task_assigned_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task
    ADD CONSTRAINT task_assigned_user_id_fkey FOREIGN KEY (assigned_user_id) REFERENCES public.users(id);


--
-- Name: task task_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task
    ADD CONSTRAINT task_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: task task_last_modified_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task
    ADD CONSTRAINT task_last_modified_by_id_fkey FOREIGN KEY (last_modified_by_id) REFERENCES public.users(id);


--
-- Name: task task_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task
    ADD CONSTRAINT task_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: task_status task_status_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_status
    ADD CONSTRAINT task_status_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: task_status task_status_last_modified_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_status
    ADD CONSTRAINT task_status_last_modified_by_id_fkey FOREIGN KEY (last_modified_by_id) REFERENCES public.users(id);


--
-- Name: task_status task_status_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_status
    ADD CONSTRAINT task_status_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: task_status task_status_task_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_status
    ADD CONSTRAINT task_status_task_type_id_fkey FOREIGN KEY (task_type_id) REFERENCES public.task_type(id);


--
-- Name: task task_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task
    ADD CONSTRAINT task_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.individual(id);


--
-- Name: task task_task_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task
    ADD CONSTRAINT task_task_status_id_fkey FOREIGN KEY (task_status_id) REFERENCES public.task_status(id);


--
-- Name: task task_task_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task
    ADD CONSTRAINT task_task_type_id_fkey FOREIGN KEY (task_type_id) REFERENCES public.task_type(id);


--
-- Name: task_type task_type_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_type
    ADD CONSTRAINT task_type_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: task_type task_type_last_modified_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_type
    ADD CONSTRAINT task_type_last_modified_by_id_fkey FOREIGN KEY (last_modified_by_id) REFERENCES public.users(id);


--
-- Name: task_type task_type_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_type
    ADD CONSTRAINT task_type_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: task_unassignment task_unassignment_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_unassignment
    ADD CONSTRAINT task_unassignment_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: task_unassignment task_unassignment_last_modified_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_unassignment
    ADD CONSTRAINT task_unassignment_last_modified_by_id_fkey FOREIGN KEY (last_modified_by_id) REFERENCES public.users(id);


--
-- Name: task_unassignment task_unassignment_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_unassignment
    ADD CONSTRAINT task_unassignment_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: task_unassignment task_unassignment_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_unassignment
    ADD CONSTRAINT task_unassignment_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.task(id);


--
-- Name: task_unassignment task_unassignment_unassigned_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_unassignment
    ADD CONSTRAINT task_unassignment_unassigned_user_id_fkey FOREIGN KEY (unassigned_user_id) REFERENCES public.users(id);


--
-- Name: template_organisation template_organisation_created_by_user_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.template_organisation
    ADD CONSTRAINT template_organisation_created_by_user_fk FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: template_organisation template_organisation_last_modified_by_user_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.template_organisation
    ADD CONSTRAINT template_organisation_last_modified_by_user_fk FOREIGN KEY (last_modified_by_id) REFERENCES public.users(id);


--
-- Name: template_organisation template_organisation_organisation_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.template_organisation
    ADD CONSTRAINT template_organisation_organisation_fk FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: translation translation_master_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.translation
    ADD CONSTRAINT translation_master_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: translation translation_organisation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.translation
    ADD CONSTRAINT translation_organisation FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: user_group user_group_group_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_group
    ADD CONSTRAINT user_group_group_id FOREIGN KEY (group_id) REFERENCES public.groups(id);


--
-- Name: user_group user_group_master_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_group
    ADD CONSTRAINT user_group_master_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: user_group user_group_organisation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_group
    ADD CONSTRAINT user_group_organisation FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: user_group user_group_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_group
    ADD CONSTRAINT user_group_user_id FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: user_subject_assignment user_subject_assignment_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subject_assignment
    ADD CONSTRAINT user_subject_assignment_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: user_subject_assignment user_subject_assignment_last_modified_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subject_assignment
    ADD CONSTRAINT user_subject_assignment_last_modified_by_id_fkey FOREIGN KEY (last_modified_by_id) REFERENCES public.users(id);


--
-- Name: user_subject_assignment user_subject_assignment_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subject_assignment
    ADD CONSTRAINT user_subject_assignment_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: user_subject_assignment user_subject_assignment_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subject_assignment
    ADD CONSTRAINT user_subject_assignment_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.individual(id);


--
-- Name: user_subject_assignment user_subject_assignment_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subject_assignment
    ADD CONSTRAINT user_subject_assignment_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: user_subject user_subject_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subject
    ADD CONSTRAINT user_subject_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: user_subject user_subject_last_modified_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subject
    ADD CONSTRAINT user_subject_last_modified_by_id_fkey FOREIGN KEY (last_modified_by_id) REFERENCES public.users(id);


--
-- Name: user_subject user_subject_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subject
    ADD CONSTRAINT user_subject_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: user_subject user_subject_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subject
    ADD CONSTRAINT user_subject_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.individual(id);


--
-- Name: user_subject user_subject_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subject
    ADD CONSTRAINT user_subject_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: users users_organisation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_organisation_id_fkey FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: video video_audit; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.video
    ADD CONSTRAINT video_audit FOREIGN KEY (audit_id) REFERENCES public.audit(id);


--
-- Name: video video_organisation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.video
    ADD CONSTRAINT video_organisation FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: video_telemetric video_telemetric_organisation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.video_telemetric
    ADD CONSTRAINT video_telemetric_organisation FOREIGN KEY (organisation_id) REFERENCES public.organisation(id);


--
-- Name: video_telemetric video_telemetric_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.video_telemetric
    ADD CONSTRAINT video_telemetric_user FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: video_telemetric video_telemetric_video; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.video_telemetric
    ADD CONSTRAINT video_telemetric_video FOREIGN KEY (video_id) REFERENCES public.video(id);


--
-- Name: address_level; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.address_level ENABLE ROW LEVEL SECURITY;

--
-- Name: address_level address_level_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY address_level_orgs ON public.address_level USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: address_level_type; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.address_level_type ENABLE ROW LEVEL SECURITY;

--
-- Name: address_level_type address_level_type_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY address_level_type_orgs ON public.address_level_type USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: answer_concept_migration; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.answer_concept_migration ENABLE ROW LEVEL SECURITY;

--
-- Name: answer_concept_migration answer_concept_migration_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY answer_concept_migration_orgs ON public.answer_concept_migration USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: storage_management_config archival_config_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY archival_config_orgs ON public.storage_management_config USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: report_card card_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY card_orgs ON public.report_card USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: catchment; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.catchment ENABLE ROW LEVEL SECURITY;

--
-- Name: catchment catchment_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY catchment_orgs ON public.catchment USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: checklist; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.checklist ENABLE ROW LEVEL SECURITY;

--
-- Name: checklist_detail; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.checklist_detail ENABLE ROW LEVEL SECURITY;

--
-- Name: checklist_detail checklist_detail_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY checklist_detail_orgs ON public.checklist_detail USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: checklist_item; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.checklist_item ENABLE ROW LEVEL SECURITY;

--
-- Name: checklist_item_detail; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.checklist_item_detail ENABLE ROW LEVEL SECURITY;

--
-- Name: checklist_item_detail checklist_item_detail_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY checklist_item_detail_orgs ON public.checklist_item_detail USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: checklist_item checklist_item_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY checklist_item_orgs ON public.checklist_item USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: checklist checklist_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY checklist_orgs ON public.checklist USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: column_metadata; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.column_metadata ENABLE ROW LEVEL SECURITY;

--
-- Name: column_metadata column_metadata_rls_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY column_metadata_rls_policy ON public.column_metadata USING ((schema_name IN ( SELECT s.schema_name
   FROM ( SELECT organisation.db_user,
            organisation.schema_name
           FROM public.organisation
        UNION ALL
         SELECT organisation_group.db_user,
            organisation_group.schema_name
           FROM public.organisation_group) s
  WHERE ((s.db_user)::text = CURRENT_USER)))) WITH CHECK ((schema_name IN ( SELECT s.schema_name
   FROM ( SELECT organisation.db_user,
            organisation.schema_name
           FROM public.organisation
        UNION ALL
         SELECT organisation_group.db_user,
            organisation_group.schema_name
           FROM public.organisation_group) s
  WHERE ((s.db_user)::text = CURRENT_USER))));


--
-- Name: comment; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.comment ENABLE ROW LEVEL SECURITY;

--
-- Name: comment comment_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY comment_orgs ON public.comment USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: comment_thread; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.comment_thread ENABLE ROW LEVEL SECURITY;

--
-- Name: comment_thread comment_thread_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY comment_thread_orgs ON public.comment_thread USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: concept; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.concept ENABLE ROW LEVEL SECURITY;

--
-- Name: concept_answer; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.concept_answer ENABLE ROW LEVEL SECURITY;

--
-- Name: concept_answer concept_answer_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY concept_answer_orgs ON public.concept_answer USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: concept concept_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY concept_orgs ON public.concept USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: custom_query; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.custom_query ENABLE ROW LEVEL SECURITY;

--
-- Name: custom_query custom_query_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY custom_query_orgs ON public.custom_query USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: dashboard; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.dashboard ENABLE ROW LEVEL SECURITY;

--
-- Name: dashboard_card_mapping; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.dashboard_card_mapping ENABLE ROW LEVEL SECURITY;

--
-- Name: dashboard_card_mapping dashboard_card_mapping_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY dashboard_card_mapping_orgs ON public.dashboard_card_mapping USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: dashboard_filter; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.dashboard_filter ENABLE ROW LEVEL SECURITY;

--
-- Name: dashboard_filter dashboard_filter_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY dashboard_filter_orgs ON public.dashboard_filter USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: dashboard dashboard_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY dashboard_orgs ON public.dashboard USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: dashboard_section; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.dashboard_section ENABLE ROW LEVEL SECURITY;

--
-- Name: dashboard_section_card_mapping; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.dashboard_section_card_mapping ENABLE ROW LEVEL SECURITY;

--
-- Name: dashboard_section_card_mapping dashboard_section_card_mapping_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY dashboard_section_card_mapping_orgs ON public.dashboard_section_card_mapping USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: dashboard_section dashboard_section_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY dashboard_section_orgs ON public.dashboard_section USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: documentation; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.documentation ENABLE ROW LEVEL SECURITY;

--
-- Name: documentation_item; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.documentation_item ENABLE ROW LEVEL SECURITY;

--
-- Name: documentation_item documentation_item_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY documentation_item_orgs ON public.documentation_item USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: documentation documentation_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY documentation_orgs ON public.documentation USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: encounter; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.encounter ENABLE ROW LEVEL SECURITY;

--
-- Name: encounter encounter_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY encounter_orgs ON public.encounter USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: encounter_type; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.encounter_type ENABLE ROW LEVEL SECURITY;

--
-- Name: encounter_type encounter_type_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY encounter_type_orgs ON public.encounter_type USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: entity_approval_status; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.entity_approval_status ENABLE ROW LEVEL SECURITY;

--
-- Name: entity_approval_status entity_approval_status_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY entity_approval_status_orgs ON public.entity_approval_status USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: entity_sync_status; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.entity_sync_status ENABLE ROW LEVEL SECURITY;

--
-- Name: entity_sync_status entity_sync_status_rls_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY entity_sync_status_rls_policy ON public.entity_sync_status USING ((db_user = CURRENT_USER)) WITH CHECK ((db_user = CURRENT_USER));


--
-- Name: export_job_parameters; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.export_job_parameters ENABLE ROW LEVEL SECURITY;

--
-- Name: export_job_parameters export_job_parameters_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY export_job_parameters_orgs ON public.export_job_parameters USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: external_system_config; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.external_system_config ENABLE ROW LEVEL SECURITY;

--
-- Name: external_system_config external_system_config_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY external_system_config_orgs ON public.external_system_config USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: facility; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.facility ENABLE ROW LEVEL SECURITY;

--
-- Name: facility facility_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY facility_orgs ON public.facility USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: flow_request_queue; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.flow_request_queue ENABLE ROW LEVEL SECURITY;

--
-- Name: flow_request_queue flow_request_queue_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY flow_request_queue_orgs ON public.flow_request_queue USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: form; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.form ENABLE ROW LEVEL SECURITY;

--
-- Name: form_element; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.form_element ENABLE ROW LEVEL SECURITY;

--
-- Name: form_element_group; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.form_element_group ENABLE ROW LEVEL SECURITY;

--
-- Name: form_element_group form_element_group_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY form_element_group_orgs ON public.form_element_group USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: form_element form_element_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY form_element_orgs ON public.form_element USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: form_mapping; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.form_mapping ENABLE ROW LEVEL SECURITY;

--
-- Name: form_mapping form_mapping_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY form_mapping_orgs ON public.form_mapping USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: form form_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY form_orgs ON public.form USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: gender; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.gender ENABLE ROW LEVEL SECURITY;

--
-- Name: gender gender_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY gender_orgs ON public.gender USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: group_dashboard; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.group_dashboard ENABLE ROW LEVEL SECURITY;

--
-- Name: group_dashboard group_dashboard_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY group_dashboard_orgs ON public.group_dashboard USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: group_privilege; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.group_privilege ENABLE ROW LEVEL SECURITY;

--
-- Name: group_privilege group_privilege_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY group_privilege_orgs ON public.group_privilege USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: group_role; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.group_role ENABLE ROW LEVEL SECURITY;

--
-- Name: group_role group_role_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY group_role_orgs ON public.group_role USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: group_subject; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.group_subject ENABLE ROW LEVEL SECURITY;

--
-- Name: group_subject group_subject_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY group_subject_orgs ON public.group_subject USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: groups; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;

--
-- Name: groups groups_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY groups_orgs ON public.groups USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: identifier_assignment; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.identifier_assignment ENABLE ROW LEVEL SECURITY;

--
-- Name: identifier_assignment identifier_assignment_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY identifier_assignment_orgs ON public.identifier_assignment USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: identifier_source; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.identifier_source ENABLE ROW LEVEL SECURITY;

--
-- Name: identifier_source identifier_source_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY identifier_source_orgs ON public.identifier_source USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: identifier_user_assignment; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.identifier_user_assignment ENABLE ROW LEVEL SECURITY;

--
-- Name: identifier_user_assignment identifier_user_assignment_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY identifier_user_assignment_orgs ON public.identifier_user_assignment USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: individual; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.individual ENABLE ROW LEVEL SECURITY;

--
-- Name: individual individual_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY individual_orgs ON public.individual USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: individual_relation; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.individual_relation ENABLE ROW LEVEL SECURITY;

--
-- Name: individual_relation_gender_mapping; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.individual_relation_gender_mapping ENABLE ROW LEVEL SECURITY;

--
-- Name: individual_relation_gender_mapping individual_relation_gender_mapping_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY individual_relation_gender_mapping_orgs ON public.individual_relation_gender_mapping USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: individual_relation individual_relation_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY individual_relation_orgs ON public.individual_relation USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: individual_relationship; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.individual_relationship ENABLE ROW LEVEL SECURITY;

--
-- Name: individual_relationship individual_relationship_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY individual_relationship_orgs ON public.individual_relationship USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: individual_relationship_type; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.individual_relationship_type ENABLE ROW LEVEL SECURITY;

--
-- Name: individual_relationship_type individual_relationship_type_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY individual_relationship_type_orgs ON public.individual_relationship_type USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: location_location_mapping; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.location_location_mapping ENABLE ROW LEVEL SECURITY;

--
-- Name: location_location_mapping location_location_mapping_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY location_location_mapping_orgs ON public.location_location_mapping USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: manual_message manual_broadcast_message_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY manual_broadcast_message_orgs ON public.manual_message USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: manual_message; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.manual_message ENABLE ROW LEVEL SECURITY;

--
-- Name: menu_item; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.menu_item ENABLE ROW LEVEL SECURITY;

--
-- Name: menu_item menu_item_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY menu_item_orgs ON public.menu_item USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: message_receiver; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.message_receiver ENABLE ROW LEVEL SECURITY;

--
-- Name: message_receiver message_receiver_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY message_receiver_orgs ON public.message_receiver USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: message_request_queue; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.message_request_queue ENABLE ROW LEVEL SECURITY;

--
-- Name: message_request_queue message_request_queue_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY message_request_queue_orgs ON public.message_request_queue USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: message_rule; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.message_rule ENABLE ROW LEVEL SECURITY;

--
-- Name: message_rule message_rule_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY message_rule_orgs ON public.message_rule USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: msg91_config; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.msg91_config ENABLE ROW LEVEL SECURITY;

--
-- Name: msg91_config msg91_config_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY msg91_config_orgs ON public.msg91_config USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: news; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.news ENABLE ROW LEVEL SECURITY;

--
-- Name: news news_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY news_orgs ON public.news USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: non_applicable_form_element; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.non_applicable_form_element ENABLE ROW LEVEL SECURITY;

--
-- Name: non_applicable_form_element non_applicable_form_element_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY non_applicable_form_element_orgs ON public.non_applicable_form_element USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: operational_encounter_type; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.operational_encounter_type ENABLE ROW LEVEL SECURITY;

--
-- Name: operational_encounter_type operational_encounter_type_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY operational_encounter_type_orgs ON public.operational_encounter_type USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: operational_program; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.operational_program ENABLE ROW LEVEL SECURITY;

--
-- Name: operational_program operational_program_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY operational_program_orgs ON public.operational_program USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: operational_subject_type; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.operational_subject_type ENABLE ROW LEVEL SECURITY;

--
-- Name: operational_subject_type operational_subject_type_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY operational_subject_type_orgs ON public.operational_subject_type USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: organisation; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.organisation ENABLE ROW LEVEL SECURITY;

--
-- Name: organisation_config; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.organisation_config ENABLE ROW LEVEL SECURITY;

--
-- Name: organisation_config organisation_config_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organisation_config_orgs ON public.organisation_config USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: organisation_group; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.organisation_group ENABLE ROW LEVEL SECURITY;

--
-- Name: organisation_group_organisation; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.organisation_group_organisation ENABLE ROW LEVEL SECURITY;

--
-- Name: organisation_group_organisation organisation_group_organisation_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organisation_group_organisation_policy ON public.organisation_group_organisation USING ((organisation_group_id IN ( SELECT organisation_group.id
   FROM public.organisation_group
  WHERE ((organisation_group.db_user)::text = CURRENT_USER))));


--
-- Name: organisation_group organisation_group_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organisation_group_policy ON public.organisation_group USING ((CURRENT_USER = (db_user)::text));


--
-- Name: organisation organisation_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organisation_policy ON public.organisation USING (((CURRENT_USER = ANY (ARRAY['openchs'::name, 'openchs_impl'::name])) OR (id IN ( SELECT org_ids.id
   FROM public.org_ids)) OR (id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation))));


--
-- Name: post_etl_sync_status; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.post_etl_sync_status ENABLE ROW LEVEL SECURITY;

--
-- Name: post_etl_sync_status post_etl_sync_status_rls_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY post_etl_sync_status_rls_policy ON public.post_etl_sync_status USING ((db_user = CURRENT_USER)) WITH CHECK ((db_user = CURRENT_USER));


--
-- Name: program; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.program ENABLE ROW LEVEL SECURITY;

--
-- Name: program_encounter; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.program_encounter ENABLE ROW LEVEL SECURITY;

--
-- Name: program_encounter program_encounter_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY program_encounter_orgs ON public.program_encounter USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: program_enrolment; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.program_enrolment ENABLE ROW LEVEL SECURITY;

--
-- Name: program_enrolment program_enrolment_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY program_enrolment_orgs ON public.program_enrolment USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: program program_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY program_orgs ON public.program USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: program_outcome; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.program_outcome ENABLE ROW LEVEL SECURITY;

--
-- Name: program_outcome program_outcome_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY program_outcome_orgs ON public.program_outcome USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: report_card; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.report_card ENABLE ROW LEVEL SECURITY;

--
-- Name: reset_sync; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.reset_sync ENABLE ROW LEVEL SECURITY;

--
-- Name: reset_sync reset_sync_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY reset_sync_orgs ON public.reset_sync USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: rule; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.rule ENABLE ROW LEVEL SECURITY;

--
-- Name: rule_dependency; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.rule_dependency ENABLE ROW LEVEL SECURITY;

--
-- Name: rule_dependency rule_dependency_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rule_dependency_orgs ON public.rule_dependency USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: rule_failure_telemetry; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.rule_failure_telemetry ENABLE ROW LEVEL SECURITY;

--
-- Name: rule_failure_telemetry rule_failure_telemetry_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rule_failure_telemetry_orgs ON public.rule_failure_telemetry USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: rule rule_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rule_orgs ON public.rule USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: storage_management_config; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.storage_management_config ENABLE ROW LEVEL SECURITY;

--
-- Name: subject_migration; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.subject_migration ENABLE ROW LEVEL SECURITY;

--
-- Name: subject_migration subject_migration_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY subject_migration_orgs ON public.subject_migration USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: subject_program_eligibility; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.subject_program_eligibility ENABLE ROW LEVEL SECURITY;

--
-- Name: subject_program_eligibility subject_program_eligibility_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY subject_program_eligibility_orgs ON public.subject_program_eligibility USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: subject_type; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.subject_type ENABLE ROW LEVEL SECURITY;

--
-- Name: subject_type subject_type_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY subject_type_orgs ON public.subject_type USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: sync_telemetry; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sync_telemetry ENABLE ROW LEVEL SECURITY;

--
-- Name: sync_telemetry sync_telemetry_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sync_telemetry_orgs ON public.sync_telemetry USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: table_metadata; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.table_metadata ENABLE ROW LEVEL SECURITY;

--
-- Name: table_metadata table_metadata_rls_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY table_metadata_rls_policy ON public.table_metadata USING ((schema_name IN ( SELECT s.schema_name
   FROM ( SELECT organisation.db_user,
            organisation.schema_name
           FROM public.organisation
        UNION ALL
         SELECT organisation_group.db_user,
            organisation_group.schema_name
           FROM public.organisation_group) s
  WHERE ((s.db_user)::text = CURRENT_USER)))) WITH CHECK ((schema_name IN ( SELECT s.schema_name
   FROM ( SELECT organisation.db_user,
            organisation.schema_name
           FROM public.organisation
        UNION ALL
         SELECT organisation_group.db_user,
            organisation_group.schema_name
           FROM public.organisation_group) s
  WHERE ((s.db_user)::text = CURRENT_USER))));


--
-- Name: task; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.task ENABLE ROW LEVEL SECURITY;

--
-- Name: task task_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY task_orgs ON public.task USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: task_status; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.task_status ENABLE ROW LEVEL SECURITY;

--
-- Name: task_status task_status_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY task_status_orgs ON public.task_status USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: task_type; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.task_type ENABLE ROW LEVEL SECURITY;

--
-- Name: task_type task_type_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY task_type_orgs ON public.task_type USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: task_unassignment; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.task_unassignment ENABLE ROW LEVEL SECURITY;

--
-- Name: task_unassignment task_unassignment_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY task_unassignment_orgs ON public.task_unassignment USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: translation; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.translation ENABLE ROW LEVEL SECURITY;

--
-- Name: translation translation_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY translation_orgs ON public.translation USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: user_group; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_group ENABLE ROW LEVEL SECURITY;

--
-- Name: user_group user_group_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_group_orgs ON public.user_group USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: user_subject; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_subject ENABLE ROW LEVEL SECURITY;

--
-- Name: user_subject_assignment; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_subject_assignment ENABLE ROW LEVEL SECURITY;

--
-- Name: user_subject_assignment user_subject_assignment_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_subject_assignment_orgs ON public.user_subject_assignment USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: user_subject user_subject_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_subject_orgs ON public.user_subject USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: users; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

--
-- Name: users users_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_policy ON public.users USING ((organisation_id IN ( WITH RECURSIVE children(id, parent_organisation_id) AS (
         SELECT organisation.id,
            organisation.parent_organisation_id
           FROM public.organisation
          WHERE ((organisation.db_user)::text = CURRENT_USER)
        UNION ALL
         SELECT grand_children.id,
            grand_children.parent_organisation_id
           FROM public.organisation grand_children,
            children
          WHERE (grand_children.parent_organisation_id = children.id)
        )
(
         SELECT children.id
           FROM children
        UNION
        ( WITH RECURSIVE parents(id, parent_organisation_id) AS (
                 SELECT organisation.id,
                    organisation.parent_organisation_id
                   FROM public.organisation
                  WHERE ((organisation.db_user)::text = CURRENT_USER)
                UNION ALL
                 SELECT grand_parents.id,
                    grand_parents.parent_organisation_id
                   FROM public.organisation grand_parents,
                    parents parents_1
                  WHERE (grand_parents.id = parents_1.parent_organisation_id)
                )
         SELECT parents.id
           FROM parents)
) UNION ALL
 SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.parent_organisation_id IS NULL) AND (CURRENT_USER = 'openchs_impl'::name))))) WITH CHECK ((organisation_id IN ( WITH RECURSIVE children(id, parent_organisation_id) AS (
         SELECT organisation.id,
            organisation.parent_organisation_id
           FROM public.organisation
          WHERE ((organisation.db_user)::text = CURRENT_USER)
        UNION ALL
         SELECT grand_children.id,
            grand_children.parent_organisation_id
           FROM public.organisation grand_children,
            children
          WHERE (grand_children.parent_organisation_id = children.id)
        )
 SELECT children.id
   FROM children
UNION ALL
 SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.parent_organisation_id IS NULL) AND (CURRENT_USER = 'openchs_impl'::name)))));


--
-- Name: users users_user; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_user ON public.users USING (((organisation_id IN ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = ANY (ARRAY['openchs'::name, CURRENT_USER])))) OR (id IN ( SELECT account_admin.admin_id
   FROM public.account_admin
  WHERE (account_admin.account_id IN ( SELECT organisation.account_id
           FROM public.organisation
          WHERE ((organisation.db_user)::text = ANY (ARRAY['openchs'::name, CURRENT_USER])))))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id IN ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = ANY (ARRAY['openchs'::name, CURRENT_USER])))));


--
-- Name: video; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.video ENABLE ROW LEVEL SECURITY;

--
-- Name: video video_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY video_orgs ON public.video USING (((organisation_id IN ( SELECT org_ids.id
   FROM public.org_ids
UNION
 SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- Name: video_telemetric; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.video_telemetric ENABLE ROW LEVEL SECURITY;

--
-- Name: video_telemetric video_telemetric_orgs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY video_telemetric_orgs ON public.video_telemetric USING (((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))) OR (organisation_id IN ( SELECT organisation_group_organisation.organisation_id
   FROM public.organisation_group_organisation)))) WITH CHECK ((organisation_id = ( SELECT organisation.id
   FROM public.organisation
  WHERE ((organisation.db_user)::text = CURRENT_USER))));


--
-- PostgreSQL database dump complete
--

\unrestrict mbQK4hFzgbubanh0VeOdKAIisfdgQNaxyxVA6Dn3aRFCxrcEHXL87qwZd5sdwhM

