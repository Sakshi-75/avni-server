--
-- PostgreSQL database dump
--

\restrict wfKXFInJVUcNGCenlpbFd4gvu1hSXeEqATsOIHqodMsSxWFL22czumbnTouDyZ7

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
-- Data for Name: account; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.account (id, name, region) FROM stdin;
1	default	IN
\.


--
-- Data for Name: organisation; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.organisation (id, name, db_user, uuid, parent_organisation_id, is_voided, media_directory, username_suffix, account_id, schema_name, category_id, status_id) FROM stdin;
1	OpenCHS	openchs_impl	3539a906-dfae-4ec3-8fbb-1b08f35c3884	\N	f	openchs	\N	1	openchs_impl	1	1
\.


--
-- Data for Name: organisation_category; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.organisation_category (id, uuid, is_voided, name, created_date_time, last_modified_date_time, created_by_id, last_modified_by_id, version) FROM stdin;
1	71e1bf3b-48fb-4d4f-90f3-71c39e15fbf0	f	Production	2026-03-12 18:32:00.409+05:30	2026-03-12 18:32:00.409+05:30	1	1	1
2	95e89458-c152-4557-9929-85f1a275d6a3	f	UAT	2026-03-12 18:32:00.409+05:30	2026-03-12 18:32:00.409+05:30	1	1	1
3	283af4ea-0024-4440-857f-c8a82328a61d	f	Prototype	2026-03-12 18:32:00.409+05:30	2026-03-12 18:32:00.409+05:30	1	1	1
4	f0b0a48d-8d4b-4d13-8956-c1bc577b4971	f	Temporary	2026-03-12 18:32:00.409+05:30	2026-03-12 18:32:00.409+05:30	1	1	1
5	470ecdab-f7be-4336-a52a-1fa280080168	f	Trial	2026-03-12 18:32:00.409+05:30	2026-03-12 18:32:00.409+05:30	1	1	1
6	d75e667e-b7ea-40dd-8d85-1328943d3b65	f	Training	2026-03-12 18:32:00.409+05:30	2026-03-12 18:32:00.409+05:30	1	1	1
7	27eeb3e7-2396-45ac-ba50-b1b50690bcfc	f	Dev	2026-03-12 18:32:00.409+05:30	2026-03-12 18:32:00.409+05:30	1	1	1
\.


--
-- Data for Name: organisation_config; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.organisation_config (id, uuid, organisation_id, settings, audit_id, version, is_voided, worklist_updation_rule, created_by_id, last_modified_by_id, created_date_time, last_modified_date_time, export_settings) FROM stdin;
1	dc7db211-b61b-4f4d-84d1-383ae84c4c1b	1	{"languages": ["en"]}	85	0	f	\N	1	1	2026-03-12 18:32:00.267+05:30	2026-03-12 18:32:00.267+05:30	\N
\.


--
-- Data for Name: organisation_status; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.organisation_status (id, uuid, is_voided, name, created_date_time, last_modified_date_time, created_by_id, last_modified_by_id, version) FROM stdin;
1	338be2e2-d0e5-4186-b113-b8197ce879c5	f	Live	2026-03-12 18:32:00.413+05:30	2026-03-12 18:32:00.413+05:30	1	1	1
2	7e609db3-ff79-472c-8f28-5b12933faaf5	f	Archived	2026-03-12 18:32:00.413+05:30	2026-03-12 18:32:00.413+05:30	1	1	1
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.users (id, uuid, username, organisation_id, created_by_id, last_modified_by_id, created_date_time, last_modified_date_time, is_voided, catchment_id, is_org_admin, operating_individual_scope, settings, email, phone_number, disabled_in_cognito, name, sync_settings, ignore_sync_settings_in_dea, last_activated_date_time) FROM stdin;
1	5fed2907-df3a-4867-aef5-c87f4c78a31a	admin	\N	1	1	2026-03-12 23:57:10.375963+05:30	2026-03-12 23:57:10.376+05:30	f	\N	f	None	\N	\N	\N	f	admin	{}	f	\N
\.


--
-- Name: account_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.account_id_seq', 1, true);


--
-- Name: organisation_category_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.organisation_category_id_seq', 7, true);


--
-- Name: organisation_config_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.organisation_config_id_seq', 3, true);


--
-- Name: organisation_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.organisation_id_seq', 1, true);


--
-- Name: organisation_status_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.organisation_status_id_seq', 2, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.users_id_seq', 1, true);


--
-- PostgreSQL database dump complete
--

\unrestrict wfKXFInJVUcNGCenlpbFd4gvu1hSXeEqATsOIHqodMsSxWFL22czumbnTouDyZ7

