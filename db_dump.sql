--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: atomfeed; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA atomfeed;


ALTER SCHEMA atomfeed OWNER TO postgres;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: getrgprogramsupplyline(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getrgprogramsupplyline() RETURNS TABLE(snode text, name text, requisitiongroup text)
    LANGUAGE plpgsql
    AS $$
DECLARE
requisitionGroupQuery VARCHAR;
finalQuery            VARCHAR;
ultimateParentRecord  RECORD;
rowRG                 RECORD;
BEGIN
EXECUTE 'CREATE TEMP TABLE rg_supervisory_node (
requisitionGroupId INTEGER,
requisitionGroup TEXT,
supervisoryNodeId INTEGER,
sNode TEXT,
programId INTEGER,
name TEXT,
ultimateParentId INTEGER
) ON COMMIT DROP';
requisitionGroupQuery := 'SELECT RG.id, RG.code || '' '' || RG.name as requisitionGroup, RG.supervisoryNodeId, RGPS.programId, pg.name
FROM requisition_groups AS RG INNER JOIN requisition_group_program_schedules AS RGPS ON RG.id = RGPS.requisitionGroupId
INNER JOIN programs pg ON pg.id=RGPS.programid WHERE pg.active=true AND pg.push=false';
FOR rowRG IN EXECUTE requisitionGroupQuery LOOP
WITH RECURSIVE supervisoryNodesRec(id, sName, parentId, depth, path) AS
(
SELECT
superNode.id,
superNode.code || ' ' || superNode.name :: TEXT AS sName,
superNode.parentId,
1 :: INT                                        AS depth,
superNode.id :: TEXT                            AS path
FROM supervisory_nodes superNode
WHERE id IN (rowRG.supervisoryNodeId)
UNION
SELECT
sn.id,
sn.code || ' ' || sn.name :: TEXT AS sName,
sn.parentId,
snRec.depth + 1                   AS depth,
(snRec.path)
FROM supervisory_nodes sn
JOIN supervisoryNodesRec snRec
ON sn.id = snRec.parentId
)
SELECT
INTO ultimateParentRecord path  AS id,
id    AS ultimateParentId,
sName AS sNode
FROM supervisoryNodesRec
WHERE depth = (SELECT
max(depth)
FROM supervisoryNodesRec);
EXECUTE
'INSERT INTO rg_supervisory_node VALUES (' || rowRG.id || ',' ||
quote_literal(rowRG.requisitionGroup) || ',' || rowRG.supervisoryNodeId ||
',' || quote_literal(ultimateParentRecord.sNode) || ',' || rowRG.programId
|| ',' || quote_literal(rowRG.name) || ',' ||
ultimateParentRecord.ultimateParentId || ')';
END LOOP;
finalQuery := 'SELECT
RGS.snode            AS SupervisoryNode,
RGS.name             AS ProgramName,
RGS.requisitiongroup AS RequisitionGroup
FROM rg_supervisory_node AS RGS
WHERE NOT EXISTS
(SELECT
*
FROM supply_lines
INNER JOIN facilities f
ON f.id = supply_lines.supplyingFacilityId
WHERE supply_lines.supervisorynodeid = RGS.ultimateparentid AND
RGS.programid = supply_lines.programid AND f.enabled = TRUE)
ORDER BY SupervisoryNode, ProgramName, RequisitionGroup';
RETURN QUERY EXECUTE finalQuery;
END;
$$;


ALTER FUNCTION public.getrgprogramsupplyline() OWNER TO postgres;

SET search_path = atomfeed, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: chunking_history; Type: TABLE; Schema: atomfeed; Owner: postgres; Tablespace: 
--

CREATE TABLE chunking_history (
    id integer NOT NULL,
    chunk_length bigint,
    start bigint NOT NULL
);


ALTER TABLE atomfeed.chunking_history OWNER TO postgres;

--
-- Name: chunking_history_id_seq; Type: SEQUENCE; Schema: atomfeed; Owner: postgres
--

CREATE SEQUENCE chunking_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE atomfeed.chunking_history_id_seq OWNER TO postgres;

--
-- Name: chunking_history_id_seq; Type: SEQUENCE OWNED BY; Schema: atomfeed; Owner: postgres
--

ALTER SEQUENCE chunking_history_id_seq OWNED BY chunking_history.id;


--
-- Name: event_records; Type: TABLE; Schema: atomfeed; Owner: postgres; Tablespace: 
--

CREATE TABLE event_records (
    id integer NOT NULL,
    uuid character varying(40),
    title character varying(255),
    "timestamp" timestamp without time zone DEFAULT now(),
    uri character varying(255),
    object character varying(5000),
    category character varying(255)
);


ALTER TABLE atomfeed.event_records OWNER TO postgres;

--
-- Name: event_records_id_seq; Type: SEQUENCE; Schema: atomfeed; Owner: postgres
--

CREATE SEQUENCE event_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE atomfeed.event_records_id_seq OWNER TO postgres;

--
-- Name: event_records_id_seq; Type: SEQUENCE OWNED BY; Schema: atomfeed; Owner: postgres
--

ALTER SEQUENCE event_records_id_seq OWNED BY event_records.id;


SET search_path = public, pg_catalog;

--
-- Name: adult_coverage_opened_vial_line_items; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE adult_coverage_opened_vial_line_items (
    id integer NOT NULL,
    facilityvisitid integer NOT NULL,
    productvialname character varying(255) NOT NULL,
    openedvials integer,
    packsize integer,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.adult_coverage_opened_vial_line_items OWNER TO postgres;

--
-- Name: adult_coverage_opened_vial_line_items_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE adult_coverage_opened_vial_line_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.adult_coverage_opened_vial_line_items_id_seq OWNER TO postgres;

--
-- Name: adult_coverage_opened_vial_line_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE adult_coverage_opened_vial_line_items_id_seq OWNED BY adult_coverage_opened_vial_line_items.id;


--
-- Name: budget_configuration; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE budget_configuration (
    headerinfile boolean NOT NULL,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.budget_configuration OWNER TO postgres;

--
-- Name: budget_file_columns; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE budget_file_columns (
    id integer NOT NULL,
    name character varying(150) NOT NULL,
    datafieldlabel character varying(150),
    "position" integer,
    include boolean NOT NULL,
    mandatory boolean NOT NULL,
    datepattern character varying(25),
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.budget_file_columns OWNER TO postgres;

--
-- Name: budget_file_columns_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE budget_file_columns_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.budget_file_columns_id_seq OWNER TO postgres;

--
-- Name: budget_file_columns_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE budget_file_columns_id_seq OWNED BY budget_file_columns.id;


--
-- Name: budget_file_info; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE budget_file_info (
    id integer NOT NULL,
    filename character varying(200) NOT NULL,
    processingerror boolean DEFAULT false NOT NULL,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.budget_file_info OWNER TO postgres;

--
-- Name: budget_file_info_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE budget_file_info_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.budget_file_info_id_seq OWNER TO postgres;

--
-- Name: budget_file_info_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE budget_file_info_id_seq OWNED BY budget_file_info.id;


--
-- Name: budget_line_items; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE budget_line_items (
    id integer NOT NULL,
    periodid integer NOT NULL,
    budgetfileid integer NOT NULL,
    perioddate timestamp without time zone NOT NULL,
    allocatedbudget numeric(20,2) NOT NULL,
    notes character varying(255),
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now(),
    facilityid integer NOT NULL,
    programid integer NOT NULL
);


ALTER TABLE public.budget_line_items OWNER TO postgres;

--
-- Name: budget_line_items_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE budget_line_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.budget_line_items_id_seq OWNER TO postgres;

--
-- Name: budget_line_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE budget_line_items_id_seq OWNED BY budget_line_items.id;


--
-- Name: child_coverage_opened_vial_line_items; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE child_coverage_opened_vial_line_items (
    id integer NOT NULL,
    facilityvisitid integer NOT NULL,
    productvialname character varying(255) NOT NULL,
    openedvials integer,
    packsize integer,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.child_coverage_opened_vial_line_items OWNER TO postgres;

--
-- Name: comments; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE comments (
    id integer NOT NULL,
    rnrid integer NOT NULL,
    commenttext character varying(250) NOT NULL,
    createdby integer NOT NULL,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer NOT NULL,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.comments OWNER TO postgres;

--
-- Name: comments_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE comments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.comments_id_seq OWNER TO postgres;

--
-- Name: comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE comments_id_seq OWNED BY comments.id;


--
-- Name: configurable_rnr_options; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE configurable_rnr_options (
    id integer NOT NULL,
    name character varying(200) NOT NULL,
    label character varying(200) NOT NULL,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.configurable_rnr_options OWNER TO postgres;

--
-- Name: configurable_rnr_options_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE configurable_rnr_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.configurable_rnr_options_id_seq OWNER TO postgres;

--
-- Name: configurable_rnr_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE configurable_rnr_options_id_seq OWNED BY configurable_rnr_options.id;


--
-- Name: coverage_product_vials; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE coverage_product_vials (
    id integer NOT NULL,
    vial character varying(255) NOT NULL,
    productcode character varying(50) NOT NULL,
    childcoverage boolean NOT NULL
);


ALTER TABLE public.coverage_product_vials OWNER TO postgres;

--
-- Name: coverage_product_vials_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE coverage_product_vials_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.coverage_product_vials_id_seq OWNER TO postgres;

--
-- Name: coverage_product_vials_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE coverage_product_vials_id_seq OWNED BY coverage_product_vials.id;


--
-- Name: coverage_target_group_products; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE coverage_target_group_products (
    id integer NOT NULL,
    targetgroupentity character varying(255) NOT NULL,
    productcode character varying(50) NOT NULL,
    childcoverage boolean NOT NULL
);


ALTER TABLE public.coverage_target_group_products OWNER TO postgres;

--
-- Name: coverage_vaccination_products_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE coverage_vaccination_products_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.coverage_vaccination_products_id_seq OWNER TO postgres;

--
-- Name: coverage_vaccination_products_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE coverage_vaccination_products_id_seq OWNED BY coverage_target_group_products.id;


--
-- Name: delivery_zone_members; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE delivery_zone_members (
    id integer NOT NULL,
    deliveryzoneid integer NOT NULL,
    facilityid integer NOT NULL,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.delivery_zone_members OWNER TO postgres;

--
-- Name: delivery_zone_members_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE delivery_zone_members_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.delivery_zone_members_id_seq OWNER TO postgres;

--
-- Name: delivery_zone_members_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE delivery_zone_members_id_seq OWNED BY delivery_zone_members.id;


--
-- Name: delivery_zone_program_schedules; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE delivery_zone_program_schedules (
    id integer NOT NULL,
    deliveryzoneid integer NOT NULL,
    programid integer NOT NULL,
    scheduleid integer NOT NULL,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.delivery_zone_program_schedules OWNER TO postgres;

--
-- Name: delivery_zone_program_schedules_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE delivery_zone_program_schedules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.delivery_zone_program_schedules_id_seq OWNER TO postgres;

--
-- Name: delivery_zone_program_schedules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE delivery_zone_program_schedules_id_seq OWNED BY delivery_zone_program_schedules.id;


--
-- Name: delivery_zone_warehouses; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE delivery_zone_warehouses (
    id integer NOT NULL,
    deliveryzoneid integer NOT NULL,
    warehouseid integer NOT NULL,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.delivery_zone_warehouses OWNER TO postgres;

--
-- Name: delivery_zone_warehouses_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE delivery_zone_warehouses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.delivery_zone_warehouses_id_seq OWNER TO postgres;

--
-- Name: delivery_zone_warehouses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE delivery_zone_warehouses_id_seq OWNED BY delivery_zone_warehouses.id;


--
-- Name: delivery_zones; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE delivery_zones (
    id integer NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.delivery_zones OWNER TO postgres;

--
-- Name: delivery_zones_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE delivery_zones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.delivery_zones_id_seq OWNER TO postgres;

--
-- Name: delivery_zones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE delivery_zones_id_seq OWNED BY delivery_zones.id;


--
-- Name: refrigerator_readings; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE refrigerator_readings (
    id integer NOT NULL,
    temperature numeric(4,1),
    functioningcorrectly character varying(1),
    lowalarmevents numeric(3,0),
    highalarmevents numeric(3,0),
    problemsincelasttime character varying(1),
    notes character varying(255),
    refrigeratorid integer NOT NULL,
    refrigeratorserialnumber character varying(30) NOT NULL,
    refrigeratorbrand character varying(20),
    refrigeratormodel character varying(20),
    facilityvisitid integer NOT NULL,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.refrigerator_readings OWNER TO postgres;

--
-- Name: distribution_refrigerator_readings_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE distribution_refrigerator_readings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.distribution_refrigerator_readings_id_seq OWNER TO postgres;

--
-- Name: distribution_refrigerator_readings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE distribution_refrigerator_readings_id_seq OWNED BY refrigerator_readings.id;


--
-- Name: distributions; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE distributions (
    id integer NOT NULL,
    deliveryzoneid integer NOT NULL,
    programid integer NOT NULL,
    periodid integer NOT NULL,
    status character varying(50),
    createdby integer NOT NULL,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer NOT NULL,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.distributions OWNER TO postgres;

--
-- Name: distributions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE distributions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.distributions_id_seq OWNER TO postgres;

--
-- Name: distributions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE distributions_id_seq OWNED BY distributions.id;


--
-- Name: dosage_units; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE dosage_units (
    id integer NOT NULL,
    code character varying(20),
    displayorder integer,
    createddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.dosage_units OWNER TO postgres;

--
-- Name: dosage_units_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE dosage_units_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dosage_units_id_seq OWNER TO postgres;

--
-- Name: dosage_units_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE dosage_units_id_seq OWNED BY dosage_units.id;


--
-- Name: email_notifications; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE email_notifications (
    id integer NOT NULL,
    receiver character varying(250) NOT NULL,
    subject text,
    content text,
    sent boolean DEFAULT false NOT NULL,
    createddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.email_notifications OWNER TO postgres;

--
-- Name: email_notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE email_notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.email_notifications_id_seq OWNER TO postgres;

--
-- Name: email_notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE email_notifications_id_seq OWNED BY email_notifications.id;


--
-- Name: epi_inventory_line_items; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE epi_inventory_line_items (
    id integer NOT NULL,
    productname character varying(250),
    idealquantity numeric,
    existingquantity numeric(7,0),
    spoiledquantity numeric(7,0),
    deliveredquantity numeric(7,0),
    facilityvisitid integer NOT NULL,
    productcode character varying(50) NOT NULL,
    productdisplayorder integer,
    programproductid integer NOT NULL,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.epi_inventory_line_items OWNER TO postgres;

--
-- Name: epi_inventory_line_items_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE epi_inventory_line_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.epi_inventory_line_items_id_seq OWNER TO postgres;

--
-- Name: epi_inventory_line_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE epi_inventory_line_items_id_seq OWNED BY epi_inventory_line_items.id;


--
-- Name: epi_use_line_items; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE epi_use_line_items (
    id integer NOT NULL,
    productgroupid integer,
    productgroupname character varying(250),
    stockatfirstofmonth numeric(7,0),
    received numeric(7,0),
    distributed numeric(7,0),
    loss numeric(7,0),
    stockatendofmonth numeric(7,0),
    expirationdate character varying(10),
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now(),
    facilityvisitid integer NOT NULL
);


ALTER TABLE public.epi_use_line_items OWNER TO postgres;

--
-- Name: epi_use_line_items_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE epi_use_line_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.epi_use_line_items_id_seq OWNER TO postgres;

--
-- Name: epi_use_line_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE epi_use_line_items_id_seq OWNED BY epi_use_line_items.id;


--
-- Name: facilities; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE facilities (
    id integer NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    gln character varying(30),
    mainphone character varying(20),
    fax character varying(20),
    address1 character varying(50),
    address2 character varying(50),
    geographiczoneid integer NOT NULL,
    typeid integer NOT NULL,
    catchmentpopulation integer,
    latitude numeric(8,5),
    longitude numeric(8,5),
    altitude numeric(8,4),
    operatedbyid integer,
    coldstoragegrosscapacity numeric(8,4),
    coldstoragenetcapacity numeric(8,4),
    suppliesothers boolean,
    sdp boolean NOT NULL,
    online boolean,
    satellite boolean,
    parentfacilityid integer,
    haselectricity boolean,
    haselectronicscc boolean,
    haselectronicdar boolean,
    active boolean NOT NULL,
    golivedate date NOT NULL,
    godowndate date,
    comment text,
    enabled boolean NOT NULL,
    virtualfacility boolean NOT NULL,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.facilities OWNER TO postgres;

--
-- Name: facilities_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE facilities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.facilities_id_seq OWNER TO postgres;

--
-- Name: facilities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE facilities_id_seq OWNED BY facilities.id;


--
-- Name: facility_approved_products; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE facility_approved_products (
    id integer NOT NULL,
    facilitytypeid integer NOT NULL,
    programproductid integer NOT NULL,
    maxmonthsofstock numeric(4,2) NOT NULL,
    minmonthsofstock numeric(4,2),
    eop numeric(4,2),
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.facility_approved_products OWNER TO postgres;

--
-- Name: facility_approved_products_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE facility_approved_products_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.facility_approved_products_id_seq OWNER TO postgres;

--
-- Name: facility_approved_products_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE facility_approved_products_id_seq OWNED BY facility_approved_products.id;


--
-- Name: facility_ftp_details; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE facility_ftp_details (
    id integer NOT NULL,
    facilityid integer NOT NULL,
    serverhost character varying(100) NOT NULL,
    serverport character varying(10) NOT NULL,
    username character varying(100) NOT NULL,
    password character varying(50) NOT NULL,
    localfolderpath character varying(255) NOT NULL,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.facility_ftp_details OWNER TO postgres;

--
-- Name: facility_ftp_details_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE facility_ftp_details_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.facility_ftp_details_id_seq OWNER TO postgres;

--
-- Name: facility_ftp_details_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE facility_ftp_details_id_seq OWNED BY facility_ftp_details.id;


--
-- Name: facility_operators; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE facility_operators (
    id integer NOT NULL,
    code character varying NOT NULL,
    text character varying(20),
    displayorder integer,
    createddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.facility_operators OWNER TO postgres;

--
-- Name: facility_operators_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE facility_operators_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.facility_operators_id_seq OWNER TO postgres;

--
-- Name: facility_operators_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE facility_operators_id_seq OWNED BY facility_operators.id;


--
-- Name: facility_program_products; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE facility_program_products (
    id integer NOT NULL,
    facilityid integer NOT NULL,
    programproductid integer NOT NULL,
    overriddenisa integer,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.facility_program_products OWNER TO postgres;

--
-- Name: facility_program_products_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE facility_program_products_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.facility_program_products_id_seq OWNER TO postgres;

--
-- Name: facility_program_products_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE facility_program_products_id_seq OWNED BY facility_program_products.id;


--
-- Name: facility_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE facility_types (
    id integer NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(30) NOT NULL,
    description character varying(250),
    levelid integer,
    nominalmaxmonth integer NOT NULL,
    nominaleop numeric(4,2) NOT NULL,
    displayorder integer,
    active boolean,
    createddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.facility_types OWNER TO postgres;

--
-- Name: facility_types_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE facility_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.facility_types_id_seq OWNER TO postgres;

--
-- Name: facility_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE facility_types_id_seq OWNED BY facility_types.id;


--
-- Name: facility_visits; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE facility_visits (
    id integer NOT NULL,
    distributionid integer,
    facilityid integer,
    confirmedbyname character varying(50),
    confirmedbytitle character varying(50),
    verifiedbyname character varying(50),
    verifiedbytitle character varying(50),
    observations text,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    synced boolean DEFAULT false,
    modifieddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    visited boolean,
    visitdate timestamp without time zone,
    vehicleid character varying(20),
    facilitycatchmentpopulation integer,
    reasonfornotvisiting character varying(50),
    otherreasondescription character varying(255)
);


ALTER TABLE public.facility_visits OWNER TO postgres;

--
-- Name: facility_visits_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE facility_visits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.facility_visits_id_seq OWNER TO postgres;

--
-- Name: facility_visits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE facility_visits_id_seq OWNED BY facility_visits.id;


--
-- Name: fulfillment_role_assignments; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE fulfillment_role_assignments (
    userid integer NOT NULL,
    roleid integer NOT NULL,
    facilityid integer NOT NULL,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.fulfillment_role_assignments OWNER TO postgres;

--
-- Name: full_coverages; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE full_coverages (
    id integer NOT NULL,
    femalehealthcenter numeric(7,0),
    femaleoutreach numeric(7,0),
    maleoutreach numeric(7,0),
    malehealthcenter numeric(7,0),
    facilityvisitid integer NOT NULL,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.full_coverages OWNER TO postgres;

--
-- Name: geographic_levels; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE geographic_levels (
    id integer NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(250) NOT NULL,
    levelnumber integer NOT NULL,
    createddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.geographic_levels OWNER TO postgres;

--
-- Name: geographic_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE geographic_levels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.geographic_levels_id_seq OWNER TO postgres;

--
-- Name: geographic_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE geographic_levels_id_seq OWNED BY geographic_levels.id;


--
-- Name: geographic_zones; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE geographic_zones (
    id integer NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(250) NOT NULL,
    levelid integer NOT NULL,
    parentid integer,
    catchmentpopulation integer,
    latitude numeric(8,5),
    longitude numeric(8,5),
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.geographic_zones OWNER TO postgres;

--
-- Name: geographic_zones_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE geographic_zones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.geographic_zones_id_seq OWNER TO postgres;

--
-- Name: geographic_zones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE geographic_zones_id_seq OWNED BY geographic_zones.id;


--
-- Name: losses_adjustments_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE losses_adjustments_types (
    name character varying(50) NOT NULL,
    description character varying(100) NOT NULL,
    additive boolean,
    displayorder integer,
    createddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.losses_adjustments_types OWNER TO postgres;

--
-- Name: master_regimen_columns; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE master_regimen_columns (
    name character varying(100) NOT NULL,
    label character varying(100) NOT NULL,
    visible boolean NOT NULL,
    datatype character varying(50) NOT NULL
);


ALTER TABLE public.master_regimen_columns OWNER TO postgres;

--
-- Name: master_rnr_column_options; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE master_rnr_column_options (
    id integer NOT NULL,
    masterrnrcolumnid integer,
    rnroptionid integer,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.master_rnr_column_options OWNER TO postgres;

--
-- Name: master_rnr_column_options_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE master_rnr_column_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.master_rnr_column_options_id_seq OWNER TO postgres;

--
-- Name: master_rnr_column_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE master_rnr_column_options_id_seq OWNED BY master_rnr_column_options.id;


--
-- Name: master_rnr_columns; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE master_rnr_columns (
    id integer NOT NULL,
    name character varying(200) NOT NULL,
    "position" integer NOT NULL,
    source character varying(1) NOT NULL,
    sourceconfigurable boolean NOT NULL,
    label character varying(200),
    formula character varying(200),
    indicator character varying(50) NOT NULL,
    used boolean NOT NULL,
    visible boolean NOT NULL,
    mandatory boolean NOT NULL,
    description character varying(250),
    createddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.master_rnr_columns OWNER TO postgres;

--
-- Name: master_rnr_columns_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE master_rnr_columns_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.master_rnr_columns_id_seq OWNER TO postgres;

--
-- Name: master_rnr_columns_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE master_rnr_columns_id_seq OWNED BY master_rnr_columns.id;


--
-- Name: opened_vial_line_items_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE opened_vial_line_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.opened_vial_line_items_id_seq OWNER TO postgres;

--
-- Name: opened_vial_line_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE opened_vial_line_items_id_seq OWNED BY child_coverage_opened_vial_line_items.id;


--
-- Name: order_configuration; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE order_configuration (
    fileprefix character varying(8),
    headerinfile boolean NOT NULL,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.order_configuration OWNER TO postgres;

--
-- Name: order_file_columns; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE order_file_columns (
    id integer NOT NULL,
    datafieldlabel character varying(50),
    nested character varying(50),
    keypath character varying(50),
    includeinorderfile boolean DEFAULT true NOT NULL,
    columnlabel character varying(50),
    format character varying(20),
    "position" integer NOT NULL,
    openlmisfield boolean DEFAULT false NOT NULL,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.order_file_columns OWNER TO postgres;

--
-- Name: order_file_columns_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE order_file_columns_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.order_file_columns_id_seq OWNER TO postgres;

--
-- Name: order_file_columns_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE order_file_columns_id_seq OWNED BY order_file_columns.id;


--
-- Name: order_number_configuration; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE order_number_configuration (
    ordernumberprefix character varying(8),
    includeordernumberprefix boolean,
    includeprogramcode boolean,
    includesequencecode boolean,
    includernrtypesuffix boolean
);


ALTER TABLE public.order_number_configuration OWNER TO postgres;

--
-- Name: orders; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE orders (
    id integer NOT NULL,
    shipmentid integer,
    status character varying(20) NOT NULL,
    ftpcomment character varying(50),
    supplylineid integer,
    createdby integer NOT NULL,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer NOT NULL,
    modifieddate timestamp without time zone DEFAULT now(),
    ordernumber character varying(100) NOT NULL
);


ALTER TABLE public.orders OWNER TO postgres;

--
-- Name: pod; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE pod (
    id integer NOT NULL,
    orderid integer NOT NULL,
    receiveddate timestamp without time zone DEFAULT now(),
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now(),
    facilityid integer NOT NULL,
    programid integer NOT NULL,
    periodid integer NOT NULL,
    deliveredby character varying(100),
    receivedby character varying(100),
    ordernumber character varying(100) NOT NULL
);


ALTER TABLE public.pod OWNER TO postgres;

--
-- Name: pod_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE pod_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pod_id_seq OWNER TO postgres;

--
-- Name: pod_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE pod_id_seq OWNED BY pod.id;


--
-- Name: pod_line_items; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE pod_line_items (
    id integer NOT NULL,
    podid integer NOT NULL,
    productcode character varying(50) NOT NULL,
    quantityreceived integer,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now(),
    productname character varying(250),
    dispensingunit character varying(20),
    packstoship integer,
    quantityshipped integer,
    notes character varying(250),
    fullsupply boolean,
    productcategory character varying(100),
    productcategorydisplayorder integer,
    productdisplayorder integer,
    quantityreturned integer,
    replacedproductcode character varying(50)
);


ALTER TABLE public.pod_line_items OWNER TO postgres;

--
-- Name: pod_line_items_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE pod_line_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pod_line_items_id_seq OWNER TO postgres;

--
-- Name: pod_line_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE pod_line_items_id_seq OWNED BY pod_line_items.id;


--
-- Name: processing_periods; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE processing_periods (
    id integer NOT NULL,
    scheduleid integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    startdate timestamp without time zone NOT NULL,
    enddate timestamp without time zone NOT NULL,
    numberofmonths integer,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.processing_periods OWNER TO postgres;

--
-- Name: processing_periods_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE processing_periods_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.processing_periods_id_seq OWNER TO postgres;

--
-- Name: processing_periods_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE processing_periods_id_seq OWNED BY processing_periods.id;


--
-- Name: processing_schedules; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE processing_schedules (
    id integer NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.processing_schedules OWNER TO postgres;

--
-- Name: processing_schedules_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE processing_schedules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.processing_schedules_id_seq OWNER TO postgres;

--
-- Name: processing_schedules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE processing_schedules_id_seq OWNED BY processing_schedules.id;


--
-- Name: product_categories; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE product_categories (
    id integer NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(100) NOT NULL,
    displayorder integer NOT NULL,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.product_categories OWNER TO postgres;

--
-- Name: product_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE product_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.product_categories_id_seq OWNER TO postgres;

--
-- Name: product_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE product_categories_id_seq OWNED BY product_categories.id;


--
-- Name: product_forms; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE product_forms (
    id integer NOT NULL,
    code character varying(20),
    displayorder integer,
    createddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.product_forms OWNER TO postgres;

--
-- Name: product_forms_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE product_forms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.product_forms_id_seq OWNER TO postgres;

--
-- Name: product_forms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE product_forms_id_seq OWNED BY product_forms.id;


--
-- Name: product_groups; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE product_groups (
    id integer NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(250) NOT NULL,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.product_groups OWNER TO postgres;

--
-- Name: product_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE product_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.product_groups_id_seq OWNER TO postgres;

--
-- Name: product_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE product_groups_id_seq OWNED BY product_groups.id;


--
-- Name: products; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE products (
    id integer NOT NULL,
    code character varying(50) NOT NULL,
    alternateitemcode character varying(20),
    manufacturer character varying(100),
    manufacturercode character varying(30),
    manufacturerbarcode character varying(20),
    mohbarcode character varying(20),
    gtin character varying(20),
    type character varying(100),
    primaryname character varying(150) NOT NULL,
    fullname character varying(250),
    genericname character varying(100),
    alternatename character varying(100),
    description character varying(250),
    strength character varying(14),
    formid integer,
    dosageunitid integer,
    productgroupid integer,
    dispensingunit character varying(20) NOT NULL,
    dosesperdispensingunit smallint NOT NULL,
    packsize smallint NOT NULL,
    alternatepacksize smallint,
    storerefrigerated boolean,
    storeroomtemperature boolean,
    hazardous boolean,
    flammable boolean,
    controlledsubstance boolean,
    lightsensitive boolean,
    approvedbywho boolean,
    contraceptivecyp numeric(8,4),
    packlength numeric(8,4),
    packwidth numeric(8,4),
    packheight numeric(8,4),
    packweight numeric(8,4),
    packspercarton smallint,
    cartonlength numeric(8,4),
    cartonwidth numeric(8,4),
    cartonheight numeric(8,4),
    cartonsperpallet smallint,
    expectedshelflife smallint,
    specialstorageinstructions text,
    specialtransportinstructions text,
    active boolean NOT NULL,
    fullsupply boolean NOT NULL,
    tracer boolean NOT NULL,
    roundtozero boolean NOT NULL,
    archived boolean,
    packroundingthreshold smallint NOT NULL,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.products OWNER TO postgres;

--
-- Name: products_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE products_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.products_id_seq OWNER TO postgres;

--
-- Name: products_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE products_id_seq OWNED BY products.id;


--
-- Name: program_product_isa; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE program_product_isa (
    id integer NOT NULL,
    whoratio numeric(6,3) NOT NULL,
    dosesperyear integer NOT NULL,
    wastagefactor numeric(6,3) NOT NULL,
    programproductid integer NOT NULL,
    bufferpercentage numeric(6,3) NOT NULL,
    minimumvalue integer,
    maximumvalue integer,
    adjustmentvalue integer NOT NULL,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.program_product_isa OWNER TO postgres;

--
-- Name: program_product_isa_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE program_product_isa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.program_product_isa_id_seq OWNER TO postgres;

--
-- Name: program_product_isa_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE program_product_isa_id_seq OWNED BY program_product_isa.id;


--
-- Name: program_product_price_history; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE program_product_price_history (
    id integer NOT NULL,
    programproductid integer NOT NULL,
    price numeric(20,2) DEFAULT 0,
    priceperdosage numeric(20,2) DEFAULT 0,
    source character varying(50),
    startdate timestamp without time zone DEFAULT now(),
    enddate timestamp without time zone DEFAULT now(),
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.program_product_price_history OWNER TO postgres;

--
-- Name: program_product_price_history_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE program_product_price_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.program_product_price_history_id_seq OWNER TO postgres;

--
-- Name: program_product_price_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE program_product_price_history_id_seq OWNED BY program_product_price_history.id;


--
-- Name: program_products; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE program_products (
    id integer NOT NULL,
    programid integer NOT NULL,
    productid integer NOT NULL,
    dosespermonth integer NOT NULL,
    active boolean NOT NULL,
    currentprice numeric(20,2) DEFAULT 0,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now(),
    productcategoryid integer NOT NULL,
    displayorder integer
);


ALTER TABLE public.program_products OWNER TO postgres;

--
-- Name: program_products_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE program_products_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.program_products_id_seq OWNER TO postgres;

--
-- Name: program_products_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE program_products_id_seq OWNED BY program_products.id;


--
-- Name: program_regimen_columns; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE program_regimen_columns (
    id integer NOT NULL,
    programid integer NOT NULL,
    name character varying(100) NOT NULL,
    label character varying(100) NOT NULL,
    visible boolean NOT NULL,
    datatype character varying(50) NOT NULL,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.program_regimen_columns OWNER TO postgres;

--
-- Name: program_regimen_columns_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE program_regimen_columns_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.program_regimen_columns_id_seq OWNER TO postgres;

--
-- Name: program_regimen_columns_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE program_regimen_columns_id_seq OWNED BY program_regimen_columns.id;


--
-- Name: program_rnr_columns; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE program_rnr_columns (
    id integer NOT NULL,
    mastercolumnid integer NOT NULL,
    programid integer NOT NULL,
    label character varying(200) NOT NULL,
    visible boolean NOT NULL,
    "position" integer NOT NULL,
    source character varying(1),
    formulavalidationrequired boolean,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now(),
    rnroptionid integer
);


ALTER TABLE public.program_rnr_columns OWNER TO postgres;

--
-- Name: program_rnr_columns_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE program_rnr_columns_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.program_rnr_columns_id_seq OWNER TO postgres;

--
-- Name: program_rnr_columns_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE program_rnr_columns_id_seq OWNED BY program_rnr_columns.id;


--
-- Name: programs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE programs (
    id integer NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(50),
    description character varying(50),
    active boolean,
    templateconfigured boolean,
    regimentemplateconfigured boolean,
    budgetingapplies boolean DEFAULT false NOT NULL,
    usesdar boolean,
    push boolean DEFAULT false,
    sendfeed boolean DEFAULT false,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.programs OWNER TO postgres;

--
-- Name: programs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE programs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.programs_id_seq OWNER TO postgres;

--
-- Name: programs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE programs_id_seq OWNED BY programs.id;


--
-- Name: programs_supported; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE programs_supported (
    id integer NOT NULL,
    facilityid integer NOT NULL,
    programid integer NOT NULL,
    startdate timestamp without time zone,
    active boolean NOT NULL,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.programs_supported OWNER TO postgres;

--
-- Name: programs_supported_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE programs_supported_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.programs_supported_id_seq OWNER TO postgres;

--
-- Name: programs_supported_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE programs_supported_id_seq OWNED BY programs_supported.id;


--
-- Name: refrigerator_problems; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE refrigerator_problems (
    id integer NOT NULL,
    readingid integer,
    operatorerror boolean DEFAULT false,
    burnerproblem boolean DEFAULT false,
    gasleakage boolean DEFAULT false,
    egpfault boolean DEFAULT false,
    thermostatsetting boolean DEFAULT false,
    other boolean DEFAULT false,
    otherproblemexplanation character varying(255),
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.refrigerator_problems OWNER TO postgres;

--
-- Name: refrigerator_problems_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE refrigerator_problems_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.refrigerator_problems_id_seq OWNER TO postgres;

--
-- Name: refrigerator_problems_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE refrigerator_problems_id_seq OWNED BY refrigerator_problems.id;


--
-- Name: refrigerators; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE refrigerators (
    id integer NOT NULL,
    brand character varying(20),
    model character varying(20),
    serialnumber character varying(30) NOT NULL,
    facilityid integer,
    createdby integer NOT NULL,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer NOT NULL,
    modifieddate timestamp without time zone DEFAULT now(),
    enabled boolean DEFAULT true
);


ALTER TABLE public.refrigerators OWNER TO postgres;

--
-- Name: refrigerators_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE refrigerators_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.refrigerators_id_seq OWNER TO postgres;

--
-- Name: refrigerators_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE refrigerators_id_seq OWNED BY refrigerators.id;


--
-- Name: regimen_categories; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE regimen_categories (
    id integer NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(50) NOT NULL,
    displayorder integer NOT NULL,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.regimen_categories OWNER TO postgres;

--
-- Name: regimen_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE regimen_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.regimen_categories_id_seq OWNER TO postgres;

--
-- Name: regimen_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE regimen_categories_id_seq OWNED BY regimen_categories.id;


--
-- Name: regimen_line_items; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE regimen_line_items (
    id integer NOT NULL,
    code character varying(50),
    name character varying(250),
    regimendisplayorder integer,
    regimencategory character varying(50),
    regimencategorydisplayorder integer,
    rnrid integer NOT NULL,
    patientsontreatment integer,
    patientstoinitiatetreatment integer,
    patientsstoppedtreatment integer,
    remarks character varying(255),
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.regimen_line_items OWNER TO postgres;

--
-- Name: regimen_line_items_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE regimen_line_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.regimen_line_items_id_seq OWNER TO postgres;

--
-- Name: regimen_line_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE regimen_line_items_id_seq OWNED BY regimen_line_items.id;


--
-- Name: regimens; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE regimens (
    id integer NOT NULL,
    programid integer NOT NULL,
    categoryid integer NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(50) NOT NULL,
    active boolean,
    displayorder integer NOT NULL,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.regimens OWNER TO postgres;

--
-- Name: regimens_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE regimens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.regimens_id_seq OWNER TO postgres;

--
-- Name: regimens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE regimens_id_seq OWNED BY regimens.id;


--
-- Name: report_rights; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE report_rights (
    id integer NOT NULL,
    templateid integer NOT NULL,
    rightname character varying NOT NULL
);


ALTER TABLE public.report_rights OWNER TO postgres;

--
-- Name: report_rights_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE report_rights_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.report_rights_id_seq OWNER TO postgres;

--
-- Name: report_rights_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE report_rights_id_seq OWNED BY report_rights.id;


--
-- Name: templates; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE templates (
    id integer NOT NULL,
    name character varying NOT NULL,
    data bytea NOT NULL,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    type character varying NOT NULL,
    description character varying(500)
);


ALTER TABLE public.templates OWNER TO postgres;

--
-- Name: report_templates_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE report_templates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.report_templates_id_seq OWNER TO postgres;

--
-- Name: report_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE report_templates_id_seq OWNED BY templates.id;


--
-- Name: requisition_group_members; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE requisition_group_members (
    id integer NOT NULL,
    requisitiongroupid integer NOT NULL,
    facilityid integer NOT NULL,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.requisition_group_members OWNER TO postgres;

--
-- Name: requisition_group_members_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE requisition_group_members_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.requisition_group_members_id_seq OWNER TO postgres;

--
-- Name: requisition_group_members_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE requisition_group_members_id_seq OWNED BY requisition_group_members.id;


--
-- Name: requisition_group_program_schedules; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE requisition_group_program_schedules (
    id integer NOT NULL,
    requisitiongroupid integer NOT NULL,
    programid integer NOT NULL,
    scheduleid integer NOT NULL,
    directdelivery boolean NOT NULL,
    dropofffacilityid integer,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.requisition_group_program_schedules OWNER TO postgres;

--
-- Name: requisition_group_program_schedules_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE requisition_group_program_schedules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.requisition_group_program_schedules_id_seq OWNER TO postgres;

--
-- Name: requisition_group_program_schedules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE requisition_group_program_schedules_id_seq OWNED BY requisition_group_program_schedules.id;


--
-- Name: requisition_groups; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE requisition_groups (
    id integer NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    supervisorynodeid integer,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.requisition_groups OWNER TO postgres;

--
-- Name: requisition_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE requisition_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.requisition_groups_id_seq OWNER TO postgres;

--
-- Name: requisition_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE requisition_groups_id_seq OWNED BY requisition_groups.id;


--
-- Name: requisition_line_item_losses_adjustments; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE requisition_line_item_losses_adjustments (
    requisitionlineitemid integer NOT NULL,
    type character varying(250) NOT NULL,
    quantity integer,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.requisition_line_item_losses_adjustments OWNER TO postgres;

--
-- Name: requisition_line_items; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE requisition_line_items (
    id integer NOT NULL,
    rnrid integer NOT NULL,
    productcode character varying(50) NOT NULL,
    product character varying(250),
    productdisplayorder integer,
    productcategory character varying(100),
    productcategorydisplayorder integer,
    dispensingunit character varying(20) NOT NULL,
    beginningbalance integer,
    quantityreceived integer,
    quantitydispensed integer,
    stockinhand integer,
    quantityrequested integer,
    reasonforrequestedquantity text,
    calculatedorderquantity integer,
    quantityapproved integer,
    totallossesandadjustments integer,
    newpatientcount integer,
    stockoutdays integer,
    normalizedconsumption integer,
    amc integer,
    maxmonthsofstock numeric(4,2) NOT NULL,
    maxstockquantity integer,
    packstoship integer,
    price numeric(15,4),
    expirationdate character varying(10),
    remarks text,
    dosespermonth integer NOT NULL,
    dosesperdispensingunit integer NOT NULL,
    packsize smallint NOT NULL,
    roundtozero boolean,
    packroundingthreshold integer,
    fullsupply boolean NOT NULL,
    skipped boolean DEFAULT false NOT NULL,
    reportingdays integer,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now(),
    previousnormalizedconsumptions character varying(25) DEFAULT '[]'::character varying,
    previousstockinhand integer,
    periodnormalizedconsumption integer
);


ALTER TABLE public.requisition_line_items OWNER TO postgres;

--
-- Name: requisition_line_items_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE requisition_line_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.requisition_line_items_id_seq OWNER TO postgres;

--
-- Name: requisition_line_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE requisition_line_items_id_seq OWNED BY requisition_line_items.id;


--
-- Name: requisition_status_changes; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE requisition_status_changes (
    id integer NOT NULL,
    rnrid integer NOT NULL,
    status character varying(20) NOT NULL,
    createdby integer NOT NULL,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer NOT NULL,
    modifieddate timestamp without time zone DEFAULT now(),
    username character varying(100)
);


ALTER TABLE public.requisition_status_changes OWNER TO postgres;

--
-- Name: requisition_status_changes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE requisition_status_changes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.requisition_status_changes_id_seq OWNER TO postgres;

--
-- Name: requisition_status_changes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE requisition_status_changes_id_seq OWNED BY requisition_status_changes.id;


--
-- Name: requisitions; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE requisitions (
    id integer NOT NULL,
    facilityid integer NOT NULL,
    programid integer NOT NULL,
    periodid integer NOT NULL,
    status character varying(20) NOT NULL,
    emergency boolean DEFAULT false NOT NULL,
    fullsupplyitemssubmittedcost numeric(15,2),
    nonfullsupplyitemssubmittedcost numeric(15,2),
    supervisorynodeid integer,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now(),
    allocatedbudget numeric(20,2)
);


ALTER TABLE public.requisitions OWNER TO postgres;

--
-- Name: requisitions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE requisitions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.requisitions_id_seq OWNER TO postgres;

--
-- Name: requisitions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE requisitions_id_seq OWNED BY requisitions.id;


--
-- Name: rights; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE rights (
    name character varying(200) NOT NULL,
    righttype character varying(20) NOT NULL,
    description character varying(200),
    createddate timestamp without time zone DEFAULT now(),
    displayorder integer,
    displaynamekey character varying(150)
);


ALTER TABLE public.rights OWNER TO postgres;

--
-- Name: role_assignments; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE role_assignments (
    userid integer NOT NULL,
    roleid integer NOT NULL,
    programid integer,
    supervisorynodeid integer,
    deliveryzoneid integer
);


ALTER TABLE public.role_assignments OWNER TO postgres;

--
-- Name: role_rights; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE role_rights (
    roleid integer NOT NULL,
    rightname character varying NOT NULL,
    createdby integer,
    createddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.role_rights OWNER TO postgres;

--
-- Name: roles; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE roles (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(250),
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.roles OWNER TO postgres;

--
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.roles_id_seq OWNER TO postgres;

--
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE roles_id_seq OWNED BY roles.id;


--
-- Name: schema_version; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE schema_version (
    version character varying(20) NOT NULL,
    description character varying(100),
    type character varying(10) NOT NULL,
    script character varying(200) NOT NULL,
    checksum integer,
    installed_by character varying(30) NOT NULL,
    installed_on timestamp without time zone DEFAULT now(),
    execution_time integer,
    state character varying(15) NOT NULL,
    current_version boolean NOT NULL
);


ALTER TABLE public.schema_version OWNER TO postgres;

--
-- Name: shipment_configuration; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE shipment_configuration (
    headerinfile boolean NOT NULL,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.shipment_configuration OWNER TO postgres;

--
-- Name: shipment_file_columns; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE shipment_file_columns (
    id integer NOT NULL,
    name character varying(150) NOT NULL,
    datafieldlabel character varying(150),
    "position" integer,
    include boolean NOT NULL,
    mandatory boolean NOT NULL,
    datepattern character varying(25),
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.shipment_file_columns OWNER TO postgres;

--
-- Name: shipment_file_columns_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE shipment_file_columns_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.shipment_file_columns_id_seq OWNER TO postgres;

--
-- Name: shipment_file_columns_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE shipment_file_columns_id_seq OWNED BY shipment_file_columns.id;


--
-- Name: shipment_file_info; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE shipment_file_info (
    id integer NOT NULL,
    filename character varying(200) NOT NULL,
    processingerror boolean NOT NULL,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.shipment_file_info OWNER TO postgres;

--
-- Name: shipment_file_info_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE shipment_file_info_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.shipment_file_info_id_seq OWNER TO postgres;

--
-- Name: shipment_file_info_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE shipment_file_info_id_seq OWNED BY shipment_file_info.id;


--
-- Name: shipment_line_items; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE shipment_line_items (
    id integer NOT NULL,
    orderid integer NOT NULL,
    productcode character varying(50) NOT NULL,
    quantityshipped integer NOT NULL,
    cost numeric(15,2),
    packeddate timestamp without time zone,
    shippeddate timestamp without time zone,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now(),
    productname character varying(250) NOT NULL,
    dispensingunit character varying(20) NOT NULL,
    productcategory character varying(100),
    packstoship integer,
    productcategorydisplayorder integer,
    productdisplayorder integer,
    fullsupply boolean,
    replacedproductcode character varying(50),
    ordernumber character varying(100) NOT NULL
);


ALTER TABLE public.shipment_line_items OWNER TO postgres;

--
-- Name: shipment_line_items_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE shipment_line_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.shipment_line_items_id_seq OWNER TO postgres;

--
-- Name: shipment_line_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE shipment_line_items_id_seq OWNED BY shipment_line_items.id;


--
-- Name: supervisory_nodes; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE supervisory_nodes (
    id integer NOT NULL,
    parentid integer,
    facilityid integer NOT NULL,
    name character varying(50) NOT NULL,
    code character varying(50) NOT NULL,
    description character varying(250),
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.supervisory_nodes OWNER TO postgres;

--
-- Name: supervisory_nodes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE supervisory_nodes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.supervisory_nodes_id_seq OWNER TO postgres;

--
-- Name: supervisory_nodes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE supervisory_nodes_id_seq OWNED BY supervisory_nodes.id;


--
-- Name: supply_lines; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE supply_lines (
    id integer NOT NULL,
    description character varying(250),
    supervisorynodeid integer NOT NULL,
    programid integer NOT NULL,
    supplyingfacilityid integer NOT NULL,
    exportorders boolean NOT NULL,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.supply_lines OWNER TO postgres;

--
-- Name: supply_lines_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE supply_lines_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.supply_lines_id_seq OWNER TO postgres;

--
-- Name: supply_lines_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE supply_lines_id_seq OWNED BY supply_lines.id;


--
-- Name: template_parameters; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE template_parameters (
    id integer NOT NULL,
    templateid integer NOT NULL,
    name character varying(250) NOT NULL,
    displayname character varying(250) NOT NULL,
    description character varying(500),
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    defaultvalue character varying(500),
    datatype character varying(500) NOT NULL
);


ALTER TABLE public.template_parameters OWNER TO postgres;

--
-- Name: template_parameters_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE template_parameters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.template_parameters_id_seq OWNER TO postgres;

--
-- Name: template_parameters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE template_parameters_id_seq OWNED BY template_parameters.id;


--
-- Name: user_password_reset_tokens; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE user_password_reset_tokens (
    userid integer NOT NULL,
    token character varying(250) NOT NULL,
    createddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.user_password_reset_tokens OWNER TO postgres;

--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE users (
    id integer NOT NULL,
    username character varying(50) NOT NULL,
    password character varying(128) DEFAULT 'not-in-use'::character varying,
    firstname character varying(50) NOT NULL,
    lastname character varying(50) NOT NULL,
    employeeid character varying(50),
    restrictlogin boolean DEFAULT false,
    jobtitle character varying(50),
    primarynotificationmethod character varying(50),
    officephone character varying(30),
    cellphone character varying(30),
    email character varying(50) NOT NULL,
    supervisorid integer,
    facilityid integer,
    verified boolean DEFAULT false,
    active boolean DEFAULT true,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.users_id_seq OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: vaccination_adult_coverage_line_items; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE vaccination_adult_coverage_line_items (
    id integer NOT NULL,
    facilityvisitid integer NOT NULL,
    demographicgroup character varying(255) NOT NULL,
    targetgroup integer,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now(),
    healthcentertetanus1 integer,
    outreachtetanus1 integer,
    healthcentertetanus2to5 integer,
    outreachtetanus2to5 integer
);


ALTER TABLE public.vaccination_adult_coverage_line_items OWNER TO postgres;

--
-- Name: vaccination_adult_coverage_line_items_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE vaccination_adult_coverage_line_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.vaccination_adult_coverage_line_items_id_seq OWNER TO postgres;

--
-- Name: vaccination_adult_coverage_line_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE vaccination_adult_coverage_line_items_id_seq OWNED BY vaccination_adult_coverage_line_items.id;


--
-- Name: vaccination_child_coverage_line_items; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE vaccination_child_coverage_line_items (
    id integer NOT NULL,
    facilityvisitid integer NOT NULL,
    vaccination character varying(255) NOT NULL,
    targetgroup integer,
    healthcenter11months integer,
    outreach11months integer,
    healthcenter23months integer,
    outreach23months integer,
    createdby integer,
    createddate timestamp without time zone DEFAULT now(),
    modifiedby integer,
    modifieddate timestamp without time zone DEFAULT now()
);


ALTER TABLE public.vaccination_child_coverage_line_items OWNER TO postgres;

--
-- Name: vaccination_child_coverage_line_items_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE vaccination_child_coverage_line_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.vaccination_child_coverage_line_items_id_seq OWNER TO postgres;

--
-- Name: vaccination_child_coverage_line_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE vaccination_child_coverage_line_items_id_seq OWNED BY vaccination_child_coverage_line_items.id;


--
-- Name: vaccination_full_coverages_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE vaccination_full_coverages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.vaccination_full_coverages_id_seq OWNER TO postgres;

--
-- Name: vaccination_full_coverages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE vaccination_full_coverages_id_seq OWNED BY full_coverages.id;


SET search_path = atomfeed, pg_catalog;

--
-- Name: id; Type: DEFAULT; Schema: atomfeed; Owner: postgres
--

ALTER TABLE ONLY chunking_history ALTER COLUMN id SET DEFAULT nextval('chunking_history_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: atomfeed; Owner: postgres
--

ALTER TABLE ONLY event_records ALTER COLUMN id SET DEFAULT nextval('event_records_id_seq'::regclass);


SET search_path = public, pg_catalog;

--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY adult_coverage_opened_vial_line_items ALTER COLUMN id SET DEFAULT nextval('adult_coverage_opened_vial_line_items_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY budget_file_columns ALTER COLUMN id SET DEFAULT nextval('budget_file_columns_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY budget_file_info ALTER COLUMN id SET DEFAULT nextval('budget_file_info_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY budget_line_items ALTER COLUMN id SET DEFAULT nextval('budget_line_items_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY child_coverage_opened_vial_line_items ALTER COLUMN id SET DEFAULT nextval('opened_vial_line_items_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY comments ALTER COLUMN id SET DEFAULT nextval('comments_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY configurable_rnr_options ALTER COLUMN id SET DEFAULT nextval('configurable_rnr_options_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY coverage_product_vials ALTER COLUMN id SET DEFAULT nextval('coverage_product_vials_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY coverage_target_group_products ALTER COLUMN id SET DEFAULT nextval('coverage_vaccination_products_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY delivery_zone_members ALTER COLUMN id SET DEFAULT nextval('delivery_zone_members_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY delivery_zone_program_schedules ALTER COLUMN id SET DEFAULT nextval('delivery_zone_program_schedules_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY delivery_zone_warehouses ALTER COLUMN id SET DEFAULT nextval('delivery_zone_warehouses_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY delivery_zones ALTER COLUMN id SET DEFAULT nextval('delivery_zones_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY distributions ALTER COLUMN id SET DEFAULT nextval('distributions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY dosage_units ALTER COLUMN id SET DEFAULT nextval('dosage_units_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY email_notifications ALTER COLUMN id SET DEFAULT nextval('email_notifications_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY epi_inventory_line_items ALTER COLUMN id SET DEFAULT nextval('epi_inventory_line_items_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY epi_use_line_items ALTER COLUMN id SET DEFAULT nextval('epi_use_line_items_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY facilities ALTER COLUMN id SET DEFAULT nextval('facilities_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY facility_approved_products ALTER COLUMN id SET DEFAULT nextval('facility_approved_products_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY facility_ftp_details ALTER COLUMN id SET DEFAULT nextval('facility_ftp_details_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY facility_operators ALTER COLUMN id SET DEFAULT nextval('facility_operators_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY facility_program_products ALTER COLUMN id SET DEFAULT nextval('facility_program_products_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY facility_types ALTER COLUMN id SET DEFAULT nextval('facility_types_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY facility_visits ALTER COLUMN id SET DEFAULT nextval('facility_visits_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY full_coverages ALTER COLUMN id SET DEFAULT nextval('vaccination_full_coverages_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY geographic_levels ALTER COLUMN id SET DEFAULT nextval('geographic_levels_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY geographic_zones ALTER COLUMN id SET DEFAULT nextval('geographic_zones_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY master_rnr_column_options ALTER COLUMN id SET DEFAULT nextval('master_rnr_column_options_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY master_rnr_columns ALTER COLUMN id SET DEFAULT nextval('master_rnr_columns_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY order_file_columns ALTER COLUMN id SET DEFAULT nextval('order_file_columns_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pod ALTER COLUMN id SET DEFAULT nextval('pod_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pod_line_items ALTER COLUMN id SET DEFAULT nextval('pod_line_items_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY processing_periods ALTER COLUMN id SET DEFAULT nextval('processing_periods_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY processing_schedules ALTER COLUMN id SET DEFAULT nextval('processing_schedules_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY product_categories ALTER COLUMN id SET DEFAULT nextval('product_categories_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY product_forms ALTER COLUMN id SET DEFAULT nextval('product_forms_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY product_groups ALTER COLUMN id SET DEFAULT nextval('product_groups_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY products ALTER COLUMN id SET DEFAULT nextval('products_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY program_product_isa ALTER COLUMN id SET DEFAULT nextval('program_product_isa_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY program_product_price_history ALTER COLUMN id SET DEFAULT nextval('program_product_price_history_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY program_products ALTER COLUMN id SET DEFAULT nextval('program_products_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY program_regimen_columns ALTER COLUMN id SET DEFAULT nextval('program_regimen_columns_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY program_rnr_columns ALTER COLUMN id SET DEFAULT nextval('program_rnr_columns_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY programs ALTER COLUMN id SET DEFAULT nextval('programs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY programs_supported ALTER COLUMN id SET DEFAULT nextval('programs_supported_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY refrigerator_problems ALTER COLUMN id SET DEFAULT nextval('refrigerator_problems_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY refrigerator_readings ALTER COLUMN id SET DEFAULT nextval('distribution_refrigerator_readings_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY refrigerators ALTER COLUMN id SET DEFAULT nextval('refrigerators_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY regimen_categories ALTER COLUMN id SET DEFAULT nextval('regimen_categories_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY regimen_line_items ALTER COLUMN id SET DEFAULT nextval('regimen_line_items_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY regimens ALTER COLUMN id SET DEFAULT nextval('regimens_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY report_rights ALTER COLUMN id SET DEFAULT nextval('report_rights_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY requisition_group_members ALTER COLUMN id SET DEFAULT nextval('requisition_group_members_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY requisition_group_program_schedules ALTER COLUMN id SET DEFAULT nextval('requisition_group_program_schedules_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY requisition_groups ALTER COLUMN id SET DEFAULT nextval('requisition_groups_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY requisition_line_items ALTER COLUMN id SET DEFAULT nextval('requisition_line_items_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY requisition_status_changes ALTER COLUMN id SET DEFAULT nextval('requisition_status_changes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY requisitions ALTER COLUMN id SET DEFAULT nextval('requisitions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY roles ALTER COLUMN id SET DEFAULT nextval('roles_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY shipment_file_columns ALTER COLUMN id SET DEFAULT nextval('shipment_file_columns_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY shipment_file_info ALTER COLUMN id SET DEFAULT nextval('shipment_file_info_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY shipment_line_items ALTER COLUMN id SET DEFAULT nextval('shipment_line_items_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY supervisory_nodes ALTER COLUMN id SET DEFAULT nextval('supervisory_nodes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY supply_lines ALTER COLUMN id SET DEFAULT nextval('supply_lines_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY template_parameters ALTER COLUMN id SET DEFAULT nextval('template_parameters_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY templates ALTER COLUMN id SET DEFAULT nextval('report_templates_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY vaccination_adult_coverage_line_items ALTER COLUMN id SET DEFAULT nextval('vaccination_adult_coverage_line_items_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY vaccination_child_coverage_line_items ALTER COLUMN id SET DEFAULT nextval('vaccination_child_coverage_line_items_id_seq'::regclass);


SET search_path = atomfeed, pg_catalog;

--
-- Data for Name: chunking_history; Type: TABLE DATA; Schema: atomfeed; Owner: postgres
--

COPY chunking_history (id, chunk_length, start) FROM stdin;
1	5	1
\.


--
-- Name: chunking_history_id_seq; Type: SEQUENCE SET; Schema: atomfeed; Owner: postgres
--

SELECT pg_catalog.setval('chunking_history_id_seq', 1, true);


--
-- Data for Name: event_records; Type: TABLE DATA; Schema: atomfeed; Owner: postgres
--

COPY event_records (id, uuid, title, "timestamp", uri, object, category) FROM stdin;
1	37490b73-7985-4b88-a656-2b81da0ab832	Facility	2014-10-27 13:31:35.132588		{"geographicZone":"District1","facilityType":"Health Center","operatedBy":"MoH","programsSupported":["ESS_MEDS"],"name":"Bukoto Health Center","id":1,"enabled":true,"code":"clinic_1","active":true,"virtualFacility":false,"modifiedBy":1,"sdp":true,"goLiveDate":1096578000000,"createdBy":1,"stringGoLiveDate":"01-10-2004"}	facilities
2	7c49725b-af9b-4646-b69b-fa946943a3ee	Programs Supported	2014-10-27 13:31:35.620658		{"facilityCode":"clinic_1","programsSupported":[{"code":"ESS_MEDS","name":"ESSENTIAL MEDICINES","active":true,"startDate":1285880400000,"stringStartDate":"01/10/2010"}]}	programs-supported
3	effecb9c-7e78-4b63-9ad9-969111d3c7c8	Facility	2014-10-27 13:33:55.97254		{"geographicZone":"District1","facilityType":"Warehouse","operatedBy":"Private","programsSupported":["ESS_MEDS"],"name":"Kampala AHF Warehouse","id":2,"enabled":true,"code":"warehouse_1","active":true,"virtualFacility":false,"modifiedBy":1,"sdp":false,"goLiveDate":1096578000000,"createdBy":1,"stringGoLiveDate":"01-10-2004"}	facilities
4	214e287c-9cd9-415d-afe0-cea5d1066c25	Programs Supported	2014-10-27 13:33:56.115567		{"facilityCode":"warehouse_1","programsSupported":[{"code":"ESS_MEDS","name":"ESSENTIAL MEDICINES","active":true,"startDate":1096578000000,"stringStartDate":"01/10/2004"}]}	programs-supported
\.


--
-- Name: event_records_id_seq; Type: SEQUENCE SET; Schema: atomfeed; Owner: postgres
--

SELECT pg_catalog.setval('event_records_id_seq', 4, true);


SET search_path = public, pg_catalog;

--
-- Data for Name: adult_coverage_opened_vial_line_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY adult_coverage_opened_vial_line_items (id, facilityvisitid, productvialname, openedvials, packsize, createdby, createddate, modifiedby, modifieddate) FROM stdin;
\.


--
-- Name: adult_coverage_opened_vial_line_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('adult_coverage_opened_vial_line_items_id_seq', 1, false);


--
-- Data for Name: budget_configuration; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY budget_configuration (headerinfile, createdby, createddate, modifiedby, modifieddate) FROM stdin;
f	\N	2014-10-27 12:27:36.407186	\N	2014-10-27 12:27:36.407186
\.


--
-- Data for Name: budget_file_columns; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY budget_file_columns (id, name, datafieldlabel, "position", include, mandatory, datepattern, createdby, createddate, modifiedby, modifieddate) FROM stdin;
1	facilityCode	header.facility.code	1	t	t	\N	\N	2014-10-27 12:27:36.419814	\N	2014-10-27 12:27:36.419814
2	programCode	header.program.code	2	t	t	\N	\N	2014-10-27 12:27:36.419814	\N	2014-10-27 12:27:36.419814
3	periodStartDate	header.period.start.date	3	t	t	dd/MM/yy	\N	2014-10-27 12:27:36.419814	\N	2014-10-27 12:27:36.419814
4	allocatedBudget	header.allocatedBudget	4	t	t	\N	\N	2014-10-27 12:27:36.419814	\N	2014-10-27 12:27:36.419814
5	notes	header.notes	5	f	f	\N	\N	2014-10-27 12:27:36.419814	\N	2014-10-27 12:27:36.419814
\.


--
-- Name: budget_file_columns_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('budget_file_columns_id_seq', 5, true);


--
-- Data for Name: budget_file_info; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY budget_file_info (id, filename, processingerror, createdby, createddate, modifiedby, modifieddate) FROM stdin;
\.


--
-- Name: budget_file_info_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('budget_file_info_id_seq', 1, false);


--
-- Data for Name: budget_line_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY budget_line_items (id, periodid, budgetfileid, perioddate, allocatedbudget, notes, createdby, createddate, modifiedby, modifieddate, facilityid, programid) FROM stdin;
\.


--
-- Name: budget_line_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('budget_line_items_id_seq', 1, false);


--
-- Data for Name: child_coverage_opened_vial_line_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY child_coverage_opened_vial_line_items (id, facilityvisitid, productvialname, openedvials, packsize, createdby, createddate, modifiedby, modifieddate) FROM stdin;
\.


--
-- Data for Name: comments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY comments (id, rnrid, commenttext, createdby, createddate, modifiedby, modifieddate) FROM stdin;
\.


--
-- Name: comments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('comments_id_seq', 1, false);


--
-- Data for Name: configurable_rnr_options; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY configurable_rnr_options (id, name, label, createdby, createddate, modifiedby, modifieddate) FROM stdin;
1	newPatientCount	label.new.patient.count	\N	2014-10-27 12:27:37.586801	\N	2014-10-27 12:27:37.586801
2	dispensingUnitsForNewPatients	label.dispensing.units.for.new.patients	\N	2014-10-27 12:27:37.586801	\N	2014-10-27 12:27:37.586801
\.


--
-- Name: configurable_rnr_options_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('configurable_rnr_options_id_seq', 2, true);


--
-- Data for Name: coverage_product_vials; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY coverage_product_vials (id, vial, productcode, childcoverage) FROM stdin;
\.


--
-- Name: coverage_product_vials_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('coverage_product_vials_id_seq', 1, false);


--
-- Data for Name: coverage_target_group_products; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY coverage_target_group_products (id, targetgroupentity, productcode, childcoverage) FROM stdin;
\.


--
-- Name: coverage_vaccination_products_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('coverage_vaccination_products_id_seq', 1, false);


--
-- Data for Name: delivery_zone_members; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY delivery_zone_members (id, deliveryzoneid, facilityid, createdby, createddate, modifiedby, modifieddate) FROM stdin;
1	1	1	\N	2014-10-27 15:53:54.336693	\N	2014-10-27 15:53:54.336693
\.


--
-- Name: delivery_zone_members_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('delivery_zone_members_id_seq', 1, false);


--
-- Data for Name: delivery_zone_program_schedules; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY delivery_zone_program_schedules (id, deliveryzoneid, programid, scheduleid, createdby, createddate, modifiedby, modifieddate) FROM stdin;
1	1	2	1	\N	2014-10-27 15:55:13.026493	\N	2014-10-27 15:55:13.026493
\.


--
-- Name: delivery_zone_program_schedules_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('delivery_zone_program_schedules_id_seq', 1, false);


--
-- Data for Name: delivery_zone_warehouses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY delivery_zone_warehouses (id, deliveryzoneid, warehouseid, createdby, createddate, modifiedby, modifieddate) FROM stdin;
1	1	2	\N	2014-10-27 15:54:52.374906	\N	2014-10-27 15:54:52.374906
\.


--
-- Name: delivery_zone_warehouses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('delivery_zone_warehouses_id_seq', 1, false);


--
-- Data for Name: delivery_zones; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY delivery_zones (id, code, name, description, createdby, createddate, modifiedby, modifieddate) FROM stdin;
1	zone_1	Zone 1	\N	\N	2014-10-27 15:52:54.983208	\N	2014-10-27 15:52:54.983208
\.


--
-- Name: delivery_zones_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('delivery_zones_id_seq', 1, false);


--
-- Name: distribution_refrigerator_readings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('distribution_refrigerator_readings_id_seq', 1, false);


--
-- Data for Name: distributions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY distributions (id, deliveryzoneid, programid, periodid, status, createdby, createddate, modifiedby, modifieddate) FROM stdin;
\.


--
-- Name: distributions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('distributions_id_seq', 1, false);


--
-- Data for Name: dosage_units; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY dosage_units (id, code, displayorder, createddate) FROM stdin;
1	mg	1	2014-10-27 12:28:16.293071
2	ml	2	2014-10-27 12:28:16.293071
3	each	3	2014-10-27 12:28:16.293071
4	cc	4	2014-10-27 12:28:16.293071
5	gm	5	2014-10-27 12:28:16.293071
6	mcg	6	2014-10-27 12:28:16.293071
7	IU	7	2014-10-27 12:28:16.293071
\.


--
-- Name: dosage_units_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('dosage_units_id_seq', 7, true);


--
-- Data for Name: email_notifications; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY email_notifications (id, receiver, subject, content, sent, createddate) FROM stdin;
\.


--
-- Name: email_notifications_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('email_notifications_id_seq', 1, false);


--
-- Data for Name: epi_inventory_line_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY epi_inventory_line_items (id, productname, idealquantity, existingquantity, spoiledquantity, deliveredquantity, facilityvisitid, productcode, productdisplayorder, programproductid, createdby, createddate, modifiedby, modifieddate) FROM stdin;
\.


--
-- Name: epi_inventory_line_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('epi_inventory_line_items_id_seq', 1, false);


--
-- Data for Name: epi_use_line_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY epi_use_line_items (id, productgroupid, productgroupname, stockatfirstofmonth, received, distributed, loss, stockatendofmonth, expirationdate, createdby, createddate, modifiedby, modifieddate, facilityvisitid) FROM stdin;
\.


--
-- Name: epi_use_line_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('epi_use_line_items_id_seq', 1, false);


--
-- Data for Name: facilities; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY facilities (id, code, name, description, gln, mainphone, fax, address1, address2, geographiczoneid, typeid, catchmentpopulation, latitude, longitude, altitude, operatedbyid, coldstoragegrosscapacity, coldstoragenetcapacity, suppliesothers, sdp, online, satellite, parentfacilityid, haselectricity, haselectronicscc, haselectronicdar, active, golivedate, godowndate, comment, enabled, virtualfacility, createdby, createddate, modifiedby, modifieddate) FROM stdin;
1	clinic_1	Bukoto Health Center	\N	\N	\N	\N	\N	\N	12	6	\N	\N	\N	\N	1	\N	\N	\N	t	\N	\N	\N	\N	\N	\N	t	2004-10-01	\N	\N	t	f	1	2014-10-27 13:31:34.76342	1	2014-10-27 13:31:34.76342
2	warehouse_1	Kampala AHF Warehouse	\N	\N	\N	\N	\N	\N	12	1	\N	\N	\N	\N	4	\N	\N	\N	f	\N	\N	\N	\N	\N	\N	t	2004-10-01	\N	\N	t	f	1	2014-10-27 13:33:55.929233	1	2014-10-27 13:33:55.929233
\.


--
-- Name: facilities_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('facilities_id_seq', 2, true);


--
-- Data for Name: facility_approved_products; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY facility_approved_products (id, facilitytypeid, programproductid, maxmonthsofstock, minmonthsofstock, eop, createdby, createddate, modifiedby, modifieddate) FROM stdin;
1	6	1	6.00	\N	\N	1	2014-10-27 14:32:40.692663	1	2014-10-27 14:32:40.692663
\.


--
-- Name: facility_approved_products_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('facility_approved_products_id_seq', 1, true);


--
-- Data for Name: facility_ftp_details; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY facility_ftp_details (id, facilityid, serverhost, serverport, username, password, localfolderpath, createdby, createddate, modifiedby, modifieddate) FROM stdin;
\.


--
-- Name: facility_ftp_details_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('facility_ftp_details_id_seq', 1, false);


--
-- Data for Name: facility_operators; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY facility_operators (id, code, text, displayorder, createddate) FROM stdin;
1	MoH	MoH	1	2014-10-27 12:28:16.314654
2	NGO	NGO	2	2014-10-27 12:28:16.314654
3	FBO	FBO	3	2014-10-27 12:28:16.314654
4	Private	Private	4	2014-10-27 12:28:16.314654
\.


--
-- Name: facility_operators_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('facility_operators_id_seq', 4, true);


--
-- Data for Name: facility_program_products; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY facility_program_products (id, facilityid, programproductid, overriddenisa, createdby, createddate, modifiedby, modifieddate) FROM stdin;
\.


--
-- Name: facility_program_products_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('facility_program_products_id_seq', 1, false);


--
-- Data for Name: facility_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY facility_types (id, code, name, description, levelid, nominalmaxmonth, nominaleop, displayorder, active, createddate) FROM stdin;
1	warehouse	Warehouse	Central Supply Depot	\N	3	0.50	11	t	2014-10-27 12:28:16.340454
2	lvl3_hospital	Lvl3 Hospital	State Hospital	\N	3	0.50	1	t	2014-10-27 12:28:16.340454
3	lvl2_hospital	Lvl2 Hospital	Regional Hospital	\N	3	0.50	2	t	2014-10-27 12:28:16.340454
4	state_office	State Office	Management Office, no patient services	\N	3	0.50	9	t	2014-10-27 12:28:16.340454
5	district_office	District Office	Management Office, no patient services	\N	3	0.50	10	t	2014-10-27 12:28:16.340454
6	health_center	Health Center	Multi-program clinic	\N	3	0.50	4	t	2014-10-27 12:28:16.340454
7	health_post	Health Post	Community Clinic	\N	3	0.50	5	t	2014-10-27 12:28:16.340454
8	lvl1_hospital	Lvl1 Hospital	District Hospital	\N	3	0.50	3	t	2014-10-27 12:28:16.340454
9	satellite_facility	Satellite Facility	Temporary service delivery point	\N	1	0.25	6	f	2014-10-27 12:28:16.340454
10	chw	CHW	Mobile worker based out of health center	\N	1	0.25	7	t	2014-10-27 12:28:16.340454
11	dhmt	DHMT	District Health Management Team	\N	3	0.50	8	t	2014-10-27 12:28:16.340454
\.


--
-- Name: facility_types_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('facility_types_id_seq', 11, true);


--
-- Data for Name: facility_visits; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY facility_visits (id, distributionid, facilityid, confirmedbyname, confirmedbytitle, verifiedbyname, verifiedbytitle, observations, createdby, createddate, synced, modifieddate, modifiedby, visited, visitdate, vehicleid, facilitycatchmentpopulation, reasonfornotvisiting, otherreasondescription) FROM stdin;
\.


--
-- Name: facility_visits_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('facility_visits_id_seq', 1, false);


--
-- Data for Name: fulfillment_role_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY fulfillment_role_assignments (userid, roleid, facilityid, createdby, createddate, modifiedby, modifieddate) FROM stdin;
3	3	2	1	2014-10-27 15:11:48.936692	1	2014-10-27 15:11:48.936692
4	5	2	1	2014-10-27 15:57:25.56362	1	2014-10-27 15:57:25.56362
\.


--
-- Data for Name: full_coverages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY full_coverages (id, femalehealthcenter, femaleoutreach, maleoutreach, malehealthcenter, facilityvisitid, createdby, createddate, modifiedby, modifieddate) FROM stdin;
\.


--
-- Data for Name: geographic_levels; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY geographic_levels (id, code, name, levelnumber, createddate) FROM stdin;
1	country	Country	1	2014-10-27 12:28:16.372238
2	state	State	2	2014-10-27 12:28:16.372238
3	province	Province	3	2014-10-27 12:28:16.372238
4	district	District	4	2014-10-27 12:28:16.372238
\.


--
-- Name: geographic_levels_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('geographic_levels_id_seq', 4, true);


--
-- Data for Name: geographic_zones; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY geographic_zones (id, code, name, levelid, parentid, catchmentpopulation, latitude, longitude, createdby, createddate, modifiedby, modifieddate) FROM stdin;
1	Root	Root	1	\N	\N	\N	\N	\N	2014-10-27 12:28:16.403	\N	2014-10-27 12:28:16.403
2	Mozambique	Mozambique	1	\N	\N	\N	\N	\N	2014-10-27 12:28:16.407225	\N	2014-10-27 12:28:16.407225
3	Arusha	Arusha	2	1	\N	\N	\N	\N	2014-10-27 12:28:16.408435	\N	2014-10-27 12:28:16.408435
4	Dodoma	Dodoma	3	3	\N	\N	\N	\N	2014-10-27 12:28:16.409697	\N	2014-10-27 12:28:16.409697
5	Ngorongoro	Ngorongoro	4	4	\N	\N	\N	\N	2014-10-27 12:28:16.410856	\N	2014-10-27 12:28:16.410856
6	Cabo Delgado Province	Cabo Delgado Province	2	2	\N	\N	\N	\N	2014-10-27 12:28:16.411957	\N	2014-10-27 12:28:16.411957
7	Gaza Province	Gaza Province	2	2	\N	\N	\N	\N	2014-10-27 12:28:16.411957	\N	2014-10-27 12:28:16.411957
8	Inhambane Province	Inhambane Province	2	2	\N	\N	\N	\N	2014-10-27 12:28:16.411957	\N	2014-10-27 12:28:16.411957
9	Norte	Norte	3	6	\N	\N	\N	\N	2014-10-27 12:28:16.414019	\N	2014-10-27 12:28:16.414019
10	Centro	Centro	3	7	\N	\N	\N	\N	2014-10-27 12:28:16.415017	\N	2014-10-27 12:28:16.415017
11	Sul	Sul	3	8	\N	\N	\N	\N	2014-10-27 12:28:16.416559	\N	2014-10-27 12:28:16.416559
12	District1	District1	4	9	\N	\N	\N	\N	2014-10-27 12:28:16.418315	\N	2014-10-27 12:28:16.418315
13	District2	District2	4	9	\N	\N	\N	\N	2014-10-27 12:28:16.418315	\N	2014-10-27 12:28:16.418315
14	District3	District3	4	9	\N	\N	\N	\N	2014-10-27 12:28:16.418315	\N	2014-10-27 12:28:16.418315
15	District4	District4	4	10	\N	\N	\N	\N	2014-10-27 12:28:16.418315	\N	2014-10-27 12:28:16.418315
16	District5	District5	4	10	\N	\N	\N	\N	2014-10-27 12:28:16.418315	\N	2014-10-27 12:28:16.418315
17	District6	District6	4	10	\N	\N	\N	\N	2014-10-27 12:28:16.418315	\N	2014-10-27 12:28:16.418315
18	District7	District7	4	11	\N	\N	\N	\N	2014-10-27 12:28:16.418315	\N	2014-10-27 12:28:16.418315
19	District8	District8	4	11	\N	\N	\N	\N	2014-10-27 12:28:16.418315	\N	2014-10-27 12:28:16.418315
20	District9	District9	4	11	\N	\N	\N	\N	2014-10-27 12:28:16.418315	\N	2014-10-27 12:28:16.418315
\.


--
-- Name: geographic_zones_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('geographic_zones_id_seq', 20, true);


--
-- Data for Name: losses_adjustments_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY losses_adjustments_types (name, description, additive, displayorder, createddate) FROM stdin;
TRANSFER_IN	Transfer In	t	2	2014-10-27 12:27:35.852449
TRANSFER_OUT	Transfer Out	f	3	2014-10-27 12:27:35.852449
DAMAGED	Damaged	f	1	2014-10-27 12:27:35.852449
LOST	Lost	f	7	2014-10-27 12:27:35.852449
STOLEN	Stolen	f	8	2014-10-27 12:27:35.852449
EXPIRED	Expired	f	4	2014-10-27 12:27:35.852449
PASSED_OPEN_VIAL_TIME_LIMIT	Passed Open-Vial Time Limit	f	5	2014-10-27 12:27:35.852449
COLD_CHAIN_FAILURE	Cold Chain Failure	f	6	2014-10-27 12:27:35.852449
CLINIC_RETURN	Clinic Return	t	9	2014-10-27 12:27:35.852449
\.


--
-- Data for Name: master_regimen_columns; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY master_regimen_columns (name, label, visible, datatype) FROM stdin;
code	header.code	t	regimen.reporting.dataType.text
name	header.name	t	regimen.reporting.dataType.text
patientsOnTreatment	Number of patients on treatment	t	regimen.reporting.dataType.numeric
patientsToInitiateTreatment	Number of patients to be initiated treatment	t	regimen.reporting.dataType.numeric
patientsStoppedTreatment	Number of patients stopped treatment	t	regimen.reporting.dataType.numeric
remarks	Remarks	t	regimen.reporting.dataType.text
\.


--
-- Data for Name: master_rnr_column_options; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY master_rnr_column_options (id, masterrnrcolumnid, rnroptionid, createdby, createddate, modifiedby, modifieddate) FROM stdin;
1	11	1	\N	2014-10-27 12:27:37.619437	\N	2014-10-27 12:27:37.619437
2	11	2	\N	2014-10-27 12:27:37.619437	\N	2014-10-27 12:27:37.619437
\.


--
-- Name: master_rnr_column_options_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('master_rnr_column_options_id_seq', 2, true);


--
-- Data for Name: master_rnr_columns; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY master_rnr_columns (id, name, "position", source, sourceconfigurable, label, formula, indicator, used, visible, mandatory, description, createddate) FROM stdin;
1	skipped	1	U	f	Skip		indicator.column.skip	t	t	f	description.column.skip	2014-10-27 12:27:35.025011
2	productCode	2	R	f	Product Code		indicator.column.product.code	t	t	f	description.column.product.code	2014-10-27 12:27:35.025011
3	product	3	R	f	Product		indicator.column.product	t	t	t	description.column.product	2014-10-27 12:27:35.025011
4	dispensingUnit	4	R	f	Unit/Unit of Issue		indicator.column.dispensing.unit	t	t	f	description.column.dispensing.unit	2014-10-27 12:27:35.025011
5	beginningBalance	5	U	f	Beginning Balance		indicator.column.beginning.balance	t	t	f	description.column.beginning.balance	2014-10-27 12:27:35.025011
6	quantityReceived	6	U	f	Total Received Quantity		indicator.column.quantity.received	t	t	f	description.column.quantity.received	2014-10-27 12:27:35.025011
7	total	7	C	f	Total	formula.column.total	indicator.column.total	t	t	f	description.column.total	2014-10-27 12:27:35.025011
8	quantityDispensed	8	U	t	Total Consumed Quantity	formula.column.quantity.dispensed	indicator.column.quantity.dispensed	t	t	f	description.column.quantity.dispensed	2014-10-27 12:27:35.025011
9	lossesAndAdjustments	9	U	f	Total Losses / Adjustments	formula.column.losses.adjustments	indicator.column.losses.adjustments	t	t	f	description.column.losses.adjustments	2014-10-27 12:27:35.025011
10	stockInHand	10	U	t	Stock on Hand	formula.column.stock.in.hand	indicator.column.stock.in.hand	t	t	f	description.column.stock.in.hand	2014-10-27 12:27:35.025011
11	newPatientCount	11	U	f	Total number of new patients added to service on the program		indicator.column.new.patient.count	t	t	f	description.column.new.patient.count	2014-10-27 12:27:35.025011
12	stockOutDays	12	U	f	Total Stockout Days		indicator.column.stock.out.days	t	t	f	description.column.stock.out.days	2014-10-27 12:27:35.025011
14	amc	15	C	f	Average Monthly Consumption(AMC)	formula.column.amc	indicator.column.amc	t	t	f	description.column.amc	2014-10-27 12:27:35.025011
15	maxStockQuantity	16	C	f	Maximum Stock Quantity	formula.column.max.stock.quantity	indicator.column.max.stock.quantity	t	t	f	description.column.max.stock.quantity	2014-10-27 12:27:35.025011
16	calculatedOrderQuantity	17	C	f	Calculated Order Quantity	formula.column.calculated.order.quantity	indicator.column.calculated.order.quantity	t	t	f	description.column.calculated.order.quantity	2014-10-27 12:27:35.025011
17	quantityRequested	18	U	f	Requested Quantity		indicator.column.quantity.requested	t	t	f	description.column.quantity.requested	2014-10-27 12:27:35.025011
18	reasonForRequestedQuantity	19	U	f	Requested Quantity Explanation		indicator.column.reason.for.requested.quantity	t	t	f	description.column.reason.for.requested.quantity	2014-10-27 12:27:35.025011
19	quantityApproved	20	U	f	Approved Quantity		indicator.column.quantity.approved	t	t	f	description.column.quantity.approved	2014-10-27 12:27:35.025011
20	packsToShip	21	C	f	Packs to Ship	formula.column.packs.to.ship	indicator.column.packs.to.ship	t	t	f	description.column.packs.to.ship	2014-10-27 12:27:35.025011
21	price	22	R	f	Price per Pack		indicator.column.price	t	t	f	description.column.price	2014-10-27 12:27:35.025011
22	cost	23	C	f	Total Cost	formula.column.cost	indicator.column.cost	t	t	f	description.column.cost	2014-10-27 12:27:35.025011
23	expirationDate	24	U	f	Expiration Date		indicator.column.expiration.date	t	t	f	description.column.expiration.date	2014-10-27 12:27:35.025011
24	remarks	25	U	f	Remarks		indicator.column.remarks	t	t	f	description.column.remarks	2014-10-27 12:27:35.025011
25	periodNormalizedConsumption	14	C	f	Period Normalized Consumption	formula.column.period.normalised.consumption	indicator.column.period.normalized.consumption	t	t	f	description.column.period.normalized.consumption	2014-10-27 12:27:37.486998
13	normalizedConsumption	13	C	f	Monthly Normalized Consumption	formula.column.normalised.consumption	indicator.column.normalized.consumption	t	t	f	description.column.normalized.consumption	2014-10-27 12:27:35.025011
\.


--
-- Name: master_rnr_columns_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('master_rnr_columns_id_seq', 25, true);


--
-- Name: opened_vial_line_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('opened_vial_line_items_id_seq', 1, false);


--
-- Data for Name: order_configuration; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY order_configuration (fileprefix, headerinfile, createdby, createddate, modifiedby, modifieddate) FROM stdin;
O	t	\N	2014-10-27 12:27:36.330794	1	2014-10-27 14:51:15.215304
\.


--
-- Data for Name: order_file_columns; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY order_file_columns (id, datafieldlabel, nested, keypath, includeinorderfile, columnlabel, format, "position", openlmisfield, createdby, createddate, modifiedby, modifieddate) FROM stdin;
9	header.order.number	order	orderNumber	t	Order number	\N	1	t	1	2014-10-27 14:51:15.215304	1	2014-10-27 14:51:15.215304
10	create.facility.code	order	rnr/facility/code	t	Facility code	\N	2	t	1	2014-10-27 14:51:15.215304	1	2014-10-27 14:51:15.215304
11	header.product.code	lineItem	productCode	t	Product code	\N	3	t	1	2014-10-27 14:51:15.215304	1	2014-10-27 14:51:15.215304
12	header.product.name	lineItem	product	t	Product name	\N	4	t	1	2014-10-27 14:51:15.215304	1	2014-10-27 14:51:15.215304
13	header.quantity.approved	lineItem	quantityApproved	t	Approved quantity	\N	5	t	1	2014-10-27 14:51:15.215304	1	2014-10-27 14:51:15.215304
14	label.period	order	rnr/period/startDate	t	Period	MM/yy	6	t	1	2014-10-27 14:51:15.215304	1	2014-10-27 14:51:15.215304
15	header.order.date	order	createdDate	t	Order date	dd/MM/yy	7	t	1	2014-10-27 14:51:15.215304	1	2014-10-27 14:51:15.215304
\.


--
-- Name: order_file_columns_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('order_file_columns_id_seq', 15, true);


--
-- Data for Name: order_number_configuration; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY order_number_configuration (ordernumberprefix, includeordernumberprefix, includeprogramcode, includesequencecode, includernrtypesuffix) FROM stdin;
O	t	t	t	t
\.


--
-- Data for Name: orders; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY orders (id, shipmentid, status, ftpcomment, supplylineid, createdby, createddate, modifiedby, modifieddate, ordernumber) FROM stdin;
\.


--
-- Data for Name: pod; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY pod (id, orderid, receiveddate, createdby, createddate, modifiedby, modifieddate, facilityid, programid, periodid, deliveredby, receivedby, ordernumber) FROM stdin;
\.


--
-- Name: pod_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('pod_id_seq', 1, false);


--
-- Data for Name: pod_line_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY pod_line_items (id, podid, productcode, quantityreceived, createdby, createddate, modifiedby, modifieddate, productname, dispensingunit, packstoship, quantityshipped, notes, fullsupply, productcategory, productcategorydisplayorder, productdisplayorder, quantityreturned, replacedproductcode) FROM stdin;
\.


--
-- Name: pod_line_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('pod_line_items_id_seq', 1, false);


--
-- Data for Name: processing_periods; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY processing_periods (id, scheduleid, name, description, startdate, enddate, numberofmonths, createdby, createddate, modifiedby, modifieddate) FROM stdin;
1	1	2014 October	\N	2014-10-01 00:00:00	2014-10-31 23:59:59	1	1	2014-10-27 13:46:06.696235	1	2014-10-27 13:46:06.696235
2	1	2014 November	\N	2014-11-01 00:00:00	2014-11-30 23:59:59	1	1	2014-10-27 13:46:43.288868	1	2014-10-27 13:46:43.288868
3	1	2014 December	\N	2014-12-01 00:00:00	2014-12-31 23:59:59	1	1	2014-10-27 13:46:54.979127	1	2014-10-27 13:46:54.979127
\.


--
-- Name: processing_periods_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('processing_periods_id_seq', 3, true);


--
-- Data for Name: processing_schedules; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY processing_schedules (id, code, name, description, createdby, createddate, modifiedby, modifieddate) FROM stdin;
1	monthly	Monthly	\N	1	2014-10-27 13:44:24.788449	1	2014-10-27 13:45:44.574596
\.


--
-- Name: processing_schedules_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('processing_schedules_id_seq', 1, true);


--
-- Data for Name: product_categories; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY product_categories (id, code, name, displayorder, createdby, createddate, modifiedby, modifieddate) FROM stdin;
1	category_anaesthetics	Anaesthetics	1	\N	2014-10-27 13:53:46.878859	\N	2014-10-27 13:53:46.878859
\.


--
-- Name: product_categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('product_categories_id_seq', 1, false);


--
-- Data for Name: product_forms; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY product_forms (id, code, displayorder, createddate) FROM stdin;
1	Tablet	1	2014-10-27 12:28:16.428713
2	Capsule	2	2014-10-27 12:28:16.428713
3	Bottle	3	2014-10-27 12:28:16.428713
4	Vial	4	2014-10-27 12:28:16.428713
5	Ampule	5	2014-10-27 12:28:16.428713
6	Drops	6	2014-10-27 12:28:16.428713
7	Powder	7	2014-10-27 12:28:16.428713
8	Each	8	2014-10-27 12:28:16.428713
9	Injectable	9	2014-10-27 12:28:16.428713
10	Tube	10	2014-10-27 12:28:16.428713
11	Solution	11	2014-10-27 12:28:16.428713
12	Inhaler	12	2014-10-27 12:28:16.428713
13	Patch	13	2014-10-27 12:28:16.428713
14	Implant	14	2014-10-27 12:28:16.428713
15	Sachet	15	2014-10-27 12:28:16.428713
16	Device	16	2014-10-27 12:28:16.428713
17	Other	17	2014-10-27 12:28:16.428713
\.


--
-- Name: product_forms_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('product_forms_id_seq', 17, true);


--
-- Data for Name: product_groups; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY product_groups (id, code, name, createdby, createddate, modifiedby, modifieddate) FROM stdin;
1	PG	Product Group 1	\N	2014-10-27 12:28:16.448762	\N	2014-10-27 12:28:16.448762
\.


--
-- Name: product_groups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('product_groups_id_seq', 1, true);


--
-- Data for Name: products; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY products (id, code, alternateitemcode, manufacturer, manufacturercode, manufacturerbarcode, mohbarcode, gtin, type, primaryname, fullname, genericname, alternatename, description, strength, formid, dosageunitid, productgroupid, dispensingunit, dosesperdispensingunit, packsize, alternatepacksize, storerefrigerated, storeroomtemperature, hazardous, flammable, controlledsubstance, lightsensitive, approvedbywho, contraceptivecyp, packlength, packwidth, packheight, packweight, packspercarton, cartonlength, cartonwidth, cartonheight, cartonsperpallet, expectedshelflife, specialstorageinstructions, specialtransportinstructions, active, fullsupply, tracer, roundtozero, archived, packroundingthreshold, createdby, createddate, modifiedby, modifieddate) FROM stdin;
1	EM1	\N	Glaxo and Smith	\N	\N	\N	\N	antibiotic	ACETYL SALICYLIC ACID, TAB 300MG	TDF/FTC/EFV	TDF/FTC/EFV	TDF/FTC/EFV	TDF/FTC/EFV	300/200/600	2	1	\N	Strip	10	10	\N	\N	\N	\N	\N	\N	\N	\N	\N	2.2000	2.0000	2.0000	2.0000	2	2.0000	2.0000	2.0000	2	2	\N	\N	t	t	t	f	t	1	1	2014-10-27 13:52:48.249439	1	2014-10-27 14:42:11.844305
\.


--
-- Name: products_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('products_id_seq', 1, true);


--
-- Data for Name: program_product_isa; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY program_product_isa (id, whoratio, dosesperyear, wastagefactor, programproductid, bufferpercentage, minimumvalue, maximumvalue, adjustmentvalue, createdby, createddate, modifiedby, modifieddate) FROM stdin;
\.


--
-- Name: program_product_isa_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('program_product_isa_id_seq', 1, false);


--
-- Data for Name: program_product_price_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY program_product_price_history (id, programproductid, price, priceperdosage, source, startdate, enddate, createdby, createddate, modifiedby, modifieddate) FROM stdin;
\.


--
-- Name: program_product_price_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('program_product_price_history_id_seq', 1, false);


--
-- Data for Name: program_products; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY program_products (id, programid, productid, dosespermonth, active, currentprice, createdby, createddate, modifiedby, modifieddate, productcategoryid, displayorder) FROM stdin;
1	2	1	30	t	0.00	\N	2014-10-27 13:55:15.150172	1	2014-10-27 14:42:11.898915	1	4
\.


--
-- Name: program_products_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('program_products_id_seq', 1, true);


--
-- Data for Name: program_regimen_columns; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY program_regimen_columns (id, programid, name, label, visible, datatype, createdby, createddate, modifiedby, modifieddate) FROM stdin;
\.


--
-- Name: program_regimen_columns_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('program_regimen_columns_id_seq', 1, false);


--
-- Data for Name: program_rnr_columns; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY program_rnr_columns (id, mastercolumnid, programid, label, visible, "position", source, formulavalidationrequired, createdby, createddate, modifiedby, modifieddate, rnroptionid) FROM stdin;
1	1	2	Skip	t	1	U	t	1	2014-10-27 14:45:01.479739	1	2014-10-27 14:45:01.479739	\N
2	2	2	Product Code	t	2	R	t	1	2014-10-27 14:45:01.479739	1	2014-10-27 14:45:01.479739	\N
3	3	2	Product	t	3	R	t	1	2014-10-27 14:45:01.479739	1	2014-10-27 14:45:01.479739	\N
4	4	2	Unit/Unit of Issue	t	4	R	t	1	2014-10-27 14:45:01.479739	1	2014-10-27 14:45:01.479739	\N
5	5	2	Beginning Balance	t	5	U	t	1	2014-10-27 14:45:01.479739	1	2014-10-27 14:45:01.479739	\N
6	6	2	Total Received Quantity	t	6	U	t	1	2014-10-27 14:45:01.479739	1	2014-10-27 14:45:01.479739	\N
7	7	2	Total	t	7	C	t	1	2014-10-27 14:45:01.479739	1	2014-10-27 14:45:01.479739	\N
8	8	2	Total Consumed Quantity	t	8	U	t	1	2014-10-27 14:45:01.479739	1	2014-10-27 14:45:01.479739	\N
9	9	2	Total Losses / Adjustments	t	9	U	t	1	2014-10-27 14:45:01.479739	1	2014-10-27 14:45:01.479739	\N
10	10	2	Stock on Hand	t	10	C	t	1	2014-10-27 14:45:01.479739	1	2014-10-27 14:45:01.479739	\N
11	11	2	Total number of new patients added to service on the program	t	11	U	t	1	2014-10-27 14:45:01.479739	1	2014-10-27 14:45:01.479739	1
12	12	2	Total Stockout Days	t	12	U	t	1	2014-10-27 14:45:01.479739	1	2014-10-27 14:45:01.479739	\N
13	14	2	Average Monthly Consumption(AMC)	t	13	C	t	1	2014-10-27 14:45:01.479739	1	2014-10-27 14:45:01.479739	\N
14	15	2	Maximum Stock Quantity	t	14	C	t	1	2014-10-27 14:45:01.479739	1	2014-10-27 14:45:01.479739	\N
15	16	2	Calculated Order Quantity	t	15	C	t	1	2014-10-27 14:45:01.479739	1	2014-10-27 14:45:01.479739	\N
16	17	2	Requested Quantity	t	16	U	t	1	2014-10-27 14:45:01.479739	1	2014-10-27 14:45:01.479739	\N
17	18	2	Requested Quantity Explanation	t	17	U	t	1	2014-10-27 14:45:01.479739	1	2014-10-27 14:45:01.479739	\N
18	19	2	Approved Quantity	t	18	U	t	1	2014-10-27 14:45:01.479739	1	2014-10-27 14:45:01.479739	\N
19	20	2	Packs to Ship	t	19	C	t	1	2014-10-27 14:45:01.479739	1	2014-10-27 14:45:01.479739	\N
20	21	2	Price per Pack	t	20	R	t	1	2014-10-27 14:45:01.479739	1	2014-10-27 14:45:01.479739	\N
21	22	2	Total Cost	t	21	C	t	1	2014-10-27 14:45:01.479739	1	2014-10-27 14:45:01.479739	\N
22	23	2	Expiration Date	t	22	U	t	1	2014-10-27 14:45:01.479739	1	2014-10-27 14:45:01.479739	\N
23	24	2	Remarks	t	23	U	t	1	2014-10-27 14:45:01.479739	1	2014-10-27 14:45:01.479739	\N
24	25	2	Period Normalized Consumption	t	24	C	t	1	2014-10-27 14:45:01.479739	1	2014-10-27 14:45:01.479739	\N
25	13	2	Monthly Normalized Consumption	t	25	C	t	1	2014-10-27 14:45:01.479739	1	2014-10-27 14:45:01.479739	\N
\.


--
-- Name: program_rnr_columns_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('program_rnr_columns_id_seq', 25, true);


--
-- Data for Name: programs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY programs (id, code, name, description, active, templateconfigured, regimentemplateconfigured, budgetingapplies, usesdar, push, sendfeed, createdby, createddate, modifiedby, modifieddate) FROM stdin;
1	HIV	HIV	HIV	t	f	f	f	f	f	f	\N	2014-10-27 12:28:16.473287	\N	2014-10-27 12:28:16.473287
3	TB	TB	TB	t	f	f	f	f	f	f	\N	2014-10-27 12:28:16.473287	\N	2014-10-27 12:28:16.473287
4	MALARIA	MALARIA	MALARIA	t	f	f	t	f	f	f	\N	2014-10-27 12:28:16.473287	\N	2014-10-27 12:28:16.473287
5	VACCINES	VACCINES	VACCINES	t	f	f	f	f	t	f	\N	2014-10-27 12:28:16.473287	\N	2014-10-27 12:28:16.473287
2	ESS_MEDS	ESSENTIAL MEDICINES	ESSENTIAL MEDICINES	t	t	t	t	f	f	t	\N	2014-10-27 12:28:16.473287	\N	2014-10-27 12:28:16.473287
\.


--
-- Name: programs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('programs_id_seq', 5, true);


--
-- Data for Name: programs_supported; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY programs_supported (id, facilityid, programid, startdate, active, createdby, createddate, modifiedby, modifieddate) FROM stdin;
1	1	2	2010-10-01 00:00:00	t	1	2014-10-27 13:31:34.76342	1	\N
2	2	2	2004-10-01 00:00:00	t	1	2014-10-27 13:33:55.929233	1	\N
\.


--
-- Name: programs_supported_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('programs_supported_id_seq', 2, true);


--
-- Data for Name: refrigerator_problems; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY refrigerator_problems (id, readingid, operatorerror, burnerproblem, gasleakage, egpfault, thermostatsetting, other, otherproblemexplanation, createdby, createddate, modifiedby, modifieddate) FROM stdin;
\.


--
-- Name: refrigerator_problems_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('refrigerator_problems_id_seq', 1, false);


--
-- Data for Name: refrigerator_readings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY refrigerator_readings (id, temperature, functioningcorrectly, lowalarmevents, highalarmevents, problemsincelasttime, notes, refrigeratorid, refrigeratorserialnumber, refrigeratorbrand, refrigeratormodel, facilityvisitid, createdby, createddate, modifiedby, modifieddate) FROM stdin;
\.


--
-- Data for Name: refrigerators; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY refrigerators (id, brand, model, serialnumber, facilityid, createdby, createddate, modifiedby, modifieddate, enabled) FROM stdin;
\.


--
-- Name: refrigerators_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('refrigerators_id_seq', 1, false);


--
-- Data for Name: regimen_categories; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY regimen_categories (id, code, name, displayorder, createdby, createddate, modifiedby, modifieddate) FROM stdin;
1	ADULTS	Adults	1	\N	2014-10-27 12:28:16.498512	\N	2014-10-27 12:28:16.498512
2	PAEDIATRICS	Paediatrics	2	\N	2014-10-27 12:28:16.498512	\N	2014-10-27 12:28:16.498512
\.


--
-- Name: regimen_categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('regimen_categories_id_seq', 2, true);


--
-- Data for Name: regimen_line_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY regimen_line_items (id, code, name, regimendisplayorder, regimencategory, regimencategorydisplayorder, rnrid, patientsontreatment, patientstoinitiatetreatment, patientsstoppedtreatment, remarks, createdby, createddate, modifiedby, modifieddate) FROM stdin;
\.


--
-- Name: regimen_line_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('regimen_line_items_id_seq', 1, false);


--
-- Data for Name: regimens; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY regimens (id, programid, categoryid, code, name, active, displayorder, createdby, createddate, modifiedby, modifieddate) FROM stdin;
\.


--
-- Name: regimens_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('regimens_id_seq', 1, false);


--
-- Data for Name: report_rights; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY report_rights (id, templateid, rightname) FROM stdin;
1	3	Facilities Missing Supporting Requisition Group
2	4	Facilities Missing Create Requisition Role
3	5	Facilities Missing Authorize Requisition Role
4	6	Supervisory Nodes Missing Approve Requisition Role
5	7	Requisition Groups Missing Supply Line
6	8	Order Routing Inconsistencies
7	9	Delivery Zones Missing Manage Distribution Role
\.


--
-- Name: report_rights_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('report_rights_id_seq', 7, true);


--
-- Name: report_templates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('report_templates_id_seq', 9, true);


--
-- Data for Name: requisition_group_members; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY requisition_group_members (id, requisitiongroupid, facilityid, createdby, createddate, modifiedby, modifieddate) FROM stdin;
1	1	1	1	2014-10-27 15:30:54.599727	1	2014-10-27 15:30:54.599727
\.


--
-- Name: requisition_group_members_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('requisition_group_members_id_seq', 1, true);


--
-- Data for Name: requisition_group_program_schedules; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY requisition_group_program_schedules (id, requisitiongroupid, programid, scheduleid, directdelivery, dropofffacilityid, createdby, createddate, modifiedby, modifieddate) FROM stdin;
2	1	2	1	f	1	1	2014-10-27 15:30:54.564912	1	2014-10-27 15:30:54.564912
\.


--
-- Name: requisition_group_program_schedules_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('requisition_group_program_schedules_id_seq', 2, true);


--
-- Data for Name: requisition_groups; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY requisition_groups (id, code, name, description, supervisorynodeid, createdby, createddate, modifiedby, modifieddate) FROM stdin;
1	group_1	Group 1	\N	1	1	2014-10-27 14:30:37.149893	1	2014-10-27 15:30:54.533156
\.


--
-- Name: requisition_groups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('requisition_groups_id_seq', 1, true);


--
-- Data for Name: requisition_line_item_losses_adjustments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY requisition_line_item_losses_adjustments (requisitionlineitemid, type, quantity, createdby, createddate, modifiedby, modifieddate) FROM stdin;
\.


--
-- Data for Name: requisition_line_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY requisition_line_items (id, rnrid, productcode, product, productdisplayorder, productcategory, productcategorydisplayorder, dispensingunit, beginningbalance, quantityreceived, quantitydispensed, stockinhand, quantityrequested, reasonforrequestedquantity, calculatedorderquantity, quantityapproved, totallossesandadjustments, newpatientcount, stockoutdays, normalizedconsumption, amc, maxmonthsofstock, maxstockquantity, packstoship, price, expirationdate, remarks, dosespermonth, dosesperdispensingunit, packsize, roundtozero, packroundingthreshold, fullsupply, skipped, reportingdays, createdby, createddate, modifiedby, modifieddate, previousnormalizedconsumptions, previousstockinhand, periodnormalizedconsumption) FROM stdin;
\.


--
-- Name: requisition_line_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('requisition_line_items_id_seq', 1, false);


--
-- Data for Name: requisition_status_changes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY requisition_status_changes (id, rnrid, status, createdby, createddate, modifiedby, modifieddate, username) FROM stdin;
\.


--
-- Name: requisition_status_changes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('requisition_status_changes_id_seq', 1, false);


--
-- Data for Name: requisitions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY requisitions (id, facilityid, programid, periodid, status, emergency, fullsupplyitemssubmittedcost, nonfullsupplyitemssubmittedcost, supervisorynodeid, createdby, createddate, modifiedby, modifieddate, allocatedbudget) FROM stdin;
\.


--
-- Name: requisitions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('requisitions_id_seq', 1, false);


--
-- Data for Name: rights; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY rights (name, righttype, description, createddate, displayorder, displaynamekey) FROM stdin;
CONFIGURE_RNR	ADMIN	Permission to create and edit r&r template for any program	2014-10-27 12:27:35.675969	1	right.configure.rnr
MANAGE_FACILITY	ADMIN	Permission to manage facilities(crud)	2014-10-27 12:27:35.675969	2	right.manage.facility
MANAGE_ROLE	ADMIN	Permission to create and edit roles in the system	2014-10-27 12:27:35.675969	5	right.manage.role
MANAGE_SCHEDULE	ADMIN	Permission to create and edit schedules in the system	2014-10-27 12:27:35.675969	6	right.manage.schedule
MANAGE_USER	ADMIN	Permission to create and view users	2014-10-27 12:27:35.675969	7	right.manage.user
MANAGE_SUPERVISORY_NODE	ADMIN	Permission to manage supervisory nodes	2014-10-27 12:27:37.740835	8	right.manage.supervisory.node
UPLOADS	ADMIN	Permission to upload	2014-10-27 12:27:35.675969	21	right.upload
VIEW_REQUISITION	REQUISITION	Permission to view requisition	2014-10-27 12:27:35.675969	16	right.view.requisition
CREATE_REQUISITION	REQUISITION	Permission to create, edit, submit and recall requisitions	2014-10-27 12:27:35.675969	15	right.create.requisition
AUTHORIZE_REQUISITION	REQUISITION	Permission to edit, authorize and recall requisitions	2014-10-27 12:27:35.675969	13	right.authorize.requisition
APPROVE_REQUISITION	REQUISITION	Permission to approve requisitions	2014-10-27 12:27:35.675969	12	right.approve.requisition
CONVERT_TO_ORDER	FULFILLMENT	Permission to convert requisitions to order	2014-10-27 12:27:35.675969	14	right.convert.to.order
VIEW_ORDER	FULFILLMENT	Permission to view orders	2014-10-27 12:27:35.675969	17	right.view.order
MANAGE_PROGRAM_PRODUCT	ADMIN	Permission to manage program products	2014-10-27 12:27:35.675969	3	right.manage.program.product
MANAGE_DISTRIBUTION	ALLOCATION	Permission to manage an distribution	2014-10-27 12:27:35.675969	9	right.manage.distribution
SYSTEM_SETTINGS	ADMIN	Permission to configure Electronic Data Interchange (EDI)	2014-10-27 12:27:35.675969	18	right.system.settings
MANAGE_REGIMEN_TEMPLATE	ADMIN	Permission to manage a regimen template	2014-10-27 12:27:35.675969	4	right.manage.regimen.template
FACILITY_FILL_SHIPMENT	FULFILLMENT	Permission to fill shipment data for facility	2014-10-27 12:27:35.675969	19	right.fulfillment.fill.shipment
MANAGE_POD	FULFILLMENT	Permission to manage proof of delivery	2014-10-27 12:27:35.675969	20	right.fulfillment.manage.pod
MANAGE_GEOGRAPHIC_ZONE	ADMIN	Permission to manage geographic zones	2014-10-27 12:27:37.750064	23	right.manage.geo.zone
MANAGE_REQUISITION_GROUP	ADMIN	Permission to manage requisition groups	2014-10-27 12:27:37.763661	24	right.manage.requisition.group
MANAGE_SUPPLY_LINE	ADMIN	Permission to manage supply lines	2014-10-27 12:27:37.775721	25	right.manage.supply.line
MANAGE_FACILITY_APPROVED_PRODUCT	ADMIN	Permission to manage facility approved products	2014-10-27 12:27:37.792829	26	right.manage.facility.approved.products
MANAGE_PRODUCT	ADMIN	Permission to manage products	2014-10-27 12:27:37.784416	27	right.manage.products
MANAGE_REPORT	REPORTING	Permission to manage reports	2014-10-27 12:27:35.675969	10	right.manage.report
Facilities Missing Supporting Requisition Group	REPORTING	\N	2014-10-27 12:28:16.554101	\N	\N
Facilities Missing Create Requisition Role	REPORTING	\N	2014-10-27 12:28:16.554101	\N	\N
Facilities Missing Authorize Requisition Role	REPORTING	\N	2014-10-27 12:28:16.554101	\N	\N
Supervisory Nodes Missing Approve Requisition Role	REPORTING	\N	2014-10-27 12:28:16.554101	\N	\N
Requisition Groups Missing Supply Line	REPORTING	\N	2014-10-27 12:28:16.554101	\N	\N
Order Routing Inconsistencies	REPORTING	\N	2014-10-27 12:28:16.554101	\N	\N
Delivery Zones Missing Manage Distribution Role	REPORTING	\N	2014-10-27 12:28:16.554101	\N	\N
\.


--
-- Data for Name: role_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY role_assignments (userid, roleid, programid, supervisorynodeid, deliveryzoneid) FROM stdin;
1	1	\N	\N	\N
2	2	2	\N	\N
4	4	2	1	\N
4	6	2	\N	1
\.


--
-- Data for Name: role_rights; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY role_rights (roleid, rightname, createdby, createddate) FROM stdin;
2	CREATE_REQUISITION	1	2014-10-27 13:19:56.308055
2	VIEW_REQUISITION	1	2014-10-27 13:19:56.308055
1	CONFIGURE_RNR	1	2014-10-27 13:24:11.956907
1	MANAGE_FACILITY	1	2014-10-27 13:24:12.034464
1	MANAGE_ROLE	1	2014-10-27 13:24:12.03696
1	MANAGE_SCHEDULE	1	2014-10-27 13:24:12.039321
1	MANAGE_USER	1	2014-10-27 13:24:12.042296
1	UPLOADS	1	2014-10-27 13:24:12.044748
1	MANAGE_PROGRAM_PRODUCT	1	2014-10-27 13:24:12.047437
1	SYSTEM_SETTINGS	1	2014-10-27 13:24:12.049791
1	MANAGE_REGIMEN_TEMPLATE	1	2014-10-27 13:24:12.052378
1	MANAGE_SUPERVISORY_NODE	1	2014-10-27 13:24:12.055463
1	MANAGE_GEOGRAPHIC_ZONE	1	2014-10-27 13:24:12.057701
1	MANAGE_REQUISITION_GROUP	1	2014-10-27 13:24:12.05996
1	MANAGE_SUPPLY_LINE	1	2014-10-27 13:24:12.061899
1	MANAGE_FACILITY_APPROVED_PRODUCT	1	2014-10-27 13:24:12.063676
1	MANAGE_PRODUCT	1	2014-10-27 13:24:12.065585
4	AUTHORIZE_REQUISITION	1	2014-10-27 13:25:26.461041
4	VIEW_REQUISITION	1	2014-10-27 13:25:26.461041
4	APPROVE_REQUISITION	1	2014-10-27 13:25:26.461041
6	MANAGE_DISTRIBUTION	1	2014-10-27 15:56:15.026509
3	VIEW_ORDER	1	2014-10-28 08:57:05.653809
5	CONVERT_TO_ORDER	1	2014-10-28 08:57:22.61109
5	VIEW_ORDER	1	2014-10-28 08:57:22.615165
5	MANAGE_POD	1	2014-10-28 08:57:22.618305
\.


--
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY roles (id, name, description, createdby, createddate, modifiedby, modifieddate) FROM stdin;
2	Clinic	\N	1	2014-10-27 13:19:56.308055	1	2014-10-27 13:19:56.308055
1	Admin	Admin	\N	2014-10-27 12:27:35.693982	1	2014-10-27 13:24:11.931053
4	Secretariat Requisition Manager	\N	1	2014-10-27 13:25:26.461041	1	2014-10-27 13:25:26.461041
6	Secretariat Allocation Manager	\N	1	2014-10-27 15:56:15.026509	1	2014-10-27 15:56:15.026509
3	Vendor	\N	1	2014-10-27 13:22:58.134127	1	2014-10-28 08:57:05.626175
5	Secretariat Order Manager	\N	1	2014-10-27 13:26:12.478298	1	2014-10-28 08:57:22.591591
\.


--
-- Name: roles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('roles_id_seq', 6, true);


--
-- Data for Name: schema_version; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY schema_version (version, description, type, script, checksum, installed_by, installed_on, execution_time, state, current_version) FROM stdin;
0	<< Flyway Init >>	INIT	<< Flyway Init >>	\N	postgres	2014-10-27 12:27:33.254174	0	SUCCESS	f
2.1	create programs	SQL	V2_1__create_programs.sql	-1499951472	postgres	2014-10-27 12:27:34.145867	109	SUCCESS	f
3	create master rnr columns	SQL	V3__create_master_rnr_columns.sql	870159188	postgres	2014-10-27 12:27:34.277492	29	SUCCESS	f
3.1	insert master rnr columns	SQL	V3_1__insert_master_rnr_columns.sql	786556896	postgres	2014-10-27 12:27:34.886717	133	SUCCESS	f
3.2	create master regimen columns	SQL	V3_2__create_master_regimen_columns.sql	-2057735256	postgres	2014-10-27 12:27:35.033029	3	SUCCESS	f
3.3	insert master regimen columns	SQL	V3_3__insert_master_regimen_columns.sql	-533069137	postgres	2014-10-27 12:27:35.047744	2	SUCCESS	f
4	create program rnr columns	SQL	V4__create_program_rnr_columns.sql	-2061262395	postgres	2014-10-27 12:27:35.060793	13	SUCCESS	f
5	create dosage units	SQL	V5__create_dosage_units.sql	-2003377209	postgres	2014-10-27 12:27:35.083924	8	SUCCESS	f
5.2	create product forms	SQL	V5_2__create_product_forms.sql	-1281268964	postgres	2014-10-27 12:27:35.103321	16	SUCCESS	f
5.3	create product categories	SQL	V5_3__create_product_categories.sql	393589330	postgres	2014-10-27 12:27:35.142178	11	SUCCESS	f
5.4	create product groups	SQL	V5_4__create_product_groups.sql	-1450586662	postgres	2014-10-27 12:27:35.167824	8	SUCCESS	f
5.5	create products	SQL	V5_5__create_products.sql	-171824887	postgres	2014-10-27 12:27:35.187393	28	SUCCESS	f
6	create geographic levels	SQL	V6__create_geographic_levels.sql	-2111855007	postgres	2014-10-27 12:27:35.226463	7	SUCCESS	f
7	create geographic zones	SQL	V7__create_geographic_zones.sql	164851985	postgres	2014-10-27 12:27:35.242929	7	SUCCESS	f
8	create facility types	SQL	V8__create_facility_types.sql	1258376520	postgres	2014-10-27 12:27:35.257877	9	SUCCESS	f
9	create facility operators	SQL	V9__create_facility_operators.sql	-477993200	postgres	2014-10-27 12:27:35.274311	8	SUCCESS	f
10	create facilities	SQL	V10__create_facilities.sql	1874213993	postgres	2014-10-27 12:27:35.291793	23	SUCCESS	f
11	create programs supported	SQL	V11__create_programs_supported.sql	544780572	postgres	2014-10-27 12:27:35.322381	8	SUCCESS	f
12	create program products	SQL	V12__create_program_products.sql	-730017834	postgres	2014-10-27 12:27:35.337747	10	SUCCESS	f
12.1	create program product price history	SQL	V12_1__create_program_product_price_history.sql	993330740	postgres	2014-10-27 12:27:35.356848	7	SUCCESS	f
13	create processing schedules	SQL	V13__create_processing_schedules.sql	601837709	postgres	2014-10-27 12:27:35.371069	6	SUCCESS	f
13.1	create processing periods	SQL	V13_1__create_processing_periods.sql	-147033262	postgres	2014-10-27 12:27:35.387839	9	SUCCESS	f
14	create facility approved products	SQL	V14__create_facility_approved_products.sql	1323671548	postgres	2014-10-27 12:27:35.407888	15	SUCCESS	f
15	create roles	SQL	V15__create_roles.sql	-157312182	postgres	2014-10-27 12:27:35.432192	11	SUCCESS	f
16	create rights	SQL	V16__create_rights.sql	623186151	postgres	2014-10-27 12:27:35.450143	4	SUCCESS	f
17	create role rights	SQL	V17__create_role_rights.sql	943429904	postgres	2014-10-27 12:27:35.461557	5	SUCCESS	f
18.1	create users	SQL	V18_1__create_users.sql	-2135664387	postgres	2014-10-27 12:27:35.474602	16	SUCCESS	f
18.2	create supervisory nodes	SQL	V18_2__create_supervisory_nodes.sql	-1461298773	postgres	2014-10-27 12:27:35.498263	31	SUCCESS	f
18.3	create user password reset tokens	SQL	V18_3__create_user_password_reset_tokens.sql	-1272043023	postgres	2014-10-27 12:27:35.538209	4	SUCCESS	f
18.5	create delivery zones	SQL	V18_5__create_delivery_zones.sql	-1099615968	postgres	2014-10-27 12:27:35.551056	6	SUCCESS	f
18.6	create delivery zone program schedules	SQL	V18_6__create_delivery_zone_program_schedules.sql	493393408	postgres	2014-10-27 12:27:35.563842	9	SUCCESS	f
18.7	create delivery zone members	SQL	V18_7__create_delivery_zone_members.sql	49039087	postgres	2014-10-27 12:27:35.580273	7	SUCCESS	f
18.8	delivery zone warehouses	SQL	V18_8__delivery_zone_warehouses.sql	1440796615	postgres	2014-10-27 12:27:35.596569	8	SUCCESS	f
19	create role assignments	SQL	V19__create_role_assignments.sql	1693486546	postgres	2014-10-27 12:27:35.620881	20	SUCCESS	f
19.1	create fulfillment role assignments	SQL	V19_1__create_fulfillment_role_assignments.sql	1525574354	postgres	2014-10-27 12:27:35.651086	5	SUCCESS	f
20	insert rights	SQL	V20__insert_rights.sql	1606977930	postgres	2014-10-27 12:27:35.665665	6	SUCCESS	f
21	insert admin	SQL	V21__insert_admin.sql	1210399529	postgres	2014-10-27 12:27:35.679999	17	SUCCESS	f
22	create requisition groups	SQL	V22__create_requisition_groups.sql	1613821970	postgres	2014-10-27 12:27:35.706485	13	SUCCESS	f
23	create requisition group members	SQL	V23__create_requisition_group_members.sql	1545082080	postgres	2014-10-27 12:27:35.731384	10	SUCCESS	f
26	create requisition group program schedules	SQL	V26__create_requisition_group_program_schedules.sql	1366535474	postgres	2014-10-27 12:27:35.754946	16	SUCCESS	f
27	create supply lines	SQL	V27__create_supply_lines.sql	1437235334	postgres	2014-10-27 12:27:35.781131	10	SUCCESS	f
28	create losses adjustments types	SQL	V28__create_losses_adjustments_types.sql	710390479	postgres	2014-10-27 12:27:35.809855	4	SUCCESS	f
28.1	insert losses adjustments types	SQL	V28_1__insert_losses_adjustments_types.sql	2099929447	postgres	2014-10-27 12:27:35.822271	29	SUCCESS	f
33	create requisitions	SQL	V33__create_requisitions.sql	16114982	postgres	2014-10-27 12:27:35.85815	11	SUCCESS	f
33.1	create requisition line items	SQL	V33_1__create_requisition_line_items.sql	21663023	postgres	2014-10-27 12:27:35.876077	39	SUCCESS	f
34	create comments	SQL	V34__create_comments.sql	-603398476	postgres	2014-10-27 12:27:35.95114	6	SUCCESS	f
33.2	create requisition line item losses adjustments	SQL	V33_2__create_requisition_line_item_losses_adjustments.sql	-329788086	postgres	2014-10-27 12:27:35.921865	7	SUCCESS	f
33.4	create requisition status changes	SQL	V33_4__create_requisition_status_changes.sql	2118193325	postgres	2014-10-27 12:27:35.936191	8	SUCCESS	f
35.1	create shipment file info	SQL	V35_1__create_shipment_file_info.sql	992238024	postgres	2014-10-27 12:27:35.964363	3	SUCCESS	f
35.2	create orders	SQL	V35_2__create_orders.sql	-285982423	postgres	2014-10-27 12:27:35.974568	6	SUCCESS	f
35.3	create shipment line items	SQL	V35_3__create_shipment_line_items.sql	39999455	postgres	2014-10-27 12:27:35.98771	8	SUCCESS	f
37	create report template	SQL	V37__create_report_template.sql	1677789943	postgres	2014-10-27 12:27:36.005194	6	SUCCESS	f
38.1	create atom feed schema	SQL	V38_1__create_atom_feed_schema.sql	1675114314	postgres	2014-10-27 12:27:36.018442	14	SUCCESS	f
39	create email notifications	SQL	V39__create_email_notifications.sql	653085705	postgres	2014-10-27 12:27:36.039573	5	SUCCESS	f
40	create program product isa	SQL	V40__create_program_product_isa.sql	924792944	postgres	2014-10-27 12:27:36.051433	10	SUCCESS	f
41	create facility program products	SQL	V41__create_facility_program_products.sql	-93153395	postgres	2014-10-27 12:27:36.068069	7	SUCCESS	f
42	create regimen categories	SQL	V42__create_regimen_categories.sql	-1277504789	postgres	2014-10-27 12:27:36.083327	5	SUCCESS	f
42.1	create regimens	SQL	V42_1__create_regimens.sql	709911915	postgres	2014-10-27 12:27:36.096576	10	SUCCESS	f
43	create program regimen columns	SQL	V43__create_program_regimen_columns.sql	-501251727	postgres	2014-10-27 12:27:36.113525	6	SUCCESS	f
44	create regimen line items	SQL	V44__create_regimen_line_items.sql	393574013	postgres	2014-10-27 12:27:36.126758	8	SUCCESS	f
45	create distributions	SQL	V45__create_distributions.sql	619122949	postgres	2014-10-27 12:27:36.141748	14	SUCCESS	f
46	create refrigerators	SQL	V46__create_refrigerators.sql	-1203982890	postgres	2014-10-27 12:27:36.165302	12	SUCCESS	f
47	create distribution refrigerator readings	SQL	V47__create_distribution_refrigerator_readings.sql	-286005308	postgres	2014-10-27 12:27:36.187042	12	SUCCESS	f
47.1	create facility visit	SQL	V47_1__create_facility_visit.sql	752645462	postgres	2014-10-27 12:27:36.214868	11	SUCCESS	f
48	create rg program supply line function	SQL	V48__create_rg_program_supply_line_function.sql	-1266839849	postgres	2014-10-27 12:27:36.235681	62	SUCCESS	f
49	create facility ftp details	SQL	V49__create_facility_ftp_details.sql	-1402472008	postgres	2014-10-27 12:27:36.307016	8	SUCCESS	f
50	create order configuration	SQL	V50__create_order_configuration.sql	1171602640	postgres	2014-10-27 12:27:36.323309	5	SUCCESS	f
51	create order file columns	SQL	V51__create_order_file_columns.sql	-1310171840	postgres	2014-10-27 12:27:36.342145	9	SUCCESS	f
52	create shipment configuration	SQL	V52__create_shipment_configuration.sql	1105398747	postgres	2014-10-27 12:27:36.360793	4	SUCCESS	f
52.1	create shipment file columns	SQL	V52_1__create_shipment_file_columns.sql	-1462266968	postgres	2014-10-27 12:27:36.372673	6	SUCCESS	f
53	create budget configuration	SQL	V53__create_budget_configuration.sql	1142138838	postgres	2014-10-27 12:27:36.386353	4	SUCCESS	f
53.1	create budget file columns	SQL	V53_1__create_budget_file_columns.sql	1734382827	postgres	2014-10-27 12:27:36.412122	10	SUCCESS	f
54	create pod	SQL	V54__create_pod.sql	956695566	postgres	2014-10-27 12:27:36.430199	5	SUCCESS	f
54.1	create pod line items	SQL	V54_1__create_pod_line_items.sql	-1627422604	postgres	2014-10-27 12:27:36.44231	7	SUCCESS	f
55	add name to rnr status change	SQL	V55__add_name_to_rnr_status_change.sql	859452128	postgres	2014-10-27 12:27:36.457406	1	SUCCESS	f
56	add previous normalized consumption requisition line items	SQL	V56__add_previous_normalized_consumption_requisition_line_items.sql	-779107078	postgres	2014-10-27 12:27:36.466484	12	SUCCESS	f
57	change name length in rnr status change	SQL	V57__change_name_length_in_rnr_status_change.sql	-801451604	postgres	2014-10-27 12:27:36.485918	2	SUCCESS	f
58	add facilityid programid periodid to pod	SQL	V58__add_facilityid_programid_periodid_to_pod.sql	-1705538338	postgres	2014-10-27 12:27:36.497603	3	SUCCESS	f
59	create epi use	SQL	V59__create_epi_use.sql	-1162193878	postgres	2014-10-27 12:27:36.508802	6	SUCCESS	f
60	create epi use line items	SQL	V60__create_epi_use_line_items.sql	272935214	postgres	2014-10-27 12:27:36.527403	6	SUCCESS	f
61.1	create budget file info	SQL	V61_1__create_budget_file_info.sql	-543462961	postgres	2014-10-27 12:27:36.542289	6	SUCCESS	f
61.2	create budget line items	SQL	V61_2__create_budget_line_items.sql	-1524912646	postgres	2014-10-27 12:27:36.560658	11	SUCCESS	f
62	add audit columns epi use	SQL	V62__add_audit_columns_epi_use.sql	1019498883	postgres	2014-10-27 12:27:36.581496	7	SUCCESS	f
63	add audit columns epi use line items	SQL	V63__add_audit_columns_epi_use_line_items.sql	426049633	postgres	2014-10-27 12:27:36.596613	9	SUCCESS	f
64	add allocated budget to requisitions	SQL	V64__add_allocated_budget_to_requisitions.sql	56795132	postgres	2014-10-27 12:27:36.613969	2	SUCCESS	f
65	add facilityId programId remove facilityCode programCode	SQL	V65__add_facilityId_programId_remove_facilityCode_programCode.sql	-1253939728	postgres	2014-10-27 12:27:36.623425	6	SUCCESS	f
66	adding budgeting constraints in programs	SQL	V66__adding_budgeting_constraints_in_programs.sql	-1304533524	postgres	2014-10-27 12:27:36.638293	3	SUCCESS	f
67	create distribution refrigerators	SQL	V67__create_distribution_refrigerators.sql	-1529294992	postgres	2014-10-27 12:27:36.649449	8	SUCCESS	f
68.1	remove serialNumber facilityId distributionId refrigerator readings	SQL	V68_1__remove_serialNumber_facilityId_distributionId_refrigerator_readings.sql	922582837	postgres	2014-10-27 12:27:36.666447	11	SUCCESS	f
70.5	add enabled refrigerators	SQL	V70_5__add_enabled_refrigerators.sql	920330631	postgres	2014-10-27 12:27:36.80804	5	SUCCESS	f
68.2	rename distribution refrigerator readings	SQL	V68_2__rename_distribution_refrigerator_readings.sql	-176302726	postgres	2014-10-27 12:27:36.688751	2	SUCCESS	f
69	create refrigerator problems	SQL	V69__create_refrigerator_problems.sql	1834647244	postgres	2014-10-27 12:27:36.701903	24	SUCCESS	f
70.1	remove audit fields refrigerator readings	SQL	V70_1__remove_audit_fields_refrigerator_readings.sql	-2136643684	postgres	2014-10-27 12:27:36.739699	4	SUCCESS	f
70.2	remove audit fields refrigerator problems	SQL	V70_2__remove_audit_fields_refrigerator_problems.sql	-719976851	postgres	2014-10-27 12:27:36.754799	3	SUCCESS	f
70.3	add refrigeratorId refrigerator readings	SQL	V70_3__add_refrigeratorId_refrigerator_readings.sql	-1179341844	postgres	2014-10-27 12:27:36.768162	8	SUCCESS	f
70.4	add refrigerator serial brand model refrigerator reading	SQL	V70_4__add_refrigerator_serial_brand_model_refrigerator_reading.sql	1904237839	postgres	2014-10-27 12:27:36.793771	4	SUCCESS	f
70.6	drop unique serial add default false alter notes size	SQL	V70_6__drop_unique_serial_add_default_false_alter_notes_size.sql	-761658861	postgres	2014-10-27 12:27:36.823434	6	SUCCESS	f
71.1	create epi inventory line items	SQL	V71_1__create_epi_inventory_line_items.sql	-763144516	postgres	2014-10-27 12:27:36.852862	5	SUCCESS	f
72	create vaccination coverage	SQL	V72__create_vaccination_coverage.sql	622354150	postgres	2014-10-27 12:27:36.86456	5	SUCCESS	f
72.1	create vaccination full coverages	SQL	V72_1__create_vaccination_full_coverages.sql	-1130511723	postgres	2014-10-27 12:27:36.87634	5	SUCCESS	f
73	add sync status facility visit	SQL	V73__add_sync_status_facility_visit.sql	1807803437	postgres	2014-10-27 12:27:36.888284	6	SUCCESS	f
73.1	add facility visit id epi use line items	SQL	V73_1__add_facility_visit_id_epi_use_line_items.sql	393661385	postgres	2014-10-27 12:27:36.902675	2	SUCCESS	f
73.2	add facility visit id refrigerator readings	SQL	V73_2__add_facility_visit_id_refrigerator_readings.sql	-365946371	postgres	2014-10-27 12:27:36.912503	3	SUCCESS	f
73.3	add facility visit id full coverages	SQL	V73_3__add_facility_visit_id_full_coverages.sql	1009373706	postgres	2014-10-27 12:27:36.921954	7	SUCCESS	f
73.4	add facility visit id epi inventory line items	SQL	V73_4__add_facility_visit_id_epi_inventory_line_items.sql	471911987	postgres	2014-10-27 12:27:36.936723	2	SUCCESS	f
71	create epi inventory	SQL	V71__create_epi_inventory.sql	-921839903	postgres	2014-10-27 12:27:36.839462	5	SUCCESS	f
73.5	add program product id epi inventory line items	SQL	V73_5__add_program_product_id_epi_inventory_line_items.sql	-582852677	postgres	2014-10-27 12:27:36.946737	2	SUCCESS	f
73.6	add audit columns epi inventory line items	SQL	V73_6__add_audit_columns_epi_inventory_line_items.sql	1453234059	postgres	2014-10-27 12:27:36.955814	5	SUCCESS	f
73.7	add audit columns refrigerator readings	SQL	V73_7__add_audit_columns_refrigerator_readings.sql	2130063118	postgres	2014-10-27 12:27:36.968526	5	SUCCESS	f
73.8	add audit columns refrigerator problems	SQL	V73_8__add_audit_columns_refrigerator_problems.sql	54723799	postgres	2014-10-27 12:27:36.981683	4	SUCCESS	f
74	drop redundant vrmis form tables	SQL	V74__drop_redundant_vrmis_form_tables.sql	1270106477	postgres	2014-10-27 12:27:36.992873	7	SUCCESS	f
75	add unique constraints vrmis form tables	SQL	V75__add_unique_constraints_vrmis_form_tables.sql	1952463392	postgres	2014-10-27 12:27:37.007903	5	SUCCESS	f
76	add additional attributes pod line items	SQL	V76__add_additional_attributes_pod_line_items.sql	-643544243	postgres	2014-10-27 12:27:37.019953	3	SUCCESS	f
77	add category display order pod line items	SQL	V77__add_category_display_order_pod_line_items.sql	1251309334	postgres	2014-10-27 12:27:37.029725	2	SUCCESS	f
77.1	add product display order pod line items	SQL	V77_1__add_product_display_order_pod_line_items.sql	-1291959720	postgres	2014-10-27 12:27:37.038004	1	SUCCESS	f
78	create coverage vaccination products	SQL	V78__create_coverage_vaccination_products.sql	2072234817	postgres	2014-10-27 12:27:37.046426	5	SUCCESS	f
80	rename full coverage columns	SQL	V80__rename_full_coverage_columns.sql	679619293	postgres	2014-10-27 12:27:37.071499	2	SUCCESS	f
84	create coverage product vials	SQL	V84__create_coverage_product_vials.sql	-1693604720	postgres	2014-10-27 12:27:37.118829	5	SUCCESS	f
85	create opened vial line items	SQL	V85__create_opened_vial_line_items.sql	-1602929156	postgres	2014-10-27 12:27:37.131137	4	SUCCESS	f
86	add visit info facility visit	SQL	V86__add_visit_info_facility_visit.sql	-1243687684	postgres	2014-10-27 12:27:37.142558	2	SUCCESS	f
87	alter requisition alter cost precision	SQL	V87__alter_requisition_alter_cost_precision.sql	-346997777	postgres	2014-10-27 12:27:37.151908	9	SUCCESS	f
87.1	alter shipment line items alter cost precision	SQL	V87_1__alter_shipment_line_items_alter_cost_precision.sql	1746293090	postgres	2014-10-27 12:27:37.168737	4	SUCCESS	f
88	add catchment population facility visit	SQL	V88__add_catchment_population_facility_visit.sql	-1483354853	postgres	2014-10-27 12:27:37.180483	2	SUCCESS	f
79	create vaccination child coverage line items	SQL	V79__create_vaccination_child_coverage_line_items.sql	1104909056	postgres	2014-10-27 12:27:37.059524	5	SUCCESS	f
81	add columns to shipment line items	SQL	V81__add_columns_to_shipment_line_items.sql	-1977461106	postgres	2014-10-27 12:27:37.08046	2	SUCCESS	f
81.1	add more columns to shipment line items	SQL	V81_1__add_more_columns_to_shipment_line_items.sql	539571887	postgres	2014-10-27 12:27:37.089353	2	SUCCESS	f
82	alter unique constraint coverage vaccination products	SQL	V82__alter_unique_constraint_coverage_vaccination_products.sql	379003383	postgres	2014-10-27 12:27:37.098302	3	SUCCESS	f
83	remove numeric limit ideal quantity epi inventory line items	SQL	V83__remove_numeric_limit_ideal_quantity_epi_inventory_line_items.sql	-275799328	postgres	2014-10-27 12:27:37.108963	3	SUCCESS	f
89	add reason columns facility visit	SQL	V89__add_reason_columns_facility_visit.sql	-1940847709	postgres	2014-10-27 12:27:37.188913	2	SUCCESS	f
90.1	add user input fields child coverage line items	SQL	V90_1__add_user_input_fields_child_coverage_line_items.sql	24163026	postgres	2014-10-27 12:27:37.197181	4	SUCCESS	f
90.2	add audit fields opened vial line items	SQL	V90_2__add_audit_fields_opened_vial_line_items.sql	705492621	postgres	2014-10-27 12:27:37.209268	4	SUCCESS	f
91	add quantity returned pod line items	SQL	V91__add_quantity_returned_pod_line_items.sql	-1692175647	postgres	2014-10-27 12:27:37.22107	1	SUCCESS	f
92	rename coverage vaccination products	SQL	V92__rename_coverage_vaccination_products.sql	1340198469	postgres	2014-10-27 12:27:37.229237	2	SUCCESS	f
94	add audit columns pod	SQL	V94__add_audit_columns_pod.sql	1170419670	postgres	2014-10-27 12:27:37.250667	2	SUCCESS	f
93	create vaccination adult coverage line items	SQL	V93__create_vaccination_adult_coverage_line_items.sql	1874102245	postgres	2014-10-27 12:27:37.238903	5	SUCCESS	f
95	alter vaccination adult line item rename col	SQL	V95__alter_vaccination_adult_line_item_rename_col.sql	1197147998	postgres	2014-10-27 12:27:37.259186	2	SUCCESS	f
96	add flag coverage product vial 	SQL	V96__add_flag_coverage_product_vial_.sql	-788146780	postgres	2014-10-27 12:27:37.271245	2	SUCCESS	f
97	rename accepted by column pod	SQL	V97__rename_accepted_by_column_pod.sql	-255808652	postgres	2014-10-27 12:27:37.283324	1	SUCCESS	f
98	add coverage columns vaccination adult coverage line items	SQL	V98__add_coverage_columns_vaccination_adult_coverage_line_items.sql	-498650543	postgres	2014-10-27 12:27:37.293181	2	SUCCESS	f
99	rename opened vial line items	SQL	V99__rename_opened_vial_line_items.sql	-429507293	postgres	2014-10-27 12:27:37.302081	1	SUCCESS	f
100	create adult coverage opened vial line items	SQL	V100__create_adult_coverage_opened_vial_line_items.sql	1309987491	postgres	2014-10-27 12:27:37.310522	7	SUCCESS	f
101	remove not null constraint epi inventory line items	SQL	V101__remove_not_null_constraint_epi_inventory_line_items.sql	214777149	postgres	2014-10-27 12:27:37.324871	1	SUCCESS	f
101.1	rename report templates to templates and add type column	SQL	V101_1__rename_report_templates_to_templates_and_add_type_column.sql	665351096	postgres	2014-10-27 12:27:37.334164	2	SUCCESS	f
101.2	insert pod print template	SQL	V101_2__insert_pod_print_template.sql	258390745	postgres	2014-10-27 12:27:37.343484	24	SUCCESS	f
102	alter programs default push false	SQL	V102__alter_programs_default_push_false.sql	-1054030193	postgres	2014-10-27 12:27:37.37596	1	SUCCESS	f
103	remove non null constraint users	SQL	V103__remove_non_null_constraint_users.sql	-335334077	postgres	2014-10-27 12:27:37.38582	1	SUCCESS	f
104	alter pod add not null constraints	SQL	V104__alter_pod_add_not_null_constraints.sql	398389017	postgres	2014-10-27 12:27:37.395061	2	SUCCESS	f
105	rename name to username	SQL	V105__rename_name_to_username.sql	-1579529539	postgres	2014-10-27 12:27:37.405045	1	SUCCESS	f
106	alter refrigerators remove not null constraints	SQL	V106__alter_refrigerators_remove_not_null_constraints.sql	813563451	postgres	2014-10-27 12:27:37.413924	2	SUCCESS	f
107	insert product name order configuration	SQL	V107__insert_product_name_order_configuration.sql	-493649925	postgres	2014-10-27 12:27:37.424585	3	SUCCESS	f
108	alter refrigerators readings remove not null constraints	SQL	V108__alter_refrigerators_readings_remove_not_null_constraints.sql	813829472	postgres	2014-10-27 12:27:37.435407	2	SUCCESS	f
109	alter requisition line items add column previous stock in hand	SQL	V109__alter_requisition_line_items_add_column_previous_stock_in_hand.sql	2047372570	postgres	2014-10-27 12:27:37.444377	2	SUCCESS	f
110.1	add replaced product code to shipment file columns	SQL	V110_1__add_replaced_product_code_to_shipment_file_columns.sql	1794122942	postgres	2014-10-27 12:27:37.454388	2	SUCCESS	f
110.2	add replaced product code shipment line items	SQL	V110_2__add_replaced_product_code_shipment_line_items.sql	1478523474	postgres	2014-10-27 12:27:37.462976	1	SUCCESS	f
110.3	drop unique constraint orderId productCode	SQL	V110_3__drop_unique_constraint_orderId_productCode.sql	864562924	postgres	2014-10-27 12:27:37.471934	1	SUCCESS	f
111.1	insert period normalized consumption master rnr columns	SQL	V111_1__insert_period_normalized_consumption_master_rnr_columns.sql	-1996238387	postgres	2014-10-27 12:27:37.480548	2	SUCCESS	f
111.2	update adjusted normalized consumption	SQL	V111_2__update_adjusted_normalized_consumption.sql	778097169	postgres	2014-10-27 12:27:37.490935	1	SUCCESS	f
111.3	add period normalized consumption requisition line items	SQL	V111_3__add_period_normalized_consumption_requisition_line_items.sql	306254386	postgres	2014-10-27 12:27:37.500605	2	SUCCESS	f
112	add product category display order program products	SQL	V112__add_product_category_display_order_program_products.sql	1960367755	postgres	2014-10-27 12:27:37.511607	3	SUCCESS	f
113	add replaced product code pod line items	SQL	V113__add_replaced_product_code_pod_line_items.sql	1541958044	postgres	2014-10-27 12:27:37.540513	1	SUCCESS	f
114	drop unique constraint podId productCode	SQL	V114__drop_unique_constraint_podId_productCode.sql	-81060293	postgres	2014-10-27 12:27:37.551183	2	SUCCESS	f
115	remove categoryid displayorder products	SQL	V115__remove_categoryid_displayorder_products.sql	651841215	postgres	2014-10-27 12:27:37.564039	2	SUCCESS	f
116.1	configurable rnr options	SQL	V116_1__configurable_rnr_options.sql	1350434892	postgres	2014-10-27 12:27:37.57782	10	SUCCESS	f
116.2	adding rnr option id program rnr columns	SQL	V116_2__adding_rnr_option_id_program_rnr_columns.sql	2123042674	postgres	2014-10-27 12:27:37.602987	3	SUCCESS	f
119	add order number orders	SQL	V119__add_order_number_orders.sql	1834416732	postgres	2014-10-27 12:27:37.647124	1	SUCCESS	f
116.3	create master rnr column options	SQL	V116_3__create_master_rnr_column_options.sql	-1812221632	postgres	2014-10-27 12:27:37.613274	7	SUCCESS	f
117	create order number configuration	SQL	V117__create_order_number_configuration.sql	1100042567	postgres	2014-10-27 12:27:37.628065	3	SUCCESS	f
118	drop unique index rnrId status	SQL	V118__drop_unique_index_rnrId_status.sql	-2034303994	postgres	2014-10-27 12:27:37.638351	1	SUCCESS	f
112.1	Adding not null constraint product category program products	SQL	V112_1__Adding_not_null_constraint_product_category_program_products.sql	1910896370	postgres	2014-10-27 12:27:37.525603	1	SUCCESS	f
120	alter column order number orders	SQL	V120__alter_column_order_number_orders.sql	-839167739	postgres	2014-10-27 12:27:37.656184	1	SUCCESS	f
121	add order number shipment line items	SQL	V121__add_order_number_shipment_line_items.sql	812632972	postgres	2014-10-27 12:27:37.664955	2	SUCCESS	f
123	update shipment file column to orderNumber	SQL	V123__update_shipment_file_column_to_orderNumber.sql	1510615693	postgres	2014-10-27 12:27:37.685443	1	SUCCESS	f
124	add order number pod	SQL	V124__add_order_number_pod.sql	-1032712641	postgres	2014-10-27 12:27:37.696885	2	SUCCESS	f
125	update template pod print	SQL	V125__update_template_pod_print.sql	284512851	postgres	2014-10-27 12:27:37.70786	17	SUCCESS	f
126	insert manage supervisory node rights	SQL	V126__insert_manage_supervisory_node_rights.sql	-390479587	postgres	2014-10-27 12:27:37.734473	1	SUCCESS	f
127	insert manage geographic zone rights	SQL	V127__insert_manage_geographic_zone_rights.sql	-234212435	postgres	2014-10-27 12:27:37.743846	1	SUCCESS	f
128	insert manage requisition group rights	SQL	V128__insert_manage_requisition_group_rights.sql	1486121329	postgres	2014-10-27 12:27:37.753224	5	SUCCESS	f
129	insert manage supply line rights	SQL	V129__insert_manage_supply_line_rights.sql	1089633241	postgres	2014-10-27 12:27:37.769112	1	SUCCESS	f
130	insert manage facility approved product rights	SQL	V130__insert_manage_facility_approved_product_rights.sql	872669433	postgres	2014-10-27 12:27:37.778582	2	SUCCESS	f
122	remove non null constraint shipmentLineItems	SQL	V122__remove_non_null_constraint_shipmentLineItems.sql	968627094	postgres	2014-10-27 12:27:37.674894	4	SUCCESS	f
131	insert manage product rights	SQL	V131__insert_manage_product_rights.sql	1532147584	postgres	2014-10-27 12:27:37.787196	1	SUCCESS	f
132	alter max months of stock facility approved products	SQL	V132__alter_max_months_of_stock_facility_approved_products.sql	850891763	postgres	2014-10-27 12:27:37.796052	4	SUCCESS	f
133	alter max months of stock requisition line items	SQL	V133__alter_max_months_of_stock_requisition_line_items.sql	-1692894306	postgres	2014-10-27 12:27:37.808041	7	SUCCESS	f
134	update pod print template	SQL	V134__update_pod_print_template.sql	1364697435	postgres	2014-10-27 12:27:37.82265	12	SUCCESS	f
135	alter templates	SQL	V135__alter_templates.sql	-516211204	postgres	2014-10-27 12:27:37.842968	2	SUCCESS	f
136	create template parameters	SQL	V136__create_template_parameters.sql	24180827	postgres	2014-10-27 12:27:37.85236	6	SUCCESS	f
137	alter template parameters	SQL	V137__alter_template_parameters.sql	2117794705	postgres	2014-10-27 12:27:37.865793	2	SUCCESS	f
138	create report rights	SQL	V138__create_report_rights.sql	-1390464735	postgres	2014-10-27 12:27:37.877062	8	SUCCESS	f
139	alter template parameters	SQL	V139__alter_template_parameters.sql	-1630418232	postgres	2014-10-27 12:27:37.895212	2	SUCCESS	f
140	remove view report right	SQL	V140__remove_view_report_right.sql	-264865080	postgres	2014-10-27 12:27:37.905089	4	SUCCESS	f
141	alter rights	SQL	V141__alter_rights.sql	26675405	postgres	2014-10-27 12:27:37.916158	3	SUCCESS	f
142	update rights	SQL	V142__update_rights.sql	169050215	postgres	2014-10-27 12:27:37.926334	9	SUCCESS	f
143	delete role rights	SQL	V143__delete_role_rights.sql	-795569368	postgres	2014-10-27 12:27:37.942385	1	SUCCESS	t
\.


--
-- Data for Name: shipment_configuration; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY shipment_configuration (headerinfile, createdby, createddate, modifiedby, modifieddate) FROM stdin;
f	\N	2014-10-27 12:27:36.367495	\N	2014-10-27 12:27:36.367495
\.


--
-- Data for Name: shipment_file_columns; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY shipment_file_columns (id, name, datafieldlabel, "position", include, mandatory, datepattern, createdby, createddate, modifiedby, modifieddate) FROM stdin;
2	productCode	header.product.code	2	t	t	\N	\N	2014-10-27 12:27:36.380011	\N	2014-10-27 12:27:36.380011
3	quantityShipped	header.quantity.shipped	3	t	t	\N	\N	2014-10-27 12:27:36.380011	\N	2014-10-27 12:27:36.380011
4	cost	header.cost	4	f	f	\N	\N	2014-10-27 12:27:36.380011	\N	2014-10-27 12:27:36.380011
5	packedDate	header.packed.date	5	f	f	dd/MM/yy	\N	2014-10-27 12:27:36.380011	\N	2014-10-27 12:27:36.380011
6	shippedDate	header.shipped.date	6	f	f	dd/MM/yy	\N	2014-10-27 12:27:36.380011	\N	2014-10-27 12:27:36.380011
7	replacedProductCode	header.replaced.product.code	7	f	f	\N	\N	2014-10-27 12:27:37.460193	\N	2014-10-27 12:27:37.460193
1	orderNumber	header.order.number	1	t	t	\N	\N	2014-10-27 12:27:36.380011	\N	2014-10-27 12:27:36.380011
\.


--
-- Name: shipment_file_columns_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('shipment_file_columns_id_seq', 7, true);


--
-- Data for Name: shipment_file_info; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY shipment_file_info (id, filename, processingerror, modifieddate) FROM stdin;
\.


--
-- Name: shipment_file_info_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('shipment_file_info_id_seq', 1, false);


--
-- Data for Name: shipment_line_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY shipment_line_items (id, orderid, productcode, quantityshipped, cost, packeddate, shippeddate, createdby, createddate, modifiedby, modifieddate, productname, dispensingunit, productcategory, packstoship, productcategorydisplayorder, productdisplayorder, fullsupply, replacedproductcode, ordernumber) FROM stdin;
\.


--
-- Name: shipment_line_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('shipment_line_items_id_seq', 1, false);


--
-- Data for Name: supervisory_nodes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY supervisory_nodes (id, parentid, facilityid, name, code, description, createdby, createddate, modifiedby, modifieddate) FROM stdin;
1	\N	1	Node 1	node_1	\N	1	2014-10-27 13:38:35.796043	1	2014-10-27 13:38:35.796043
\.


--
-- Name: supervisory_nodes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('supervisory_nodes_id_seq', 1, true);


--
-- Data for Name: supply_lines; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY supply_lines (id, description, supervisorynodeid, programid, supplyingfacilityid, exportorders, createdby, createddate, modifiedby, modifieddate) FROM stdin;
1	\N	1	2	2	t	1	2014-10-27 14:34:54.273273	1	2014-10-27 14:49:08.712042
\.


--
-- Name: supply_lines_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('supply_lines_id_seq', 1, true);


--
-- Data for Name: template_parameters; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY template_parameters (id, templateid, name, displayname, description, createdby, createddate, defaultvalue, datatype) FROM stdin;
\.


--
-- Name: template_parameters_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('template_parameters_id_seq', 1, false);


--
-- Data for Name: templates; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY templates (id, name, data, createdby, createddate, type, description) FROM stdin;
2	Print POD	\\xaced0005737200286e65742e73662e6a61737065727265706f7274732e656e67696e652e4a61737065725265706f727400000000000027d80200034c000b636f6d70696c65446174617400164c6a6176612f696f2f53657269616c697a61626c653b4c0011636f6d70696c654e616d655375666669787400124c6a6176612f6c616e672f537472696e673b4c000d636f6d70696c6572436c61737371007e00027872002d6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655265706f727400000000000027d802002a49001950534555444f5f53455249414c5f56455253494f4e5f55494449000c626f74746f6d4d617267696e49000b636f6c756d6e436f756e7449000d636f6c756d6e53706163696e6749000b636f6c756d6e57696474685a001069676e6f7265506167696e6174696f6e5a00136973466c6f6174436f6c756d6e466f6f7465725a0010697353756d6d6172794e6577506167655a0020697353756d6d6172795769746850616765486561646572416e64466f6f7465725a000e69735469746c654e65775061676549000a6c6566744d617267696e42000b6f7269656e746174696f6e49000a7061676548656967687449000970616765576964746842000a7072696e744f7264657249000b72696768744d617267696e490009746f704d617267696e42000e7768656e4e6f44617461547970654c000a6261636b67726f756e647400244c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5242616e643b4c000f636f6c756d6e446972656374696f6e7400334c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f52756e446972656374696f6e456e756d3b4c000c636f6c756d6e466f6f74657271007e00044c000c636f6c756d6e48656164657271007e00045b000864617461736574737400285b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52446174617365743b4c000c64656661756c745374796c657400254c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525374796c653b4c000664657461696c71007e00044c000d64657461696c53656374696f6e7400274c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5253656374696f6e3b4c0012666f726d6174466163746f7279436c61737371007e00024c000a696d706f72747353657474000f4c6a6176612f7574696c2f5365743b4c00086c616e677561676571007e00024c000e6c61737450616765466f6f74657271007e00044c000b6d61696e446174617365747400274c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52446174617365743b4c00046e616d6571007e00024c00066e6f4461746171007e00044c00106f7269656e746174696f6e56616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4f7269656e746174696f6e456e756d3b4c000a70616765466f6f74657271007e00044c000a7061676548656164657271007e00044c000f7072696e744f7264657256616c75657400314c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5072696e744f72646572456e756d3b5b00067374796c65737400265b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525374796c653b4c000773756d6d61727971007e00045b000974656d706c6174657374002f5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525265706f727454656d706c6174653b4c00057469746c6571007e00044c00137768656e4e6f446174615479706556616c75657400354c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5768656e4e6f4461746154797065456e756d3b78700000c3540000000000000001000000000000034a00010000000000000000000002530000034a000000000000000000007372002b6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736542616e6400000000000027d802000749001950534555444f5f53455249414c5f56455253494f4e5f5549444900066865696768745a000e697353706c6974416c6c6f7765644c00137072696e745768656e45787072657373696f6e74002a4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5245787072657373696f6e3b4c000d70726f706572746965734d617074002d4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250726f706572746965734d61703b4c000973706c6974547970657400104c6a6176612f6c616e672f427974653b4c000e73706c69745479706556616c75657400304c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f53706c697454797065456e756d3b787200336e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365456c656d656e7447726f757000000000000027d80200024c00086368696c6472656e7400104c6a6176612f7574696c2f4c6973743b4c000c656c656d656e7447726f757074002c4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52456c656d656e7447726f75703b7870737200136a6176612e7574696c2e41727261794c6973747881d21d99c7619d03000149000473697a6578700000000077040000000078700000c35400000000017070707e72002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e53706c697454797065456e756d00000000000000001200007872000e6a6176612e6c616e672e456e756d00000000000000001200007870740007535452455443487e7200316e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e52756e446972656374696f6e456e756d00000000000000001200007871007e001d7400034c545270707070707372002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736553656374696f6e00000000000027d80200015b000562616e64737400255b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5242616e643b7870757200255b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5242616e643b95dd7eec8cca85350200007870000000017371007e00117371007e001a00000001770400000001737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655375627265706f727400000000000027d80200084c0014636f6e6e656374696f6e45787072657373696f6e71007e00124c001464617461536f7572636545787072657373696f6e71007e00124c000a65787072657373696f6e71007e00124c000c69735573696e6743616368657400134c6a6176612f6c616e672f426f6f6c65616e3b5b000a706172616d65746572737400335b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525375627265706f7274506172616d657465723b4c0017706172616d65746572734d617045787072657373696f6e71007e00125b000c72657475726e56616c7565737400355b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525375627265706f727452657475726e56616c75653b4c000b72756e546f426f74746f6d71007e002b7872002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365456c656d656e7400000000000027d802001b49001950534555444f5f53455249414c5f56455253494f4e5f5549444900066865696768745a001769735072696e74496e466972737457686f6c6542616e645a001569735072696e74526570656174656456616c7565735a001a69735072696e745768656e44657461696c4f766572666c6f77735a0015697352656d6f76654c696e655768656e426c616e6b42000c706f736974696f6e5479706542000b7374726574636854797065490005776964746849000178490001794c00096261636b636f6c6f727400104c6a6176612f6177742f436f6c6f723b4c001464656661756c745374796c6550726f76696465727400344c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5244656661756c745374796c6550726f76696465723b4c000c656c656d656e7447726f757071007e00184c0009666f7265636f6c6f7271007e002f4c00036b657971007e00024c00046d6f646571007e00144c00096d6f646556616c756574002b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4d6f6465456e756d3b4c000b706172656e745374796c6571007e00074c0018706172656e745374796c654e616d655265666572656e636571007e00024c0011706f736974696f6e5479706556616c75657400334c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f506f736974696f6e54797065456e756d3b4c00137072696e745768656e45787072657373696f6e71007e00124c00157072696e745768656e47726f75704368616e6765737400254c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5247726f75703b4c000d70726f706572746965734d617071007e00135b001370726f706572747945787072657373696f6e737400335b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250726f706572747945787072657373696f6e3b4c0010737472657463685479706556616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5374726574636854797065456e756d3b4c0004757569647400104c6a6176612f7574696c2f555549443b78700000c354000000320001000000000000034bffffffff000000017071007e001071007e00287070707070707e7200316e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e506f736974696f6e54797065456e756d00000000000000001200007871007e001d7400134649585f52454c41544956455f544f5f544f50707070707e7200306e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5374726574636854797065456e756d00000000000000001200007871007e001d74000a4e4f5f535452455443487372000e6a6176612e7574696c2e55554944bc9903f7986d852f0200024a000c6c65617374536967426974734a000b6d6f7374536967426974737870a29bbc0f9ddc781691c47d3bfabe42d7737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736545787072657373696f6e00000000000027d802000449000269645b00066368756e6b737400305b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5245787072657373696f6e4368756e6b3b4c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e0002787000000020757200305b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5245787072657373696f6e4368756e6b3b6d59cfde694ba355020000787000000001737200366e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736545787072657373696f6e4368756e6b00000000000027d8020002420004747970654c00047465787471007e00027870027400115245504f52545f434f4e4e454354494f4e7070707371007e0040000000217571007e0043000000037371007e0045017400234a6173706572436f6d70696c654d616e616765722e636f6d70696c655265706f7274287371007e00450274000d7375627265706f72745f6469727371007e00450174001c202b2022706f644c696e654974656d5072696e742e6a72786d6c2229707070757200335b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a525375627265706f7274506172616d657465723b5b039ca387c0be42020000787000000004737200396e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655375627265706f7274506172616d6574657200000000000027d8020000787200376e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736544617461736574506172616d6574657200000000000027d80200024c000a65787072657373696f6e71007e00124c00046e616d6571007e000278707371007e00400000001c7571007e0043000000017371007e004502740006706f645f69647070740006706f645f69647371007e00527371007e00400000001d7571007e0043000000017371007e004502740009696d6167655f6469727070740009696d6167655f6469727371007e00527371007e00400000001e7571007e0043000000017371007e00450274000d5245504f52545f4c4f43414c45707074000d5245504f52545f4c4f43414c457371007e00527371007e00400000001f7571007e0043000000017371007e0045027400165245504f52545f5245534f555243455f42554e444c4570707400165245504f52545f5245534f555243455f42554e444c4570707078700000c35400000033017070707070707400046a6176617371007e00117371007e001a000000017704000000017372002c6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365427265616b00000000000027d802000349001950534555444f5f53455249414c5f56455253494f4e5f554944420004747970654c00097479706556616c75657400304c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f427265616b54797065456e756d3b7871007e002e0000c354000000010001000000000000034a00000000000000037071007e001071007e006d70707070707071007e00397070707071007e003c7371007e003eb1195b40b96e24dd20d9368b1c7647aa0000c354007e72002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e427265616b54797065456e756d00000000000000001200007871007e001d7400045041474578700000c3540000000801707070707372002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173654461746173657400000000000027d802001149001950534555444f5f53455249414c5f56455253494f4e5f5549445a000669734d61696e4200177768656e5265736f757263654d697373696e67547970655b00066669656c64737400265b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a524669656c643b4c001066696c74657245787072657373696f6e71007e00125b000667726f7570737400265b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5247726f75703b4c00046e616d6571007e00025b000a706172616d657465727374002a5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52506172616d657465723b4c000d70726f706572746965734d617071007e00134c000571756572797400254c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5251756572793b4c000e7265736f7572636542756e646c6571007e00024c000e7363726970746c6574436c61737371007e00025b000a7363726970746c65747374002a5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525363726970746c65743b5b000a736f72744669656c647374002a5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52536f72744669656c643b4c00047575696471007e00365b00097661726961626c65737400295b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525661726961626c653b4c001c7768656e5265736f757263654d697373696e675479706556616c756574003e4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5768656e5265736f757263654d697373696e6754797065456e756d3b78700000c3540100757200265b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a524669656c643b023cdfc74e2af27002000078700000000e7372002c6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173654669656c6400000000000027d80200054c000b6465736372697074696f6e71007e00024c00046e616d6571007e00024c000d70726f706572746965734d617071007e00134c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e000278707074000c7265636569766564646174657372002b6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5250726f706572746965734d617000000000000027d80200034c00046261736571007e00134c000e70726f706572746965734c69737471007e00174c000d70726f706572746965734d617074000f4c6a6176612f7574696c2f4d61703b787070707074000e6a6176612e7574696c2e44617465707371007e00827074000a726563656976656462797371007e00857070707400106a6176612e6c616e672e537472696e67707371007e00827074000b64656c69766572656462797371007e00857070707400106a6176612e6c616e672e537472696e67707371007e0082707400076f7264657269647371007e008570707074000e6a6176612e6c616e672e4c6f6e67707371007e00827074000b63726561746564646174657371007e008570707074000e6a6176612e7574696c2e44617465707371007e008270740008666163696c6974797371007e00857070707400106a6176612e6c616e672e537472696e67707371007e008270740004747970657371007e00857070707400106a6176612e6c616e672e537472696e67707371007e00827074000e737570706c79696e676465706f747371007e00857070707400106a6176612e6c616e672e537472696e67707371007e00827074000770726f6772616d7371007e00857070707400106a6176612e6c616e672e537472696e67707371007e0082707400097374617274646174657371007e008570707074000e6a6176612e7574696c2e44617465707371007e008270740007656e64646174657371007e008570707074000e6a6176612e7574696c2e44617465707371007e008270740015746f74616c7175616e7469747972657475726e65647371007e00857070707400116a6176612e6c616e672e496e7465676572707371007e008270740014746f74616c7175616e74697479736869707065647371007e00857070707400116a6176612e6c616e672e496e7465676572707371007e008270740015746f74616c7175616e7469747972656365697665647371007e00857070707400116a6176612e6c616e672e496e74656765727070757200265b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5247726f75703b40a35f7a4cfd78ea0200007870000000017372002c6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736547726f757000000000000027d802001049001950534555444f5f53455249414c5f56455253494f4e5f55494442000e666f6f746572506f736974696f6e5a0019697352657072696e744865616465724f6e45616368506167655a001169735265736574506167654e756d6265725a0010697353746172744e6577436f6c756d6e5a000e697353746172744e6577506167655a000c6b656570546f6765746865724900176d696e486569676874546f53746172744e6577506167654c000d636f756e745661726961626c657400284c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525661726961626c653b4c000a65787072657373696f6e71007e00124c0013666f6f746572506f736974696f6e56616c75657400354c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f466f6f746572506f736974696f6e456e756d3b4c000b67726f7570466f6f74657271007e00044c001267726f7570466f6f74657253656374696f6e71007e00084c000b67726f757048656164657271007e00044c001267726f757048656164657253656374696f6e71007e00084c00046e616d6571007e000278700000c354000000000000000000007372002f6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655661726961626c6500000000000027d802001149001950534555444f5f53455249414c5f56455253494f4e5f55494442000b63616c63756c6174696f6e42000d696e6372656d656e74547970655a000f697353797374656d446566696e65644200097265736574547970654c001063616c63756c6174696f6e56616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f43616c63756c6174696f6e456e756d3b4c000a65787072657373696f6e71007e00124c000e696e6372656d656e7447726f757071007e00334c0012696e6372656d656e745479706556616c75657400344c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f496e6372656d656e7454797065456e756d3b4c001b696e6372656d656e746572466163746f7279436c6173734e616d6571007e00024c001f696e6372656d656e746572466163746f7279436c6173735265616c4e616d6571007e00024c0016696e697469616c56616c756545787072657373696f6e71007e00124c00046e616d6571007e00024c000a726573657447726f757071007e00334c000e72657365745479706556616c75657400304c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f526573657454797065456e756d3b4c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e00027870000077ee000001007e7200306e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e43616c63756c6174696f6e456e756d00000000000000001200007871007e001d740005434f554e547371007e00400000000b7571007e0043000000017371007e0045017400186e6577206a6176612e6c616e672e496e74656765722831297070707e7200326e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e496e6372656d656e7454797065456e756d00000000000000001200007871007e001d7400044e4f4e4570707371007e00400000000c7571007e0043000000017371007e0045017400186e6577206a6176612e6c616e672e496e7465676572283029707074000c4865616465725f434f554e5471007e00c27e72002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e526573657454797065456e756d00000000000000001200007871007e001d74000547524f55507400116a6176612e6c616e672e496e746567657270707e7200336e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e466f6f746572506f736974696f6e456e756d00000000000000001200007871007e001d7400064e4f524d414c707371007e002370707371007e00237571007e0026000000027371007e00117371007e001a00000002770400000002737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365546578744669656c6400000000000027d802001549001950534555444f5f53455249414c5f56455253494f4e5f55494449000d626f6f6b6d61726b4c6576656c42000e6576616c756174696f6e54696d6542000f68797065726c696e6b54617267657442000d68797065726c696e6b547970655a0015697353747265746368576974684f766572666c6f774c0014616e63686f724e616d6545787072657373696f6e71007e00124c000f6576616c756174696f6e47726f757071007e00334c00136576616c756174696f6e54696d6556616c75657400354c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4576616c756174696f6e54696d65456e756d3b4c000a65787072657373696f6e71007e00124c001968797065726c696e6b416e63686f7245787072657373696f6e71007e00124c001768797065726c696e6b5061676545787072657373696f6e71007e00125b001368797065726c696e6b506172616d65746572737400335b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5248797065726c696e6b506172616d657465723b4c001c68797065726c696e6b5265666572656e636545787072657373696f6e71007e00124c001a68797065726c696e6b546f6f6c74697045787072657373696f6e71007e00124c001768797065726c696e6b5768656e45787072657373696f6e71007e00124c000f6973426c616e6b5768656e4e756c6c71007e002b4c000a6c696e6b54617267657471007e00024c00086c696e6b5479706571007e00024c00077061747465726e71007e00024c00117061747465726e45787072657373696f6e71007e0012787200326e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736554657874456c656d656e7400000000000027d802002549001950534555444f5f53455249414c5f56455253494f4e5f5549444c0006626f7264657271007e00144c000b626f72646572436f6c6f7271007e002f4c000c626f74746f6d426f7264657271007e00144c0011626f74746f6d426f72646572436f6c6f7271007e002f4c000d626f74746f6d50616464696e677400134c6a6176612f6c616e672f496e74656765723b4c0008666f6e744e616d6571007e00024c0008666f6e7453697a6571007e00e74c0013686f72697a6f6e74616c416c69676e6d656e7471007e00144c0018686f72697a6f6e74616c416c69676e6d656e7456616c75657400364c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f486f72697a6f6e74616c416c69676e456e756d3b4c00066973426f6c6471007e002b4c000869734974616c696371007e002b4c000d6973506466456d62656464656471007e002b4c000f6973537472696b655468726f75676871007e002b4c000c69735374796c65645465787471007e002b4c000b6973556e6465726c696e6571007e002b4c000a6c656674426f7264657271007e00144c000f6c656674426f72646572436f6c6f7271007e002f4c000b6c65667450616464696e6771007e00e74c00076c696e65426f787400274c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a524c696e65426f783b4c000b6c696e6553706163696e6771007e00144c00106c696e6553706163696e6756616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4c696e6553706163696e67456e756d3b4c00066d61726b757071007e00024c000770616464696e6771007e00e74c00097061726167726170687400294c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525061726167726170683b4c000b706466456e636f64696e6771007e00024c000b706466466f6e744e616d6571007e00024c000b7269676874426f7264657271007e00144c00107269676874426f72646572436f6c6f7271007e002f4c000c726967687450616464696e6771007e00e74c0008726f746174696f6e71007e00144c000d726f746174696f6e56616c756574002f4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f526f746174696f6e456e756d3b4c0009746f70426f7264657271007e00144c000e746f70426f72646572436f6c6f7271007e002f4c000a746f7050616464696e6771007e00e74c0011766572746963616c416c69676e6d656e7471007e00144c0016766572746963616c416c69676e6d656e7456616c75657400344c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f566572746963616c416c69676e456e756d3b7871007e002e0000c3540000002d000100000000000002d80000000d000000057071007e001071007e00e170707070707071007e0039707070707e71007e003b74001a52454c41544956455f544f5f54414c4c4553545f4f424a4543547371007e003e8f61a735ab2074b7212194e972ca43210000c354707070707074000953616e735365726966737200116a6176612e6c616e672e496e746567657212e2a0a4f781873802000149000576616c7565787200106a6176612e6c616e672e4e756d62657286ac951d0b94e08b02000078700000001870707070707070737200116a6176612e6c616e672e426f6f6c65616ecd207280d59cfaee0200015a000576616c75657870007070707372002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173654c696e65426f7800000000000027d802000b4c000d626f74746f6d50616464696e6771007e00e74c0009626f74746f6d50656e74002b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f626173652f4a52426f7850656e3b4c000c626f78436f6e7461696e657274002c4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52426f78436f6e7461696e65723b4c000b6c65667450616464696e6771007e00e74c00076c65667450656e71007e00f94c000770616464696e6771007e00e74c000370656e71007e00f94c000c726967687450616464696e6771007e00e74c0008726967687450656e71007e00f94c000a746f7050616464696e6771007e00e74c0006746f7050656e71007e00f9787070737200336e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f78426f74746f6d50656e00000000000027d80200007872002d6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f7850656e00000000000027d80200014c00076c696e65426f7871007e00e97872002a6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736550656e00000000000027d802000649001950534555444f5f53455249414c5f56455253494f4e5f5549444c00096c696e65436f6c6f7271007e002f4c00096c696e655374796c6571007e00144c000e6c696e655374796c6556616c75657400304c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4c696e655374796c65456e756d3b4c00096c696e6557696474687400114c6a6176612f6c616e672f466c6f61743b4c000c70656e436f6e7461696e657274002c4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250656e436f6e7461696e65723b78700000c3547070707071007e00fb71007e00fb71007e00ee70737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f784c65667450656e00000000000027d80200007871007e00fd0000c3547070707071007e00fb71007e00fb707371007e00fd0000c3547070707071007e00fb71007e00fb70737200326e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f78526967687450656e00000000000027d80200007871007e00fd0000c3547070707071007e00fb71007e00fb70737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f78546f7050656e00000000000027d80200007871007e00fd0000c3547070707071007e00fb71007e00fb70707070737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736550617261677261706800000000000027d802000a4c000f66697273744c696e65496e64656e7471007e00e74c000a6c656674496e64656e7471007e00e74c000b6c696e6553706163696e6771007e00ea4c000f6c696e6553706163696e6753697a6571007e01004c0012706172616772617068436f6e7461696e65727400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52506172616772617068436f6e7461696e65723b4c000b7269676874496e64656e7471007e00e74c000c73706163696e67416674657271007e00e74c000d73706163696e674265666f726571007e00e74c000c74616253746f70576964746871007e00e74c000874616253746f707371007e001778707070707071007e00ee707070707070707070707070707070707e7200326e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e566572746963616c416c69676e456e756d00000000000000001200007871007e001d7400064d4944444c450000c354000000000000000170707e7200336e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e4576616c756174696f6e54696d65456e756d00000000000000001200007871007e001d7400034e4f577371007e00400000000d7571007e0043000000057371007e0045017400046d7367287371007e00450574001b6c6162656c2e70726f6f662e6f662e64656c69766572792e666f727371007e0045017400022c207371007e00450374000770726f6772616d7371007e00450174000129707070707070707070707070707371007e00e30000c3540000001600010000000000000039000002f20000000a7071007e001071007e00e17070707070707e71007e0038740005464c4f41547070707071007e003c7371007e003e89ab02f2dda79bb52dd094dce4b543c00000c354707070707074000953616e7353657269667371007e00f300000008707e7200346e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e486f72697a6f6e74616c416c69676e456e756d00000000000000001200007871007e001d74000552494748547070707070707070707371007e00f8707371007e00fc0000c3547070707071007e012871007e012871007e011f707371007e01030000c3547070707071007e012871007e0128707371007e00fd0000c3547070707071007e012871007e0128707371007e01060000c3547070707071007e012871007e0128707371007e01080000c3547070707071007e012871007e0128707070707371007e010a7070707071007e011f70707070707070707070707070707070700000c3540000000000000001707071007e01117371007e00400000000e7571007e0043000000017371007e0045017400146e6577206a6176612e7574696c2e446174652829707070707070707070707074000a64642f4d4d2f797979797078700000c3540000003201707070707371007e00117371007e001a00000015770400000015737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736552656374616e676c6500000000000027d80200014c000672616469757371007e00e7787200356e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736547726170686963456c656d656e7400000000000027d802000549001950534555444f5f53455249414c5f56455253494f4e5f5549444c000466696c6c71007e00144c000966696c6c56616c756574002b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f46696c6c456e756d3b4c00076c696e6550656e7400234c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250656e3b4c000370656e71007e00147871007e002e0000c354000000320001000000000000032f0000000b000000007071007e001071007e01347070707e7200296e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e4d6f6465456e756d00000000000000001200007871007e001d74000b5452414e53504152454e54707071007e00397070707071007e00ef7371007e003ea3af16f19527213476726b22ed2c4378000077ee70707371007e00fe0000c3547070707372000f6a6176612e6c616e672e466c6f6174daedc9a2db3cf0ec02000146000576616c75657871007e00f43f80000071007e013a70707371007e00e30000c3540000000a000100000000000000480000001c000000027071007e001071007e013470707070707071007e00397070707071007e003c7371007e003e86d00d0bb793f7dffbc318b89cbc4b440000c35470707070707071007e012470707070707070707070707371007e00f8707371007e00fc0000c3547070707071007e014471007e014471007e0142707371007e01030000c3547070707071007e014471007e0144707371007e00fd0000c3547070707071007e014471007e0144707371007e01060000c3547070707071007e014471007e0144707371007e01080000c3547070707071007e014471007e0144707070707371007e010a7070707071007e014270707070707070707070707070707070700000c3540000000000000001707071007e01117371007e00400000000f7571007e0043000000017371007e00450574000e6c6162656c2e6f726465722e6e6f707070707070707070707070707371007e00e30000c3540000000a000100000000000000480000001c000000157071007e001071007e013470707070707071007e00397070707071007e003c7371007e003eb25101f05f2ae792290c6493c0dd41f40000c35470707070707071007e012470707070707070707070707371007e00f8707371007e00fc0000c3547070707071007e015171007e015171007e014f707371007e01030000c3547070707071007e015171007e0151707371007e00fd0000c3547070707071007e015171007e0151707371007e01060000c3547070707071007e015171007e0151707371007e01080000c3547070707071007e015171007e0151707070707371007e010a7070707071007e014f70707070707070707070707070707070700000c3540000000000000001707071007e01117371007e0040000000107571007e0043000000017371007e00450574001e6c6162656c2e666163696c6974792e7265706f7274696e67506572696f64707070707070707070707070707371007e00e30000c3540000000a000100000000000000480000010e000000027071007e001071007e013470707070707071007e00397070707071007e003c7371007e003ead2d6244c73ce77b7c75268cc1bf46450000c35470707070707071007e012470707070707070707070707371007e00f8707371007e00fc0000c3547070707071007e015e71007e015e71007e015c707371007e01030000c3547070707071007e015e71007e015e707371007e00fd0000c3547070707071007e015e71007e015e707371007e01060000c3547070707071007e015e71007e015e707371007e01080000c3547070707071007e015e71007e015e707070707371007e010a7070707071007e015c70707070707070707070707070707070700000c3540000000000000001707071007e01117371007e0040000000117571007e0043000000017371007e00450574000e6c6162656c2e666163696c697479707070707070707070707070707371007e00e30000c3540000000a000100000000000000480000010e000000157071007e001071007e013470707070707071007e00397070707071007e003c7371007e003eae168411f352b0ea2b080c4f486c46c40000c35470707070707071007e012470707070707070707070707371007e00f8707371007e00fc0000c3547070707071007e016b71007e016b71007e0169707371007e01030000c3547070707071007e016b71007e016b707371007e00fd0000c3547070707071007e016b71007e016b707371007e01060000c3547070707071007e016b71007e016b707371007e01080000c3547070707071007e016b71007e016b707070707371007e010a7070707071007e016970707070707070707070707070707070700000c3540000000000000001707071007e01117371007e0040000000127571007e0043000000017371007e0045057400156c6162656c2e737570706c79696e672e6465706f74707070707070707070707070707371007e00e30000c3540000000a0001000000000000004800000239000000027071007e001071007e013470707070707071007e00397070707071007e003c7371007e003eb45d23fd4e1c18f3bada7198edba48840000c35470707070707071007e012470707070707070707070707371007e00f8707371007e00fc0000c3547070707071007e017871007e017871007e0176707371007e01030000c3547070707071007e017871007e0178707371007e00fd0000c3547070707071007e017871007e0178707371007e01060000c3547070707071007e017871007e0178707371007e01080000c3547070707071007e017871007e0178707070707371007e010a7070707071007e017670707070707070707070707070707070700000c3540000000000000001707071007e01117371007e0040000000137571007e0043000000017371007e0045057400116865616465722e6f726465722e64617465707070707070707070707070707371007e00e30000c3540000000a0001000000000000002f0000006d000000027071007e001071007e013470707070707071007e00397070707071007e003c7371007e003eacfb8e262215827d219fe37117e14ab40000c35470707070707071007e012470707070707070707070707371007e00f8707371007e00fc0000c3547070707071007e018571007e018571007e0183707371007e01030000c3547070707071007e018571007e0185707371007e00fd0000c3547070707071007e018571007e0185707371007e01060000c3547070707071007e018571007e0185707371007e01080000c3547070707071007e018571007e0185707070707371007e010a7070707071007e018370707070707070707070707070707070700000c3540000000000000001707071007e01117371007e0040000000147571007e0043000000017371007e0045037400076f726465726964707070707070707070707070707371007e00e30000c3540000000a000100000000000000350000006d000000157071007e001071007e013470707070707071007e00397070707071007e003c7371007e003e8cb4014dd4704077c2d7f24d862a4da90000c35470707070707071007e012470707070707070707070707371007e00f8707371007e00fc0000c3547070707071007e019271007e019271007e0190707371007e01030000c3547070707071007e019271007e0192707371007e00fd0000c3547070707071007e019271007e0192707371007e01060000c3547070707071007e019271007e0192707371007e01080000c3547070707071007e019271007e0192707070707371007e010a7070707071007e0190707070707070707070707070707070707e71007e010d740006424f54544f4d0000c3540000000000000001707071007e01117371007e0040000000157571007e0043000000017371007e004503740009737461727464617465707070707070707070707074000a64642f4d4d2f79797979707371007e00e30000c3540000000a000100000000000000c80000015f000000027071007e001071007e013470707070707071007e00397070707071007e003c7371007e003ea3577ac00bbc91aea24da1db27e04a370000c35470707070707071007e012470707070707070707070707371007e00f8707371007e00fc0000c3547070707071007e01a271007e01a271007e01a0707371007e01030000c3547070707071007e01a271007e01a2707371007e00fd0000c3547070707071007e01a271007e01a2707371007e01060000c3547070707071007e01a271007e01a2707371007e01080000c3547070707071007e01a271007e01a2707070707371007e010a7070707071007e01a070707070707070707070707070707070700000c3540000000000000001707071007e01117371007e0040000000167571007e0043000000017371007e004503740008666163696c697479707070707070707070707070707371007e00e30000c3540000000a000100000000000000c80000015f000000157071007e001071007e013470707070707071007e00397070707071007e003c7371007e003ea7518bc5e1bf144552daec0bf903438c0000c35470707070707071007e012470707070707070707070707371007e00f8707371007e00fc0000c3547070707071007e01af71007e01af71007e01ad707371007e01030000c3547070707071007e01af71007e01af707371007e00fd0000c3547070707071007e01af71007e01af707371007e01060000c3547070707071007e01af71007e01af707371007e01080000c3547070707071007e01af71007e01af707070707371007e010a7070707071007e01ad70707070707070707070707070707070700000c3540000000000000001707071007e01117371007e0040000000177571007e0043000000017371007e00450374000e737570706c79696e676465706f74707070707070707070707070707371007e00e30000c3540000000a0001000000000000009a00000289000000027071007e001071007e013470707070707071007e00397070707071007e003c7371007e003e9f1d48fc20f45b884ce36984d86c47fd0000c35470707070707071007e012470707070707070707070707371007e00f8707371007e00fc0000c3547070707071007e01bc71007e01bc71007e01ba707371007e01030000c3547070707071007e01bc71007e01bc707371007e00fd0000c3547070707071007e01bc71007e01bc707371007e01060000c3547070707071007e01bc71007e01bc707371007e01080000c3547070707071007e01bc71007e01bc707070707371007e010a7070707071007e01ba70707070707070707070707070707070700000c354000000000000000170707e71007e01107400065245504f52547371007e0040000000187571007e0043000000017371007e00450374000b6372656174656464617465707070707070707071007e00f7707074000a64642f4d4d2f79797979707371007e00e30000c3540000000a00010000000000000032000000a2000000157071007e001071007e013470707070707071007e00397070707071007e003c7371007e003e9651d969df25e43c68a067965a0f47080000c35470707070707071007e012470707070707070707070707371007e00f8707371007e00fc0000c3547070707071007e01cc71007e01cc71007e01ca707371007e01030000c3547070707071007e01cc71007e01cc707371007e00fd0000c3547070707071007e01cc71007e01cc707371007e01060000c3547070707071007e01cc71007e01cc707371007e01080000c3547070707071007e01cc71007e01cc707070707371007e010a7070707071007e01ca7070707070707070707070707070707071007e01990000c3540000000000000001707071007e01117371007e0040000000197571007e0043000000017371007e004503740007656e6464617465707070707070707070707074000a64642f4d4d2f7979797970737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655374617469635465787400000000000027d80200014c00047465787471007e00027871007e00e60000c3540000000a000100000000000000030000009b000000157071007e001071007e013470707070707071007e00397070707071007e003c7371007e003ea6c006ed6ba3b5a2b237397537c94d210000c35470707070707071007e0124707e71007e012574000643454e5445527070707070707070707371007e00f8707371007e00fc0000c3547070707071007e01dd71007e01dd71007e01d9707371007e01030000c3547070707071007e01dd71007e01dd707371007e00fd0000c3547070707071007e01dd71007e01dd707371007e01060000c3547070707071007e01dd71007e01dd707371007e01080000c3547070707071007e01dd71007e01dd707070707371007e010a7070707071007e01d970707070707070707070707070707070707400012d7371007e00e30000c3540000000a0001000000000000004800000239000000157071007e001071007e013470707070707071007e00397070707071007e003c7371007e003e919858c70250dcc4b0ae376069db4e0a0000c35470707070707071007e012470707070707070707070707371007e00f8707371007e00fc0000c3547070707071007e01e771007e01e771007e01e5707371007e01030000c3547070707071007e01e771007e01e7707371007e00fd0000c3547070707071007e01e771007e01e7707371007e01060000c3547070707071007e01e771007e01e7707371007e01080000c3547070707071007e01e771007e01e7707070707371007e010a7070707071007e01e570707070707070707070707070707070700000c3540000000000000001707071007e01117371007e00400000001a7571007e0043000000017371007e0045057400146865616465722e74656d706c6174652e74797065707070707070707070707070707371007e00e30000c3540000000a0001000000000000003f0000028a000000157071007e001071007e013470707070707071007e00397070707071007e003c7371007e003ea680158271d559e5eae60c5bba1a4dbc0000c35470707070707071007e012470707070707070707070707371007e00f8707371007e00fc0000c3547070707071007e01f471007e01f471007e01f2707371007e01030000c3547070707071007e01f471007e01f4707371007e00fd0000c3547070707071007e01f471007e01f4707371007e01060000c3547070707071007e01f471007e01f4707371007e01080000c3547070707071007e01f471007e01f4707070707371007e010a7070707071007e01f270707070707070707070707070707070700000c3540000000000000001707071007e01117371007e00400000001b7571007e0043000000017371007e00450374000474797065707070707070707070707070707371007e01d80000c3540000000a0001000000000000000f0000005e000000027071007e001071007e013470707070707071007e00397070707071007e003c7371007e003eb766ac094d88b863c764bfc6a3c64fa80000c35470707070707071007e01247071007e01db7070707070707070707371007e00f8707371007e00fc0000c3547070707071007e020171007e020171007e01ff707371007e01030000c3547070707071007e020171007e0201707371007e00fd0000c3547070707071007e020171007e0201707371007e01060000c3547070707071007e020171007e0201707371007e01080000c3547070707071007e020171007e0201707070707371007e010a7070707071007e01ff707070707070707070707070707070707e71007e010d740003544f5074000520203a20207371007e01d80000c3540000000a0001000000000000000f0000005e000000157071007e001071007e013470707070707071007e00397070707071007e003c7371007e003e8d4ac4dc283fdc3289a0a3ff0b1a4c830000c35470707070707071007e01247071007e01db7070707070707070707371007e00f8707371007e00fc0000c3547070707071007e020d71007e020d71007e020b707371007e01030000c3547070707071007e020d71007e020d707371007e00fd0000c3547070707071007e020d71007e020d707371007e01060000c3547070707071007e020d71007e020d707371007e01080000c3547070707071007e020d71007e020d707070707371007e010a7070707071007e020b7070707070707070707070707070707071007e020874000520203a20207371007e01d80000c3540000000a0001000000000000000f00000150000000027071007e001071007e013470707070707071007e00397070707071007e003c7371007e003ea0f0f90fa79d63f10e1207277fe64fb80000c35470707070707071007e01247071007e01db7070707070707070707371007e00f8707371007e00fc0000c3547070707071007e021771007e021771007e0215707371007e01030000c3547070707071007e021771007e0217707371007e00fd0000c3547070707071007e021771007e0217707371007e01060000c3547070707071007e021771007e0217707371007e01080000c3547070707071007e021771007e0217707070707371007e010a7070707071007e02157070707070707070707070707070707071007e020874000520203a20207371007e01d80000c3540000000a0001000000000000000f00000150000000157071007e001071007e013470707070707071007e00397070707071007e003c7371007e003eb10418c61404d5460ddeb01912d84bb90000c35470707070707071007e01247071007e01db7070707070707070707371007e00f8707371007e00fc0000c3547070707071007e022171007e022171007e021f707371007e01030000c3547070707071007e022171007e0221707371007e00fd0000c3547070707071007e022171007e0221707371007e01060000c3547070707071007e022171007e0221707371007e01080000c3547070707071007e022171007e0221707070707371007e010a7070707071007e021f7070707070707070707070707070707071007e020874000520203a20207371007e01d80000c3540000000a0001000000000000000f0000027a000000027071007e001071007e013470707070707071007e00397070707071007e003c7371007e003e8767216237b2425f05863133e0ec4c590000c35470707070707071007e01247071007e01db7070707070707070707371007e00f8707371007e00fc0000c3547070707071007e022b71007e022b71007e0229707371007e01030000c3547070707071007e022b71007e022b707371007e00fd0000c3547070707071007e022b71007e022b707371007e01060000c3547070707071007e022b71007e022b707371007e01080000c3547070707071007e022b71007e022b707070707371007e010a7070707071007e02297070707070707070707070707070707071007e020874000520203a20207371007e01d80000c3540000000a0001000000000000000f0000027b000000157071007e001071007e013470707070707071007e00397070707071007e003c7371007e003eb06173d47b9ae71a125d4c267ced4a320000c35470707070707071007e01247071007e01db7070707070707070707371007e00f8707371007e00fc0000c3547070707071007e023571007e023571007e0233707371007e01030000c3547070707071007e023571007e0235707371007e00fd0000c3547070707071007e023571007e0235707371007e01060000c3547070707071007e023571007e0235707371007e01080000c3547070707071007e023571007e0235707070707371007e010a7070707071007e02337070707070707070707070707070707071007e020874000520203a202078700000c3540000003201707070707400064865616465727400077265706f7274317572002a5b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a52506172616d657465723b22000c8d2ac36021020000787000000016737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365506172616d6574657200000000000027d80200095a000e6973466f7250726f6d7074696e675a000f697353797374656d446566696e65644c001664656661756c7456616c756545787072657373696f6e71007e00124c000b6465736372697074696f6e71007e00024c00046e616d6571007e00024c000e6e6573746564547970654e616d6571007e00024c000d70726f706572746965734d617071007e00134c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e000278700101707074000e5245504f52545f434f4e54455854707371007e00857070707400296e65742e73662e6a61737065727265706f7274732e656e67696e652e5265706f7274436f6e74657874707371007e0241010170707400155245504f52545f504152414d45544552535f4d4150707371007e008570707074000d6a6176612e7574696c2e4d6170707371007e02410101707074000d4a41535045525f5245504f5254707371007e00857070707400286e65742e73662e6a61737065727265706f7274732e656e67696e652e4a61737065725265706f7274707371007e0241010170707400115245504f52545f434f4e4e454354494f4e707371007e00857070707400136a6176612e73716c2e436f6e6e656374696f6e707371007e0241010170707400105245504f52545f4d41585f434f554e54707371007e008570707071007e00da707371007e0241010170707400125245504f52545f444154415f534f55524345707371007e00857070707400286e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5244617461536f75726365707371007e0241010170707400105245504f52545f5343524950544c4554707371007e008570707074002f6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5241627374726163745363726970746c6574707371007e02410101707074000d5245504f52545f4c4f43414c45707371007e00857070707400106a6176612e7574696c2e4c6f63616c65707371007e0241010170707400165245504f52545f5245534f555243455f42554e444c45707371007e00857070707400186a6176612e7574696c2e5265736f7572636542756e646c65707371007e0241010170707400105245504f52545f54494d455f5a4f4e45707371007e00857070707400126a6176612e7574696c2e54696d655a6f6e65707371007e0241010170707400155245504f52545f464f524d41545f464143544f5259707371007e008570707074002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e7574696c2e466f726d6174466163746f7279707371007e0241010170707400135245504f52545f434c4153535f4c4f41444552707371007e00857070707400156a6176612e6c616e672e436c6173734c6f61646572707371007e02410101707074001a5245504f52545f55524c5f48414e444c45525f464143544f5259707371007e00857070707400206a6176612e6e65742e55524c53747265616d48616e646c6572466163746f7279707371007e0241010170707400145245504f52545f46494c455f5245534f4c564552707371007e008570707074002d6e65742e73662e6a61737065727265706f7274732e656e67696e652e7574696c2e46696c655265736f6c766572707371007e0241010170707400105245504f52545f54454d504c41544553707371007e00857070707400146a6176612e7574696c2e436f6c6c656374696f6e707371007e02410101707074000b534f52545f4649454c4453707371007e008570707074000e6a6176612e7574696c2e4c697374707371007e02410101707074000646494c544552707371007e00857070707400296e65742e73662e6a61737065727265706f7274732e656e67696e652e4461746173657446696c746572707371007e0241010170707400125245504f52545f5649525455414c495a4552707371007e00857070707400296e65742e73662e6a61737065727265706f7274732e656e67696e652e4a525669727475616c697a6572707371007e02410101707074001449535f49474e4f52455f504147494e4154494f4e707371007e00857070707400116a6176612e6c616e672e426f6f6c65616e707371007e024100007371007e0040000000007070707074000d7375627265706f72745f646972707371007e00857070707400106a6176612e6c616e672e537472696e67707371007e024100007371007e00400000000170707070740009696d6167655f646972707371007e00857070707400106a6176612e6c616e672e537472696e67707371007e024100007371007e00400000000270707070740006706f645f6964707371007e00857070707400116a6176612e6c616e672e496e7465676572707371007e0085707371007e001a0000000377040000000374000c697265706f72742e7a6f6f6d740009697265706f72742e78740009697265706f72742e7978737200116a6176612e7574696c2e486173684d61700507dac1c31660d103000246000a6c6f6164466163746f724900097468726573686f6c6478703f400000000000037708000000040000000371007e02a07400013071007e029e740003312e3571007e029f74000130787372002c6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365517565727900000000000027d80200025b00066368756e6b7374002b5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5251756572794368756e6b3b4c00086c616e677561676571007e000278707572002b5b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5251756572794368756e6b3b409f00a1e8ba34a4020000787000000008737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736551756572794368756e6b00000000000027d8020003420004747970654c00047465787471007e00025b0006746f6b656e737400135b4c6a6176612f6c616e672f537472696e673b78700174004753454c454354202853454c4543542073756d287175616e7469747972657475726e6564292046524f4d20706f645f6c696e655f6974656d7320574845524520706f646964203d20707371007e02ab02740006706f645f6964707371007e02ab017400672920415320746f74616c7175616e7469747972657475726e65642c0a2020202020202020202020202853454c4543542073756d287175616e7469747973686970706564292046524f4d20706f645f6c696e655f6974656d7320574845524520706f646964203d20707371007e02ab02740006706f645f6964707371007e02ab017400672920415320746f74616c7175616e74697479736869707065642c0a2020202020202020202020202853454c4543542073756d287175616e746974797265636569766564292046524f4d20706f645f6c696e655f6974656d7320574845524520706f646964203d20707371007e02ab02740006706f645f6964707371007e02ab017403322920415320746f74616c7175616e7469747972656365697665642c0a202020202020202020202020702e7265636569766564646174652c20702e726563656976656462792c20702e64656c69766572656462792c20702e6f7264657269642c206f2e63726561746564646174652c2028662e636f6465207c7c2027202d2027207c7c20662e6e616d652920617320666163696c6974792c0a2020202020202020202020202043415345205748454e20722e656d657267656e6379203d2074727565205448454e2027456d657267656e6379270a20202020202020202020202020454c53452027526567756c61722720454e4420617320747970652c0a2020202020202020202020202073662e6e616d6520617320737570706c79696e676465706f742c2070676d2e6e616d652061732070726f6772616d2c2070702e7374617274646174652c2070702e656e64646174650a2020202020202020202020202046524f4d20706f64207020696e6e6572206a6f696e206f7264657273206f206f6e20702e6f726465726964203d206f2e69640a202020202020202020202020202020494e4e4552204a4f494e20666163696c69746965732066206f6e20702e666163696c6974796964203d20662e69640a202020202020202020202020202020494e4e4552204a4f494e20737570706c795f6c696e65732073206f6e206f2e737570706c796c696e656964203d20732e69640a202020202020202020202020202020494e4e4552204a4f494e20666163696c6974696573207366206f6e20732e737570706c79696e67666163696c6974796964203d2073662e69640a202020202020202020202020202020494e4e4552204a4f494e207265717569736974696f6e732072206f6e206f2e6964203d20722e69640a202020202020202020202020202020494e4e4552204a4f494e2070726f6772616d732070676d206f6e20702e70726f6772616d6964203d2070676d2e69640a202020202020202020202020202020494e4e4552204a4f494e2070726f63657373696e675f706572696f6473207070206f6e20702e706572696f646964203d2070702e69640a20202020202020202020202020574845524520702e6964203d20707371007e02ab02740006706f645f69647074000373716c707070707371007e003eb3d554b1aefe96cea0a4e8610726422f757200295b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a525661726961626c653b62e6837c982cb7440200007870000000067371007e00c3000077ee000001007e71007e00c874000653595354454d707071007e00d070707371007e0040000000037571007e0043000000017371007e0045017400186e6577206a6176612e6c616e672e496e7465676572283129707074000b504147455f4e554d424552707e71007e00d77400065245504f525471007e00da707371007e00c3000077ee0000010071007e02c2707071007e00d070707371007e0040000000047571007e0043000000017371007e0045017400186e6577206a6176612e6c616e672e496e7465676572283129707074000d434f4c554d4e5f4e554d424552707e71007e00d77400045041474571007e00da707371007e00c3000077ee0000010071007e00c97371007e0040000000057571007e0043000000017371007e0045017400186e6577206a6176612e6c616e672e496e746567657228312970707071007e00d070707371007e0040000000067571007e0043000000017371007e0045017400186e6577206a6176612e6c616e672e496e7465676572283029707074000c5245504f52545f434f554e547071007e02c971007e00da707371007e00c3000077ee0000010071007e00c97371007e0040000000077571007e0043000000017371007e0045017400186e6577206a6176612e6c616e672e496e746567657228312970707071007e00d070707371007e0040000000087571007e0043000000017371007e0045017400186e6577206a6176612e6c616e672e496e7465676572283029707074000a504147455f434f554e547071007e02d171007e00da707371007e00c3000077ee0000010071007e00c97371007e0040000000097571007e0043000000017371007e0045017400186e6577206a6176612e6c616e672e496e746567657228312970707071007e00d070707371007e00400000000a7571007e0043000000017371007e0045017400186e6577206a6176612e6c616e672e496e7465676572283029707074000c434f4c554d4e5f434f554e54707e71007e00d7740006434f4c554d4e71007e00da7071007e00c77e72003c6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5768656e5265736f757263654d697373696e6754797065456e756d00000000000000001200007871007e001d7400044e554c4c71007e023e7371007e00117371007e001a0000000077040000000078700000c3540000009901707070707e7200306e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e4f7269656e746174696f6e456e756d00000000000000001200007871007e001d7400094c414e4453434150457371007e00117371007e001a000000027704000000027371007e00e30000c3540000000b000100000000000000ac0000027c000000047071007e001071007e02fb70707070707071007e00397070707071007e003c7371007e003e843f39a0c2e70009c6758d1a4ca348990000c35470707070707071007e01247071007e01267070707070707070707371007e00f8707371007e00fc0000c3547070707071007e02ff71007e02ff71007e02fd707371007e01030000c3547070707071007e02ff71007e02ff707371007e00fd0000c3547070707071007e02ff71007e02ff707371007e01060000c3547070707071007e02ff71007e02ff707371007e01080000c3547070707071007e02ff71007e02ff707070707371007e010a7070707071007e02fd70707070707070707070707070707070700000c3540000000000000001707071007e01117371007e0040000000227571007e0043000000057371007e0045017400046d7367287371007e00450574000d6c6162656c2e706167652e6f667371007e0045017400022c207371007e00450474000b504147455f4e554d4245527371007e004501740001297070707070707070707070740000707371007e00e30000c3540000000b0001000000000000001300000329000000047071007e001071007e02fb70707070707071007e00397070707071007e003c7371007e003ebbf9a5527705d801477ffc9d22bf46f50000c35470707070707071007e012470707070707070707070707371007e00f8707371007e00fc0000c3547070707071007e031571007e031571007e0313707371007e01030000c3547070707071007e031571007e0315707371007e00fd0000c3547070707071007e031571007e0315707371007e01060000c3547070707071007e031571007e0315707371007e01080000c3547070707071007e031571007e0315707070707371007e010a7070707071007e031370707070707070707070707070707070700000c3540000000000000000707071007e01c37371007e0040000000237571007e0043000000027371007e004501740006222022202b207371007e00450474000b504147455f4e554d4245527070707070707070707070707078700000c354000000160170707070707e72002f6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5072696e744f72646572456e756d00000000000000001200007871007e001d740008564552544943414c757200265b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a525374796c653bd49cc311d90572350200007870000000087372002c6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655374796c65000000000000271102003a49001950534555444f5f53455249414c5f56455253494f4e5f5549445a0009697344656661756c744c00096261636b636f6c6f7271007e002f4c0006626f7264657271007e00144c000b626f72646572436f6c6f7271007e002f4c000c626f74746f6d426f7264657271007e00144c0011626f74746f6d426f72646572436f6c6f7271007e002f4c000d626f74746f6d50616464696e6771007e00e75b0011636f6e646974696f6e616c5374796c65737400315b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52436f6e646974696f6e616c5374796c653b4c001464656661756c745374796c6550726f766964657271007e00304c000466696c6c71007e00144c000966696c6c56616c756571007e01384c0008666f6e744e616d6571007e00024c0008666f6e7453697a6571007e00e74c0009666f7265636f6c6f7271007e002f4c0013686f72697a6f6e74616c416c69676e6d656e7471007e00144c0018686f72697a6f6e74616c416c69676e6d656e7456616c756571007e00e84c000f6973426c616e6b5768656e4e756c6c71007e002b4c00066973426f6c6471007e002b4c000869734974616c696371007e002b4c000d6973506466456d62656464656471007e002b4c000f6973537472696b655468726f75676871007e002b4c000c69735374796c65645465787471007e002b4c000b6973556e6465726c696e6571007e002b4c000a6c656674426f7264657271007e00144c000f6c656674426f72646572436f6c6f7271007e002f4c000b6c65667450616464696e6771007e00e74c00076c696e65426f7871007e00e94c00076c696e6550656e71007e01394c000b6c696e6553706163696e6771007e00144c00106c696e6553706163696e6756616c756571007e00ea4c00066d61726b757071007e00024c00046d6f646571007e00144c00096d6f646556616c756571007e00314c00046e616d6571007e00024c000770616464696e6771007e00e74c000970617261677261706871007e00eb4c000b706172656e745374796c6571007e00074c0018706172656e745374796c654e616d655265666572656e636571007e00024c00077061747465726e71007e00024c000b706466456e636f64696e6771007e00024c000b706466466f6e744e616d6571007e00024c000370656e71007e00144c000c706f736974696f6e5479706571007e00144c000672616469757371007e00e74c000b7269676874426f7264657271007e00144c00107269676874426f72646572436f6c6f7271007e002f4c000c726967687450616464696e6771007e00e74c0008726f746174696f6e71007e00144c000d726f746174696f6e56616c756571007e00ec4c000a7363616c65496d61676571007e00144c000f7363616c65496d61676556616c75657400314c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5363616c65496d616765456e756d3b4c000b737472657463685479706571007e00144c0009746f70426f7264657271007e00144c000e746f70426f72646572436f6c6f7271007e002f4c000a746f7050616464696e6771007e00e74c0011766572746963616c416c69676e6d656e7471007e00144c0016766572746963616c416c69676e6d656e7456616c756571007e00ed78700000c35400707070707070707070707070707070707070707070707070707371007e00f8707371007e00fc0000c3547070707071007e032b71007e032b71007e032a707371007e01030000c3547070707071007e032b71007e032b707371007e00fd0000c3547372000e6a6176612e6177742e436f6c6f7201a51783108f337502000546000666616c70686149000576616c75654c0002637374001b4c6a6176612f6177742f636f6c6f722f436f6c6f7253706163653b5b00096672676276616c75657400025b465b00066676616c756571007e0331787000000000ff00000070707070707371007e01403f80000071007e032b71007e032b707371007e01060000c3547070707071007e032b71007e032b707371007e01080000c3547070707071007e032b71007e032b7371007e00fe0000c3547070707071007e032a70707070707400057461626c65707371007e010a7070707071007e032a70707070707070707070707070707070707070707070707070707371007e03270000c354007371007e032f00000000fff0f8ff7070707070707070707070707070707070707070707070707070707371007e00f8707371007e00fc0000c3547070707071007e033b71007e033b71007e0339707371007e01030000c3547070707071007e033b71007e033b707371007e00fd0000c3547371007e032f00000000ff00000070707070707371007e01403f00000071007e033b71007e033b707371007e01060000c3547070707071007e033b71007e033b707371007e01080000c3547070707071007e033b71007e033b7371007e00fe0000c3547070707071007e0339707070707e71007e013b7400064f50415155457400087461626c655f5448707371007e010a7070707071007e033970707070707070707070707070707070707070707070707070707371007e03270000c354007371007e032f00000000ffbfe1ff7070707070707070707070707070707070707070707070707070707371007e00f8707371007e00fc0000c3547070707071007e034a71007e034a71007e0348707371007e01030000c3547070707071007e034a71007e034a707371007e00fd0000c3547371007e032f00000000ff00000070707070707371007e01403f00000071007e034a71007e034a707371007e01060000c3547070707071007e034a71007e034a707371007e01080000c3547070707071007e034a71007e034a7371007e00fe0000c3547070707071007e03487070707071007e03447400087461626c655f4348707371007e010a7070707071007e034870707070707070707070707070707070707070707070707070707371007e03270000c354007371007e032f00000000ffffffff7070707070707070707070707070707070707070707070707070707371007e00f8707371007e00fc0000c3547070707071007e035771007e035771007e0355707371007e01030000c3547070707071007e035771007e0357707371007e00fd0000c3547371007e032f00000000ff00000070707070707371007e01403f00000071007e035771007e0357707371007e01060000c3547070707071007e035771007e0357707371007e01080000c3547070707071007e035771007e03577371007e00fe0000c3547070707071007e03557070707071007e03447400087461626c655f5444707371007e010a7070707071007e035570707070707070707070707070707070707070707070707070707371007e03270000c35400707070707070707070707070707070707070707070707070707371007e00f8707371007e00fc0000c3547070707071007e036371007e036371007e0362707371007e01030000c3547070707071007e036371007e0363707371007e00fd0000c3547371007e032f00000000ff00000070707070707371007e01403f80000071007e036371007e0363707371007e01060000c3547070707071007e036371007e0363707371007e01080000c3547070707071007e036371007e03637371007e00fe0000c3547070707071007e036270707070707400077461626c652031707371007e010a7070707071007e036270707070707070707070707070707070707070707070707070707371007e03270000c354007371007e032f00000000fff0f8ff7070707070707070707070707070707070707070707070707070707371007e00f8707371007e00fc0000c3547070707071007e037071007e037071007e036e707371007e01030000c3547070707071007e037071007e0370707371007e00fd0000c3547371007e032f00000000ff00000070707070707371007e01403f00000071007e037071007e0370707371007e01060000c3547070707071007e037071007e0370707371007e01080000c3547070707071007e037071007e03707371007e00fe0000c3547070707071007e036e7070707071007e034474000a7461626c6520315f5448707371007e010a7070707071007e036e70707070707070707070707070707070707070707070707070707371007e03270000c354007371007e032f00000000ffbfe1ff7070707070707070707070707070707070707070707070707070707371007e00f8707371007e00fc0000c3547070707071007e037d71007e037d71007e037b707371007e01030000c3547070707071007e037d71007e037d707371007e00fd0000c3547371007e032f00000000ff00000070707070707371007e01403f00000071007e037d71007e037d707371007e01060000c3547070707071007e037d71007e037d707371007e01080000c3547070707071007e037d71007e037d7371007e00fe0000c3547070707071007e037b7070707071007e034474000a7461626c6520315f4348707371007e010a7070707071007e037b70707070707070707070707070707070707070707070707070707371007e03270000c354007371007e032f00000000ffffffff7070707070707070707070707070707070707070707070707070707371007e00f8707371007e00fc0000c3547070707071007e038a71007e038a71007e0388707371007e01030000c3547070707071007e038a71007e038a707371007e00fd0000c3547371007e032f00000000ff00000070707070707371007e01403f00000071007e038a71007e038a707371007e01060000c3547070707071007e038a71007e038a707371007e01080000c3547070707071007e038a71007e038a7371007e00fe0000c3547070707071007e03887070707071007e034474000a7461626c6520315f5444707371007e010a7070707071007e038870707070707070707070707070707070707070707070707070707371007e00117371007e001a000000157704000000157371007e01360000c3540000007b000100000000000000c50000000d000000207071007e001071007e039570707071007e013c707071007e00397070707071007e00ef7371007e003e9be2cb5c14a2f2acccb8fa435e6f4783000077ee70707371007e00fe0000c3547070707371007e01400000000071007e039770707371007e00e30000c3540000003e000100000000000000720000000c000000207071007e001071007e039570707070707071007e00397070707071007e00ef7371007e003ea97f5841d2d27c2574639613be3b46ce0000c3547070707070707371007e00f30000000e70707070707070707070707371007e00f87371007e00f3000000057371007e00fc0000c3547070707071007e039e71007e039e71007e039b71007e039f7371007e01030000c3547070707071007e039e71007e039e707371007e00fd0000c3547070707071007e039e71007e039e71007e039f7371007e01060000c3547070707071007e039e71007e039e7371007e00f3000000147371007e01080000c3547070707071007e039e71007e039e707070707371007e010a7070707071007e039b7070707070707070707070707070707071007e02080000c3540000000000000001707071007e01117371007e0040000000247571007e0043000000017371007e00450574000d6c6162656c2e73756d6d617279707070707070707070707070707371007e00e30000c35400000016000100000000000000640000000d0000005e7071007e001071007e039570707070707071007e00397070707071007e00ef7371007e003e8deebd742234878d6fe8bbadbec44b6a0000c35470707070707071007e012470707070707070707070707371007e00f8707371007e00fc0000c3547070707071007e03ad71007e03ad71007e03ab707371007e01030000c3547070707071007e03ad71007e03ad707371007e00fd0000c3547070707071007e03ad71007e03ad707371007e01060000c3547070707071007e03ad71007e03ad707371007e01080000c3547070707071007e03ad71007e03ad707070707371007e010a7070707071007e03ab7070707070707070707070707070707071007e02080000c3540000000000000001707071007e01117371007e0040000000257571007e0043000000017371007e0045057400196c6162656c2e746f74616c2e736869707065642e7061636b73707070707070707070707070707371007e00e30000c35400000015000100000000000000640000000d000000727071007e001071007e039570707070707071007e00397070707071007e00ef7371007e003e9c543ba0037dfbcdb61f59bb8282415f0000c35470707070707071007e012470707070707070707070707371007e00f8707371007e00fc0000c3547070707071007e03ba71007e03ba71007e03b8707371007e01030000c3547070707071007e03ba71007e03ba707371007e00fd0000c3547070707071007e03ba71007e03ba707371007e01060000c3547070707071007e03ba71007e03ba707371007e01080000c3547070707071007e03ba71007e03ba707070707371007e010a7070707071007e03b87070707070707070707070707070707071007e02080000c3540000000000000001707071007e01117371007e0040000000267571007e0043000000027371007e00450574001a6c6162656c2e746f74616c2e72656365697665642e7061636b737371007e004501740005202b202222707070707070707070707070707371007e00e30000c35400000014000100000000000000640000000d000000867071007e001071007e039570707070707071007e00397070707071007e00ef7371007e003e9e1fcb501f4287e124a5d9528d524f230000c35470707070707071007e012470707070707070707070707371007e00f8707371007e00fc0000c3547070707071007e03c971007e03c971007e03c7707371007e01030000c3547070707071007e03c971007e03c9707371007e00fd0000c3547070707071007e03c971007e03c9707371007e01060000c3547070707071007e03c971007e03c9707371007e01080000c3547070707071007e03c971007e03c9707070707371007e010a7070707071007e03c77070707070707070707070707070707071007e02080000c3540000000000000001707071007e01117371007e0040000000277571007e0043000000027371007e00450574001a6c6162656c2e746f74616c2e72657475726e65642e7061636b737371007e004501740005202b202222707070707070707070707070707371007e00e30000c3540000000a000100000000000000640000000d000000c67071007e001071007e039570707070707071007e00397070707071007e00ef7371007e003e9e118a432990a0edcb6c632b896242790000c35470707070707071007e012470707070707070707070707371007e00f8707371007e00fc0000c3547070707071007e03d871007e03d871007e03d6707371007e01030000c3547070707071007e03d871007e03d8707371007e00fd0000c3547070707071007e03d871007e03d8707371007e01060000c3547070707071007e03d871007e03d8707371007e01080000c3547070707071007e03d871007e03d8707070707371007e010a7070707071007e03d670707070707070707070707070707070700000c3540000000000000001707071007e01117371007e0040000000287571007e0043000000017371007e0045057400106c6162656c2e72656365697665644279707070707070707070707070707371007e00e30000c3540000000a000100000000000000640000000d000000b17071007e001071007e039570707070707071007e00397070707071007e00ef7371007e003e89e8d6de02eda420ae8968315346451d0000c35470707070707071007e012470707070707070707070707371007e00f8707371007e00fc0000c3547070707071007e03e571007e03e571007e03e3707371007e01030000c3547070707071007e03e571007e03e5707371007e00fd0000c3547070707071007e03e571007e03e5707371007e01060000c3547070707071007e03e571007e03e5707371007e01080000c3547070707071007e03e571007e03e5707070707371007e010a7070707071007e03e370707070707070707070707070707070700000c3540000000000000001707071007e01117371007e0040000000297571007e0043000000017371007e0045057400116c6162656c2e64656c6976657265644279707070707070707070707070707371007e00e30000c354000000150001000000000000004e000000840000005e7071007e001071007e039570707070707071007e00397070707071007e00ef7371007e003e91db4045e7c9608f827c0b6fda7d4f200000c35470707070707071007e01247071007e01267070707070707070707371007e00f8707371007e00fc0000c3547070707071007e03f271007e03f271007e03f0707371007e01030000c3547070707071007e03f271007e03f2707371007e00fd0000c3547070707071007e03f271007e03f2707371007e01060000c3547070707071007e03f271007e03f2707371007e01080000c3547070707071007e03f271007e03f2707070707371007e010a7070707071007e03f070707070707070707070707070707070700000c3540000000000000001707071007e01117371007e00400000002a7571007e0043000000017371007e004503740014746f74616c7175616e746974797368697070656470707070707070707371007e00f601707070707371007e00e30000c354000000150001000000000000004e00000084000000867071007e001071007e039570707070707071007e00397070707071007e00ef7371007e003eba5f7f70a1a867845788e28184fc479f0000c35470707070707071007e01247071007e01267070707070707070707371007e00f8707371007e00fc0000c3547070707071007e040071007e040071007e03fe707371007e01030000c3547070707071007e040071007e0400707371007e00fd0000c3547070707071007e040071007e0400707371007e01060000c3547070707071007e040071007e0400707371007e01080000c3547070707071007e040071007e0400707070707371007e010a7070707071007e03fe70707070707070707070707070707070700000c3540000000000000001707071007e01117371007e00400000002b7571007e0043000000017371007e004503740015746f74616c7175616e7469747972657475726e6564707070707070707071007e03fd707070707371007e00e30000c354000000150001000000000000004e00000084000000727071007e001071007e039570707070707071007e00397070707071007e00ef7371007e003e9e8d4a3c6cd7b01b5d5d4b0258184b500000c35470707070707071007e01247071007e01267070707070707070707371007e00f8707371007e00fc0000c3547070707071007e040d71007e040d71007e040b707371007e01030000c3547070707071007e040d71007e040d707371007e00fd0000c3547070707071007e040d71007e040d707371007e01060000c3547070707071007e040d71007e040d707371007e01080000c3547070707071007e040d71007e040d707070707371007e010a7070707071007e040b70707070707070707070707070707070700000c3540000000000000001707071007e01117371007e00400000002c7571007e0043000000017371007e004503740015746f74616c7175616e746974797265636569766564707070707070707071007e03fd707070707371007e00e30000c3540000000a0001000000000000005300000234000000b17071007e001071007e039570707070707071007e00397070707071007e003c7371007e003ea34ae8de6047ea3030bcea009bc342c30000c35470707070707071007e012470707070707070707070707371007e00f8707371007e00fc0000c3547070707071007e041a71007e041a71007e0418707371007e01030000c3547070707071007e041a71007e041a707371007e00fd0000c3547070707071007e041a71007e041a707371007e01060000c3547070707071007e041a71007e041a707371007e01080000c3547070707071007e041a71007e041a707070707371007e010a7070707071007e041870707070707070707070707070707070700000c3540000000000000001707071007e01117371007e00400000002d7571007e0043000000017371007e00450374000c726563656976656464617465707070707070707071007e03fd707074000a64642f4d4d2f79797979707371007e00e30000c3540000000a00010000000000000064000001c3000000b17071007e001071007e039570707070707071007e00397070707071007e003c7371007e003e99cbddf1806e00c2bf42eae8e94249360000c35470707070707071007e012470707070707070707070707371007e00f8707371007e00fc0000c3547070707071007e042871007e042871007e0426707371007e01030000c3547070707071007e042871007e0428707371007e00fd0000c3547070707071007e042871007e0428707371007e01060000c3547070707071007e042871007e0428707371007e01080000c3547070707071007e042871007e0428707070707371007e010a7070707071007e042670707070707070707070707070707070700000c3540000000000000001707071007e01117371007e00400000002e7571007e0043000000017371007e0045057400126c6162656c2e726563656976656444617465707070707070707070707070707371007e00e30000c3540000000a000100000000000000df00000084000000b17071007e001071007e039570707070707071007e00397070707071007e003c7371007e003ea254b405a06feb6228c285558f6c47e50000c35470707070707071007e012470707070707070707070707371007e00f8707371007e00fc0000c3547070707071007e043571007e043571007e0433707371007e01030000c3547070707071007e043571007e0435707371007e00fd0000c3547070707071007e043571007e0435707371007e01060000c3547070707071007e043571007e0435707371007e01080000c3547070707071007e043571007e0435707070707371007e010a7070707071007e043370707070707070707070707070707070700000c3540000000000000001707071007e01117371007e00400000002f7571007e0043000000017371007e00450374000b64656c6976657265646279707070707070707071007e03fd707070707371007e00e30000c3540000000a000100000000000000df00000084000000c67071007e001071007e039570707070707071007e00397070707071007e003c7371007e003ebdcb26d4e495b5ab6d0d6e5b1fea45ca0000c35470707070707071007e012470707070707070707070707371007e00f8707371007e00fc0000c3547070707071007e044271007e044271007e0440707371007e01030000c3547070707071007e044271007e0442707371007e00fd0000c3547070707071007e044271007e0442707371007e01060000c3547070707071007e044271007e0442707371007e01080000c3547070707071007e044271007e0442707070707371007e010a7070707071007e044070707070707070707070707070707070700000c3540000000000000001707071007e01117371007e0040000000307571007e0043000000017371007e00450374000a72656365697665646279707070707070707071007e03fd707070707371007e01d80000c3540000000a0001000000000000000f000000730000005e7071007e001071007e039570707070707071007e00397070707071007e00ef7371007e003e9d74654bc5b18537849cafd2798f4c730000c35470707070707071007e01247071007e01db7070707070707070707371007e00f8707371007e00fc0000c3547070707071007e044f71007e044f71007e044d707371007e01030000c3547070707071007e044f71007e044f707371007e00fd0000c3547070707071007e044f71007e044f707371007e01060000c3547070707071007e044f71007e044f707371007e01080000c3547070707071007e044f71007e044f707070707371007e010a7070707071007e044d7070707070707070707070707070707071007e020874000520203a20207371007e01d80000c3540000000a0001000000000000000f00000073000000737071007e001071007e039570707070707071007e00397070707071007e00ef7371007e003e9139c1ea93bd22fb35baa8ac7bac4f680000c35470707070707071007e01247071007e01db7070707070707070707371007e00f8707371007e00fc0000c3547070707071007e045971007e045971007e0457707371007e01030000c3547070707071007e045971007e0459707371007e00fd0000c3547070707071007e045971007e0459707371007e01060000c3547070707071007e045971007e0459707371007e01080000c3547070707071007e045971007e0459707070707371007e010a7070707071007e04577070707070707070707070707070707071007e020874000520203a20207371007e01d80000c3540000000a0001000000000000000f00000073000000877071007e001071007e039570707070707071007e00397070707071007e00ef7371007e003eb2ba2e0b065ca72b5244f766554842070000c35470707070707071007e01247071007e01db7070707070707070707371007e00f8707371007e00fc0000c3547070707071007e046371007e046371007e0461707371007e01030000c3547070707071007e046371007e0463707371007e00fd0000c3547070707071007e046371007e0463707371007e01060000c3547070707071007e046371007e0463707371007e01080000c3547070707071007e046371007e0463707070707371007e010a7070707071007e04617070707070707070707070707070707071007e020874000520203a20207371007e01d80000c3540000000a0001000000000000000f00000226000000b17071007e001071007e039570707070707071007e00397070707071007e003c7371007e003e8acdec1e3b1410f52794c49c51724d3c0000c35470707070707071007e01247071007e01db7070707070707070707371007e00f8707371007e00fc0000c3547070707071007e046d71007e046d71007e046b707371007e01030000c3547070707071007e046d71007e046d707371007e00fd0000c3547070707071007e046d71007e046d707371007e01060000c3547070707071007e046d71007e046d707371007e01080000c3547070707071007e046d71007e046d707070707371007e010a7070707071007e046b7070707070707070707070707070707071007e020874000520203a20207371007e01d80000c3540000000a0001000000000000000f00000073000000b17071007e001071007e039570707070707071007e00397070707071007e003c7371007e003eb8d931410ecc1f87f3a22e73997247910000c35470707070707071007e01247071007e01db7070707070707070707371007e00f8707371007e00fc0000c3547070707071007e047771007e047771007e0475707371007e01030000c3547070707071007e047771007e0477707371007e00fd0000c3547070707071007e047771007e0477707371007e01060000c3547070707071007e047771007e0477707371007e01080000c3547070707071007e047771007e0477707070707371007e010a7070707071007e04757070707070707070707070707070707071007e020874000520203a20207371007e01d80000c3540000000a0001000000000000000f00000073000000c67071007e001071007e039570707070707071007e00397070707071007e003c7371007e003e8baade2e2e2fa551bb511410183e46600000c35470707070707071007e01247071007e01db7070707070707070707371007e00f8707371007e00fc0000c3547070707071007e048171007e048171007e047f707371007e01030000c3547070707071007e048171007e0481707371007e00fd0000c3547070707071007e048171007e0481707371007e01060000c3547070707071007e048171007e0481707371007e01080000c3547070707071007e048171007e0481707070707371007e010a7070707071007e047f7070707070707070707070707070707071007e020874000520203a20207371007e01360000c3540000002e0001000000000000032f0000000dffffff4f7071007e001071007e039570707071007e013c707071007e00397070707071007e00ef7371007e003e8ec07188f5893e33fadb0c71bb5d4dd3000077ee70707371007e00fe0000c3547070707371007e01400000000071007e0489707078700000c354000000d9017070707070707e7200336e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5768656e4e6f4461746154797065456e756d00000000000000001200007871007e001d74000f4e4f5f444154415f53454354494f4e737200366e65742e73662e6a61737065727265706f7274732e656e67696e652e64657369676e2e4a525265706f7274436f6d70696c654461746100000000000027d80200034c001363726f7373746162436f6d70696c654461746171007e00864c001264617461736574436f6d70696c654461746171007e00864c00166d61696e44617461736574436f6d70696c654461746171007e000178707371007e02a13f4000000000001077080000001000000000787371007e02a13f400000000000107708000000100000000078757200025b42acf317f8060854e002000078700000284fcafebabe0000002e016301001c7265706f7274315f313339353231343030323630315f38363836363407000101002c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a524576616c7561746f72070003010017706172616d657465725f5245504f52545f4c4f43414c450100324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c506172616d657465723b010017706172616d657465725f4a41535045525f5245504f525401001c706172616d657465725f5245504f52545f5649525455414c495a455201001a706172616d657465725f5245504f52545f54494d455f5a4f4e45010015706172616d657465725f534f52545f4649454c445301001e706172616d657465725f5245504f52545f46494c455f5245534f4c564552010017706172616d657465725f7375627265706f72745f646972010010706172616d657465725f706f645f696401001a706172616d657465725f5245504f52545f5343524950544c455401001f706172616d657465725f5245504f52545f504152414d45544552535f4d415001001b706172616d657465725f5245504f52545f434f4e4e454354494f4e010018706172616d657465725f5245504f52545f434f4e5445585401001d706172616d657465725f5245504f52545f434c4153535f4c4f41444552010024706172616d657465725f5245504f52545f55524c5f48414e444c45525f464143544f525901001c706172616d657465725f5245504f52545f444154415f534f5552434501001e706172616d657465725f49535f49474e4f52455f504147494e4154494f4e010010706172616d657465725f46494c54455201001f706172616d657465725f5245504f52545f464f524d41545f464143544f525901001a706172616d657465725f5245504f52545f4d41585f434f554e5401001a706172616d657465725f5245504f52545f54454d504c41544553010020706172616d657465725f5245504f52545f5245534f555243455f42554e444c45010013706172616d657465725f696d6167655f64697201001b6669656c645f746f74616c7175616e74697479726563656976656401002e4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c4669656c643b0100146669656c645f737570706c79696e676465706f7401000f6669656c645f73746172746461746501000e6669656c645f666163696c69747901000d6669656c645f70726f6772616d0100106669656c645f726563656976656462790100126669656c645f72656365697665646461746501001a6669656c645f746f74616c7175616e746974797368697070656401001b6669656c645f746f74616c7175616e7469747972657475726e65640100116669656c645f637265617465646461746501000d6669656c645f6f7264657269640100116669656c645f64656c697665726564627901000d6669656c645f656e646461746501000a6669656c645f747970650100147661726961626c655f504147455f4e554d4245520100314c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c5661726961626c653b0100167661726961626c655f434f4c554d4e5f4e554d4245520100157661726961626c655f5245504f52545f434f554e540100137661726961626c655f504147455f434f554e540100157661726961626c655f434f4c554d4e5f434f554e540100157661726961626c655f4865616465725f434f554e540100063c696e69743e010003282956010004436f64650c003200330a000400350c0005000609000200370c0007000609000200390c00080006090002003b0c00090006090002003d0c000a0006090002003f0c000b000609000200410c000c000609000200430c000d000609000200450c000e000609000200470c000f000609000200490c00100006090002004b0c00110006090002004d0c00120006090002004f0c0013000609000200510c0014000609000200530c0015000609000200550c0016000609000200570c0017000609000200590c00180006090002005b0c00190006090002005d0c001a0006090002005f0c001b000609000200610c001c001d09000200630c001e001d09000200650c001f001d09000200670c0020001d09000200690c0021001d090002006b0c0022001d090002006d0c0023001d090002006f0c0024001d09000200710c0025001d09000200730c0026001d09000200750c0027001d09000200770c0028001d09000200790c0029001d090002007b0c002a001d090002007d0c002b002c090002007f0c002d002c09000200810c002e002c09000200830c002f002c09000200850c0030002c09000200870c0031002c090002008901000f4c696e654e756d6265725461626c6501000e637573746f6d697a6564496e6974010030284c6a6176612f7574696c2f4d61703b4c6a6176612f7574696c2f4d61703b4c6a6176612f7574696c2f4d61703b295601000a696e6974506172616d73010012284c6a6176612f7574696c2f4d61703b29560c008e008f0a0002009001000a696e69744669656c64730c0092008f0a00020093010008696e6974566172730c0095008f0a0002009601000d5245504f52545f4c4f43414c4508009801000d6a6176612f7574696c2f4d617007009a010003676574010026284c6a6176612f6c616e672f4f626a6563743b294c6a6176612f6c616e672f4f626a6563743b0c009c009d0b009b009e0100306e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c506172616d657465720700a001000d4a41535045525f5245504f52540800a20100125245504f52545f5649525455414c495a45520800a40100105245504f52545f54494d455f5a4f4e450800a601000b534f52545f4649454c44530800a80100145245504f52545f46494c455f5245534f4c5645520800aa01000d7375627265706f72745f6469720800ac010006706f645f69640800ae0100105245504f52545f5343524950544c45540800b00100155245504f52545f504152414d45544552535f4d41500800b20100115245504f52545f434f4e4e454354494f4e0800b401000e5245504f52545f434f4e544558540800b60100135245504f52545f434c4153535f4c4f414445520800b801001a5245504f52545f55524c5f48414e444c45525f464143544f52590800ba0100125245504f52545f444154415f534f555243450800bc01001449535f49474e4f52455f504147494e4154494f4e0800be01000646494c5445520800c00100155245504f52545f464f524d41545f464143544f52590800c20100105245504f52545f4d41585f434f554e540800c40100105245504f52545f54454d504c415445530800c60100165245504f52545f5245534f555243455f42554e444c450800c8010009696d6167655f6469720800ca010015746f74616c7175616e7469747972656365697665640800cc01002c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c4669656c640700ce01000e737570706c79696e676465706f740800d00100097374617274646174650800d2010008666163696c6974790800d401000770726f6772616d0800d601000a726563656976656462790800d801000c7265636569766564646174650800da010014746f74616c7175616e74697479736869707065640800dc010015746f74616c7175616e7469747972657475726e65640800de01000b63726561746564646174650800e00100076f7264657269640800e201000b64656c69766572656462790800e4010007656e64646174650800e6010004747970650800e801000b504147455f4e554d4245520800ea01002f6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c5661726961626c650700ec01000d434f4c554d4e5f4e554d4245520800ee01000c5245504f52545f434f554e540800f001000a504147455f434f554e540800f201000c434f4c554d4e5f434f554e540800f401000c4865616465725f434f554e540800f60100086576616c756174650100152849294c6a6176612f6c616e672f4f626a6563743b01000a457863657074696f6e730100136a6176612f6c616e672f5468726f7761626c650700fb0100116a6176612f6c616e672f496e74656765720700fd010004284929560c003200ff0a00fe010001001b6c6162656c2e70726f6f662e6f662e64656c69766572792e666f72080102010003737472010026284c6a6176612f6c616e672f537472696e673b294c6a6176612f6c616e672f537472696e673b0c010401050a0002010601000867657456616c756501001428294c6a6176612f6c616e672f4f626a6563743b0c010801090a00cf010a0100106a6176612f6c616e672f537472696e6707010c0100036d7367010038284c6a6176612f6c616e672f537472696e673b4c6a6176612f6c616e672f4f626a6563743b294c6a6176612f6c616e672f537472696e673b0c010e010f0a0002011001000e6a6176612f7574696c2f446174650701120a0113003501000e6c6162656c2e6f726465722e6e6f08011501001e6c6162656c2e666163696c6974792e7265706f7274696e67506572696f6408011701000e6c6162656c2e666163696c6974790801190100156c6162656c2e737570706c79696e672e6465706f7408011b0100116865616465722e6f726465722e6461746508011d01000e6a6176612f6c616e672f4c6f6e6707011f0100146865616465722e74656d706c6174652e747970650801210a00a1010a0100106a6176612f7574696c2f4c6f63616c650701240100186a6176612f7574696c2f5265736f7572636542756e646c650701260100136a6176612f73716c2f436f6e6e656374696f6e0701280100166a6176612f6c616e672f537472696e6742756666657207012a01000776616c75654f66010026284c6a6176612f6c616e672f4f626a6563743b294c6a6176612f6c616e672f537472696e673b0c012c012d0a010d012e010015284c6a6176612f6c616e672f537472696e673b29560c003201300a012b0131010016706f644c696e654974656d5072696e742e6a72786d6c080133010006617070656e6401002c284c6a6176612f6c616e672f537472696e673b294c6a6176612f6c616e672f537472696e674275666665723b0c013501360a012b0137010008746f537472696e6701001428294c6a6176612f6c616e672f537472696e673b0c0139013a0a012b013b0100306e65742f73662f6a61737065727265706f7274732f656e67696e652f4a6173706572436f6d70696c654d616e6167657207013d01000d636f6d70696c655265706f727401003e284c6a6176612f6c616e672f537472696e673b294c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a61737065725265706f72743b0c013f01400a013e014101000d6c6162656c2e706167652e6f660801430a00ed010a0100012008014601002c284c6a6176612f6c616e672f4f626a6563743b294c6a6176612f6c616e672f537472696e674275666665723b0c013501480a012b014901000d6c6162656c2e73756d6d61727908014b0100196c6162656c2e746f74616c2e736869707065642e7061636b7308014d01001a6c6162656c2e746f74616c2e72656365697665642e7061636b7308014f01001a6c6162656c2e746f74616c2e72657475726e65642e7061636b730801510100106c6162656c2e726563656976656442790801530100116c6162656c2e64656c69766572656442790801550100126c6162656c2e72656365697665644461746508015701000b6576616c756174654f6c6401000b6765744f6c6456616c75650c015a01090a00cf015b0a00ed015b0100116576616c75617465457374696d61746564010011676574457374696d6174656456616c75650c015f01090a00ed016001000a536f7572636546696c650021000200040000002a00020005000600000002000700060000000200080006000000020009000600000002000a000600000002000b000600000002000c000600000002000d000600000002000e000600000002000f0006000000020010000600000002001100060000000200120006000000020013000600000002001400060000000200150006000000020016000600000002001700060000000200180006000000020019000600000002001a000600000002001b000600000002001c001d00000002001e001d00000002001f001d000000020020001d000000020021001d000000020022001d000000020023001d000000020024001d000000020025001d000000020026001d000000020027001d000000020028001d000000020029001d00000002002a001d00000002002b002c00000002002d002c00000002002e002c00000002002f002c000000020030002c000000020031002c00000008000100320033000100340000019b00020001000000d72ab700362a01b500382a01b5003a2a01b5003c2a01b5003e2a01b500402a01b500422a01b500442a01b500462a01b500482a01b5004a2a01b5004c2a01b5004e2a01b500502a01b500522a01b500542a01b500562a01b500582a01b5005a2a01b5005c2a01b5005e2a01b500602a01b500622a01b500642a01b500662a01b500682a01b5006a2a01b5006c2a01b5006e2a01b500702a01b500722a01b500742a01b500762a01b500782a01b5007a2a01b5007c2a01b5007e2a01b500802a01b500822a01b500842a01b500862a01b500882a01b5008ab100000001008b000000b2002c00000012000400190009001a000e001b0013001c0018001d001d001e0022001f00270020002c00210031002200360023003b00240040002500450026004a0027004f0028005400290059002a005e002b0063002c0068002d006d002e0072002f00770030007c00310081003200860033008b00340090003500950036009a0037009f003800a4003900a9003a00ae003b00b3003c00b8003d00bd003e00c2003f00c7004000cc004100d1004200d600120001008c008d000100340000003400020004000000102a2bb700912a2cb700942a2db70097b100000001008b0000001200040000004e0005004f000a0050000f00510002008e008f00010034000001fd000300020000018d2a2b1299b9009f0200c000a1c000a1b500382a2b12a3b9009f0200c000a1c000a1b5003a2a2b12a5b9009f0200c000a1c000a1b5003c2a2b12a7b9009f0200c000a1c000a1b5003e2a2b12a9b9009f0200c000a1c000a1b500402a2b12abb9009f0200c000a1c000a1b500422a2b12adb9009f0200c000a1c000a1b500442a2b12afb9009f0200c000a1c000a1b500462a2b12b1b9009f0200c000a1c000a1b500482a2b12b3b9009f0200c000a1c000a1b5004a2a2b12b5b9009f0200c000a1c000a1b5004c2a2b12b7b9009f0200c000a1c000a1b5004e2a2b12b9b9009f0200c000a1c000a1b500502a2b12bbb9009f0200c000a1c000a1b500522a2b12bdb9009f0200c000a1c000a1b500542a2b12bfb9009f0200c000a1c000a1b500562a2b12c1b9009f0200c000a1c000a1b500582a2b12c3b9009f0200c000a1c000a1b5005a2a2b12c5b9009f0200c000a1c000a1b5005c2a2b12c7b9009f0200c000a1c000a1b5005e2a2b12c9b9009f0200c000a1c000a1b500602a2b12cbb9009f0200c000a1c000a1b50062b100000001008b0000005e0017000000590012005a0024005b0036005c0048005d005a005e006c005f007e00600090006100a2006200b4006300c6006400d8006500ea006600fc0067010e0068012000690132006a0144006b0156006c0168006d017a006e018c006f00020092008f000100340000014d00030002000000fd2a2b12cdb9009f0200c000cfc000cfb500642a2b12d1b9009f0200c000cfc000cfb500662a2b12d3b9009f0200c000cfc000cfb500682a2b12d5b9009f0200c000cfc000cfb5006a2a2b12d7b9009f0200c000cfc000cfb5006c2a2b12d9b9009f0200c000cfc000cfb5006e2a2b12dbb9009f0200c000cfc000cfb500702a2b12ddb9009f0200c000cfc000cfb500722a2b12dfb9009f0200c000cfc000cfb500742a2b12e1b9009f0200c000cfc000cfb500762a2b12e3b9009f0200c000cfc000cfb500782a2b12e5b9009f0200c000cfc000cfb5007a2a2b12e7b9009f0200c000cfc000cfb5007c2a2b12e9b9009f0200c000cfc000cfb5007eb100000001008b0000003e000f0000007700120078002400790036007a0048007b005a007c006c007d007e007e0090007f00a2008000b4008100c6008200d8008300ea008400fc008500020095008f000100340000009d000300020000006d2a2b12ebb9009f0200c000edc000edb500802a2b12efb9009f0200c000edc000edb500822a2b12f1b9009f0200c000edc000edb500842a2b12f3b9009f0200c000edc000edb500862a2b12f5b9009f0200c000edc000edb500882a2b12f7b9009f0200c000edc000edb5008ab100000001008b0000001e00070000008d0012008e0024008f0036009000480091005a0092006c0093000100f800f9000200fa00000004000100fc003400000522000400030000037e014d1baa000003790000000000000030000000d1000000d6000000db000000e0000000ec000000f800000104000001100000011c0000012800000134000001400000014c00000158000001710000017c00000187000001920000019d000001a8000001b3000001c1000001cf000001dd000001eb000001f90000020700000212000002200000022e0000023c0000024a00000258000002660000028a000002a3000002c1000002cc000002d7000002ef00000307000003120000031d0000032b000003390000034700000355000003600000036e014da702a6014da702a1014da7029cbb00fe5904b701014da70290bb00fe5904b701014da70284bb00fe5904b701014da70278bb00fe5903b701014da7026cbb00fe5904b701014da70260bb00fe5903b701014da70254bb00fe5904b701014da70248bb00fe5903b701014da7023cbb00fe5904b701014da70230bb00fe5903b701014da702242a2a130103b601072ab4006cb6010bc0010db601114da7020bbb011359b701144da702002a130116b601074da701f52a130118b601074da701ea2a13011ab601074da701df2a13011cb601074da701d42a13011eb601074da701c92ab40078b6010bc001204da701bb2ab40068b6010bc001134da701ad2ab4006ab6010bc0010d4da7019f2ab40066b6010bc0010d4da701912ab40076b6010bc001134da701832ab4007cb6010bc001134da701752a130122b601074da7016a2ab4007eb6010bc0010d4da7015c2ab40046b60123c000fe4da7014e2ab40062b60123c0010d4da701402ab40038b60123c001254da701322ab40060b60123c001274da701242ab4004cb60123c001294da70116bb012b592ab40044b60123c0010db8012fb70132130134b60138b6013cb801424da700f22a2a130144b601072ab40080b60145c000feb601114da700d9bb012b59130147b701322ab40080b60145c000feb6014ab6013c4da700bb2a13014cb601074da700b02a13014eb601074da700a5bb012b592a130150b60107b8012fb70132b6013c4da7008dbb012b592a130152b60107b8012fb70132b6013c4da700752a130154b601074da7006a2a130156b601074da7005f2ab40072b6010bc000fe4da700512ab40074b6010bc000fe4da700432ab40064b6010bc000fe4da700352ab40070b6010bc001134da700272a130158b601074da7001c2ab4007ab6010bc0010d4da7000e2ab4006eb6010bc0010d4d2cb000000001008b0000019200640000009b0002009d00d400a100d600a200d900a600db00a700de00ab00e000ac00e300b000ec00b100ef00b500f800b600fb00ba010400bb010700bf011000c0011300c4011c00c5011f00c9012800ca012b00ce013400cf013700d3014000d4014300d8014c00d9014f00dd015800de015b00e2017100e3017400e7017c00e8017f00ec018700ed018a00f1019200f2019500f6019d00f701a000fb01a800fc01ab010001b3010101b6010501c1010601c4010a01cf010b01d2010f01dd011001e0011401eb011501ee011901f9011a01fc011e0207011f020a01230212012402150128022001290223012d022e012e02310132023c0133023f0137024a0138024d013c0258013d025b01410266014202690146028a0147028d014b02a3014c02a6015002c1015102c4015502cc015602cf015a02d7015b02da015f02ef016002f2016403070165030a01690312016a0315016e031d016f03200173032b0174032e017803390179033c017d0347017e034a01820355018303580187036001880363018c036e018d03710191037c01990001015900f9000200fa00000004000100fc003400000522000400030000037e014d1baa000003790000000000000030000000d1000000d6000000db000000e0000000ec000000f800000104000001100000011c0000012800000134000001400000014c00000158000001710000017c00000187000001920000019d000001a8000001b3000001c1000001cf000001dd000001eb000001f90000020700000212000002200000022e0000023c0000024a00000258000002660000028a000002a3000002c1000002cc000002d7000002ef00000307000003120000031d0000032b000003390000034700000355000003600000036e014da702a6014da702a1014da7029cbb00fe5904b701014da70290bb00fe5904b701014da70284bb00fe5904b701014da70278bb00fe5903b701014da7026cbb00fe5904b701014da70260bb00fe5903b701014da70254bb00fe5904b701014da70248bb00fe5903b701014da7023cbb00fe5904b701014da70230bb00fe5903b701014da702242a2a130103b601072ab4006cb6015cc0010db601114da7020bbb011359b701144da702002a130116b601074da701f52a130118b601074da701ea2a13011ab601074da701df2a13011cb601074da701d42a13011eb601074da701c92ab40078b6015cc001204da701bb2ab40068b6015cc001134da701ad2ab4006ab6015cc0010d4da7019f2ab40066b6015cc0010d4da701912ab40076b6015cc001134da701832ab4007cb6015cc001134da701752a130122b601074da7016a2ab4007eb6015cc0010d4da7015c2ab40046b60123c000fe4da7014e2ab40062b60123c0010d4da701402ab40038b60123c001254da701322ab40060b60123c001274da701242ab4004cb60123c001294da70116bb012b592ab40044b60123c0010db8012fb70132130134b60138b6013cb801424da700f22a2a130144b601072ab40080b6015dc000feb601114da700d9bb012b59130147b701322ab40080b6015dc000feb6014ab6013c4da700bb2a13014cb601074da700b02a13014eb601074da700a5bb012b592a130150b60107b8012fb70132b6013c4da7008dbb012b592a130152b60107b8012fb70132b6013c4da700752a130154b601074da7006a2a130156b601074da7005f2ab40072b6015cc000fe4da700512ab40074b6015cc000fe4da700432ab40064b6015cc000fe4da700352ab40070b6015cc001134da700272a130158b601074da7001c2ab4007ab6015cc0010d4da7000e2ab4006eb6015cc0010d4d2cb000000001008b000001920064000001a2000201a400d401a800d601a900d901ad00db01ae00de01b200e001b300e301b700ec01b800ef01bc00f801bd00fb01c1010401c2010701c6011001c7011301cb011c01cc011f01d0012801d1012b01d5013401d6013701da014001db014301df014c01e0014f01e4015801e5015b01e9017101ea017401ee017c01ef017f01f3018701f4018a01f8019201f9019501fd019d01fe01a0020201a8020301ab020701b3020801b6020c01c1020d01c4021101cf021201d2021601dd021701e0021b01eb021c01ee022001f9022101fc022502070226020a022a0212022b0215022f0220023002230234022e023502310239023c023a023f023e024a023f024d024302580244025b0248026602490269024d028a024e028d025202a3025302a6025702c1025802c4025c02cc025d02cf026102d7026202da026602ef026702f2026b0307026c030a02700312027103150275031d02760320027a032b027b032e027f03390280033c028403470285034a02890355028a0358028e0360028f03630293036e029403710298037c02a00001015e00f9000200fa00000004000100fc003400000522000400030000037e014d1baa000003790000000000000030000000d1000000d6000000db000000e0000000ec000000f800000104000001100000011c0000012800000134000001400000014c00000158000001710000017c00000187000001920000019d000001a8000001b3000001c1000001cf000001dd000001eb000001f90000020700000212000002200000022e0000023c0000024a00000258000002660000028a000002a3000002c1000002cc000002d7000002ef00000307000003120000031d0000032b000003390000034700000355000003600000036e014da702a6014da702a1014da7029cbb00fe5904b701014da70290bb00fe5904b701014da70284bb00fe5904b701014da70278bb00fe5903b701014da7026cbb00fe5904b701014da70260bb00fe5903b701014da70254bb00fe5904b701014da70248bb00fe5903b701014da7023cbb00fe5904b701014da70230bb00fe5903b701014da702242a2a130103b601072ab4006cb6010bc0010db601114da7020bbb011359b701144da702002a130116b601074da701f52a130118b601074da701ea2a13011ab601074da701df2a13011cb601074da701d42a13011eb601074da701c92ab40078b6010bc001204da701bb2ab40068b6010bc001134da701ad2ab4006ab6010bc0010d4da7019f2ab40066b6010bc0010d4da701912ab40076b6010bc001134da701832ab4007cb6010bc001134da701752a130122b601074da7016a2ab4007eb6010bc0010d4da7015c2ab40046b60123c000fe4da7014e2ab40062b60123c0010d4da701402ab40038b60123c001254da701322ab40060b60123c001274da701242ab4004cb60123c001294da70116bb012b592ab40044b60123c0010db8012fb70132130134b60138b6013cb801424da700f22a2a130144b601072ab40080b60161c000feb601114da700d9bb012b59130147b701322ab40080b60161c000feb6014ab6013c4da700bb2a13014cb601074da700b02a13014eb601074da700a5bb012b592a130150b60107b8012fb70132b6013c4da7008dbb012b592a130152b60107b8012fb70132b6013c4da700752a130154b601074da7006a2a130156b601074da7005f2ab40072b6010bc000fe4da700512ab40074b6010bc000fe4da700432ab40064b6010bc000fe4da700352ab40070b6010bc001134da700272a130158b601074da7001c2ab4007ab6010bc0010d4da7000e2ab4006eb6010bc0010d4d2cb000000001008b000001920064000002a9000202ab00d402af00d602b000d902b400db02b500de02b900e002ba00e302be00ec02bf00ef02c300f802c400fb02c8010402c9010702cd011002ce011302d2011c02d3011f02d7012802d8012b02dc013402dd013702e1014002e2014302e6014c02e7014f02eb015802ec015b02f0017102f1017402f5017c02f6017f02fa018702fb018a02ff0192030001950304019d030501a0030901a8030a01ab030e01b3030f01b6031301c1031401c4031801cf031901d2031d01dd031e01e0032201eb032301ee032701f9032801fc032c0207032d020a03310212033202150336022003370223033b022e033c02310340023c0341023f0345024a0346024d034a0258034b025b034f0266035002690354028a0355028d035902a3035a02a6035e02c1035f02c4036302cc036402cf036802d7036902da036d02ef036e02f2037203070373030a0377031203780315037c031d037d03200381032b0382032e038603390387033c038b0347038c034a03900355039103580395036003960363039a036e039b0371039f037c03a7000101620000000200017400155f313339353231343030323630315f3836383636347400326e65742e73662e6a61737065727265706f7274732e656e67696e652e64657369676e2e4a524a61766163436f6d70696c6572	\N	2014-10-27 12:27:37.834589	Print	\N
3	Facilities Missing Supporting Requisition Group	\\xaced0005737200286e65742e73662e6a61737065727265706f7274732e656e67696e652e4a61737065725265706f727400000000000027d80200034c000b636f6d70696c65446174617400164c6a6176612f696f2f53657269616c697a61626c653b4c0011636f6d70696c654e616d655375666669787400124c6a6176612f6c616e672f537472696e673b4c000d636f6d70696c6572436c61737371007e00027872002d6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655265706f727400000000000027d802002a49001950534555444f5f53455249414c5f56455253494f4e5f55494449000c626f74746f6d4d617267696e49000b636f6c756d6e436f756e7449000d636f6c756d6e53706163696e6749000b636f6c756d6e57696474685a001069676e6f7265506167696e6174696f6e5a00136973466c6f6174436f6c756d6e466f6f7465725a0010697353756d6d6172794e6577506167655a0020697353756d6d6172795769746850616765486561646572416e64466f6f7465725a000e69735469746c654e65775061676549000a6c6566744d617267696e42000b6f7269656e746174696f6e49000a7061676548656967687449000970616765576964746842000a7072696e744f7264657249000b72696768744d617267696e490009746f704d617267696e42000e7768656e4e6f44617461547970654c000a6261636b67726f756e647400244c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5242616e643b4c000f636f6c756d6e446972656374696f6e7400334c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f52756e446972656374696f6e456e756d3b4c000c636f6c756d6e466f6f74657271007e00044c000c636f6c756d6e48656164657271007e00045b000864617461736574737400285b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52446174617365743b4c000c64656661756c745374796c657400254c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525374796c653b4c000664657461696c71007e00044c000d64657461696c53656374696f6e7400274c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5253656374696f6e3b4c0012666f726d6174466163746f7279436c61737371007e00024c000a696d706f72747353657474000f4c6a6176612f7574696c2f5365743b4c00086c616e677561676571007e00024c000e6c61737450616765466f6f74657271007e00044c000b6d61696e446174617365747400274c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52446174617365743b4c00046e616d6571007e00024c00066e6f4461746171007e00044c00106f7269656e746174696f6e56616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4f7269656e746174696f6e456e756d3b4c000a70616765466f6f74657271007e00044c000a7061676548656164657271007e00044c000f7072696e744f7264657256616c75657400314c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5072696e744f72646572456e756d3b5b00067374796c65737400265b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525374796c653b4c000773756d6d61727971007e00045b000974656d706c6174657374002f5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525265706f727454656d706c6174653b4c00057469746c6571007e00044c00137768656e4e6f446174615479706556616c75657400354c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5768656e4e6f4461746154797065456e756d3b78700000c3540000000000000001000000000000030e000100000000000000000000022b0000030e000000000000000000007372002b6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736542616e6400000000000027d802000749001950534555444f5f53455249414c5f56455253494f4e5f5549444900066865696768745a000e697353706c6974416c6c6f7765644c00137072696e745768656e45787072657373696f6e74002a4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5245787072657373696f6e3b4c000d70726f706572746965734d617074002d4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250726f706572746965734d61703b4c000973706c6974547970657400104c6a6176612f6c616e672f427974653b4c000e73706c69745479706556616c75657400304c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f53706c697454797065456e756d3b787200336e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365456c656d656e7447726f757000000000000027d80200024c00086368696c6472656e7400104c6a6176612f7574696c2f4c6973743b4c000c656c656d656e7447726f757074002c4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52456c656d656e7447726f75703b7870737200136a6176612e7574696c2e41727261794c6973747881d21d99c7619d03000149000473697a6578700000000077040000000a78700000c35400000000017070707e72002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e53706c697454797065456e756d00000000000000001200007872000e6a6176612e6c616e672e456e756d00000000000000001200007870740007535452455443487e7200316e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e52756e446972656374696f6e456e756d00000000000000001200007871007e001d7400034c545270707070707372002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736553656374696f6e00000000000027d80200015b000562616e64737400255b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5242616e643b7870757200255b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5242616e643b95dd7eec8cca85350200007870000000017371007e00117371007e001a0000000777040000000a737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365546578744669656c6400000000000027d802001549001950534555444f5f53455249414c5f56455253494f4e5f55494449000d626f6f6b6d61726b4c6576656c42000e6576616c756174696f6e54696d6542000f68797065726c696e6b54617267657442000d68797065726c696e6b547970655a0015697353747265746368576974684f766572666c6f774c0014616e63686f724e616d6545787072657373696f6e71007e00124c000f6576616c756174696f6e47726f75707400254c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5247726f75703b4c00136576616c756174696f6e54696d6556616c75657400354c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4576616c756174696f6e54696d65456e756d3b4c000a65787072657373696f6e71007e00124c001968797065726c696e6b416e63686f7245787072657373696f6e71007e00124c001768797065726c696e6b5061676545787072657373696f6e71007e00125b001368797065726c696e6b506172616d65746572737400335b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5248797065726c696e6b506172616d657465723b4c001c68797065726c696e6b5265666572656e636545787072657373696f6e71007e00124c001a68797065726c696e6b546f6f6c74697045787072657373696f6e71007e00124c001768797065726c696e6b5768656e45787072657373696f6e71007e00124c000f6973426c616e6b5768656e4e756c6c7400134c6a6176612f6c616e672f426f6f6c65616e3b4c000a6c696e6b54617267657471007e00024c00086c696e6b5479706571007e00024c00077061747465726e71007e00024c00117061747465726e45787072657373696f6e71007e0012787200326e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736554657874456c656d656e7400000000000027d802002549001950534555444f5f53455249414c5f56455253494f4e5f5549444c0006626f7264657271007e00144c000b626f72646572436f6c6f727400104c6a6176612f6177742f436f6c6f723b4c000c626f74746f6d426f7264657271007e00144c0011626f74746f6d426f72646572436f6c6f7271007e00304c000d626f74746f6d50616464696e677400134c6a6176612f6c616e672f496e74656765723b4c0008666f6e744e616d6571007e00024c0008666f6e7453697a6571007e00314c0013686f72697a6f6e74616c416c69676e6d656e7471007e00144c0018686f72697a6f6e74616c416c69676e6d656e7456616c75657400364c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f486f72697a6f6e74616c416c69676e456e756d3b4c00066973426f6c6471007e002e4c000869734974616c696371007e002e4c000d6973506466456d62656464656471007e002e4c000f6973537472696b655468726f75676871007e002e4c000c69735374796c65645465787471007e002e4c000b6973556e6465726c696e6571007e002e4c000a6c656674426f7264657271007e00144c000f6c656674426f72646572436f6c6f7271007e00304c000b6c65667450616464696e6771007e00314c00076c696e65426f787400274c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a524c696e65426f783b4c000b6c696e6553706163696e6771007e00144c00106c696e6553706163696e6756616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4c696e6553706163696e67456e756d3b4c00066d61726b757071007e00024c000770616464696e6771007e00314c00097061726167726170687400294c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525061726167726170683b4c000b706466456e636f64696e6771007e00024c000b706466466f6e744e616d6571007e00024c000b7269676874426f7264657271007e00144c00107269676874426f72646572436f6c6f7271007e00304c000c726967687450616464696e6771007e00314c0008726f746174696f6e71007e00144c000d726f746174696f6e56616c756574002f4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f526f746174696f6e456e756d3b4c0009746f70426f7264657271007e00144c000e746f70426f72646572436f6c6f7271007e00304c000a746f7050616464696e6771007e00314c0011766572746963616c416c69676e6d656e7471007e00144c0016766572746963616c416c69676e6d656e7456616c75657400344c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f566572746963616c416c69676e456e756d3b7872002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365456c656d656e7400000000000027d802001b49001950534555444f5f53455249414c5f56455253494f4e5f5549444900066865696768745a001769735072696e74496e466972737457686f6c6542616e645a001569735072696e74526570656174656456616c7565735a001a69735072696e745768656e44657461696c4f766572666c6f77735a0015697352656d6f76654c696e655768656e426c616e6b42000c706f736974696f6e5479706542000b7374726574636854797065490005776964746849000178490001794c00096261636b636f6c6f7271007e00304c001464656661756c745374796c6550726f76696465727400344c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5244656661756c745374796c6550726f76696465723b4c000c656c656d656e7447726f757071007e00184c0009666f7265636f6c6f7271007e00304c00036b657971007e00024c00046d6f646571007e00144c00096d6f646556616c756574002b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4d6f6465456e756d3b4c000b706172656e745374796c6571007e00074c0018706172656e745374796c654e616d655265666572656e636571007e00024c0011706f736974696f6e5479706556616c75657400334c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f506f736974696f6e54797065456e756d3b4c00137072696e745768656e45787072657373696f6e71007e00124c00157072696e745768656e47726f75704368616e67657371007e002b4c000d70726f706572746965734d617071007e00135b001370726f706572747945787072657373696f6e737400335b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250726f706572747945787072657373696f6e3b4c0010737472657463685479706556616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5374726574636854797065456e756d3b4c0004757569647400104c6a6176612f7574696c2f555549443b78700000c354000000140001000000000000006800000228000000007071007e001071007e00287070707070707e7200316e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e506f736974696f6e54797065456e756d00000000000000001200007871007e001d7400134649585f52454c41544956455f544f5f544f50707070707e7200306e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5374726574636854797065456e756d00000000000000001200007871007e001d74000a4e4f5f535452455443487372000e6a6176612e7574696c2e55554944bc9903f7986d852f0200024a000c6c65617374536967426974734a000b6d6f7374536967426974737870bf8fb4e8e8a3620a5cd9e45fa83f46270000c3547070707070707070707070707070707070707372002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173654c696e65426f7800000000000027d802000b4c000d626f74746f6d50616464696e6771007e00314c0009626f74746f6d50656e74002b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f626173652f4a52426f7850656e3b4c000c626f78436f6e7461696e657274002c4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52426f78436f6e7461696e65723b4c000b6c65667450616464696e6771007e00314c00076c65667450656e71007e00494c000770616464696e6771007e00314c000370656e71007e00494c000c726967687450616464696e6771007e00314c0008726967687450656e71007e00494c000a746f7050616464696e6771007e00314c0006746f7050656e71007e0049787070737200336e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f78426f74746f6d50656e00000000000027d80200007872002d6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f7850656e00000000000027d80200014c00076c696e65426f7871007e00337872002a6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736550656e00000000000027d802000649001950534555444f5f53455249414c5f56455253494f4e5f5549444c00096c696e65436f6c6f7271007e00304c00096c696e655374796c6571007e00144c000e6c696e655374796c6556616c75657400304c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4c696e655374796c65456e756d3b4c00096c696e6557696474687400114c6a6176612f6c616e672f466c6f61743b4c000c70656e436f6e7461696e657274002c4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250656e436f6e7461696e65723b78700000c3547070707071007e004b71007e004b71007e003f70737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f784c65667450656e00000000000027d80200007871007e004d0000c3547070707071007e004b71007e004b707371007e004d0000c3547070707071007e004b71007e004b70737200326e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f78526967687450656e00000000000027d80200007871007e004d0000c3547070707071007e004b71007e004b70737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f78546f7050656e00000000000027d80200007871007e004d0000c3547070707071007e004b71007e004b70707070737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736550617261677261706800000000000027d802000a4c000f66697273744c696e65496e64656e7471007e00314c000a6c656674496e64656e7471007e00314c000b6c696e6553706163696e6771007e00344c000f6c696e6553706163696e6753697a6571007e00504c0012706172616772617068436f6e7461696e65727400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52506172616772617068436f6e7461696e65723b4c000b7269676874496e64656e7471007e00314c000c73706163696e67416674657271007e00314c000d73706163696e674265666f726571007e00314c000c74616253746f70576964746871007e00314c000874616253746f707371007e001778707070707071007e003f70707070707070707070707070707070700000c354000000000000000070707e7200336e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e4576616c756174696f6e54696d65456e756d00000000000000001200007871007e001d7400034e4f57737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736545787072657373696f6e00000000000027d802000449000269645b00066368756e6b737400305b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5245787072657373696f6e4368756e6b3b4c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e000278700000000b757200305b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5245787072657373696f6e4368756e6b3b6d59cfde694ba355020000787000000001737200366e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736545787072657373696f6e4368756e6b00000000000027d8020002420004747970654c00047465787471007e000278700374000e67656f677261706869637a6f6e65707070707070707070707070707371007e002a0000c3540000001400010000000000000080000001a8000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e00468879e692ca246dc4f8bab911145749100000c3547070707070707070707070707070707070707371007e0048707371007e004c0000c3547070707071007e006a71007e006a71007e0068707371007e00530000c3547070707071007e006a71007e006a707371007e004d0000c3547070707071007e006a71007e006a707371007e00560000c3547070707071007e006a71007e006a707371007e00580000c3547070707071007e006a71007e006a707070707371007e005a7070707071007e006870707070707070707070707070707070700000c3540000000000000000707071007e005e7371007e00600000000c7571007e0063000000017371007e006503740014706172656e7467656f677261706869637a6f6e65707070707070707070707070707371007e002a0000c3540000001400010000000000000080000000e2000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e0046990e358e193a279795c7a6d65ba14e3e0000c3547070707070707070707070707070707070707371007e0048707371007e004c0000c3547070707071007e007771007e007771007e0075707371007e00530000c3547070707071007e007771007e0077707371007e004d0000c3547070707071007e007771007e0077707371007e00560000c3547070707071007e007771007e0077707371007e00580000c3547070707071007e007771007e0077707070707371007e005a7070707071007e007570707070707070707070707070707070700000c3540000000000000000707071007e005e7371007e00600000000d7571007e0063000000017371007e006503740010666163696c697479747970656e616d65707070707070707070707070707371007e002a0000c354000000140001000000000000007e00000290000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e00469d9e285c95e3e369857488dbeb8d44d00000c3547070707070707070707070707070707070707371007e0048707371007e004c0000c3547070707071007e008471007e008471007e0082707371007e00530000c3547070707071007e008471007e0084707371007e004d0000c3547070707071007e008471007e0084707371007e00560000c3547070707071007e008471007e0084707371007e00580000c3547070707071007e008471007e0084707070707371007e005a7070707071007e008270707070707070707070707070707070700000c3540000000000000000707071007e005e7371007e00600000000e7571007e0063000000017371007e00650374000b70726f6772616d6e616d65707070707070707070707070707371007e002a0000c354000000140001000000000000004600000162000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e00469e9fcd1bf48772847396086d2a404c6c0000c3547070707070707070707070707070707070707371007e0048707371007e004c0000c3547070707071007e009171007e009171007e008f707371007e00530000c3547070707071007e009171007e0091707371007e004d0000c3547070707071007e009171007e0091707371007e00560000c3547070707071007e009171007e0091707371007e00580000c3547070707071007e009171007e0091707070707371007e005a7070707071007e008f70707070707070707070707070707070700000c3540000000000000000707071007e005e7371007e00600000000f7571007e0063000000017371007e006503740006737461747573707070707070707070707070707371007e002a0000c35400000014000100000000000000ab00000037000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e0046807b993dcada8fda0c4098bfd02742d20000c3547070707070707070707070707070707070707371007e0048707371007e004c0000c3547070707071007e009e71007e009e71007e009c707371007e00530000c3547070707071007e009e71007e009e707371007e004d0000c3547070707071007e009e71007e009e707371007e00560000c3547070707071007e009e71007e009e707371007e00580000c3547070707071007e009e71007e009e707070707371007e005a7070707071007e009c70707070707070707070707070707070700000c3540000000000000000707071007e005e7371007e0060000000107571007e0063000000017371007e006503740008636f64656e616d65707070707070707070707070707371007e002a0000c354000000140001000000000000003700000000000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e0046a6ef3c97765d531deb632d7aa4f142e30000c35470707070707070707e7200346e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e486f72697a6f6e74616c416c69676e456e756d00000000000000001200007871007e001d74000643454e5445527070707070707070707371007e0048707371007e004c0000c3547070707071007e00ae71007e00ae71007e00a9707371007e00530000c3547070707071007e00ae71007e00ae707371007e004d0000c3547070707071007e00ae71007e00ae707371007e00560000c3547070707071007e00ae71007e00ae707371007e00580000c3547070707071007e00ae71007e00ae707070707371007e005a7070707071007e00a970707070707070707070707070707070700000c3540000000000000000707071007e005e7371007e0060000000117571007e0063000000017371007e00650474000c5245504f52545f434f554e547070707070707070707070707078700000c35400000014017070707070707400046a617661707372002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173654461746173657400000000000027d802001149001950534555444f5f53455249414c5f56455253494f4e5f5549445a000669734d61696e4200177768656e5265736f757263654d697373696e67547970655b00066669656c64737400265b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a524669656c643b4c001066696c74657245787072657373696f6e71007e00125b000667726f7570737400265b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5247726f75703b4c00046e616d6571007e00025b000a706172616d657465727374002a5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52506172616d657465723b4c000d70726f706572746965734d617071007e00134c000571756572797400254c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5251756572793b4c000e7265736f7572636542756e646c6571007e00024c000e7363726970746c6574436c61737371007e00025b000a7363726970746c65747374002a5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525363726970746c65743b5b000a736f72744669656c647374002a5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52536f72744669656c643b4c00047575696471007e003e5b00097661726961626c65737400295b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525661726961626c653b4c001c7768656e5265736f757263654d697373696e675479706556616c756574003e4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5768656e5265736f757263654d697373696e6754797065456e756d3b78700000c3540100757200265b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a524669656c643b023cdfc74e2af2700200007870000000087372002c6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173654669656c6400000000000027d80200054c000b6465736372697074696f6e71007e00024c00046e616d6571007e00024c000d70726f706572746965734d617071007e00134c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e0002787070740008636f64656e616d657372002b6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5250726f706572746965734d617000000000000027d80200034c00046261736571007e00134c000e70726f706572746965734c69737471007e00174c000d70726f706572746965734d617074000f4c6a6176612f7574696c2f4d61703b78707070707400106a6176612e6c616e672e537472696e67707371007e00c6707400067374617475737371007e00c97070707400106a6176612e6c616e672e537472696e67707371007e00c670740010666163696c697479747970656e616d657371007e00c97070707400106a6176612e6c616e672e537472696e67707371007e00c67074000b70726f6772616d6e616d657371007e00c97070707400106a6176612e6c616e672e537472696e67707371007e00c67074000e67656f677261706869637a6f6e657371007e00c97070707400106a6176612e6c616e672e537472696e67707371007e00c67074000967656f5f6c6576656c7371007e00c97070707400106a6176612e6c616e672e537472696e67707371007e00c670740014706172656e7467656f677261706869637a6f6e657371007e00c97070707400106a6176612e6c616e672e537472696e67707371007e00c67074001067656f5f6c6576656c5f706172656e747371007e00c97070707400106a6176612e6c616e672e537472696e677070707400077265706f7274317572002a5b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a52506172616d657465723b22000c8d2ac36021020000787000000013737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365506172616d6574657200000000000027d80200095a000e6973466f7250726f6d7074696e675a000f697353797374656d446566696e65644c001664656661756c7456616c756545787072657373696f6e71007e00124c000b6465736372697074696f6e71007e00024c00046e616d6571007e00024c000e6e6573746564547970654e616d6571007e00024c000d70726f706572746965734d617071007e00134c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e000278700101707074000e5245504f52545f434f4e54455854707371007e00c97070707400296e65742e73662e6a61737065727265706f7274732e656e67696e652e5265706f7274436f6e74657874707371007e00ec010170707400155245504f52545f504152414d45544552535f4d4150707371007e00c970707074000d6a6176612e7574696c2e4d6170707371007e00ec0101707074000d4a41535045525f5245504f5254707371007e00c97070707400286e65742e73662e6a61737065727265706f7274732e656e67696e652e4a61737065725265706f7274707371007e00ec010170707400115245504f52545f434f4e4e454354494f4e707371007e00c97070707400136a6176612e73716c2e436f6e6e656374696f6e707371007e00ec010170707400105245504f52545f4d41585f434f554e54707371007e00c97070707400116a6176612e6c616e672e496e7465676572707371007e00ec010170707400125245504f52545f444154415f534f55524345707371007e00c97070707400286e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5244617461536f75726365707371007e00ec010170707400105245504f52545f5343524950544c4554707371007e00c970707074002f6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5241627374726163745363726970746c6574707371007e00ec0101707074000d5245504f52545f4c4f43414c45707371007e00c97070707400106a6176612e7574696c2e4c6f63616c65707371007e00ec010170707400165245504f52545f5245534f555243455f42554e444c45707371007e00c97070707400186a6176612e7574696c2e5265736f7572636542756e646c65707371007e00ec010170707400105245504f52545f54494d455f5a4f4e45707371007e00c97070707400126a6176612e7574696c2e54696d655a6f6e65707371007e00ec010170707400155245504f52545f464f524d41545f464143544f5259707371007e00c970707074002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e7574696c2e466f726d6174466163746f7279707371007e00ec010170707400135245504f52545f434c4153535f4c4f41444552707371007e00c97070707400156a6176612e6c616e672e436c6173734c6f61646572707371007e00ec0101707074001a5245504f52545f55524c5f48414e444c45525f464143544f5259707371007e00c97070707400206a6176612e6e65742e55524c53747265616d48616e646c6572466163746f7279707371007e00ec010170707400145245504f52545f46494c455f5245534f4c564552707371007e00c970707074002d6e65742e73662e6a61737065727265706f7274732e656e67696e652e7574696c2e46696c655265736f6c766572707371007e00ec010170707400105245504f52545f54454d504c41544553707371007e00c97070707400146a6176612e7574696c2e436f6c6c656374696f6e707371007e00ec0101707074000b534f52545f4649454c4453707371007e00c970707074000e6a6176612e7574696c2e4c697374707371007e00ec0101707074000646494c544552707371007e00c97070707400296e65742e73662e6a61737065727265706f7274732e656e67696e652e4461746173657446696c746572707371007e00ec010170707400125245504f52545f5649525455414c495a4552707371007e00c97070707400296e65742e73662e6a61737065727265706f7274732e656e67696e652e4a525669727475616c697a6572707371007e00ec0101707074001449535f49474e4f52455f504147494e4154494f4e707371007e00c97070707400116a6176612e6c616e672e426f6f6c65616e707371007e00c9707371007e001a0000000377040000000374000c697265706f72742e7a6f6f6d740009697265706f72742e78740009697265706f72742e7978737200116a6176612e7574696c2e486173684d61700507dac1c31660d103000246000a6c6f6164466163746f724900097468726573686f6c6478703f400000000000037708000000040000000371007e013d7400013071007e013b740003312e3071007e013c74000130787372002c6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365517565727900000000000027d80200025b00066368756e6b7374002b5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5251756572794368756e6b3b4c00086c616e677561676571007e000278707572002b5b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5251756572794368756e6b3b409f00a1e8ba34a4020000787000000001737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736551756572794368756e6b00000000000027d8020003420004747970654c00047465787471007e00025b0006746f6b656e737400135b4c6a6176612f6c616e672f537472696e673b78700174074853454c4543540a2020462e636f6465207c7c20272d27207c7c20462e6e616d6520415320636f64656e616d652c0a20202843415345205748454e20462e616374697665203d2074727565205448454e202741637469766527205748454e20462e616374697665203d2066616c7365205448454e2027496e6163746976652720454e4429206173207374617475732c0a202046542e6e616d652020202020202020202020202020202020415320666163696c697479747970656e616d652c0a2020502e6e616d6520202020202020202020202020202020202041532070726f6772616d6e616d652c0a2020475a2e6e616d65202020202020202020202020202020202041532067656f677261706869635a6f6e652c0a2020474c2e6e616d65202020202020202020202020202020202041532067656f5f6c6576656c2c0a2020475a502e6e616d6520202020202020202020202020202020415320706172656e7467656f677261706869637a6f6e652c0a2020474c502e6e616d652020202020202020202020202020202041532067656f5f6c6576656c5f706172656e740a46524f4d202853454c4543540a2020202020202020462e6964202020202020202020415320666163696c6974792c0a202020202020202050532e70726f6772616d69642041532070726f6772616d0a20202020202046524f4d20666163696c697469657320460a2020202020202020494e4e4552204a4f494e2070726f6772616d735f737570706f727465642050530a202020202020202020204f4e2050532e666163696c6974796964203d20462e69640a20202020202020204c454654204f55544552204a4f494e207265717569736974696f6e5f67726f75705f6d656d626572732052474d0a202020202020202020204f4e20462e6964203d2052474d2e666163696c69747969640a20202020202020204c454654204f55544552204a4f494e207265717569736974696f6e5f67726f75705f70726f6772616d5f7363686564756c657320524750530a202020202020202020204f4e2050532e70726f6772616d6964203d20524750532e70726f6772616d69642077686572652050532e616374697665203d20545255450a2020202020204558434550540a20202020202053454c4543540a2020202020202020462e6964202020202020202020415320666163696c6974792c0a202020202020202050532e70726f6772616d69642041532070726f6772616d0a20202020202046524f4d20666163696c697469657320460a2020202020202020494e4e4552204a4f494e2070726f6772616d735f737570706f727465642050530a202020202020202020204f4e2050532e666163696c6974796964203d20462e69640a20202020202020204c454654204f55544552204a4f494e207265717569736974696f6e5f67726f75705f6d656d626572732052474d0a202020202020202020204f4e20462e6964203d2052474d2e666163696c69747969640a20202020202020204c454654204f55544552204a4f494e207265717569736974696f6e5f67726f75705f70726f6772616d5f7363686564756c657320524750530a202020202020202020204f4e2050532e70726f6772616d6964203d20524750532e70726f6772616d69640a20202020202057484552452052474d2e7265717569736974696f6e67726f75706964203d20524750532e7265717569736974696f6e67726f7570696429204153204946500a0a2020494e4e4552204a4f494e20666163696c697469657320460a202020204f4e20462e6964203d204946502e666163696c6974790a2020494e4e4552204a4f494e20666163696c6974795f74797065732046540a202020204f4e2046542e6964203d20462e7479706569640a2020494e4e4552204a4f494e2070726f6772616d7320500a202020204f4e20502e6964203d204946502e70726f6772616d0a2020494e4e4552204a4f494e2067656f677261706869635f7a6f6e657320475a0a202020204f4e20462e67656f677261706869637a6f6e656964203d20475a2e69640a2020494e4e4552204a4f494e2067656f677261706869635f6c6576656c7320474c0a202020204f4e20475a2e6c6576656c6964203d20474c2e69640a2020494e4e4552204a4f494e2067656f677261706869635f7a6f6e657320475a500a202020204f4e20475a2e706172656e746964203d20475a502e69640a2020494e4e4552204a4f494e2067656f677261706869635f6c6576656c7320474c500a202020204f4e20475a502e6c6576656c6964203d20474c502e69640a0a574845524520462e656e61626c6564203d20545255450a202020202020414e4420462e7669727475616c466163696c697479203d2046414c53450a202020202020414e4420462e736174656c6c697465203c3e20747275650a202020202020414e4420502e616374697665203d20545255450a202020202020414e4420502e70757368203d2046414c53450a4f52444552204259207374617475732c20475a502e6e616d652c20475a2e6e616d652c20462e636f64653b7074000373716c707070707371007e0046b3d554b1aefe96cea0a4e8610726422f757200295b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a525661726961626c653b62e6837c982cb7440200007870000000057372002f6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655661726961626c6500000000000027d802001149001950534555444f5f53455249414c5f56455253494f4e5f55494442000b63616c63756c6174696f6e42000d696e6372656d656e74547970655a000f697353797374656d446566696e65644200097265736574547970654c001063616c63756c6174696f6e56616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f43616c63756c6174696f6e456e756d3b4c000a65787072657373696f6e71007e00124c000e696e6372656d656e7447726f757071007e002b4c0012696e6372656d656e745479706556616c75657400344c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f496e6372656d656e7454797065456e756d3b4c001b696e6372656d656e746572466163746f7279436c6173734e616d6571007e00024c001f696e6372656d656e746572466163746f7279436c6173735265616c4e616d6571007e00024c0016696e697469616c56616c756545787072657373696f6e71007e00124c00046e616d6571007e00024c000a726573657447726f757071007e002b4c000e72657365745479706556616c75657400304c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f526573657454797065456e756d3b4c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e00027870000077ee000001007e7200306e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e43616c63756c6174696f6e456e756d00000000000000001200007871007e001d74000653595354454d70707e7200326e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e496e6372656d656e7454797065456e756d00000000000000001200007871007e001d7400044e4f4e4570707371007e0060000000007571007e0063000000017371007e0065017400186e6577206a6176612e6c616e672e496e7465676572283129707074000b504147455f4e554d424552707e72002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e526573657454797065456e756d00000000000000001200007871007e001d7400065245504f525471007e0100707371007e0150000077ee0000010071007e0156707071007e015970707371007e0060000000017571007e0063000000017371007e0065017400186e6577206a6176612e6c616e672e496e7465676572283129707074000d434f4c554d4e5f4e554d424552707e71007e01607400045041474571007e0100707371007e0150000077ee000001007e71007e0155740005434f554e547371007e0060000000027571007e0063000000017371007e0065017400186e6577206a6176612e6c616e672e496e746567657228312970707071007e015970707371007e0060000000037571007e0063000000017371007e0065017400186e6577206a6176612e6c616e672e496e7465676572283029707074000c5245504f52545f434f554e547071007e016171007e0100707371007e0150000077ee0000010071007e016c7371007e0060000000047571007e0063000000017371007e0065017400186e6577206a6176612e6c616e672e496e746567657228312970707071007e015970707371007e0060000000057571007e0063000000017371007e0065017400186e6577206a6176612e6c616e672e496e7465676572283029707074000a504147455f434f554e547071007e016971007e0100707371007e0150000077ee0000010071007e016c7371007e0060000000067571007e0063000000017371007e0065017400186e6577206a6176612e6c616e672e496e746567657228312970707071007e015970707371007e0060000000077571007e0063000000017371007e0065017400186e6577206a6176612e6c616e672e496e7465676572283029707074000c434f4c554d4e5f434f554e54707e71007e0160740006434f4c554d4e71007e0100707e72003c6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5768656e5265736f757263654d697373696e6754797065456e756d00000000000000001200007871007e001d7400044e554c4c71007e00e97371007e00117371007e001a0000000277040000000a737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655374617469635465787400000000000027d80200014c00047465787471007e00027871007e002f0000c354000000140001000000000000030e00000000000000207071007e001071007e019070707070707071007e00417070707071007e00447371007e00468769af621a8e549b488f93d8d2fe4df60000c354707070707070737200116a6176612e6c616e672e496e746567657212e2a0a4f781873802000149000576616c7565787200106a6176612e6c616e672e4e756d62657286ac951d0b94e08b02000078700000000f7071007e00ac7070707070707070707371007e0048707371007e004c0000c3547070707071007e019871007e019871007e0193707371007e00530000c3547070707071007e019871007e0198707371007e004d0000c3547070707071007e019871007e0198707371007e00560000c3547070707071007e019871007e0198707371007e00580000c3547070707071007e019871007e0198707070707371007e005a7070707071007e0193707070707070707070707070707070707074006e416c6c20666163696c69746965732070726f7065726c792061737369676e656420746f207265717569736974696f6e2067726f7570287329207468617420737570706f72742065616368206f662074686569722063757272656e746c79206163746976652070726f6772616d732e7371007e01920000c354000000200001000000000000030e00000000000000007071007e001071007e019070707070707071007e00417070707071007e00447371007e00469238092a1177a2f66659ba1e006b4f7f0000c354707070707074000953616e7353657269667371007e0195000000187071007e00ac7070707070737200116a6176612e6c616e672e426f6f6c65616ecd207280d59cfaee0200015a000576616c75657870017070707371007e0048707371007e004c0000c3547070707071007e01a671007e01a671007e01a0707371007e00530000c3547070707071007e01a671007e01a6707371007e004d0000c3547070707071007e01a671007e01a6707371007e00560000c3547070707071007e01a671007e01a6707371007e00580000c3547070707071007e01a671007e01a6707070707371007e005a7070707071007e01a0707070707070707070707070707070707074002f466163696c6974696573204d697373696e6720537570706f7274696e67205265717569736974696f6e2047726f757078700000c3540000003401707070707e7200306e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e4f7269656e746174696f6e456e756d00000000000000001200007871007e001d7400094c414e4453434150457371007e00117371007e001a0000000277040000000a7371007e002a0000c3540000001400010000000000000048000002c6000000007071007e001071007e01b170707070707071007e00417070707071007e00447371007e0046a6cd4885e72541551abcd2c71ce14a4b0000c354707070707074000953616e7353657269667371007e01950000000870707070707070707070707371007e0048707371007e004c0000c3547070707071007e01b771007e01b771007e01b3707371007e00530000c3547070707071007e01b771007e01b7707371007e004d0000c3547070707071007e01b771007e01b7707371007e00560000c3547070707071007e01b771007e01b7707371007e00580000c3547070707071007e01b771007e01b7707070707371007e005a7070707071007e01b370707070707070707070707070707070700000c3540000000000000000707071007e005e7371007e0060000000127571007e0063000000017371007e00650474000b504147455f4e554d424552707070707070707070707070707371007e01920000c35400000014000100000000000002c600000000000000007071007e001071007e01b170707070707071007e00417070707071007e00447371007e0046b62f68c26194b7c32e4a2985b90149630000c3547070707070707070707070707070707070707371007e0048707371007e004c0000c3547070707071007e01c471007e01c471007e01c2707371007e00530000c3547070707071007e01c471007e01c4707371007e004d0000c3547070707071007e01c471007e01c4707371007e00560000c3547070707071007e01c471007e01c4707371007e00580000c3547070707071007e01c471007e01c4707070707371007e005a7070707071007e01c270707070707070707070707070707070707400012078700000c3540000001401707070707371007e00117371007e001a0000000777040000000a7371007e01920000c3540000001400010000000000000080000000e2000000007071007e001071007e01cc70707070707071007e00417070707071007e00447371007e00469b596670c74bd785ef159a2f33d942ba0000c354707070707074000953616e7353657269667371007e01950000000c707071007e01a57070707071007e01a57070707371007e0048707371007e004c0000c3547070707071007e01d271007e01d271007e01ce707371007e00530000c3547070707071007e01d271007e01d2707371007e004d0000c3547070707071007e01d271007e01d2707371007e00560000c3547070707071007e01d271007e01d2707371007e00580000c3547070707071007e01d271007e01d2707070707371007e005a7070707071007e01ce707070707070707070707070707070707074000d466163696c69747920547970657371007e01920000c35400000014000100000000000000ab00000037000000007071007e001071007e01cc70707070707071007e00417070707071007e00447371007e00469f72d87cd57c5a0d9a07393f55224bce0000c354707070707074000953616e73536572696671007e01d1707071007e01a57070707071007e01a57070707371007e0048707371007e004c0000c3547070707071007e01dd71007e01dd71007e01da707371007e00530000c3547070707071007e01dd71007e01dd707371007e004d0000c3547070707071007e01dd71007e01dd707371007e00560000c3547070707071007e01dd71007e01dd707371007e00580000c3547070707071007e01dd71007e01dd707070707371007e005a7070707071007e01da7070707070707070707070707070707070740014466163696c69747920436f6465202d204e616d657371007e01920000c354000000140001000000000000004600000162000000007071007e001071007e01cc70707070707071007e00417070707071007e00447371007e0046b48a4feb4161ed645a7f10ba925c4ca70000c354707070707074000953616e73536572696671007e01d1707071007e01a57070707071007e01a57070707371007e0048707371007e004c0000c3547070707071007e01e871007e01e871007e01e5707371007e00530000c3547070707071007e01e871007e01e8707371007e004d0000c3547070707071007e01e871007e01e8707371007e00560000c3547070707071007e01e871007e01e8707371007e00580000c3547070707071007e01e871007e01e8707070707371007e005a7070707071007e01e570707070707070707070707070707070707400065374617475737371007e01920000c354000000140001000000000000007e00000290000000007071007e001071007e01cc70707070707071007e00417070707071007e00447371007e0046971680a78c3269f83161a1ea075d4af80000c35470707070707071007e01d1707071007e01a57070707071007e01a57070707371007e0048707371007e004c0000c3547070707071007e01f271007e01f271007e01f0707371007e00530000c3547070707071007e01f271007e01f2707371007e004d0000c3547070707071007e01f271007e01f2707371007e00560000c3547070707071007e01f271007e01f2707371007e00580000c3547070707071007e01f271007e01f2707070707371007e005a7070707071007e01f0707070707070707070707070707070707074000750726f6772616d7371007e002a0000c354000000140001000000000000006800000228000000007071007e001071007e01cc70707070707071007e00417070707071007e00447371007e00469095c3dfae17053a2ec662981d0b4a170000c35470707070707071007e01d1707071007e01a57070707071007e01a57070707371007e0048707371007e004c0000c3547070707071007e01fc71007e01fc71007e01fa707371007e00530000c3547070707071007e01fc71007e01fc707371007e004d0000c3547070707071007e01fc71007e01fc707371007e00560000c3547070707071007e01fc71007e01fc707371007e00580000c3547070707071007e01fc71007e01fc707070707371007e005a7070707071007e01fa70707070707070707070707070707070700000c3540000000000000000707071007e005e7371007e0060000000097571007e0063000000017371007e00650374001067656f5f6c6576656c5f706172656e74707070707070707070707070707371007e002a0000c3540000001400010000000000000080000001a8000000007071007e001071007e01cc70707070707071007e00417070707071007e00447371007e00469f10e829735ed20e535fc724225549e10000c35470707070707071007e01d1707071007e01a57070707071007e01a57070707371007e0048707371007e004c0000c3547070707071007e020971007e020971007e0207707371007e00530000c3547070707071007e020971007e0209707371007e004d0000c3547070707071007e020971007e0209707371007e00560000c3547070707071007e020971007e0209707371007e00580000c3547070707071007e020971007e0209707070707371007e005a7070707071007e020770707070707070707070707070707070700000c3540000000000000000707071007e005e7371007e00600000000a7571007e0063000000017371007e00650374000967656f5f6c6576656c707070707070707070707070707371007e01920000c354000000140001000000000000003700000000000000007071007e001071007e01cc70707070707071007e00417070707071007e00447371007e0046b801bab259cd2177038536ecacb14e500000c35470707070707071007e01d17071007e00ac71007e01a57070707071007e01a57070707371007e0048707371007e004c0000c3547070707071007e021671007e021671007e0214707371007e00530000c3547070707071007e021671007e0216707371007e004d0000c3547070707071007e021671007e0216707371007e00560000c3547070707071007e021671007e0216707371007e00580000c3547070707071007e021671007e0216707070707371007e005a7070707071007e02147070707070707070707070707070707070740005532e4e6f2e78700000c354000000140170707071007e001e7e72002f6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5072696e744f72646572456e756d00000000000000001200007871007e001d740008564552544943414c757200265b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a525374796c653bd49cc311d90572350200007870000000087372002c6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655374796c65000000000000271102003a49001950534555444f5f53455249414c5f56455253494f4e5f5549445a0009697344656661756c744c00096261636b636f6c6f7271007e00304c0006626f7264657271007e00144c000b626f72646572436f6c6f7271007e00304c000c626f74746f6d426f7264657271007e00144c0011626f74746f6d426f72646572436f6c6f7271007e00304c000d626f74746f6d50616464696e6771007e00315b0011636f6e646974696f6e616c5374796c65737400315b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52436f6e646974696f6e616c5374796c653b4c001464656661756c745374796c6550726f766964657271007e00394c000466696c6c71007e00144c000966696c6c56616c756574002b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f46696c6c456e756d3b4c0008666f6e744e616d6571007e00024c0008666f6e7453697a6571007e00314c0009666f7265636f6c6f7271007e00304c0013686f72697a6f6e74616c416c69676e6d656e7471007e00144c0018686f72697a6f6e74616c416c69676e6d656e7456616c756571007e00324c000f6973426c616e6b5768656e4e756c6c71007e002e4c00066973426f6c6471007e002e4c000869734974616c696371007e002e4c000d6973506466456d62656464656471007e002e4c000f6973537472696b655468726f75676871007e002e4c000c69735374796c65645465787471007e002e4c000b6973556e6465726c696e6571007e002e4c000a6c656674426f7264657271007e00144c000f6c656674426f72646572436f6c6f7271007e00304c000b6c65667450616464696e6771007e00314c00076c696e65426f7871007e00334c00076c696e6550656e7400234c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250656e3b4c000b6c696e6553706163696e6771007e00144c00106c696e6553706163696e6756616c756571007e00344c00066d61726b757071007e00024c00046d6f646571007e00144c00096d6f646556616c756571007e003a4c00046e616d6571007e00024c000770616464696e6771007e00314c000970617261677261706871007e00354c000b706172656e745374796c6571007e00074c0018706172656e745374796c654e616d655265666572656e636571007e00024c00077061747465726e71007e00024c000b706466456e636f64696e6771007e00024c000b706466466f6e744e616d6571007e00024c000370656e71007e00144c000c706f736974696f6e5479706571007e00144c000672616469757371007e00314c000b7269676874426f7264657271007e00144c00107269676874426f72646572436f6c6f7271007e00304c000c726967687450616464696e6771007e00314c0008726f746174696f6e71007e00144c000d726f746174696f6e56616c756571007e00364c000a7363616c65496d61676571007e00144c000f7363616c65496d61676556616c75657400314c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5363616c65496d616765456e756d3b4c000b737472657463685479706571007e00144c0009746f70426f7264657271007e00144c000e746f70426f72646572436f6c6f7271007e00304c000a746f7050616464696e6771007e00314c0011766572746963616c416c69676e6d656e7471007e00144c0016766572746963616c416c69676e6d656e7456616c756571007e003778700000c35400707070707070707070707070707070707070707070707070707371007e0048707371007e004c0000c3547070707071007e022971007e022971007e0228707371007e00530000c3547070707071007e022971007e0229707371007e004d0000c3547372000e6a6176612e6177742e436f6c6f7201a51783108f337502000546000666616c70686149000576616c75654c0002637374001b4c6a6176612f6177742f636f6c6f722f436f6c6f7253706163653b5b00096672676276616c75657400025b465b00066676616c756571007e022f787000000000ff00000070707070707372000f6a6176612e6c616e672e466c6f6174daedc9a2db3cf0ec02000146000576616c75657871007e01963f80000071007e022971007e0229707371007e00560000c3547070707071007e022971007e0229707371007e00580000c3547070707071007e022971007e02297371007e004e0000c3547070707071007e022870707070707400057461626c65707371007e005a7070707071007e022870707070707070707070707070707070707070707070707070707371007e02230000c354007371007e022d00000000fff0f8ff7070707070707070707070707070707070707070707070707070707371007e0048707371007e004c0000c3547070707071007e023a71007e023a71007e0238707371007e00530000c3547070707071007e023a71007e023a707371007e004d0000c3547371007e022d00000000ff00000070707070707371007e02313f00000071007e023a71007e023a707371007e00560000c3547070707071007e023a71007e023a707371007e00580000c3547070707071007e023a71007e023a7371007e004e0000c3547070707071007e0238707070707e7200296e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e4d6f6465456e756d00000000000000001200007871007e001d7400064f50415155457400087461626c655f5448707371007e005a7070707071007e023870707070707070707070707070707070707070707070707070707371007e02230000c354007371007e022d00000000ffbfe1ff7070707070707070707070707070707070707070707070707070707371007e0048707371007e004c0000c3547070707071007e024a71007e024a71007e0248707371007e00530000c3547070707071007e024a71007e024a707371007e004d0000c3547371007e022d00000000ff00000070707070707371007e02313f00000071007e024a71007e024a707371007e00560000c3547070707071007e024a71007e024a707371007e00580000c3547070707071007e024a71007e024a7371007e004e0000c3547070707071007e02487070707071007e02447400087461626c655f4348707371007e005a7070707071007e024870707070707070707070707070707070707070707070707070707371007e02230000c354007371007e022d00000000ffffffff7070707070707070707070707070707070707070707070707070707371007e0048707371007e004c0000c3547070707071007e025771007e025771007e0255707371007e00530000c3547070707071007e025771007e0257707371007e004d0000c3547371007e022d00000000ff00000070707070707371007e02313f00000071007e025771007e0257707371007e00560000c3547070707071007e025771007e0257707371007e00580000c3547070707071007e025771007e02577371007e004e0000c3547070707071007e02557070707071007e02447400087461626c655f5444707371007e005a7070707071007e025570707070707070707070707070707070707070707070707070707371007e02230000c35400707070707070707070707070707070707070707070707070707371007e0048707371007e004c0000c3547070707071007e026371007e026371007e0262707371007e00530000c3547070707071007e026371007e0263707371007e004d0000c3547371007e022d00000000ff00000070707070707371007e02313f80000071007e026371007e0263707371007e00560000c3547070707071007e026371007e0263707371007e00580000c3547070707071007e026371007e02637371007e004e0000c3547070707071007e026270707070707400077461626c652031707371007e005a7070707071007e026270707070707070707070707070707070707070707070707070707371007e02230000c354007371007e022d00000000fff0f8ff7070707070707070707070707070707070707070707070707070707371007e0048707371007e004c0000c3547070707071007e027071007e027071007e026e707371007e00530000c3547070707071007e027071007e0270707371007e004d0000c3547371007e022d00000000ff00000070707070707371007e02313f00000071007e027071007e0270707371007e00560000c3547070707071007e027071007e0270707371007e00580000c3547070707071007e027071007e02707371007e004e0000c3547070707071007e026e7070707071007e024474000a7461626c6520315f5448707371007e005a7070707071007e026e70707070707070707070707070707070707070707070707070707371007e02230000c354007371007e022d00000000ffbfe1ff7070707070707070707070707070707070707070707070707070707371007e0048707371007e004c0000c3547070707071007e027d71007e027d71007e027b707371007e00530000c3547070707071007e027d71007e027d707371007e004d0000c3547371007e022d00000000ff00000070707070707371007e02313f00000071007e027d71007e027d707371007e00560000c3547070707071007e027d71007e027d707371007e00580000c3547070707071007e027d71007e027d7371007e004e0000c3547070707071007e027b7070707071007e024474000a7461626c6520315f4348707371007e005a7070707071007e027b70707070707070707070707070707070707070707070707070707371007e02230000c354007371007e022d00000000ffffffff7070707070707070707070707070707070707070707070707070707371007e0048707371007e004c0000c3547070707071007e028a71007e028a71007e0288707371007e00530000c3547070707071007e028a71007e028a707371007e004d0000c3547371007e022d00000000ff00000070707070707371007e02313f00000071007e028a71007e028a707371007e00560000c3547070707071007e028a71007e028a707371007e00580000c3547070707071007e028a71007e028a7371007e004e0000c3547070707071007e02887070707071007e024474000a7461626c6520315f5444707371007e005a7070707071007e0288707070707070707070707070707070707070707070707070707070707371007e00117371007e001a0000000277040000000a7371007e01920000c35400000020000100000000000002c600000000000000007071007e001071007e029570707070707071007e00417070707071007e00447371007e00468f61a735ab2074b7212194e972ca43210000c354707070707074000953616e73536572696671007e01a37071007e00ac707070707071007e01a57070707371007e0048707371007e004c0000c3547070707071007e029a71007e029a71007e0297707371007e00530000c3547070707071007e029a71007e029a707371007e004d0000c3547070707071007e029a71007e029a707371007e00560000c3547070707071007e029a71007e029a707371007e00580000c3547070707071007e029a71007e029a707070707371007e005a7070707071007e0297707070707070707070707070707070707074002f466163696c6974696573204d697373696e6720537570706f7274696e67205265717569736974696f6e2047726f75707371007e002a0000c3540000002000010000000000000048000002c6000000007071007e001071007e029570707070707071007e00417070707071007e00447371007e004689ab02f2dda79bb52dd094dce4b543c00000c354707070707074000953616e73536572696671007e01b670707070707070707070707371007e0048707371007e004c0000c3547070707071007e02a571007e02a571007e02a2707371007e00530000c3547070707071007e02a571007e02a5707371007e004d0000c3547070707071007e02a571007e02a5707371007e00560000c3547070707071007e02a571007e02a5707371007e00580000c3547070707071007e02a571007e02a5707070707371007e005a7070707071007e02a270707070707070707070707070707070700000c3540000000000000000707071007e005e7371007e0060000000087571007e0063000000017371007e0065017400146e6577206a6176612e7574696c2e446174652829707070707070707070707074000a64642f4d4d2f797979797078700000c3540000002001707070707e7200336e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5768656e4e6f4461746154797065456e756d00000000000000001200007871007e001d74000f4e4f5f444154415f53454354494f4e737200366e65742e73662e6a61737065727265706f7274732e656e67696e652e64657369676e2e4a525265706f7274436f6d70696c654461746100000000000027d80200034c001363726f7373746162436f6d70696c654461746171007e00ca4c001264617461736574436f6d70696c654461746171007e00ca4c00166d61696e44617461736574436f6d70696c654461746171007e000178707371007e013e3f4000000000000c77080000001000000000787371007e013e3f4000000000000c7708000000100000000078757200025b42acf317f8060854e002000078700000175dcafebabe0000002e00e401001c7265706f7274315f313338303137383933343638305f31323737393907000101002c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a524576616c7561746f72070003010017706172616d657465725f5245504f52545f4c4f43414c450100324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c506172616d657465723b010017706172616d657465725f4a41535045525f5245504f525401001c706172616d657465725f5245504f52545f5649525455414c495a455201001a706172616d657465725f5245504f52545f54494d455f5a4f4e45010015706172616d657465725f534f52545f4649454c445301001e706172616d657465725f5245504f52545f46494c455f5245534f4c56455201001a706172616d657465725f5245504f52545f5343524950544c455401001f706172616d657465725f5245504f52545f504152414d45544552535f4d415001001b706172616d657465725f5245504f52545f434f4e4e454354494f4e010018706172616d657465725f5245504f52545f434f4e5445585401001d706172616d657465725f5245504f52545f434c4153535f4c4f41444552010024706172616d657465725f5245504f52545f55524c5f48414e444c45525f464143544f525901001c706172616d657465725f5245504f52545f444154415f534f5552434501001e706172616d657465725f49535f49474e4f52455f504147494e4154494f4e010010706172616d657465725f46494c54455201001f706172616d657465725f5245504f52545f464f524d41545f464143544f525901001a706172616d657465725f5245504f52545f4d41585f434f554e5401001a706172616d657465725f5245504f52545f54454d504c41544553010020706172616d657465725f5245504f52545f5245534f555243455f42554e444c4501001a6669656c645f706172656e7467656f677261706869637a6f6e6501002e4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c4669656c643b01000c6669656c645f73746174757301000e6669656c645f636f64656e616d650100146669656c645f67656f677261706869637a6f6e6501000f6669656c645f67656f5f6c6576656c0100116669656c645f70726f6772616d6e616d650100166669656c645f67656f5f6c6576656c5f706172656e740100166669656c645f666163696c697479747970656e616d650100147661726961626c655f504147455f4e554d4245520100314c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c5661726961626c653b0100167661726961626c655f434f4c554d4e5f4e554d4245520100157661726961626c655f5245504f52545f434f554e540100137661726961626c655f504147455f434f554e540100157661726961626c655f434f4c554d4e5f434f554e540100063c696e69743e010003282956010004436f64650c002800290a0004002b0c00050006090002002d0c00070006090002002f0c0008000609000200310c0009000609000200330c000a000609000200350c000b000609000200370c000c000609000200390c000d0006090002003b0c000e0006090002003d0c000f0006090002003f0c0010000609000200410c0011000609000200430c0012000609000200450c0013000609000200470c0014000609000200490c00150006090002004b0c00160006090002004d0c00170006090002004f0c0018000609000200510c0019001a09000200530c001b001a09000200550c001c001a09000200570c001d001a09000200590c001e001a090002005b0c001f001a090002005d0c0020001a090002005f0c0021001a09000200610c0022002309000200630c0024002309000200650c0025002309000200670c0026002309000200690c00270023090002006b01000f4c696e654e756d6265725461626c6501000e637573746f6d697a6564496e6974010030284c6a6176612f7574696c2f4d61703b4c6a6176612f7574696c2f4d61703b4c6a6176612f7574696c2f4d61703b295601000a696e6974506172616d73010012284c6a6176612f7574696c2f4d61703b29560c007000710a0002007201000a696e69744669656c64730c007400710a00020075010008696e6974566172730c007700710a0002007801000d5245504f52545f4c4f43414c4508007a01000d6a6176612f7574696c2f4d617007007c010003676574010026284c6a6176612f6c616e672f4f626a6563743b294c6a6176612f6c616e672f4f626a6563743b0c007e007f0b007d00800100306e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c506172616d6574657207008201000d4a41535045525f5245504f52540800840100125245504f52545f5649525455414c495a45520800860100105245504f52545f54494d455f5a4f4e4508008801000b534f52545f4649454c445308008a0100145245504f52545f46494c455f5245534f4c56455208008c0100105245504f52545f5343524950544c455408008e0100155245504f52545f504152414d45544552535f4d41500800900100115245504f52545f434f4e4e454354494f4e08009201000e5245504f52545f434f4e544558540800940100135245504f52545f434c4153535f4c4f4144455208009601001a5245504f52545f55524c5f48414e444c45525f464143544f52590800980100125245504f52545f444154415f534f5552434508009a01001449535f49474e4f52455f504147494e4154494f4e08009c01000646494c54455208009e0100155245504f52545f464f524d41545f464143544f52590800a00100105245504f52545f4d41585f434f554e540800a20100105245504f52545f54454d504c415445530800a40100165245504f52545f5245534f555243455f42554e444c450800a6010014706172656e7467656f677261706869637a6f6e650800a801002c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c4669656c640700aa0100067374617475730800ac010008636f64656e616d650800ae01000e67656f677261706869637a6f6e650800b001000967656f5f6c6576656c0800b201000b70726f6772616d6e616d650800b401001067656f5f6c6576656c5f706172656e740800b6010010666163696c697479747970656e616d650800b801000b504147455f4e554d4245520800ba01002f6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c5661726961626c650700bc01000d434f4c554d4e5f4e554d4245520800be01000c5245504f52545f434f554e540800c001000a504147455f434f554e540800c201000c434f4c554d4e5f434f554e540800c40100086576616c756174650100152849294c6a6176612f6c616e672f4f626a6563743b01000a457863657074696f6e730100136a6176612f6c616e672f5468726f7761626c650700c90100116a6176612f6c616e672f496e74656765720700cb010004284929560c002800cd0a00cc00ce01000e6a6176612f7574696c2f446174650700d00a00d1002b01000867657456616c756501001428294c6a6176612f6c616e672f4f626a6563743b0c00d300d40a00ab00d50100106a6176612f6c616e672f537472696e670700d70a00bd00d501000b6576616c756174654f6c6401000b6765744f6c6456616c75650c00db00d40a00ab00dc0a00bd00dc0100116576616c75617465457374696d61746564010011676574457374696d6174656456616c75650c00e000d40a00bd00e101000a536f7572636546696c650021000200040000002000020005000600000002000700060000000200080006000000020009000600000002000a000600000002000b000600000002000c000600000002000d000600000002000e000600000002000f0006000000020010000600000002001100060000000200120006000000020013000600000002001400060000000200150006000000020016000600000002001700060000000200180006000000020019001a00000002001b001a00000002001c001a00000002001d001a00000002001e001a00000002001f001a000000020020001a000000020021001a00000002002200230000000200240023000000020025002300000002002600230000000200270023000000080001002800290001002a0000014100020001000000a52ab7002c2a01b5002e2a01b500302a01b500322a01b500342a01b500362a01b500382a01b5003a2a01b5003c2a01b5003e2a01b500402a01b500422a01b500442a01b500462a01b500482a01b5004a2a01b5004c2a01b5004e2a01b500502a01b500522a01b500542a01b500562a01b500582a01b5005a2a01b5005c2a01b5005e2a01b500602a01b500622a01b500642a01b500662a01b500682a01b5006a2a01b5006cb100000001006d0000008a002200000012000400190009001a000e001b0013001c0018001d001d001e0022001f00270020002c00210031002200360023003b00240040002500450026004a0027004f0028005400290059002a005e002b0063002c0068002d006d002e0072002f00770030007c00310081003200860033008b00340090003500950036009a0037009f003800a400120001006e006f0001002a0000003400020004000000102a2bb700732a2cb700762a2db70079b100000001006d0000001200040000004400050045000a0046000f00470002007000710001002a000001bb00030002000001572a2b127bb900810200c00083c00083b5002e2a2b1285b900810200c00083c00083b500302a2b1287b900810200c00083c00083b500322a2b1289b900810200c00083c00083b500342a2b128bb900810200c00083c00083b500362a2b128db900810200c00083c00083b500382a2b128fb900810200c00083c00083b5003a2a2b1291b900810200c00083c00083b5003c2a2b1293b900810200c00083c00083b5003e2a2b1295b900810200c00083c00083b500402a2b1297b900810200c00083c00083b500422a2b1299b900810200c00083c00083b500442a2b129bb900810200c00083c00083b500462a2b129db900810200c00083c00083b500482a2b129fb900810200c00083c00083b5004a2a2b12a1b900810200c00083c00083b5004c2a2b12a3b900810200c00083c00083b5004e2a2b12a5b900810200c00083c00083b500502a2b12a7b900810200c00083c00083b50052b100000001006d0000005200140000004f00120050002400510036005200480053005a0054006c0055007e00560090005700a2005800b4005900c6005a00d8005b00ea005c00fc005d010e005e0120005f0132006001440061015600620002007400710001002a000000c900030002000000912a2b12a9b900810200c000abc000abb500542a2b12adb900810200c000abc000abb500562a2b12afb900810200c000abc000abb500582a2b12b1b900810200c000abc000abb5005a2a2b12b3b900810200c000abc000abb5005c2a2b12b5b900810200c000abc000abb5005e2a2b12b7b900810200c000abc000abb500602a2b12b9b900810200c000abc000abb50062b100000001006d0000002600090000006a0012006b0024006c0036006d0048006e005a006f006c0070007e0071009000720002007700710001002a00000087000300020000005b2a2b12bbb900810200c000bdc000bdb500642a2b12bfb900810200c000bdc000bdb500662a2b12c1b900810200c000bdc000bdb500682a2b12c3b900810200c000bdc000bdb5006a2a2b12c5b900810200c000bdc000bdb5006cb100000001006d0000001a00060000007a0012007b0024007c0036007d0048007e005a007f000100c600c7000200c800000004000100ca002a000002060003000300000152014d1baa0000014d00000000000000120000005900000065000000710000007d0000008900000095000000a1000000ad000000b9000000c4000000d2000000e0000000ee000000fc0000010a00000118000001260000013400000142bb00cc5904b700cf4da700ebbb00cc5904b700cf4da700dfbb00cc5904b700cf4da700d3bb00cc5903b700cf4da700c7bb00cc5904b700cf4da700bbbb00cc5903b700cf4da700afbb00cc5904b700cf4da700a3bb00cc5903b700cf4da70097bb00d159b700d24da7008c2ab40060b600d6c000d84da7007e2ab4005cb600d6c000d84da700702ab4005ab600d6c000d84da700622ab40054b600d6c000d84da700542ab40062b600d6c000d84da700462ab4005eb600d6c000d84da700382ab40056b600d6c000d84da7002a2ab40058b600d6c000d84da7001c2ab40068b600d9c000cc4da7000e2ab40064b600d9c000cc4d2cb000000001006d000000a200280000008700020089005c008d0065008e006800920071009300740097007d00980080009c0089009d008c00a1009500a2009800a600a100a700a400ab00ad00ac00b000b000b900b100bc00b500c400b600c700ba00d200bb00d500bf00e000c000e300c400ee00c500f100c900fc00ca00ff00ce010a00cf010d00d3011800d4011b00d8012600d9012900dd013400de013700e2014200e3014500e7015000ef000100da00c7000200c800000004000100ca002a000002060003000300000152014d1baa0000014d00000000000000120000005900000065000000710000007d0000008900000095000000a1000000ad000000b9000000c4000000d2000000e0000000ee000000fc0000010a00000118000001260000013400000142bb00cc5904b700cf4da700ebbb00cc5904b700cf4da700dfbb00cc5904b700cf4da700d3bb00cc5903b700cf4da700c7bb00cc5904b700cf4da700bbbb00cc5903b700cf4da700afbb00cc5904b700cf4da700a3bb00cc5903b700cf4da70097bb00d159b700d24da7008c2ab40060b600ddc000d84da7007e2ab4005cb600ddc000d84da700702ab4005ab600ddc000d84da700622ab40054b600ddc000d84da700542ab40062b600ddc000d84da700462ab4005eb600ddc000d84da700382ab40056b600ddc000d84da7002a2ab40058b600ddc000d84da7001c2ab40068b600dec000cc4da7000e2ab40064b600dec000cc4d2cb000000001006d000000a20028000000f8000200fa005c00fe006500ff006801030071010400740108007d01090080010d0089010e008c0112009501130098011700a1011800a4011c00ad011d00b0012100b9012200bc012600c4012700c7012b00d2012c00d5013000e0013100e3013500ee013600f1013a00fc013b00ff013f010a0140010d014401180145011b01490126014a0129014e0134014f01370153014201540145015801500160000100df00c7000200c800000004000100ca002a000002060003000300000152014d1baa0000014d00000000000000120000005900000065000000710000007d0000008900000095000000a1000000ad000000b9000000c4000000d2000000e0000000ee000000fc0000010a00000118000001260000013400000142bb00cc5904b700cf4da700ebbb00cc5904b700cf4da700dfbb00cc5904b700cf4da700d3bb00cc5903b700cf4da700c7bb00cc5904b700cf4da700bbbb00cc5903b700cf4da700afbb00cc5904b700cf4da700a3bb00cc5903b700cf4da70097bb00d159b700d24da7008c2ab40060b600d6c000d84da7007e2ab4005cb600d6c000d84da700702ab4005ab600d6c000d84da700622ab40054b600d6c000d84da700542ab40062b600d6c000d84da700462ab4005eb600d6c000d84da700382ab40056b600d6c000d84da7002a2ab40058b600d6c000d84da7001c2ab40068b600e2c000cc4da7000e2ab40064b600e2c000cc4d2cb000000001006d000000a20028000001690002016b005c016f00650170006801740071017500740179007d017a0080017e0089017f008c0183009501840098018800a1018900a4018d00ad018e00b0019200b9019300bc019700c4019800c7019c00d2019d00d501a100e001a200e301a600ee01a700f101ab00fc01ac00ff01b0010a01b1010d01b5011801b6011b01ba012601bb012901bf013401c0013701c4014201c5014501c9015001d1000100e30000000200017400155f313338303137383933343638305f3132373739397400326e65742e73662e6a61737065727265706f7274732e656e67696e652e64657369676e2e4a524a61766163436f6d70696c6572	\N	2014-10-27 12:28:16.507804	Consistency Report	\N
4	Facilities Missing Create Requisition Role	\\xaced0005737200286e65742e73662e6a61737065727265706f7274732e656e67696e652e4a61737065725265706f727400000000000027d80200034c000b636f6d70696c65446174617400164c6a6176612f696f2f53657269616c697a61626c653b4c0011636f6d70696c654e616d655375666669787400124c6a6176612f6c616e672f537472696e673b4c000d636f6d70696c6572436c61737371007e00027872002d6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655265706f727400000000000027d802002a49001950534555444f5f53455249414c5f56455253494f4e5f55494449000c626f74746f6d4d617267696e49000b636f6c756d6e436f756e7449000d636f6c756d6e53706163696e6749000b636f6c756d6e57696474685a001069676e6f7265506167696e6174696f6e5a00136973466c6f6174436f6c756d6e466f6f7465725a0010697353756d6d6172794e6577506167655a0020697353756d6d6172795769746850616765486561646572416e64466f6f7465725a000e69735469746c654e65775061676549000a6c6566744d617267696e42000b6f7269656e746174696f6e49000a7061676548656967687449000970616765576964746842000a7072696e744f7264657249000b72696768744d617267696e490009746f704d617267696e42000e7768656e4e6f44617461547970654c000a6261636b67726f756e647400244c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5242616e643b4c000f636f6c756d6e446972656374696f6e7400334c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f52756e446972656374696f6e456e756d3b4c000c636f6c756d6e466f6f74657271007e00044c000c636f6c756d6e48656164657271007e00045b000864617461736574737400285b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52446174617365743b4c000c64656661756c745374796c657400254c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525374796c653b4c000664657461696c71007e00044c000d64657461696c53656374696f6e7400274c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5253656374696f6e3b4c0012666f726d6174466163746f7279436c61737371007e00024c000a696d706f72747353657474000f4c6a6176612f7574696c2f5365743b4c00086c616e677561676571007e00024c000e6c61737450616765466f6f74657271007e00044c000b6d61696e446174617365747400274c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52446174617365743b4c00046e616d6571007e00024c00066e6f4461746171007e00044c00106f7269656e746174696f6e56616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4f7269656e746174696f6e456e756d3b4c000a70616765466f6f74657271007e00044c000a7061676548656164657271007e00044c000f7072696e744f7264657256616c75657400314c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5072696e744f72646572456e756d3b5b00067374796c65737400265b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525374796c653b4c000773756d6d61727971007e00045b000974656d706c6174657374002f5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525265706f727454656d706c6174653b4c00057469746c6571007e00044c00137768656e4e6f446174615479706556616c75657400354c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5768656e4e6f4461746154797065456e756d3b78700000c3540000000000000001000000000000030e000100000000000000000000022b0000030e000000000000000000007372002b6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736542616e6400000000000027d802000749001950534555444f5f53455249414c5f56455253494f4e5f5549444900066865696768745a000e697353706c6974416c6c6f7765644c00137072696e745768656e45787072657373696f6e74002a4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5245787072657373696f6e3b4c000d70726f706572746965734d617074002d4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250726f706572746965734d61703b4c000973706c6974547970657400104c6a6176612f6c616e672f427974653b4c000e73706c69745479706556616c75657400304c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f53706c697454797065456e756d3b787200336e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365456c656d656e7447726f757000000000000027d80200024c00086368696c6472656e7400104c6a6176612f7574696c2f4c6973743b4c000c656c656d656e7447726f757074002c4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52456c656d656e7447726f75703b7870737200136a6176612e7574696c2e41727261794c6973747881d21d99c7619d03000149000473697a6578700000000077040000000a78700000c35400000000017070707e72002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e53706c697454797065456e756d00000000000000001200007872000e6a6176612e6c616e672e456e756d00000000000000001200007870740007535452455443487e7200316e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e52756e446972656374696f6e456e756d00000000000000001200007871007e001d7400034c545270707070707372002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736553656374696f6e00000000000027d80200015b000562616e64737400255b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5242616e643b7870757200255b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5242616e643b95dd7eec8cca85350200007870000000017371007e00117371007e001a0000000677040000000a737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365546578744669656c6400000000000027d802001549001950534555444f5f53455249414c5f56455253494f4e5f55494449000d626f6f6b6d61726b4c6576656c42000e6576616c756174696f6e54696d6542000f68797065726c696e6b54617267657442000d68797065726c696e6b547970655a0015697353747265746368576974684f766572666c6f774c0014616e63686f724e616d6545787072657373696f6e71007e00124c000f6576616c756174696f6e47726f75707400254c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5247726f75703b4c00136576616c756174696f6e54696d6556616c75657400354c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4576616c756174696f6e54696d65456e756d3b4c000a65787072657373696f6e71007e00124c001968797065726c696e6b416e63686f7245787072657373696f6e71007e00124c001768797065726c696e6b5061676545787072657373696f6e71007e00125b001368797065726c696e6b506172616d65746572737400335b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5248797065726c696e6b506172616d657465723b4c001c68797065726c696e6b5265666572656e636545787072657373696f6e71007e00124c001a68797065726c696e6b546f6f6c74697045787072657373696f6e71007e00124c001768797065726c696e6b5768656e45787072657373696f6e71007e00124c000f6973426c616e6b5768656e4e756c6c7400134c6a6176612f6c616e672f426f6f6c65616e3b4c000a6c696e6b54617267657471007e00024c00086c696e6b5479706571007e00024c00077061747465726e71007e00024c00117061747465726e45787072657373696f6e71007e0012787200326e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736554657874456c656d656e7400000000000027d802002549001950534555444f5f53455249414c5f56455253494f4e5f5549444c0006626f7264657271007e00144c000b626f72646572436f6c6f727400104c6a6176612f6177742f436f6c6f723b4c000c626f74746f6d426f7264657271007e00144c0011626f74746f6d426f72646572436f6c6f7271007e00304c000d626f74746f6d50616464696e677400134c6a6176612f6c616e672f496e74656765723b4c0008666f6e744e616d6571007e00024c0008666f6e7453697a6571007e00314c0013686f72697a6f6e74616c416c69676e6d656e7471007e00144c0018686f72697a6f6e74616c416c69676e6d656e7456616c75657400364c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f486f72697a6f6e74616c416c69676e456e756d3b4c00066973426f6c6471007e002e4c000869734974616c696371007e002e4c000d6973506466456d62656464656471007e002e4c000f6973537472696b655468726f75676871007e002e4c000c69735374796c65645465787471007e002e4c000b6973556e6465726c696e6571007e002e4c000a6c656674426f7264657271007e00144c000f6c656674426f72646572436f6c6f7271007e00304c000b6c65667450616464696e6771007e00314c00076c696e65426f787400274c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a524c696e65426f783b4c000b6c696e6553706163696e6771007e00144c00106c696e6553706163696e6756616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4c696e6553706163696e67456e756d3b4c00066d61726b757071007e00024c000770616464696e6771007e00314c00097061726167726170687400294c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525061726167726170683b4c000b706466456e636f64696e6771007e00024c000b706466466f6e744e616d6571007e00024c000b7269676874426f7264657271007e00144c00107269676874426f72646572436f6c6f7271007e00304c000c726967687450616464696e6771007e00314c0008726f746174696f6e71007e00144c000d726f746174696f6e56616c756574002f4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f526f746174696f6e456e756d3b4c0009746f70426f7264657271007e00144c000e746f70426f72646572436f6c6f7271007e00304c000a746f7050616464696e6771007e00314c0011766572746963616c416c69676e6d656e7471007e00144c0016766572746963616c416c69676e6d656e7456616c75657400344c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f566572746963616c416c69676e456e756d3b7872002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365456c656d656e7400000000000027d802001b49001950534555444f5f53455249414c5f56455253494f4e5f5549444900066865696768745a001769735072696e74496e466972737457686f6c6542616e645a001569735072696e74526570656174656456616c7565735a001a69735072696e745768656e44657461696c4f766572666c6f77735a0015697352656d6f76654c696e655768656e426c616e6b42000c706f736974696f6e5479706542000b7374726574636854797065490005776964746849000178490001794c00096261636b636f6c6f7271007e00304c001464656661756c745374796c6550726f76696465727400344c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5244656661756c745374796c6550726f76696465723b4c000c656c656d656e7447726f757071007e00184c0009666f7265636f6c6f7271007e00304c00036b657971007e00024c00046d6f646571007e00144c00096d6f646556616c756574002b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4d6f6465456e756d3b4c000b706172656e745374796c6571007e00074c0018706172656e745374796c654e616d655265666572656e636571007e00024c0011706f736974696f6e5479706556616c75657400334c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f506f736974696f6e54797065456e756d3b4c00137072696e745768656e45787072657373696f6e71007e00124c00157072696e745768656e47726f75704368616e67657371007e002b4c000d70726f706572746965734d617071007e00135b001370726f706572747945787072657373696f6e737400335b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250726f706572747945787072657373696f6e3b4c0010737472657463685479706556616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5374726574636854797065456e756d3b4c0004757569647400104c6a6176612f7574696c2f555549443b78700000c354000000140001000000000000003d00000000000000007071007e001071007e00287070707070707e7200316e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e506f736974696f6e54797065456e756d00000000000000001200007871007e001d7400134649585f52454c41544956455f544f5f544f50707070707e7200306e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5374726574636854797065456e756d00000000000000001200007871007e001d74000a4e4f5f535452455443487372000e6a6176612e7574696c2e55554944bc9903f7986d852f0200024a000c6c65617374536967426974734a000b6d6f7374536967426974737870a3c35f9512886f9f0cb682e445b14bae0000c354707070707070737200116a6176612e6c616e672e496e746567657212e2a0a4f781873802000149000576616c7565787200106a6176612e6c616e672e4e756d62657286ac951d0b94e08b02000078700000000a707e7200346e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e486f72697a6f6e74616c416c69676e456e756d00000000000000001200007871007e001d74000643454e5445527070707070707070707372002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173654c696e65426f7800000000000027d802000b4c000d626f74746f6d50616464696e6771007e00314c0009626f74746f6d50656e74002b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f626173652f4a52426f7850656e3b4c000c626f78436f6e7461696e657274002c4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52426f78436f6e7461696e65723b4c000b6c65667450616464696e6771007e00314c00076c65667450656e71007e004f4c000770616464696e6771007e00314c000370656e71007e004f4c000c726967687450616464696e6771007e00314c0008726967687450656e71007e004f4c000a746f7050616464696e6771007e00314c0006746f7050656e71007e004f787070737200336e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f78426f74746f6d50656e00000000000027d80200007872002d6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f7850656e00000000000027d80200014c00076c696e65426f7871007e00337872002a6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736550656e00000000000027d802000649001950534555444f5f53455249414c5f56455253494f4e5f5549444c00096c696e65436f6c6f7271007e00304c00096c696e655374796c6571007e00144c000e6c696e655374796c6556616c75657400304c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4c696e655374796c65456e756d3b4c00096c696e6557696474687400114c6a6176612f6c616e672f466c6f61743b4c000c70656e436f6e7461696e657274002c4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250656e436f6e7461696e65723b78700000c3547070707071007e005171007e005171007e003f70737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f784c65667450656e00000000000027d80200007871007e00530000c3547070707071007e005171007e0051707371007e00530000c3547070707071007e005171007e005170737200326e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f78526967687450656e00000000000027d80200007871007e00530000c3547070707071007e005171007e005170737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f78546f7050656e00000000000027d80200007871007e00530000c3547070707071007e005171007e005170707070737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736550617261677261706800000000000027d802000a4c000f66697273744c696e65496e64656e7471007e00314c000a6c656674496e64656e7471007e00314c000b6c696e6553706163696e6771007e00344c000f6c696e6553706163696e6753697a6571007e00564c0012706172616772617068436f6e7461696e65727400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52506172616772617068436f6e7461696e65723b4c000b7269676874496e64656e7471007e00314c000c73706163696e67416674657271007e00314c000d73706163696e674265666f726571007e00314c000c74616253746f70576964746871007e00314c000874616253746f707371007e001778707070707071007e003f70707070707070707070707070707070700000c354000000000000000070707e7200336e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e4576616c756174696f6e54696d65456e756d00000000000000001200007871007e001d7400034e4f57737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736545787072657373696f6e00000000000027d802000449000269645b00066368756e6b737400305b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5245787072657373696f6e4368756e6b3b4c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e0002787000000009757200305b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5245787072657373696f6e4368756e6b3b6d59cfde694ba355020000787000000001737200366e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736545787072657373696f6e4368756e6b00000000000027d8020002420004747970654c00047465787471007e000278700474000c5245504f52545f434f554e54707070707070707070707070707371007e002a0000c35400000014000100000000000000b10000003d000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e0046bc9d337b6af09873656d88930a9d43ba0000c3547070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e007071007e007071007e006e707371007e00590000c3547070707071007e007071007e0070707371007e00530000c3547070707071007e007071007e0070707371007e005c0000c3547070707071007e007071007e0070707371007e005e0000c3547070707071007e007071007e0070707070707371007e00607070707071007e006e70707070707070707070707070707070700000c3540000000000000000707071007e00647371007e00660000000a7571007e0069000000037371007e006b0374000d666163696c6974795f636f64657371007e006b017400052b272d272b7371007e006b0374000d666163696c6974795f6e616d65707070707070707070707070707371007e002a0000c3540000001400010000000000000059000000ee000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e004698f4376032bdf48f2d97d1a7f057497d0000c3547070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e008171007e008171007e007f707371007e00590000c3547070707071007e008171007e0081707371007e00530000c3547070707071007e008171007e0081707371007e005c0000c3547070707071007e008171007e0081707371007e005e0000c3547070707071007e008171007e0081707070707371007e00607070707071007e007f70707070707070707070707070707070700000c3540000000000000000707071007e00647371007e00660000000b7571007e0069000000017371007e006b0374000f666163696c6974795f616374697665707070707070707070707070707371007e002a0000c354000000140001000000000000006500000147000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e0046bf4b5560f753e6ae3b6201ef3bb64bb50000c3547070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e008e71007e008e71007e008c707371007e00590000c3547070707071007e008e71007e008e707371007e00530000c3547070707071007e008e71007e008e707371007e005c0000c3547070707071007e008e71007e008e707371007e005e0000c3547070707071007e008e71007e008e707070707371007e00607070707071007e008c70707070707070707070707070707070700000c3540000000000000000707071007e00647371007e00660000000c7571007e0069000000017371007e006b0374000c70726f6772616d5f6e616d65707070707070707070707070707371007e002a0000c35400000014000100000000000000cd000001ac000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e00468b47c18385282767a2f59c46025d43280000c3547070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e009b71007e009b71007e0099707371007e00590000c3547070707071007e009b71007e009b707371007e00530000c3547070707071007e009b71007e009b707371007e005c0000c3547070707071007e009b71007e009b707371007e005e0000c3547070707071007e009b71007e009b707070707371007e00607070707071007e009970707070707070707070707070707070700000c3540000000000000000707071007e00647371007e00660000000d7571007e0069000000037371007e006b0374001573757065727669736f72795f6e6f64655f636f64657371007e006b017400052b272d272b7371007e006b0374001573757065727669736f72795f6e6f64655f6e616d65707070707070707070707070707371007e002a0000c354000000140001000000000000009500000279000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e0046be94070ffee2354714e89f25808142c80000c3547070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e00ac71007e00ac71007e00aa707371007e00590000c3547070707071007e00ac71007e00ac707371007e00530000c3547070707071007e00ac71007e00ac707371007e005c0000c3547070707071007e00ac71007e00ac707371007e005e0000c3547070707071007e00ac71007e00ac707070707371007e00607070707071007e00aa70707070707070707070707070707070700000c3540000000000000000707071007e00647371007e00660000000e7571007e0069000000017371007e006b037400117573657269645f756e76657269666965647070707070707070707070707078700000c35400000014017070707070707400046a617661707372002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173654461746173657400000000000027d802001149001950534555444f5f53455249414c5f56455253494f4e5f5549445a000669734d61696e4200177768656e5265736f757263654d697373696e67547970655b00066669656c64737400265b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a524669656c643b4c001066696c74657245787072657373696f6e71007e00125b000667726f7570737400265b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5247726f75703b4c00046e616d6571007e00025b000a706172616d657465727374002a5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52506172616d657465723b4c000d70726f706572746965734d617071007e00134c000571756572797400254c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5251756572793b4c000e7265736f7572636542756e646c6571007e00024c000e7363726970746c6574436c61737371007e00025b000a7363726970746c65747374002a5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525363726970746c65743b5b000a736f72744669656c647374002a5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52536f72744669656c643b4c00047575696471007e003e5b00097661726961626c65737400295b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525661726961626c653b4c001c7768656e5265736f757263654d697373696e675479706556616c756574003e4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5768656e5265736f757263654d697373696e6754797065456e756d3b78700000c3540100757200265b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a524669656c643b023cdfc74e2af2700200007870000000077372002c6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173654669656c6400000000000027d80200054c000b6465736372697074696f6e71007e00024c00046e616d6571007e00024c000d70726f706572746965734d617071007e00134c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e000278707074000d666163696c6974795f636f64657372002b6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5250726f706572746965734d617000000000000027d80200034c00046261736571007e00134c000e70726f706572746965734c69737471007e00174c000d70726f706572746965734d617074000f4c6a6176612f7574696c2f4d61703b78707070707400106a6176612e6c616e672e537472696e67707371007e00c47074000d666163696c6974795f6e616d657371007e00c77070707400106a6176612e6c616e672e537472696e67707371007e00c47074000f666163696c6974795f6163746976657371007e00c77070707400116a6176612e6c616e672e426f6f6c65616e707371007e00c47074000c70726f6772616d5f6e616d657371007e00c77070707400106a6176612e6c616e672e537472696e67707371007e00c47074001573757065727669736f72795f6e6f64655f636f64657371007e00c77070707400106a6176612e6c616e672e537472696e67707371007e00c47074001573757065727669736f72795f6e6f64655f6e616d657371007e00c77070707400106a6176612e6c616e672e537472696e67707371007e00c4707400117573657269645f756e76657269666965647371007e00c77070707400106a6176612e6c616e672e537472696e677070707400077265706f7274317572002a5b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a52506172616d657465723b22000c8d2ac36021020000787000000013737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365506172616d6574657200000000000027d80200095a000e6973466f7250726f6d7074696e675a000f697353797374656d446566696e65644c001664656661756c7456616c756545787072657373696f6e71007e00124c000b6465736372697074696f6e71007e00024c00046e616d6571007e00024c000e6e6573746564547970654e616d6571007e00024c000d70726f706572746965734d617071007e00134c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e000278700101707074000e5245504f52545f434f4e54455854707371007e00c77070707400296e65742e73662e6a61737065727265706f7274732e656e67696e652e5265706f7274436f6e74657874707371007e00e6010170707400155245504f52545f504152414d45544552535f4d4150707371007e00c770707074000d6a6176612e7574696c2e4d6170707371007e00e60101707074000d4a41535045525f5245504f5254707371007e00c77070707400286e65742e73662e6a61737065727265706f7274732e656e67696e652e4a61737065725265706f7274707371007e00e6010170707400115245504f52545f434f4e4e454354494f4e707371007e00c77070707400136a6176612e73716c2e436f6e6e656374696f6e707371007e00e6010170707400105245504f52545f4d41585f434f554e54707371007e00c77070707400116a6176612e6c616e672e496e7465676572707371007e00e6010170707400125245504f52545f444154415f534f55524345707371007e00c77070707400286e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5244617461536f75726365707371007e00e6010170707400105245504f52545f5343524950544c4554707371007e00c770707074002f6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5241627374726163745363726970746c6574707371007e00e60101707074000d5245504f52545f4c4f43414c45707371007e00c77070707400106a6176612e7574696c2e4c6f63616c65707371007e00e6010170707400165245504f52545f5245534f555243455f42554e444c45707371007e00c77070707400186a6176612e7574696c2e5265736f7572636542756e646c65707371007e00e6010170707400105245504f52545f54494d455f5a4f4e45707371007e00c77070707400126a6176612e7574696c2e54696d655a6f6e65707371007e00e6010170707400155245504f52545f464f524d41545f464143544f5259707371007e00c770707074002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e7574696c2e466f726d6174466163746f7279707371007e00e6010170707400135245504f52545f434c4153535f4c4f41444552707371007e00c77070707400156a6176612e6c616e672e436c6173734c6f61646572707371007e00e60101707074001a5245504f52545f55524c5f48414e444c45525f464143544f5259707371007e00c77070707400206a6176612e6e65742e55524c53747265616d48616e646c6572466163746f7279707371007e00e6010170707400145245504f52545f46494c455f5245534f4c564552707371007e00c770707074002d6e65742e73662e6a61737065727265706f7274732e656e67696e652e7574696c2e46696c655265736f6c766572707371007e00e6010170707400105245504f52545f54454d504c41544553707371007e00c77070707400146a6176612e7574696c2e436f6c6c656374696f6e707371007e00e60101707074000b534f52545f4649454c4453707371007e00c770707074000e6a6176612e7574696c2e4c697374707371007e00e60101707074000646494c544552707371007e00c77070707400296e65742e73662e6a61737065727265706f7274732e656e67696e652e4461746173657446696c746572707371007e00e6010170707400125245504f52545f5649525455414c495a4552707371007e00c77070707400296e65742e73662e6a61737065727265706f7274732e656e67696e652e4a525669727475616c697a6572707371007e00e60101707074001449535f49474e4f52455f504147494e4154494f4e707371007e00c77070707400116a6176612e6c616e672e426f6f6c65616e707371007e00c7707371007e001a0000000377040000000374000c697265706f72742e7a6f6f6d740009697265706f72742e78740009697265706f72742e7978737200116a6176612e7574696c2e486173684d61700507dac1c31660d103000246000a6c6f6164466163746f724900097468726573686f6c6478703f400000000000037708000000040000000371007e01377400013071007e0135740003312e3071007e013674000130787372002c6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365517565727900000000000027d80200025b00066368756e6b7374002b5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5251756572794368756e6b3b4c00086c616e677561676571007e000278707572002b5b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5251756572794368756e6b3b409f00a1e8ba34a4020000787000000001737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736551756572794368756e6b00000000000027d8020003420004747970654c00047465787471007e00025b0006746f6b656e737400135b4c6a6176612f6c616e672f537472696e673b78700174163257495448205245435552534956452073705f6e6f646528736e69642c20736e706172656e7469642920415320280a20202853454c4543540a202020202069642c0a2020202020706172656e7469640a20202046524f4d2073757065727669736f72795f6e6f646573290a2020554e494f4e20414c4c202853454c4543540a202020202020202020202020202020736e2e69642c0a20202020202020202020202020202073706e2e736e706172656e7469640a2020202020202020202020202046524f4d2073757065727669736f72795f6e6f64657320736e0a2020202020202020202020202020204a4f494e2073705f6e6f64652073706e0a20202020202020202020202020202020204f4e20736e2e706172656e746964203d2073706e2e736e69640a2020290a292c0a2020202070726f6772616d5f666163696c6974795f776974685f75736572735f696e5f686965726172636879202870726f6772616d5f69642c20666163696c6974795f69642c2072696768745f6e616d652c20757365725f6163746976652c20757365725f76657269666965642c20757365725f69642920415320280a2020202053454c4543540a20202020202070732e70726f6772616d69642c0a202020202020662e69642c0a20202020202072722e72696768746e616d652c0a202020202020752e6163746976652c0a202020202020752e76657269666965642c0a202020202020752e69640a0a2020202046524f4d20666163696c6974696573206620494e4e4552204a4f494e207265717569736974696f6e5f67726f75705f6d656d626572732072676d0a20202020202020204f4e20662e6964203d2072676d2e666163696c69747969640a202020202020494e4e4552204a4f494e2070726f6772616d735f737570706f727465642070730a20202020202020204f4e20662e6964203d2070732e666163696c69747969640a202020202020494e4e4552204a4f494e207265717569736974696f6e5f67726f7570732072670a20202020202020204f4e2072676d2e7265717569736974696f6e67726f75706964203d2072672e69640a202020202020494e4e4552204a4f494e207265717569736974696f6e5f67726f75705f70726f6772616d5f7363686564756c657320726770730a20202020202020204f4e2070732e70726f6772616d6964203d20726770732e70726f6772616d696420414e442072676d2e7265717569736974696f6e67726f75706964203d20726770732e7265717569736974696f6e67726f757069640a202020202020494e4e4552204a4f494e202853454c4543540a2020202020202020202020202020202020202020736e69642c0a2020202020202020202020202020202020202020434153450a20202020202020202020202020202020202020205748454e20736e706172656e746964204953204e554c4c205448454e20736e69640a2020202020202020202020202020202020202020454c534520736e706172656e74696420454e442041532073757065726e6f646569640a20202020202020202020202020202020202046524f4d2073705f6e6f64650a202020202020202020202020202020202029204153206e6f6465730a20202020202020204f4e2072672e73757065727669736f72796e6f64656964203d206e6f6465732e736e69640a2020202020204c454654204a4f494e20726f6c655f61737369676e6d656e74732072610a20202020202020204f4e206e6f6465732e73757065726e6f64656964203d2072612e53555045525649534f52594e4f4445494420414e442070732e70726f6772616d6964203d2072612e70726f6772616d69640a2020202020204c454654204a4f494e20757365727320750a20202020202020204f4e2072612e757365726964203d20752e69640a2020202020204c454654204a4f494e20726f6c655f7269676874732072720a20202020202020204f4e2072612e726f6c656964203d2072722e726f6c6569640a0a20202020554e494f4e20414c4c0a0a2020202053454c4543540a20202020202070732e70726f6772616d69642c0a202020202020662e69642c0a20202020202072722e72696768746e616d652c0a202020202020752e6163746976652c0a202020202020752e76657269666965642c0a202020202020752e69640a2020202046524f4d20666163696c697469657320660a202020202020494e4e4552204a4f494e2070726f6772616d735f737570706f727465642070730a20202020202020204f4e20662e6964203d2070732e666163696c69747969640a2020202020204c454654204a4f494e20757365727320750a20202020202020204f4e20662e6964203d20752e666163696c69747969640a2020202020204c454654204a4f494e20726f6c655f61737369676e6d656e74732072610a20202020202020204f4e2070732e70726f6772616d6964203d2072612e70726f6772616d696420414e4420752e6964203d2072612e75736572696420414e442072612e73757065727669736f72796e6f64656964204953204e554c4c0a2020202020204c454654204a4f494e20726f6c655f7269676874732072720a20202020202020204f4e2072612e726f6c656964203d2072722e726f6c6569640a0a2020292c0a202020206163746976655f76657269666965645f75736572735f666f725f737570706f727465645f70726f6772616d732870726f6772616d69642c20666163696c69747969642920415320280a20202020202053454c4543540a202020202020202070726f6772616d5f69642c0a2020202020202020666163696c6974795f69640a20202020202046524f4d2070726f6772616d5f666163696c6974795f776974685f75736572735f696e5f6869657261726368790a20202020202057484552452072696768745f6e616d65203d20274352454154455f5245515549534954494f4e2720414e4420757365725f616374697665203d205452554520414e4420757365725f7665726966696564203d20545255450a2020292c0a202020206163746976655f756e76657269666965645f75736572735f666f725f737570706f727465645f70726f6772616d732870726f6772616d5f69642c20666163696c6974795f69642c20757365725f69642920415320280a20202020202053454c4543540a202020202020202070726f6772616d5f69642c0a2020202020202020666163696c6974795f69642c0a2020202020202020757365725f69640a20202020202046524f4d2070726f6772616d5f666163696c6974795f776974685f75736572735f696e5f6869657261726368790a20202020202057484552452072696768745f6e616d65203d20274352454154455f5245515549534954494f4e2720414e4420757365725f616374697665203d205452554520414e4420757365725f7665726966696564203d2046414c53450a0a2020290a0a53454c4543540a202044495354494e43540a2020662e636f64652020202020202020202020202020202020202020202020202020202020202020202020202020202020415320666163696c6974795f636f64652c0a2020662e6e616d652020202020202020202020202020202020202020202020202020202020202020202020202020202020415320666163696c6974795f6e616d652c0a2020662e616374697665202020202020202020202020202020202020202020202020202020202020202020202020202020415320666163696c6974795f6163746976652c0a2020702e6e616d65202020202020202020202020202020202020202020202020202020202020202020202020202020202041532070726f6772616d5f6e616d652c0a2020736e2e636f64652020202020202020202020202020202020202020202020202020202020202020202020202020202041532073757065727669736f72795f6e6f64655f636f64652c0a2020736e2e6e616d652020202020202020202020202020202020202020202020202020202020202020202020202020202041532073757065727669736f72795f6e6f64655f6e616d652c0a202043415345205748454e20752e616374697665203d2046414c5345205448454e20434f414c45534345282727290a2020454c53450a20202020434f414c4553434528752e757365726e616d652c2027272920454e44204153207573657249645f756e76657269666965640a0a46524f4d2070726f6772616d5f666163696c6974795f776974685f75736572735f696e5f686965726172636879207066777520494e4e4552204a4f494e2070726f6772616d7320700a202020204f4e20706677752e70726f6772616d5f6964203d20702e696420414e4420702e70757368203d2046414c53450a20204c454654204a4f494e20757365727320750a202020204f4e20706677752e757365725f6964203d20752e69640a2020494e4e4552204a4f494e20666163696c697469657320660a202020204f4e20706677752e666163696c6974795f6964203d20662e69640a20204c454654204a4f494e207265717569736974696f6e5f67726f75705f6d656d626572732072676d0a202020204f4e20662e6964203d2072676d2e666163696c69747969640a20204c454654204a4f494e207265717569736974696f6e5f67726f75705f70726f6772616d5f7363686564756c657320726770730a202020204f4e20702e6964203d20726770732e70726f6772616d69640a20204c454654204a4f494e207265717569736974696f6e5f67726f7570732072670a202020204f4e20726770732e7265717569736974696f6e67726f75706964203d2072672e69640a20204c454654204a4f494e2073757065727669736f72795f6e6f64657320736e0a202020204f4e2072672e73757065727669736f72796e6f64656964203d20736e2e69640a57484552452028706677752e70726f6772616d5f6964204e4f5420494e202853454c4543540a20202020202020202020202020202020202020202020202020202020202020202070726f6772616d69640a2020202020202020202020202020202020202020202020202020202020202046524f4d206163746976655f76657269666965645f75736572735f666f725f737570706f727465645f70726f6772616d7329204f5220706677752e666163696c6974795f6964204e4f5420494e202853454c4543540a20202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020666163696c69747969640a202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202046524f4d0a202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020206163746976655f76657269666965645f75736572735f666f725f737570706f727465645f70726f6772616d730a202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202057484552450a2020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202070726f6772616d69640a202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020203d0a20202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020706677752e70726f6772616d5f696429290a202020202020414e44202843415345205748454e2028706677752e70726f6772616d5f6964204e4f5420494e202853454c4543540a20202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202070726f6772616d5f69640a2020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202046524f4d206163746976655f756e76657269666965645f75736572735f666f725f737570706f727465645f70726f6772616d7329204f520a20202020202020202020202020202020202020202020706677752e666163696c6974795f6964204e4f5420494e202853454c4543540a20202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020666163696c6974795f69640a202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202046524f4d206163746976655f756e76657269666965645f75736572735f666f725f737570706f727465645f70726f6772616d730a202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202057484552452070726f6772616d5f6964203d20706677752e70726f6772616d5f6964290a29205448454e2028752e616374697665203d2046414c5345204f522075204953204e554c4c290a2020202020202020202020454c534520752e696420494e202853454c4543540a202020202020202020202020202020202020202020202020202020757365725f69640a2020202020202020202020202020202020202020202020202046524f4d206163746976655f756e76657269666965645f75736572735f666f725f737570706f727465645f70726f6772616d730a20202020202020202020202020202020202020202020202020574845524520666163696c6974795f6964203d20706677752e666163696c6974795f696420414e442070726f6772616d5f6964203d20706677752e70726f6772616d5f6964290a2020202020202020202020454e44290a202020202020414e442072676d2e7265717569736974696f6e67726f75706964203d20726770732e7265717569736974696f6e67726f7570696420414e4420662e656e61626c6564203d205452554520414e4420702e616374697665203d205452554520414e4420702e70757368203d2046414c53450a202020202020414e4420662e7669727475616c666163696c697479203d2066616c736520414e4420662e736174656c6c697465203c3e20747275650a4f5244455220425920662e636f64652c20702e6e616d652c20736e2e636f64657074000373716c707070707371007e0046b3d554b1aefe96cea0a4e8610726422f757200295b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a525661726961626c653b62e6837c982cb7440200007870000000057372002f6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655661726961626c6500000000000027d802001149001950534555444f5f53455249414c5f56455253494f4e5f55494442000b63616c63756c6174696f6e42000d696e6372656d656e74547970655a000f697353797374656d446566696e65644200097265736574547970654c001063616c63756c6174696f6e56616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f43616c63756c6174696f6e456e756d3b4c000a65787072657373696f6e71007e00124c000e696e6372656d656e7447726f757071007e002b4c0012696e6372656d656e745479706556616c75657400344c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f496e6372656d656e7454797065456e756d3b4c001b696e6372656d656e746572466163746f7279436c6173734e616d6571007e00024c001f696e6372656d656e746572466163746f7279436c6173735265616c4e616d6571007e00024c0016696e697469616c56616c756545787072657373696f6e71007e00124c00046e616d6571007e00024c000a726573657447726f757071007e002b4c000e72657365745479706556616c75657400304c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f526573657454797065456e756d3b4c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e00027870000077ee000001007e7200306e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e43616c63756c6174696f6e456e756d00000000000000001200007871007e001d74000653595354454d70707e7200326e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e496e6372656d656e7454797065456e756d00000000000000001200007871007e001d7400044e4f4e4570707371007e0066000000007571007e0069000000017371007e006b017400186e6577206a6176612e6c616e672e496e7465676572283129707074000b504147455f4e554d424552707e72002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e526573657454797065456e756d00000000000000001200007871007e001d7400065245504f525471007e00fa707371007e014a000077ee0000010071007e0150707071007e015370707371007e0066000000017571007e0069000000017371007e006b017400186e6577206a6176612e6c616e672e496e7465676572283129707074000d434f4c554d4e5f4e554d424552707e71007e015a7400045041474571007e00fa707371007e014a000077ee000001007e71007e014f740005434f554e547371007e0066000000027571007e0069000000017371007e006b017400186e6577206a6176612e6c616e672e496e746567657228312970707071007e015370707371007e0066000000037571007e0069000000017371007e006b017400186e6577206a6176612e6c616e672e496e7465676572283029707074000c5245504f52545f434f554e547071007e015b71007e00fa707371007e014a000077ee0000010071007e01667371007e0066000000047571007e0069000000017371007e006b017400186e6577206a6176612e6c616e672e496e746567657228312970707071007e015370707371007e0066000000057571007e0069000000017371007e006b017400186e6577206a6176612e6c616e672e496e7465676572283029707074000a504147455f434f554e547071007e016371007e00fa707371007e014a000077ee0000010071007e01667371007e0066000000067571007e0069000000017371007e006b017400186e6577206a6176612e6c616e672e496e746567657228312970707071007e015370707371007e0066000000077571007e0069000000017371007e006b017400186e6577206a6176612e6c616e672e496e7465676572283029707074000c434f4c554d4e5f434f554e54707e71007e015a740006434f4c554d4e71007e00fa707e72003c6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5768656e5265736f757263654d697373696e6754797065456e756d00000000000000001200007871007e001d7400044e554c4c71007e00e37371007e00117371007e001a0000000277040000000a737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655374617469635465787400000000000027d80200014c00047465787471007e00027871007e002f0000c354000000140001000000000000030e00000000000000207071007e001071007e018a70707070707071007e00417070707071007e00447371007e00468769af621a8e549b488f93d8d2fe4df60000c3547070707070707371007e00480000000f7071007e004c7070707070707070707371007e004e707371007e00520000c3547070707071007e019071007e019071007e018d707371007e00590000c3547070707071007e019071007e0190707371007e00530000c3547070707071007e019071007e0190707371007e005c0000c3547070707071007e019071007e0190707371007e005e0000c3547070707071007e019071007e0190707070707371007e00607070707071007e018d70707070707070707070707070707070707400124e6f2070726f626c656d7320666f756e642e7371007e018c0000c354000000200001000000000000030e00000000000000007071007e001071007e018a70707070707071007e00417070707071007e00447371007e00469238092a1177a2f66659ba1e006b4f7f0000c354707070707074000953616e7353657269667371007e0048000000187071007e004c7070707070737200116a6176612e6c616e672e426f6f6c65616ecd207280d59cfaee0200015a000576616c75657870017070707371007e004e707371007e00520000c3547070707071007e019e71007e019e71007e0198707371007e00590000c3547070707071007e019e71007e019e707371007e00530000c3547070707071007e019e71007e019e707371007e005c0000c3547070707071007e019e71007e019e707371007e005e0000c3547070707071007e019e71007e019e707070707371007e00607070707071007e0198707070707070707070707070707070707074002a466163696c6974696573204d697373696e6720437265617465205265717569736974696f6e20526f6c6578700000c3540000003401707070707e7200306e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e4f7269656e746174696f6e456e756d00000000000000001200007871007e001d7400094c414e4453434150457371007e00117371007e001a0000000277040000000a7371007e002a0000c3540000001400010000000000000048000002c6000000007071007e001071007e01a970707070707071007e00417070707071007e00447371007e0046a6cd4885e72541551abcd2c71ce14a4b0000c354707070707074000953616e7353657269667371007e00480000000870707070707070707070707371007e004e707371007e00520000c3547070707071007e01af71007e01af71007e01ab707371007e00590000c3547070707071007e01af71007e01af707371007e00530000c3547070707071007e01af71007e01af707371007e005c0000c3547070707071007e01af71007e01af707371007e005e0000c3547070707071007e01af71007e01af707070707371007e00607070707071007e01ab70707070707070707070707070707070700000c3540000000000000000707071007e00647371007e00660000000f7571007e0069000000017371007e006b0474000b504147455f4e554d424552707070707070707070707070707371007e018c0000c35400000014000100000000000002c600000000000000007071007e001071007e01a970707070707071007e00417070707071007e00447371007e0046b62f68c26194b7c32e4a2985b90149630000c3547070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e01bc71007e01bc71007e01ba707371007e00590000c3547070707071007e01bc71007e01bc707371007e00530000c3547070707071007e01bc71007e01bc707371007e005c0000c3547070707071007e01bc71007e01bc707371007e005e0000c3547070707071007e01bc71007e01bc707070707371007e00607070707071007e01ba70707070707070707070707070707070707400012078700000c3540000001401707070707371007e00117371007e001a0000000677040000000a7371007e018c0000c354000000140001000000000000006500000147000000007071007e001071007e01c470707070707071007e00417070707071007e00447371007e00469b596670c74bd785ef159a2f33d942ba0000c354707070707074000953616e7353657269667371007e00480000000c707071007e019d7070707071007e019d7070707371007e004e707371007e00520000c3547070707071007e01ca71007e01ca71007e01c6707371007e00590000c3547070707071007e01ca71007e01ca707371007e00530000c3547070707071007e01ca71007e01ca707371007e005c0000c3547070707071007e01ca71007e01ca707371007e005e0000c3547070707071007e01ca71007e01ca707070707371007e00607070707071007e01c6707070707070707070707070707070707074000c50726f6772616d204e616d657371007e018c0000c35400000014000100000000000000cd000001ac000000007071007e001071007e01c470707070707071007e00417070707071007e00447371007e00469f72d87cd57c5a0d9a07393f55224bce0000c354707070707074000953616e73536572696671007e01c9707071007e019d7070707071007e019d7070707371007e004e707371007e00520000c3547070707071007e01d571007e01d571007e01d2707371007e00590000c3547070707071007e01d571007e01d5707371007e00530000c3547070707071007e01d571007e01d5707371007e005c0000c3547070707071007e01d571007e01d5707371007e005e0000c3547070707071007e01d571007e01d5707070707371007e00607070707071007e01d2707070707070707070707070707070707074001c53757065727669736f7279204e6f646520436f6465202d204e616d657371007e018c0000c35400000014000100000000000000b10000003d000000007071007e001071007e01c470707070707071007e00417070707071007e00447371007e0046a2a43d5c0bd9170ad949733d046b41aa0000c354707070707074000953616e73536572696671007e01c9707071007e019d7070707071007e019d7070707371007e004e707371007e00520000c3547070707071007e01e071007e01e071007e01dd707371007e00590000c3547070707071007e01e071007e01e0707371007e00530000c3547070707071007e01e071007e01e0707371007e005c0000c3547070707071007e01e071007e01e0707371007e005e0000c3547070707071007e01e071007e01e0707070707371007e00607070707071007e01dd7070707070707070707070707070707070740014466163696c69747920436f6465202d204e616d657371007e018c0000c3540000001400010000000000000059000000ee000000007071007e001071007e01c470707070707071007e00417070707071007e00447371007e0046835adf817aa47786a3153510d28746ad0000c354707070707074000953616e73536572696671007e01c9707071007e019d7070707071007e019d7070707371007e004e707371007e00520000c3547070707071007e01eb71007e01eb71007e01e8707371007e00590000c3547070707071007e01eb71007e01eb707371007e00530000c3547070707071007e01eb71007e01eb707371007e005c0000c3547070707071007e01eb71007e01eb707371007e005e0000c3547070707071007e01eb71007e01eb707070707371007e00607070707071007e01e8707070707070707070707070707070707074000f466163696c697479204163746976657371007e018c0000c354000000140001000000000000003d00000000000000007071007e001071007e01c470707070707071007e00417070707071007e00447371007e0046b48a4feb4161ed645a7f10ba925c4ca70000c354707070707074000953616e73536572696671007e01c97071007e004c71007e019d7070707071007e019d7070707371007e004e707371007e00520000c3547070707071007e01f671007e01f671007e01f3707371007e00590000c3547070707071007e01f671007e01f6707371007e00530000c3547070707071007e01f671007e01f6707371007e005c0000c3547070707071007e01f671007e01f6707371007e005e0000c3547070707071007e01f671007e01f6707070707371007e00607070707071007e01f37070707070707070707070707070707070740004532e4e6f7371007e018c0000c354000000140001000000000000009500000279000000007071007e001071007e01c470707070707071007e00417070707071007e00447371007e004695811259740284767a2bce85864e42e70000c354707070707074000953616e73536572696671007e01c9707071007e019d7070707071007e019d7070707371007e004e707371007e00520000c3547070707071007e020171007e020171007e01fe707371007e00590000c3547070707071007e020171007e0201707371007e00530000c3547070707071007e020171007e0201707371007e005c0000c3547070707071007e020171007e0201707371007e005e0000c3547070707071007e020171007e0201707070707371007e00607070707071007e01fe707070707070707070707070707070707074001455736572204964202d20556e766572696669656478700000c354000000140170707071007e001e7e72002f6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5072696e744f72646572456e756d00000000000000001200007871007e001d740008564552544943414c757200265b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a525374796c653bd49cc311d90572350200007870000000087372002c6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655374796c65000000000000271102003a49001950534555444f5f53455249414c5f56455253494f4e5f5549445a0009697344656661756c744c00096261636b636f6c6f7271007e00304c0006626f7264657271007e00144c000b626f72646572436f6c6f7271007e00304c000c626f74746f6d426f7264657271007e00144c0011626f74746f6d426f72646572436f6c6f7271007e00304c000d626f74746f6d50616464696e6771007e00315b0011636f6e646974696f6e616c5374796c65737400315b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52436f6e646974696f6e616c5374796c653b4c001464656661756c745374796c6550726f766964657271007e00394c000466696c6c71007e00144c000966696c6c56616c756574002b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f46696c6c456e756d3b4c0008666f6e744e616d6571007e00024c0008666f6e7453697a6571007e00314c0009666f7265636f6c6f7271007e00304c0013686f72697a6f6e74616c416c69676e6d656e7471007e00144c0018686f72697a6f6e74616c416c69676e6d656e7456616c756571007e00324c000f6973426c616e6b5768656e4e756c6c71007e002e4c00066973426f6c6471007e002e4c000869734974616c696371007e002e4c000d6973506466456d62656464656471007e002e4c000f6973537472696b655468726f75676871007e002e4c000c69735374796c65645465787471007e002e4c000b6973556e6465726c696e6571007e002e4c000a6c656674426f7264657271007e00144c000f6c656674426f72646572436f6c6f7271007e00304c000b6c65667450616464696e6771007e00314c00076c696e65426f7871007e00334c00076c696e6550656e7400234c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250656e3b4c000b6c696e6553706163696e6771007e00144c00106c696e6553706163696e6756616c756571007e00344c00066d61726b757071007e00024c00046d6f646571007e00144c00096d6f646556616c756571007e003a4c00046e616d6571007e00024c000770616464696e6771007e00314c000970617261677261706871007e00354c000b706172656e745374796c6571007e00074c0018706172656e745374796c654e616d655265666572656e636571007e00024c00077061747465726e71007e00024c000b706466456e636f64696e6771007e00024c000b706466466f6e744e616d6571007e00024c000370656e71007e00144c000c706f736974696f6e5479706571007e00144c000672616469757371007e00314c000b7269676874426f7264657271007e00144c00107269676874426f72646572436f6c6f7271007e00304c000c726967687450616464696e6771007e00314c0008726f746174696f6e71007e00144c000d726f746174696f6e56616c756571007e00364c000a7363616c65496d61676571007e00144c000f7363616c65496d61676556616c75657400314c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5363616c65496d616765456e756d3b4c000b737472657463685479706571007e00144c0009746f70426f7264657271007e00144c000e746f70426f72646572436f6c6f7271007e00304c000a746f7050616464696e6771007e00314c0011766572746963616c416c69676e6d656e7471007e00144c0016766572746963616c416c69676e6d656e7456616c756571007e003778700000c35400707070707070707070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e021471007e021471007e0213707371007e00590000c3547070707071007e021471007e0214707371007e00530000c3547372000e6a6176612e6177742e436f6c6f7201a51783108f337502000546000666616c70686149000576616c75654c0002637374001b4c6a6176612f6177742f636f6c6f722f436f6c6f7253706163653b5b00096672676276616c75657400025b465b00066676616c756571007e021a787000000000ff00000070707070707372000f6a6176612e6c616e672e466c6f6174daedc9a2db3cf0ec02000146000576616c75657871007e00493f80000071007e021471007e0214707371007e005c0000c3547070707071007e021471007e0214707371007e005e0000c3547070707071007e021471007e02147371007e00540000c3547070707071007e021370707070707400057461626c65707371007e00607070707071007e021370707070707070707070707070707070707070707070707070707371007e020e0000c354007371007e021800000000fff0f8ff7070707070707070707070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e022571007e022571007e0223707371007e00590000c3547070707071007e022571007e0225707371007e00530000c3547371007e021800000000ff00000070707070707371007e021c3f00000071007e022571007e0225707371007e005c0000c3547070707071007e022571007e0225707371007e005e0000c3547070707071007e022571007e02257371007e00540000c3547070707071007e0223707070707e7200296e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e4d6f6465456e756d00000000000000001200007871007e001d7400064f50415155457400087461626c655f5448707371007e00607070707071007e022370707070707070707070707070707070707070707070707070707371007e020e0000c354007371007e021800000000ffbfe1ff7070707070707070707070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e023571007e023571007e0233707371007e00590000c3547070707071007e023571007e0235707371007e00530000c3547371007e021800000000ff00000070707070707371007e021c3f00000071007e023571007e0235707371007e005c0000c3547070707071007e023571007e0235707371007e005e0000c3547070707071007e023571007e02357371007e00540000c3547070707071007e02337070707071007e022f7400087461626c655f4348707371007e00607070707071007e023370707070707070707070707070707070707070707070707070707371007e020e0000c354007371007e021800000000ffffffff7070707070707070707070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e024271007e024271007e0240707371007e00590000c3547070707071007e024271007e0242707371007e00530000c3547371007e021800000000ff00000070707070707371007e021c3f00000071007e024271007e0242707371007e005c0000c3547070707071007e024271007e0242707371007e005e0000c3547070707071007e024271007e02427371007e00540000c3547070707071007e02407070707071007e022f7400087461626c655f5444707371007e00607070707071007e024070707070707070707070707070707070707070707070707070707371007e020e0000c35400707070707070707070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e024e71007e024e71007e024d707371007e00590000c3547070707071007e024e71007e024e707371007e00530000c3547371007e021800000000ff00000070707070707371007e021c3f80000071007e024e71007e024e707371007e005c0000c3547070707071007e024e71007e024e707371007e005e0000c3547070707071007e024e71007e024e7371007e00540000c3547070707071007e024d70707070707400077461626c652031707371007e00607070707071007e024d70707070707070707070707070707070707070707070707070707371007e020e0000c354007371007e021800000000fff0f8ff7070707070707070707070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e025b71007e025b71007e0259707371007e00590000c3547070707071007e025b71007e025b707371007e00530000c3547371007e021800000000ff00000070707070707371007e021c3f00000071007e025b71007e025b707371007e005c0000c3547070707071007e025b71007e025b707371007e005e0000c3547070707071007e025b71007e025b7371007e00540000c3547070707071007e02597070707071007e022f74000a7461626c6520315f5448707371007e00607070707071007e025970707070707070707070707070707070707070707070707070707371007e020e0000c354007371007e021800000000ffbfe1ff7070707070707070707070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e026871007e026871007e0266707371007e00590000c3547070707071007e026871007e0268707371007e00530000c3547371007e021800000000ff00000070707070707371007e021c3f00000071007e026871007e0268707371007e005c0000c3547070707071007e026871007e0268707371007e005e0000c3547070707071007e026871007e02687371007e00540000c3547070707071007e02667070707071007e022f74000a7461626c6520315f4348707371007e00607070707071007e026670707070707070707070707070707070707070707070707070707371007e020e0000c354007371007e021800000000ffffffff7070707070707070707070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e027571007e027571007e0273707371007e00590000c3547070707071007e027571007e0275707371007e00530000c3547371007e021800000000ff00000070707070707371007e021c3f00000071007e027571007e0275707371007e005c0000c3547070707071007e027571007e0275707371007e005e0000c3547070707071007e027571007e02757371007e00540000c3547070707071007e02737070707071007e022f74000a7461626c6520315f5444707371007e00607070707071007e0273707070707070707070707070707070707070707070707070707070707371007e00117371007e001a0000000277040000000a7371007e018c0000c35400000020000100000000000002c500000000000000007071007e001071007e028070707070707071007e00417070707071007e00447371007e00468f61a735ab2074b7212194e972ca43210000c354707070707074000953616e73536572696671007e019b7071007e004c707070707071007e019d7070707371007e004e707371007e00520000c3547070707071007e028571007e028571007e0282707371007e00590000c3547070707071007e028571007e0285707371007e00530000c3547070707071007e028571007e0285707371007e005c0000c3547070707071007e028571007e0285707371007e005e0000c3547070707071007e028571007e0285707070707371007e00607070707071007e0282707070707070707070707070707070707074002a466163696c6974696573204d697373696e6720437265617465205265717569736974696f6e20526f6c657371007e002a0000c3540000002000010000000000000049000002c5000000007071007e001071007e028070707070707071007e00417070707071007e00447371007e004689ab02f2dda79bb52dd094dce4b543c00000c354707070707074000953616e73536572696671007e01ae70707070707070707070707371007e004e707371007e00520000c3547070707071007e029071007e029071007e028d707371007e00590000c3547070707071007e029071007e0290707371007e00530000c3547070707071007e029071007e0290707371007e005c0000c3547070707071007e029071007e0290707371007e005e0000c3547070707071007e029071007e0290707070707371007e00607070707071007e028d70707070707070707070707070707070700000c3540000000000000000707071007e00647371007e0066000000087571007e0069000000017371007e006b017400146e6577206a6176612e7574696c2e446174652829707070707070707070707074000a64642f4d4d2f797979797078700000c3540000002001707070707e7200336e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5768656e4e6f4461746154797065456e756d00000000000000001200007871007e001d74000f4e4f5f444154415f53454354494f4e737200366e65742e73662e6a61737065727265706f7274732e656e67696e652e64657369676e2e4a525265706f7274436f6d70696c654461746100000000000027d80200034c001363726f7373746162436f6d70696c654461746171007e00c84c001264617461736574436f6d70696c654461746171007e00c84c00166d61696e44617461736574436f6d70696c654461746171007e000178707371007e01383f4000000000000c77080000001000000000787371007e01383f4000000000000c7708000000100000000078757200025b42acf317f8060854e002000078700000182dcafebabe0000002e00f501001c7265706f7274315f313338303137383832353234385f38363335313307000101002c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a524576616c7561746f72070003010017706172616d657465725f5245504f52545f4c4f43414c450100324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c506172616d657465723b010017706172616d657465725f4a41535045525f5245504f525401001c706172616d657465725f5245504f52545f5649525455414c495a455201001a706172616d657465725f5245504f52545f54494d455f5a4f4e45010015706172616d657465725f534f52545f4649454c445301001e706172616d657465725f5245504f52545f46494c455f5245534f4c56455201001a706172616d657465725f5245504f52545f5343524950544c455401001f706172616d657465725f5245504f52545f504152414d45544552535f4d415001001b706172616d657465725f5245504f52545f434f4e4e454354494f4e010018706172616d657465725f5245504f52545f434f4e5445585401001d706172616d657465725f5245504f52545f434c4153535f4c4f41444552010024706172616d657465725f5245504f52545f55524c5f48414e444c45525f464143544f525901001c706172616d657465725f5245504f52545f444154415f534f5552434501001e706172616d657465725f49535f49474e4f52455f504147494e4154494f4e010010706172616d657465725f46494c54455201001f706172616d657465725f5245504f52545f464f524d41545f464143544f525901001a706172616d657465725f5245504f52545f4d41585f434f554e5401001a706172616d657465725f5245504f52545f54454d504c41544553010020706172616d657465725f5245504f52545f5245534f555243455f42554e444c450100176669656c645f7573657269645f756e766572696669656401002e4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c4669656c643b0100136669656c645f666163696c6974795f6e616d6501001b6669656c645f73757065727669736f72795f6e6f64655f636f64650100126669656c645f70726f6772616d5f6e616d6501001b6669656c645f73757065727669736f72795f6e6f64655f6e616d650100136669656c645f666163696c6974795f636f64650100156669656c645f666163696c6974795f6163746976650100147661726961626c655f504147455f4e554d4245520100314c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c5661726961626c653b0100167661726961626c655f434f4c554d4e5f4e554d4245520100157661726961626c655f5245504f52545f434f554e540100137661726961626c655f504147455f434f554e540100157661726961626c655f434f4c554d4e5f434f554e540100063c696e69743e010003282956010004436f64650c002700280a0004002a0c00050006090002002c0c00070006090002002e0c0008000609000200300c0009000609000200320c000a000609000200340c000b000609000200360c000c000609000200380c000d0006090002003a0c000e0006090002003c0c000f0006090002003e0c0010000609000200400c0011000609000200420c0012000609000200440c0013000609000200460c0014000609000200480c00150006090002004a0c00160006090002004c0c00170006090002004e0c0018000609000200500c0019001a09000200520c001b001a09000200540c001c001a09000200560c001d001a09000200580c001e001a090002005a0c001f001a090002005c0c0020001a090002005e0c0021002209000200600c0023002209000200620c0024002209000200640c0025002209000200660c00260022090002006801000f4c696e654e756d6265725461626c6501000e637573746f6d697a6564496e6974010030284c6a6176612f7574696c2f4d61703b4c6a6176612f7574696c2f4d61703b4c6a6176612f7574696c2f4d61703b295601000a696e6974506172616d73010012284c6a6176612f7574696c2f4d61703b29560c006d006e0a0002006f01000a696e69744669656c64730c0071006e0a00020072010008696e6974566172730c0074006e0a0002007501000d5245504f52545f4c4f43414c4508007701000d6a6176612f7574696c2f4d6170070079010003676574010026284c6a6176612f6c616e672f4f626a6563743b294c6a6176612f6c616e672f4f626a6563743b0c007b007c0b007a007d0100306e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c506172616d6574657207007f01000d4a41535045525f5245504f52540800810100125245504f52545f5649525455414c495a45520800830100105245504f52545f54494d455f5a4f4e4508008501000b534f52545f4649454c44530800870100145245504f52545f46494c455f5245534f4c5645520800890100105245504f52545f5343524950544c455408008b0100155245504f52545f504152414d45544552535f4d415008008d0100115245504f52545f434f4e4e454354494f4e08008f01000e5245504f52545f434f4e544558540800910100135245504f52545f434c4153535f4c4f4144455208009301001a5245504f52545f55524c5f48414e444c45525f464143544f52590800950100125245504f52545f444154415f534f5552434508009701001449535f49474e4f52455f504147494e4154494f4e08009901000646494c54455208009b0100155245504f52545f464f524d41545f464143544f525908009d0100105245504f52545f4d41585f434f554e5408009f0100105245504f52545f54454d504c415445530800a10100165245504f52545f5245534f555243455f42554e444c450800a30100117573657269645f756e76657269666965640800a501002c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c4669656c640700a701000d666163696c6974795f6e616d650800a901001573757065727669736f72795f6e6f64655f636f64650800ab01000c70726f6772616d5f6e616d650800ad01001573757065727669736f72795f6e6f64655f6e616d650800af01000d666163696c6974795f636f64650800b101000f666163696c6974795f6163746976650800b301000b504147455f4e554d4245520800b501002f6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c5661726961626c650700b701000d434f4c554d4e5f4e554d4245520800b901000c5245504f52545f434f554e540800bb01000a504147455f434f554e540800bd01000c434f4c554d4e5f434f554e540800bf0100086576616c756174650100152849294c6a6176612f6c616e672f4f626a6563743b01000a457863657074696f6e730100136a6176612f6c616e672f5468726f7761626c650700c40100116a6176612f6c616e672f496e74656765720700c6010004284929560c002700c80a00c700c901000e6a6176612f7574696c2f446174650700cb0a00cc002a01000867657456616c756501001428294c6a6176612f6c616e672f4f626a6563743b0c00ce00cf0a00b800d00100166a6176612f6c616e672f537472696e674275666665720700d20a00a800d00100106a6176612f6c616e672f537472696e670700d501000776616c75654f66010026284c6a6176612f6c616e672f4f626a6563743b294c6a6176612f6c616e672f537472696e673b0c00d700d80a00d600d9010015284c6a6176612f6c616e672f537472696e673b29560c002700db0a00d300dc010006617070656e6401001b2843294c6a6176612f6c616e672f537472696e674275666665723b0c00de00df0a00d300e001002c284c6a6176612f6c616e672f537472696e673b294c6a6176612f6c616e672f537472696e674275666665723b0c00de00e20a00d300e3010008746f537472696e6701001428294c6a6176612f6c616e672f537472696e673b0c00e500e60a00d300e70100116a6176612f6c616e672f426f6f6c65616e0700e901000b6576616c756174654f6c6401000b6765744f6c6456616c75650c00ec00cf0a00b800ed0a00a800ed0100116576616c75617465457374696d61746564010011676574457374696d6174656456616c75650c00f100cf0a00b800f201000a536f7572636546696c650021000200040000001f00020005000600000002000700060000000200080006000000020009000600000002000a000600000002000b000600000002000c000600000002000d000600000002000e000600000002000f0006000000020010000600000002001100060000000200120006000000020013000600000002001400060000000200150006000000020016000600000002001700060000000200180006000000020019001a00000002001b001a00000002001c001a00000002001d001a00000002001e001a00000002001f001a000000020020001a0000000200210022000000020023002200000002002400220000000200250022000000020026002200000008000100270028000100290000013800020001000000a02ab7002b2a01b5002d2a01b5002f2a01b500312a01b500332a01b500352a01b500372a01b500392a01b5003b2a01b5003d2a01b5003f2a01b500412a01b500432a01b500452a01b500472a01b500492a01b5004b2a01b5004d2a01b5004f2a01b500512a01b500532a01b500552a01b500572a01b500592a01b5005b2a01b5005d2a01b5005f2a01b500612a01b500632a01b500652a01b500672a01b50069b100000001006a00000086002100000012000400190009001a000e001b0013001c0018001d001d001e0022001f00270020002c00210031002200360023003b00240040002500450026004a0027004f0028005400290059002a005e002b0063002c0068002d006d002e0072002f00770030007c00310081003200860033008b00340090003500950036009a0037009f00120001006b006c000100290000003400020004000000102a2bb700702a2cb700732a2db70076b100000001006a0000001200040000004300050044000a0045000f00460002006d006e00010029000001bb00030002000001572a2b1278b9007e0200c00080c00080b5002d2a2b1282b9007e0200c00080c00080b5002f2a2b1284b9007e0200c00080c00080b500312a2b1286b9007e0200c00080c00080b500332a2b1288b9007e0200c00080c00080b500352a2b128ab9007e0200c00080c00080b500372a2b128cb9007e0200c00080c00080b500392a2b128eb9007e0200c00080c00080b5003b2a2b1290b9007e0200c00080c00080b5003d2a2b1292b9007e0200c00080c00080b5003f2a2b1294b9007e0200c00080c00080b500412a2b1296b9007e0200c00080c00080b500432a2b1298b9007e0200c00080c00080b500452a2b129ab9007e0200c00080c00080b500472a2b129cb9007e0200c00080c00080b500492a2b129eb9007e0200c00080c00080b5004b2a2b12a0b9007e0200c00080c00080b5004d2a2b12a2b9007e0200c00080c00080b5004f2a2b12a4b9007e0200c00080c00080b50051b100000001006a0000005200140000004e0012004f002400500036005100480052005a0053006c0054007e00550090005600a2005700b4005800c6005900d8005a00ea005b00fc005c010e005d0120005e0132005f014400600156006100020071006e00010029000000b3000300020000007f2a2b12a6b9007e0200c000a8c000a8b500532a2b12aab9007e0200c000a8c000a8b500552a2b12acb9007e0200c000a8c000a8b500572a2b12aeb9007e0200c000a8c000a8b500592a2b12b0b9007e0200c000a8c000a8b5005b2a2b12b2b9007e0200c000a8c000a8b5005d2a2b12b4b9007e0200c000a8c000a8b5005fb100000001006a000000220008000000690012006a0024006b0036006c0048006d005a006e006c006f007e007000020074006e0001002900000087000300020000005b2a2b12b6b9007e0200c000b8c000b8b500612a2b12bab9007e0200c000b8c000b8b500632a2b12bcb9007e0200c000b8c000b8b500652a2b12beb9007e0200c000b8c000b8b500672a2b12c0b9007e0200c000b8c000b8b50069b100000001006a0000001a000600000078001200790024007a0036007b0048007c005a007d000100c100c2000200c300000004000100c50029000001f6000300030000015a014d1baa00000155000000000000000f0000004d0000005900000065000000710000007d0000008900000095000000a1000000ad000000b8000000c6000000f3000001010000010f0000013c0000014abb00c75904b700ca4da700ffbb00c75904b700ca4da700f3bb00c75904b700ca4da700e7bb00c75903b700ca4da700dbbb00c75904b700ca4da700cfbb00c75903b700ca4da700c3bb00c75904b700ca4da700b7bb00c75903b700ca4da700abbb00cc59b700cd4da700a02ab40065b600d1c000c74da70092bb00d3592ab4005db600d4c000d6b800dab700dd102db600e12ab40055b600d4c000d6b600e4b600e84da700652ab4005fb600d4c000ea4da700572ab40059b600d4c000d64da70049bb00d3592ab40057b600d4c000d6b800dab700dd102db600e12ab4005bb600d4c000d6b600e4b600e84da7001c2ab40053b600d4c000d64da7000e2ab40061b600d1c000c74d2cb000000001006a0000008a002200000085000200870050008b0059008c005c00900065009100680095007100960074009a007d009b0080009f008900a0008c00a4009500a5009800a900a100aa00a400ae00ad00af00b000b300b800b400bb00b800c600b900c900bd00f300be00f600c2010100c3010400c7010f00c8011200cc013c00cd013f00d1014a00d2014d00d6015800de000100eb00c2000200c300000004000100c50029000001f6000300030000015a014d1baa00000155000000000000000f0000004d0000005900000065000000710000007d0000008900000095000000a1000000ad000000b8000000c6000000f3000001010000010f0000013c0000014abb00c75904b700ca4da700ffbb00c75904b700ca4da700f3bb00c75904b700ca4da700e7bb00c75903b700ca4da700dbbb00c75904b700ca4da700cfbb00c75903b700ca4da700c3bb00c75904b700ca4da700b7bb00c75903b700ca4da700abbb00cc59b700cd4da700a02ab40065b600eec000c74da70092bb00d3592ab4005db600efc000d6b800dab700dd102db600e12ab40055b600efc000d6b600e4b600e84da700652ab4005fb600efc000ea4da700572ab40059b600efc000d64da70049bb00d3592ab40057b600efc000d6b800dab700dd102db600e12ab4005bb600efc000d6b600e4b600e84da7001c2ab40053b600efc000d64da7000e2ab40061b600eec000c74d2cb000000001006a0000008a0022000000e7000200e9005000ed005900ee005c00f2006500f3006800f7007100f8007400fc007d00fd0080010100890102008c0106009501070098010b00a1010c00a4011000ad011100b0011500b8011600bb011a00c6011b00c9011f00f3012000f601240101012501040129010f012a0112012e013c012f013f0133014a0134014d013801580140000100f000c2000200c300000004000100c50029000001f6000300030000015a014d1baa00000155000000000000000f0000004d0000005900000065000000710000007d0000008900000095000000a1000000ad000000b8000000c6000000f3000001010000010f0000013c0000014abb00c75904b700ca4da700ffbb00c75904b700ca4da700f3bb00c75904b700ca4da700e7bb00c75903b700ca4da700dbbb00c75904b700ca4da700cfbb00c75903b700ca4da700c3bb00c75904b700ca4da700b7bb00c75903b700ca4da700abbb00cc59b700cd4da700a02ab40065b600f3c000c74da70092bb00d3592ab4005db600d4c000d6b800dab700dd102db600e12ab40055b600d4c000d6b600e4b600e84da700652ab4005fb600d4c000ea4da700572ab40059b600d4c000d64da70049bb00d3592ab40057b600d4c000d6b800dab700dd102db600e12ab4005bb600d4c000d6b600e4b600e84da7001c2ab40053b600d4c000d64da7000e2ab40061b600f3c000c74d2cb000000001006a0000008a0022000001490002014b0050014f00590150005c015400650155006801590071015a0074015e007d015f0080016300890164008c0168009501690098016d00a1016e00a4017200ad017300b0017700b8017800bb017c00c6017d00c9018100f3018200f60186010101870104018b010f018c01120190013c0191013f0195014a0196014d019a015801a2000100f40000000200017400155f313338303137383832353234385f3836333531337400326e65742e73662e6a61737065727265706f7274732e656e67696e652e64657369676e2e4a524a61766163436f6d70696c6572	\N	2014-10-27 12:28:16.532752	Consistency Report	\N
5	Facilities Missing Authorize Requisition Role	\\xaced0005737200286e65742e73662e6a61737065727265706f7274732e656e67696e652e4a61737065725265706f727400000000000027d80200034c000b636f6d70696c65446174617400164c6a6176612f696f2f53657269616c697a61626c653b4c0011636f6d70696c654e616d655375666669787400124c6a6176612f6c616e672f537472696e673b4c000d636f6d70696c6572436c61737371007e00027872002d6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655265706f727400000000000027d802002a49001950534555444f5f53455249414c5f56455253494f4e5f55494449000c626f74746f6d4d617267696e49000b636f6c756d6e436f756e7449000d636f6c756d6e53706163696e6749000b636f6c756d6e57696474685a001069676e6f7265506167696e6174696f6e5a00136973466c6f6174436f6c756d6e466f6f7465725a0010697353756d6d6172794e6577506167655a0020697353756d6d6172795769746850616765486561646572416e64466f6f7465725a000e69735469746c654e65775061676549000a6c6566744d617267696e42000b6f7269656e746174696f6e49000a7061676548656967687449000970616765576964746842000a7072696e744f7264657249000b72696768744d617267696e490009746f704d617267696e42000e7768656e4e6f44617461547970654c000a6261636b67726f756e647400244c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5242616e643b4c000f636f6c756d6e446972656374696f6e7400334c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f52756e446972656374696f6e456e756d3b4c000c636f6c756d6e466f6f74657271007e00044c000c636f6c756d6e48656164657271007e00045b000864617461736574737400285b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52446174617365743b4c000c64656661756c745374796c657400254c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525374796c653b4c000664657461696c71007e00044c000d64657461696c53656374696f6e7400274c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5253656374696f6e3b4c0012666f726d6174466163746f7279436c61737371007e00024c000a696d706f72747353657474000f4c6a6176612f7574696c2f5365743b4c00086c616e677561676571007e00024c000e6c61737450616765466f6f74657271007e00044c000b6d61696e446174617365747400274c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52446174617365743b4c00046e616d6571007e00024c00066e6f4461746171007e00044c00106f7269656e746174696f6e56616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4f7269656e746174696f6e456e756d3b4c000a70616765466f6f74657271007e00044c000a7061676548656164657271007e00044c000f7072696e744f7264657256616c75657400314c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5072696e744f72646572456e756d3b5b00067374796c65737400265b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525374796c653b4c000773756d6d61727971007e00045b000974656d706c6174657374002f5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525265706f727454656d706c6174653b4c00057469746c6571007e00044c00137768656e4e6f446174615479706556616c75657400354c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5768656e4e6f4461746154797065456e756d3b78700000c3540000000000000001000000000000030e000100000000000000000000022b0000030e000000000000000000007372002b6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736542616e6400000000000027d802000749001950534555444f5f53455249414c5f56455253494f4e5f5549444900066865696768745a000e697353706c6974416c6c6f7765644c00137072696e745768656e45787072657373696f6e74002a4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5245787072657373696f6e3b4c000d70726f706572746965734d617074002d4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250726f706572746965734d61703b4c000973706c6974547970657400104c6a6176612f6c616e672f427974653b4c000e73706c69745479706556616c75657400304c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f53706c697454797065456e756d3b787200336e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365456c656d656e7447726f757000000000000027d80200024c00086368696c6472656e7400104c6a6176612f7574696c2f4c6973743b4c000c656c656d656e7447726f757074002c4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52456c656d656e7447726f75703b7870737200136a6176612e7574696c2e41727261794c6973747881d21d99c7619d03000149000473697a6578700000000077040000000a78700000c35400000000017070707e72002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e53706c697454797065456e756d00000000000000001200007872000e6a6176612e6c616e672e456e756d00000000000000001200007870740007535452455443487e7200316e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e52756e446972656374696f6e456e756d00000000000000001200007871007e001d7400034c545270707070707372002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736553656374696f6e00000000000027d80200015b000562616e64737400255b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5242616e643b7870757200255b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5242616e643b95dd7eec8cca85350200007870000000017371007e00117371007e001a0000000677040000000a737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365546578744669656c6400000000000027d802001549001950534555444f5f53455249414c5f56455253494f4e5f55494449000d626f6f6b6d61726b4c6576656c42000e6576616c756174696f6e54696d6542000f68797065726c696e6b54617267657442000d68797065726c696e6b547970655a0015697353747265746368576974684f766572666c6f774c0014616e63686f724e616d6545787072657373696f6e71007e00124c000f6576616c756174696f6e47726f75707400254c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5247726f75703b4c00136576616c756174696f6e54696d6556616c75657400354c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4576616c756174696f6e54696d65456e756d3b4c000a65787072657373696f6e71007e00124c001968797065726c696e6b416e63686f7245787072657373696f6e71007e00124c001768797065726c696e6b5061676545787072657373696f6e71007e00125b001368797065726c696e6b506172616d65746572737400335b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5248797065726c696e6b506172616d657465723b4c001c68797065726c696e6b5265666572656e636545787072657373696f6e71007e00124c001a68797065726c696e6b546f6f6c74697045787072657373696f6e71007e00124c001768797065726c696e6b5768656e45787072657373696f6e71007e00124c000f6973426c616e6b5768656e4e756c6c7400134c6a6176612f6c616e672f426f6f6c65616e3b4c000a6c696e6b54617267657471007e00024c00086c696e6b5479706571007e00024c00077061747465726e71007e00024c00117061747465726e45787072657373696f6e71007e0012787200326e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736554657874456c656d656e7400000000000027d802002549001950534555444f5f53455249414c5f56455253494f4e5f5549444c0006626f7264657271007e00144c000b626f72646572436f6c6f727400104c6a6176612f6177742f436f6c6f723b4c000c626f74746f6d426f7264657271007e00144c0011626f74746f6d426f72646572436f6c6f7271007e00304c000d626f74746f6d50616464696e677400134c6a6176612f6c616e672f496e74656765723b4c0008666f6e744e616d6571007e00024c0008666f6e7453697a6571007e00314c0013686f72697a6f6e74616c416c69676e6d656e7471007e00144c0018686f72697a6f6e74616c416c69676e6d656e7456616c75657400364c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f486f72697a6f6e74616c416c69676e456e756d3b4c00066973426f6c6471007e002e4c000869734974616c696371007e002e4c000d6973506466456d62656464656471007e002e4c000f6973537472696b655468726f75676871007e002e4c000c69735374796c65645465787471007e002e4c000b6973556e6465726c696e6571007e002e4c000a6c656674426f7264657271007e00144c000f6c656674426f72646572436f6c6f7271007e00304c000b6c65667450616464696e6771007e00314c00076c696e65426f787400274c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a524c696e65426f783b4c000b6c696e6553706163696e6771007e00144c00106c696e6553706163696e6756616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4c696e6553706163696e67456e756d3b4c00066d61726b757071007e00024c000770616464696e6771007e00314c00097061726167726170687400294c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525061726167726170683b4c000b706466456e636f64696e6771007e00024c000b706466466f6e744e616d6571007e00024c000b7269676874426f7264657271007e00144c00107269676874426f72646572436f6c6f7271007e00304c000c726967687450616464696e6771007e00314c0008726f746174696f6e71007e00144c000d726f746174696f6e56616c756574002f4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f526f746174696f6e456e756d3b4c0009746f70426f7264657271007e00144c000e746f70426f72646572436f6c6f7271007e00304c000a746f7050616464696e6771007e00314c0011766572746963616c416c69676e6d656e7471007e00144c0016766572746963616c416c69676e6d656e7456616c75657400344c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f566572746963616c416c69676e456e756d3b7872002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365456c656d656e7400000000000027d802001b49001950534555444f5f53455249414c5f56455253494f4e5f5549444900066865696768745a001769735072696e74496e466972737457686f6c6542616e645a001569735072696e74526570656174656456616c7565735a001a69735072696e745768656e44657461696c4f766572666c6f77735a0015697352656d6f76654c696e655768656e426c616e6b42000c706f736974696f6e5479706542000b7374726574636854797065490005776964746849000178490001794c00096261636b636f6c6f7271007e00304c001464656661756c745374796c6550726f76696465727400344c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5244656661756c745374796c6550726f76696465723b4c000c656c656d656e7447726f757071007e00184c0009666f7265636f6c6f7271007e00304c00036b657971007e00024c00046d6f646571007e00144c00096d6f646556616c756574002b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4d6f6465456e756d3b4c000b706172656e745374796c6571007e00074c0018706172656e745374796c654e616d655265666572656e636571007e00024c0011706f736974696f6e5479706556616c75657400334c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f506f736974696f6e54797065456e756d3b4c00137072696e745768656e45787072657373696f6e71007e00124c00157072696e745768656e47726f75704368616e67657371007e002b4c000d70726f706572746965734d617071007e00135b001370726f706572747945787072657373696f6e737400335b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250726f706572747945787072657373696f6e3b4c0010737472657463685479706556616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5374726574636854797065456e756d3b4c0004757569647400104c6a6176612f7574696c2f555549443b78700000c354000000140001000000000000003d00000000000000007071007e001071007e00287070707070707e7200316e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e506f736974696f6e54797065456e756d00000000000000001200007871007e001d7400134649585f52454c41544956455f544f5f544f50707070707e7200306e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5374726574636854797065456e756d00000000000000001200007871007e001d74000a4e4f5f535452455443487372000e6a6176612e7574696c2e55554944bc9903f7986d852f0200024a000c6c65617374536967426974734a000b6d6f7374536967426974737870a3c35f9512886f9f0cb682e445b14bae0000c354707070707070737200116a6176612e6c616e672e496e746567657212e2a0a4f781873802000149000576616c7565787200106a6176612e6c616e672e4e756d62657286ac951d0b94e08b02000078700000000a707e7200346e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e486f72697a6f6e74616c416c69676e456e756d00000000000000001200007871007e001d74000643454e5445527070707070707070707372002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173654c696e65426f7800000000000027d802000b4c000d626f74746f6d50616464696e6771007e00314c0009626f74746f6d50656e74002b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f626173652f4a52426f7850656e3b4c000c626f78436f6e7461696e657274002c4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52426f78436f6e7461696e65723b4c000b6c65667450616464696e6771007e00314c00076c65667450656e71007e004f4c000770616464696e6771007e00314c000370656e71007e004f4c000c726967687450616464696e6771007e00314c0008726967687450656e71007e004f4c000a746f7050616464696e6771007e00314c0006746f7050656e71007e004f787070737200336e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f78426f74746f6d50656e00000000000027d80200007872002d6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f7850656e00000000000027d80200014c00076c696e65426f7871007e00337872002a6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736550656e00000000000027d802000649001950534555444f5f53455249414c5f56455253494f4e5f5549444c00096c696e65436f6c6f7271007e00304c00096c696e655374796c6571007e00144c000e6c696e655374796c6556616c75657400304c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4c696e655374796c65456e756d3b4c00096c696e6557696474687400114c6a6176612f6c616e672f466c6f61743b4c000c70656e436f6e7461696e657274002c4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250656e436f6e7461696e65723b78700000c3547070707071007e005171007e005171007e003f70737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f784c65667450656e00000000000027d80200007871007e00530000c3547070707071007e005171007e0051707371007e00530000c3547070707071007e005171007e005170737200326e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f78526967687450656e00000000000027d80200007871007e00530000c3547070707071007e005171007e005170737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f78546f7050656e00000000000027d80200007871007e00530000c3547070707071007e005171007e005170707070737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736550617261677261706800000000000027d802000a4c000f66697273744c696e65496e64656e7471007e00314c000a6c656674496e64656e7471007e00314c000b6c696e6553706163696e6771007e00344c000f6c696e6553706163696e6753697a6571007e00564c0012706172616772617068436f6e7461696e65727400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52506172616772617068436f6e7461696e65723b4c000b7269676874496e64656e7471007e00314c000c73706163696e67416674657271007e00314c000d73706163696e674265666f726571007e00314c000c74616253746f70576964746871007e00314c000874616253746f707371007e001778707070707071007e003f70707070707070707070707070707070700000c354000000000000000070707e7200336e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e4576616c756174696f6e54696d65456e756d00000000000000001200007871007e001d7400034e4f57737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736545787072657373696f6e00000000000027d802000449000269645b00066368756e6b737400305b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5245787072657373696f6e4368756e6b3b4c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e0002787000000009757200305b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5245787072657373696f6e4368756e6b3b6d59cfde694ba355020000787000000001737200366e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736545787072657373696f6e4368756e6b00000000000027d8020002420004747970654c00047465787471007e000278700474000c5245504f52545f434f554e54707070707070707070707070707371007e002a0000c35400000014000100000000000000b10000003d000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e0046bc9d337b6af09873656d88930a9d43ba0000c3547070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e007071007e007071007e006e707371007e00590000c3547070707071007e007071007e0070707371007e00530000c3547070707071007e007071007e0070707371007e005c0000c3547070707071007e007071007e0070707371007e005e0000c3547070707071007e007071007e0070707070707371007e00607070707071007e006e70707070707070707070707070707070700000c3540000000000000000707071007e00647371007e00660000000a7571007e0069000000037371007e006b0374000d666163696c6974795f636f64657371007e006b017400052b272d272b7371007e006b0374000d666163696c6974795f6e616d65707070707070707070707070707371007e002a0000c3540000001400010000000000000059000000ee000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e004698f4376032bdf48f2d97d1a7f057497d0000c3547070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e008171007e008171007e007f707371007e00590000c3547070707071007e008171007e0081707371007e00530000c3547070707071007e008171007e0081707371007e005c0000c3547070707071007e008171007e0081707371007e005e0000c3547070707071007e008171007e0081707070707371007e00607070707071007e007f70707070707070707070707070707070700000c3540000000000000000707071007e00647371007e00660000000b7571007e0069000000017371007e006b0374000f666163696c6974795f616374697665707070707070707070707070707371007e002a0000c354000000140001000000000000006500000147000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e0046bf4b5560f753e6ae3b6201ef3bb64bb50000c3547070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e008e71007e008e71007e008c707371007e00590000c3547070707071007e008e71007e008e707371007e00530000c3547070707071007e008e71007e008e707371007e005c0000c3547070707071007e008e71007e008e707371007e005e0000c3547070707071007e008e71007e008e707070707371007e00607070707071007e008c70707070707070707070707070707070700000c3540000000000000000707071007e00647371007e00660000000c7571007e0069000000017371007e006b0374000c70726f6772616d5f6e616d65707070707070707070707070707371007e002a0000c35400000014000100000000000000de000001ac000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e00468b47c18385282767a2f59c46025d43280000c3547070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e009b71007e009b71007e0099707371007e00590000c3547070707071007e009b71007e009b707371007e00530000c3547070707071007e009b71007e009b707371007e005c0000c3547070707071007e009b71007e009b707371007e005e0000c3547070707071007e009b71007e009b707070707371007e00607070707071007e009970707070707070707070707070707070700000c3540000000000000000707071007e00647371007e00660000000d7571007e0069000000037371007e006b0374001573757065727669736f72795f6e6f64655f636f64657371007e006b017400052b272d272b7371007e006b0374001573757065727669736f72795f6e6f64655f6e616d65707070707070707070707070707371007e002a0000c35400000014000100000000000000840000028a000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e0046be94070ffee2354714e89f25808142c80000c3547070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e00ac71007e00ac71007e00aa707371007e00590000c3547070707071007e00ac71007e00ac707371007e00530000c3547070707071007e00ac71007e00ac707371007e005c0000c3547070707071007e00ac71007e00ac707371007e005e0000c3547070707071007e00ac71007e00ac707070707371007e00607070707071007e00aa70707070707070707070707070707070700000c3540000000000000000707071007e00647371007e00660000000e7571007e0069000000017371007e006b037400117573657269645f756e76657269666965647070707070707070707070707078700000c35400000014017070707070707400046a617661707372002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173654461746173657400000000000027d802001149001950534555444f5f53455249414c5f56455253494f4e5f5549445a000669734d61696e4200177768656e5265736f757263654d697373696e67547970655b00066669656c64737400265b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a524669656c643b4c001066696c74657245787072657373696f6e71007e00125b000667726f7570737400265b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5247726f75703b4c00046e616d6571007e00025b000a706172616d657465727374002a5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52506172616d657465723b4c000d70726f706572746965734d617071007e00134c000571756572797400254c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5251756572793b4c000e7265736f7572636542756e646c6571007e00024c000e7363726970746c6574436c61737371007e00025b000a7363726970746c65747374002a5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525363726970746c65743b5b000a736f72744669656c647374002a5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52536f72744669656c643b4c00047575696471007e003e5b00097661726961626c65737400295b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525661726961626c653b4c001c7768656e5265736f757263654d697373696e675479706556616c756574003e4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5768656e5265736f757263654d697373696e6754797065456e756d3b78700000c3540100757200265b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a524669656c643b023cdfc74e2af2700200007870000000077372002c6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173654669656c6400000000000027d80200054c000b6465736372697074696f6e71007e00024c00046e616d6571007e00024c000d70726f706572746965734d617071007e00134c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e000278707074000d666163696c6974795f636f64657372002b6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5250726f706572746965734d617000000000000027d80200034c00046261736571007e00134c000e70726f706572746965734c69737471007e00174c000d70726f706572746965734d617074000f4c6a6176612f7574696c2f4d61703b78707070707400106a6176612e6c616e672e537472696e67707371007e00c47074000d666163696c6974795f6e616d657371007e00c77070707400106a6176612e6c616e672e537472696e67707371007e00c47074000f666163696c6974795f6163746976657371007e00c77070707400116a6176612e6c616e672e426f6f6c65616e707371007e00c47074000c70726f6772616d5f6e616d657371007e00c77070707400106a6176612e6c616e672e537472696e67707371007e00c47074001573757065727669736f72795f6e6f64655f636f64657371007e00c77070707400106a6176612e6c616e672e537472696e67707371007e00c47074001573757065727669736f72795f6e6f64655f6e616d657371007e00c77070707400106a6176612e6c616e672e537472696e67707371007e00c4707400117573657269645f756e76657269666965647371007e00c77070707400106a6176612e6c616e672e537472696e677070707400077265706f7274317572002a5b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a52506172616d657465723b22000c8d2ac36021020000787000000013737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365506172616d6574657200000000000027d80200095a000e6973466f7250726f6d7074696e675a000f697353797374656d446566696e65644c001664656661756c7456616c756545787072657373696f6e71007e00124c000b6465736372697074696f6e71007e00024c00046e616d6571007e00024c000e6e6573746564547970654e616d6571007e00024c000d70726f706572746965734d617071007e00134c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e000278700101707074000e5245504f52545f434f4e54455854707371007e00c77070707400296e65742e73662e6a61737065727265706f7274732e656e67696e652e5265706f7274436f6e74657874707371007e00e6010170707400155245504f52545f504152414d45544552535f4d4150707371007e00c770707074000d6a6176612e7574696c2e4d6170707371007e00e60101707074000d4a41535045525f5245504f5254707371007e00c77070707400286e65742e73662e6a61737065727265706f7274732e656e67696e652e4a61737065725265706f7274707371007e00e6010170707400115245504f52545f434f4e4e454354494f4e707371007e00c77070707400136a6176612e73716c2e436f6e6e656374696f6e707371007e00e6010170707400105245504f52545f4d41585f434f554e54707371007e00c77070707400116a6176612e6c616e672e496e7465676572707371007e00e6010170707400125245504f52545f444154415f534f55524345707371007e00c77070707400286e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5244617461536f75726365707371007e00e6010170707400105245504f52545f5343524950544c4554707371007e00c770707074002f6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5241627374726163745363726970746c6574707371007e00e60101707074000d5245504f52545f4c4f43414c45707371007e00c77070707400106a6176612e7574696c2e4c6f63616c65707371007e00e6010170707400165245504f52545f5245534f555243455f42554e444c45707371007e00c77070707400186a6176612e7574696c2e5265736f7572636542756e646c65707371007e00e6010170707400105245504f52545f54494d455f5a4f4e45707371007e00c77070707400126a6176612e7574696c2e54696d655a6f6e65707371007e00e6010170707400155245504f52545f464f524d41545f464143544f5259707371007e00c770707074002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e7574696c2e466f726d6174466163746f7279707371007e00e6010170707400135245504f52545f434c4153535f4c4f41444552707371007e00c77070707400156a6176612e6c616e672e436c6173734c6f61646572707371007e00e60101707074001a5245504f52545f55524c5f48414e444c45525f464143544f5259707371007e00c77070707400206a6176612e6e65742e55524c53747265616d48616e646c6572466163746f7279707371007e00e6010170707400145245504f52545f46494c455f5245534f4c564552707371007e00c770707074002d6e65742e73662e6a61737065727265706f7274732e656e67696e652e7574696c2e46696c655265736f6c766572707371007e00e6010170707400105245504f52545f54454d504c41544553707371007e00c77070707400146a6176612e7574696c2e436f6c6c656374696f6e707371007e00e60101707074000b534f52545f4649454c4453707371007e00c770707074000e6a6176612e7574696c2e4c697374707371007e00e60101707074000646494c544552707371007e00c77070707400296e65742e73662e6a61737065727265706f7274732e656e67696e652e4461746173657446696c746572707371007e00e6010170707400125245504f52545f5649525455414c495a4552707371007e00c77070707400296e65742e73662e6a61737065727265706f7274732e656e67696e652e4a525669727475616c697a6572707371007e00e60101707074001449535f49474e4f52455f504147494e4154494f4e707371007e00c77070707400116a6176612e6c616e672e426f6f6c65616e707371007e00c7707371007e001a0000000377040000000374000c697265706f72742e7a6f6f6d740009697265706f72742e78740009697265706f72742e7978737200116a6176612e7574696c2e486173684d61700507dac1c31660d103000246000a6c6f6164466163746f724900097468726573686f6c6478703f400000000000037708000000040000000371007e01377400013071007e0135740003312e3071007e013674000130787372002c6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365517565727900000000000027d80200025b00066368756e6b7374002b5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5251756572794368756e6b3b4c00086c616e677561676571007e000278707572002b5b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5251756572794368756e6b3b409f00a1e8ba34a4020000787000000001737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736551756572794368756e6b00000000000027d8020003420004747970654c00047465787471007e00025b0006746f6b656e737400135b4c6a6176612f6c616e672f537472696e673b78700174163857495448205245435552534956452073705f6e6f646528736e69642c20736e706172656e7469642920415320280a20202853454c4543540a202020202069642c0a2020202020706172656e7469640a20202046524f4d2073757065727669736f72795f6e6f646573290a2020554e494f4e20414c4c202853454c4543540a202020202020202020202020202020736e2e69642c0a20202020202020202020202020202073706e2e736e706172656e7469640a2020202020202020202020202046524f4d2073757065727669736f72795f6e6f64657320736e0a2020202020202020202020202020204a4f494e2073705f6e6f64652073706e0a20202020202020202020202020202020204f4e20736e2e706172656e746964203d2073706e2e736e69640a2020290a292c0a2020202070726f6772616d5f666163696c6974795f776974685f75736572735f696e5f686965726172636879202870726f6772616d5f69642c20666163696c6974795f69642c2072696768745f6e616d652c20757365725f6163746976652c20757365725f76657269666965642c20757365725f69642920415320280a2020202053454c4543540a20202020202070732e70726f6772616d69642c0a202020202020662e69642c0a20202020202072722e72696768746e616d652c0a202020202020752e6163746976652c0a202020202020752e76657269666965642c0a202020202020752e69640a0a2020202046524f4d20666163696c6974696573206620494e4e4552204a4f494e207265717569736974696f6e5f67726f75705f6d656d626572732072676d0a20202020202020204f4e20662e6964203d2072676d2e666163696c69747969640a202020202020494e4e4552204a4f494e2070726f6772616d735f737570706f727465642070730a20202020202020204f4e20662e6964203d2070732e666163696c69747969640a202020202020494e4e4552204a4f494e207265717569736974696f6e5f67726f7570732072670a20202020202020204f4e2072676d2e7265717569736974696f6e67726f75706964203d2072672e69640a202020202020494e4e4552204a4f494e207265717569736974696f6e5f67726f75705f70726f6772616d5f7363686564756c657320726770730a20202020202020204f4e2070732e70726f6772616d6964203d20726770732e70726f6772616d696420414e442072676d2e7265717569736974696f6e67726f75706964203d20726770732e7265717569736974696f6e67726f757069640a202020202020494e4e4552204a4f494e202853454c4543540a2020202020202020202020202020202020202020736e69642c0a2020202020202020202020202020202020202020434153450a20202020202020202020202020202020202020205748454e20736e706172656e746964204953204e554c4c205448454e20736e69640a2020202020202020202020202020202020202020454c534520736e706172656e74696420454e442041532073757065726e6f646569640a20202020202020202020202020202020202046524f4d2073705f6e6f64650a202020202020202020202020202020202029204153206e6f6465730a20202020202020204f4e2072672e73757065727669736f72796e6f64656964203d206e6f6465732e736e69640a2020202020204c454654204a4f494e20726f6c655f61737369676e6d656e74732072610a20202020202020204f4e206e6f6465732e73757065726e6f64656964203d2072612e53555045525649534f52594e4f4445494420414e442070732e70726f6772616d6964203d2072612e70726f6772616d69640a2020202020204c454654204a4f494e20757365727320750a20202020202020204f4e2072612e757365726964203d20752e69640a2020202020204c454654204a4f494e20726f6c655f7269676874732072720a20202020202020204f4e2072612e726f6c656964203d2072722e726f6c6569640a0a20202020554e494f4e20414c4c0a0a2020202053454c4543540a20202020202070732e70726f6772616d69642c0a202020202020662e69642c0a20202020202072722e72696768746e616d652c0a202020202020752e6163746976652c0a202020202020752e76657269666965642c0a202020202020752e69640a2020202046524f4d20666163696c697469657320660a202020202020494e4e4552204a4f494e2070726f6772616d735f737570706f727465642070730a20202020202020204f4e20662e6964203d2070732e666163696c69747969640a2020202020204c454654204a4f494e20757365727320750a20202020202020204f4e20662e6964203d20752e666163696c69747969640a2020202020204c454654204a4f494e20726f6c655f61737369676e6d656e74732072610a20202020202020204f4e2070732e70726f6772616d6964203d2072612e70726f6772616d696420414e4420752e6964203d2072612e75736572696420414e442072612e73757065727669736f72796e6f64656964204953204e554c4c0a2020202020204c454654204a4f494e20726f6c655f7269676874732072720a20202020202020204f4e2072612e726f6c656964203d2072722e726f6c6569640a0a2020292c0a202020206163746976655f76657269666965645f75736572735f666f725f737570706f727465645f70726f6772616d732870726f6772616d69642c20666163696c69747969642920415320280a20202020202053454c4543540a202020202020202070726f6772616d5f69642c0a2020202020202020666163696c6974795f69640a20202020202046524f4d2070726f6772616d5f666163696c6974795f776974685f75736572735f696e5f6869657261726368790a20202020202057484552452072696768745f6e616d65203d2027415554484f52495a455f5245515549534954494f4e2720414e4420757365725f616374697665203d205452554520414e4420757365725f7665726966696564203d20545255450a2020292c0a202020206163746976655f756e76657269666965645f75736572735f666f725f737570706f727465645f70726f6772616d732870726f6772616d5f69642c20666163696c6974795f69642c20757365725f69642920415320280a20202020202053454c4543540a202020202020202070726f6772616d5f69642c0a2020202020202020666163696c6974795f69642c0a2020202020202020757365725f69640a20202020202046524f4d2070726f6772616d5f666163696c6974795f776974685f75736572735f696e5f6869657261726368790a20202020202057484552452072696768745f6e616d65203d2027415554484f52495a455f5245515549534954494f4e2720414e4420757365725f616374697665203d205452554520414e4420757365725f7665726966696564203d2046414c53450a0a2020290a0a53454c4543540a202044495354494e43540a2020662e636f64652020202020202020202020202020202020202020202020202020202020202020202020202020202020415320666163696c6974795f636f64652c0a2020662e6e616d652020202020202020202020202020202020202020202020202020202020202020202020202020202020415320666163696c6974795f6e616d652c0a2020662e616374697665202020202020202020202020202020202020202020202020202020202020202020202020202020415320666163696c6974795f6163746976652c0a2020702e6e616d65202020202020202020202020202020202020202020202020202020202020202020202020202020202041532070726f6772616d5f6e616d652c0a2020736e2e636f64652020202020202020202020202020202020202020202020202020202020202020202020202020202041532073757065727669736f72795f6e6f64655f636f64652c0a2020736e2e6e616d652020202020202020202020202020202020202020202020202020202020202020202020202020202041532073757065727669736f72795f6e6f64655f6e616d652c0a202043415345205748454e20752e616374697665203d2046414c5345205448454e20434f414c45534345282727290a2020454c53450a20202020434f414c4553434528752e757365726e616d652c2027272920454e44204153207573657249645f756e76657269666965640a0a46524f4d2070726f6772616d5f666163696c6974795f776974685f75736572735f696e5f686965726172636879207066777520494e4e4552204a4f494e2070726f6772616d7320700a202020204f4e20706677752e70726f6772616d5f6964203d20702e696420414e4420702e70757368203d2046414c53450a20204c454654204a4f494e20757365727320750a202020204f4e20706677752e757365725f6964203d20752e69640a2020494e4e4552204a4f494e20666163696c697469657320660a202020204f4e20706677752e666163696c6974795f6964203d20662e69640a20204c454654204a4f494e207265717569736974696f6e5f67726f75705f6d656d626572732072676d0a202020204f4e20662e6964203d2072676d2e666163696c69747969640a20204c454654204a4f494e207265717569736974696f6e5f67726f75705f70726f6772616d5f7363686564756c657320726770730a202020204f4e20702e6964203d20726770732e70726f6772616d69640a20204c454654204a4f494e207265717569736974696f6e5f67726f7570732072670a202020204f4e20726770732e7265717569736974696f6e67726f75706964203d2072672e69640a20204c454654204a4f494e2073757065727669736f72795f6e6f64657320736e0a202020204f4e2072672e73757065727669736f72796e6f64656964203d20736e2e69640a57484552452028706677752e70726f6772616d5f6964204e4f5420494e202853454c4543540a20202020202020202020202020202020202020202020202020202020202020202070726f6772616d69640a2020202020202020202020202020202020202020202020202020202020202046524f4d206163746976655f76657269666965645f75736572735f666f725f737570706f727465645f70726f6772616d7329204f5220706677752e666163696c6974795f6964204e4f5420494e202853454c4543540a20202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020666163696c69747969640a202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202046524f4d0a202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020206163746976655f76657269666965645f75736572735f666f725f737570706f727465645f70726f6772616d730a202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202057484552450a2020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202070726f6772616d69640a202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020203d0a20202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020706677752e70726f6772616d5f696429290a202020202020414e44202843415345205748454e2028706677752e70726f6772616d5f6964204e4f5420494e202853454c4543540a20202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202070726f6772616d5f69640a2020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202046524f4d206163746976655f756e76657269666965645f75736572735f666f725f737570706f727465645f70726f6772616d7329204f520a20202020202020202020202020202020202020202020706677752e666163696c6974795f6964204e4f5420494e202853454c4543540a20202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020666163696c6974795f69640a202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202046524f4d206163746976655f756e76657269666965645f75736572735f666f725f737570706f727465645f70726f6772616d730a202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202057484552452070726f6772616d5f6964203d20706677752e70726f6772616d5f6964290a29205448454e2028752e616374697665203d2046414c5345204f522075204953204e554c4c290a2020202020202020202020454c534520752e696420494e202853454c4543540a202020202020202020202020202020202020202020202020202020757365725f69640a2020202020202020202020202020202020202020202020202046524f4d206163746976655f756e76657269666965645f75736572735f666f725f737570706f727465645f70726f6772616d730a20202020202020202020202020202020202020202020202020574845524520666163696c6974795f6964203d20706677752e666163696c6974795f696420414e442070726f6772616d5f6964203d20706677752e70726f6772616d5f6964290a2020202020202020202020454e44290a202020202020414e442072676d2e7265717569736974696f6e67726f75706964203d20726770732e7265717569736974696f6e67726f7570696420414e4420662e656e61626c6564203d205452554520414e4420702e616374697665203d205452554520414e4420702e70757368203d2046414c53450a202020202020414e4420662e7669727475616c666163696c697479203d2066616c736520414e4420662e736174656c6c697465203c3e20747275650a4f5244455220425920662e636f64652c20702e6e616d652c20736e2e636f64657074000373716c707070707371007e0046b3d554b1aefe96cea0a4e8610726422f757200295b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a525661726961626c653b62e6837c982cb7440200007870000000057372002f6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655661726961626c6500000000000027d802001149001950534555444f5f53455249414c5f56455253494f4e5f55494442000b63616c63756c6174696f6e42000d696e6372656d656e74547970655a000f697353797374656d446566696e65644200097265736574547970654c001063616c63756c6174696f6e56616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f43616c63756c6174696f6e456e756d3b4c000a65787072657373696f6e71007e00124c000e696e6372656d656e7447726f757071007e002b4c0012696e6372656d656e745479706556616c75657400344c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f496e6372656d656e7454797065456e756d3b4c001b696e6372656d656e746572466163746f7279436c6173734e616d6571007e00024c001f696e6372656d656e746572466163746f7279436c6173735265616c4e616d6571007e00024c0016696e697469616c56616c756545787072657373696f6e71007e00124c00046e616d6571007e00024c000a726573657447726f757071007e002b4c000e72657365745479706556616c75657400304c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f526573657454797065456e756d3b4c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e00027870000077ee000001007e7200306e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e43616c63756c6174696f6e456e756d00000000000000001200007871007e001d74000653595354454d70707e7200326e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e496e6372656d656e7454797065456e756d00000000000000001200007871007e001d7400044e4f4e4570707371007e0066000000007571007e0069000000017371007e006b017400186e6577206a6176612e6c616e672e496e7465676572283129707074000b504147455f4e554d424552707e72002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e526573657454797065456e756d00000000000000001200007871007e001d7400065245504f525471007e00fa707371007e014a000077ee0000010071007e0150707071007e015370707371007e0066000000017571007e0069000000017371007e006b017400186e6577206a6176612e6c616e672e496e7465676572283129707074000d434f4c554d4e5f4e554d424552707e71007e015a7400045041474571007e00fa707371007e014a000077ee000001007e71007e014f740005434f554e547371007e0066000000027571007e0069000000017371007e006b017400186e6577206a6176612e6c616e672e496e746567657228312970707071007e015370707371007e0066000000037571007e0069000000017371007e006b017400186e6577206a6176612e6c616e672e496e7465676572283029707074000c5245504f52545f434f554e547071007e015b71007e00fa707371007e014a000077ee0000010071007e01667371007e0066000000047571007e0069000000017371007e006b017400186e6577206a6176612e6c616e672e496e746567657228312970707071007e015370707371007e0066000000057571007e0069000000017371007e006b017400186e6577206a6176612e6c616e672e496e7465676572283029707074000a504147455f434f554e547071007e016371007e00fa707371007e014a000077ee0000010071007e01667371007e0066000000067571007e0069000000017371007e006b017400186e6577206a6176612e6c616e672e496e746567657228312970707071007e015370707371007e0066000000077571007e0069000000017371007e006b017400186e6577206a6176612e6c616e672e496e7465676572283029707074000c434f4c554d4e5f434f554e54707e71007e015a740006434f4c554d4e71007e00fa707e72003c6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5768656e5265736f757263654d697373696e6754797065456e756d00000000000000001200007871007e001d7400044e554c4c71007e00e37371007e00117371007e001a0000000277040000000a737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655374617469635465787400000000000027d80200014c00047465787471007e00027871007e002f0000c354000000140001000000000000030e00000000000000207071007e001071007e018a70707070707071007e00417070707071007e00447371007e00468769af621a8e549b488f93d8d2fe4df60000c3547070707070707371007e00480000000f7071007e004c7070707070707070707371007e004e707371007e00520000c3547070707071007e019071007e019071007e018d707371007e00590000c3547070707071007e019071007e0190707371007e00530000c3547070707071007e019071007e0190707371007e005c0000c3547070707071007e019071007e0190707371007e005e0000c3547070707071007e019071007e0190707070707371007e00607070707071007e018d70707070707070707070707070707070707400124e6f2070726f626c656d7320666f756e642e7371007e018c0000c354000000200001000000000000030e00000000000000007071007e001071007e018a70707070707071007e00417070707071007e00447371007e00469238092a1177a2f66659ba1e006b4f7f0000c354707070707074000953616e7353657269667371007e0048000000187071007e004c7070707070737200116a6176612e6c616e672e426f6f6c65616ecd207280d59cfaee0200015a000576616c75657870017070707371007e004e707371007e00520000c3547070707071007e019e71007e019e71007e0198707371007e00590000c3547070707071007e019e71007e019e707371007e00530000c3547070707071007e019e71007e019e707371007e005c0000c3547070707071007e019e71007e019e707371007e005e0000c3547070707071007e019e71007e019e707070707371007e00607070707071007e0198707070707070707070707070707070707074002d466163696c6974696573204d697373696e6720417574686f72697a65205265717569736974696f6e20526f6c6578700000c3540000003401707070707e7200306e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e4f7269656e746174696f6e456e756d00000000000000001200007871007e001d7400094c414e4453434150457371007e00117371007e001a0000000277040000000a7371007e002a0000c3540000001400010000000000000048000002c6000000007071007e001071007e01a970707070707071007e00417070707071007e00447371007e0046a6cd4885e72541551abcd2c71ce14a4b0000c354707070707074000953616e7353657269667371007e00480000000870707070707070707070707371007e004e707371007e00520000c3547070707071007e01af71007e01af71007e01ab707371007e00590000c3547070707071007e01af71007e01af707371007e00530000c3547070707071007e01af71007e01af707371007e005c0000c3547070707071007e01af71007e01af707371007e005e0000c3547070707071007e01af71007e01af707070707371007e00607070707071007e01ab70707070707070707070707070707070700000c3540000000000000000707071007e00647371007e00660000000f7571007e0069000000017371007e006b0474000b504147455f4e554d424552707070707070707070707070707371007e018c0000c35400000014000100000000000002c600000000000000007071007e001071007e01a970707070707071007e00417070707071007e00447371007e0046b62f68c26194b7c32e4a2985b90149630000c3547070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e01bc71007e01bc71007e01ba707371007e00590000c3547070707071007e01bc71007e01bc707371007e00530000c3547070707071007e01bc71007e01bc707371007e005c0000c3547070707071007e01bc71007e01bc707371007e005e0000c3547070707071007e01bc71007e01bc707070707371007e00607070707071007e01ba70707070707070707070707070707070707400012078700000c3540000001401707070707371007e00117371007e001a0000000677040000000a7371007e018c0000c354000000140001000000000000006500000147000000007071007e001071007e01c470707070707071007e00417070707071007e00447371007e00469b596670c74bd785ef159a2f33d942ba0000c354707070707074000953616e7353657269667371007e00480000000c707071007e019d7070707071007e019d7070707371007e004e707371007e00520000c3547070707071007e01ca71007e01ca71007e01c6707371007e00590000c3547070707071007e01ca71007e01ca707371007e00530000c3547070707071007e01ca71007e01ca707371007e005c0000c3547070707071007e01ca71007e01ca707371007e005e0000c3547070707071007e01ca71007e01ca707070707371007e00607070707071007e01c6707070707070707070707070707070707074000c50726f6772616d204e616d657371007e018c0000c35400000014000100000000000000de000001ac000000007071007e001071007e01c470707070707071007e00417070707071007e00447371007e00469f72d87cd57c5a0d9a07393f55224bce0000c354707070707074000953616e73536572696671007e01c9707071007e019d7070707071007e019d7070707371007e004e707371007e00520000c3547070707071007e01d571007e01d571007e01d2707371007e00590000c3547070707071007e01d571007e01d5707371007e00530000c3547070707071007e01d571007e01d5707371007e005c0000c3547070707071007e01d571007e01d5707371007e005e0000c3547070707071007e01d571007e01d5707070707371007e00607070707071007e01d2707070707070707070707070707070707074001c53757065727669736f7279204e6f646520436f6465202d204e616d657371007e018c0000c35400000014000100000000000000b10000003d000000007071007e001071007e01c470707070707071007e00417070707071007e00447371007e0046a2a43d5c0bd9170ad949733d046b41aa0000c354707070707074000953616e73536572696671007e01c9707071007e019d7070707071007e019d7070707371007e004e707371007e00520000c3547070707071007e01e071007e01e071007e01dd707371007e00590000c3547070707071007e01e071007e01e0707371007e00530000c3547070707071007e01e071007e01e0707371007e005c0000c3547070707071007e01e071007e01e0707371007e005e0000c3547070707071007e01e071007e01e0707070707371007e00607070707071007e01dd7070707070707070707070707070707070740014466163696c69747920436f6465202d204e616d657371007e018c0000c3540000001400010000000000000059000000ee000000007071007e001071007e01c470707070707071007e00417070707071007e00447371007e0046835adf817aa47786a3153510d28746ad0000c354707070707074000953616e73536572696671007e01c9707071007e019d7070707071007e019d7070707371007e004e707371007e00520000c3547070707071007e01eb71007e01eb71007e01e8707371007e00590000c3547070707071007e01eb71007e01eb707371007e00530000c3547070707071007e01eb71007e01eb707371007e005c0000c3547070707071007e01eb71007e01eb707371007e005e0000c3547070707071007e01eb71007e01eb707070707371007e00607070707071007e01e8707070707070707070707070707070707074000f466163696c697479204163746976657371007e018c0000c354000000140001000000000000003d00000000000000007071007e001071007e01c470707070707071007e00417070707071007e00447371007e0046b48a4feb4161ed645a7f10ba925c4ca70000c354707070707074000953616e73536572696671007e01c97071007e004c71007e019d7070707071007e019d7070707371007e004e707371007e00520000c3547070707071007e01f671007e01f671007e01f3707371007e00590000c3547070707071007e01f671007e01f6707371007e00530000c3547070707071007e01f671007e01f6707371007e005c0000c3547070707071007e01f671007e01f6707371007e005e0000c3547070707071007e01f671007e01f6707070707371007e00607070707071007e01f37070707070707070707070707070707070740004532e4e6f7371007e018c0000c35400000014000100000000000000840000028a000000007071007e001071007e01c470707070707071007e00417070707071007e00447371007e004695811259740284767a2bce85864e42e70000c354707070707074000953616e73536572696671007e01c9707071007e019d7070707071007e019d7070707371007e004e707371007e00520000c3547070707071007e020171007e020171007e01fe707371007e00590000c3547070707071007e020171007e0201707371007e00530000c3547070707071007e020171007e0201707371007e005c0000c3547070707071007e020171007e0201707371007e005e0000c3547070707071007e020171007e0201707070707371007e00607070707071007e01fe707070707070707070707070707070707074001455736572204964202d20556e766572696669656478700000c354000000140170707071007e001e7e72002f6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5072696e744f72646572456e756d00000000000000001200007871007e001d740008564552544943414c757200265b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a525374796c653bd49cc311d90572350200007870000000087372002c6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655374796c65000000000000271102003a49001950534555444f5f53455249414c5f56455253494f4e5f5549445a0009697344656661756c744c00096261636b636f6c6f7271007e00304c0006626f7264657271007e00144c000b626f72646572436f6c6f7271007e00304c000c626f74746f6d426f7264657271007e00144c0011626f74746f6d426f72646572436f6c6f7271007e00304c000d626f74746f6d50616464696e6771007e00315b0011636f6e646974696f6e616c5374796c65737400315b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52436f6e646974696f6e616c5374796c653b4c001464656661756c745374796c6550726f766964657271007e00394c000466696c6c71007e00144c000966696c6c56616c756574002b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f46696c6c456e756d3b4c0008666f6e744e616d6571007e00024c0008666f6e7453697a6571007e00314c0009666f7265636f6c6f7271007e00304c0013686f72697a6f6e74616c416c69676e6d656e7471007e00144c0018686f72697a6f6e74616c416c69676e6d656e7456616c756571007e00324c000f6973426c616e6b5768656e4e756c6c71007e002e4c00066973426f6c6471007e002e4c000869734974616c696371007e002e4c000d6973506466456d62656464656471007e002e4c000f6973537472696b655468726f75676871007e002e4c000c69735374796c65645465787471007e002e4c000b6973556e6465726c696e6571007e002e4c000a6c656674426f7264657271007e00144c000f6c656674426f72646572436f6c6f7271007e00304c000b6c65667450616464696e6771007e00314c00076c696e65426f7871007e00334c00076c696e6550656e7400234c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250656e3b4c000b6c696e6553706163696e6771007e00144c00106c696e6553706163696e6756616c756571007e00344c00066d61726b757071007e00024c00046d6f646571007e00144c00096d6f646556616c756571007e003a4c00046e616d6571007e00024c000770616464696e6771007e00314c000970617261677261706871007e00354c000b706172656e745374796c6571007e00074c0018706172656e745374796c654e616d655265666572656e636571007e00024c00077061747465726e71007e00024c000b706466456e636f64696e6771007e00024c000b706466466f6e744e616d6571007e00024c000370656e71007e00144c000c706f736974696f6e5479706571007e00144c000672616469757371007e00314c000b7269676874426f7264657271007e00144c00107269676874426f72646572436f6c6f7271007e00304c000c726967687450616464696e6771007e00314c0008726f746174696f6e71007e00144c000d726f746174696f6e56616c756571007e00364c000a7363616c65496d61676571007e00144c000f7363616c65496d61676556616c75657400314c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5363616c65496d616765456e756d3b4c000b737472657463685479706571007e00144c0009746f70426f7264657271007e00144c000e746f70426f72646572436f6c6f7271007e00304c000a746f7050616464696e6771007e00314c0011766572746963616c416c69676e6d656e7471007e00144c0016766572746963616c416c69676e6d656e7456616c756571007e003778700000c35400707070707070707070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e021471007e021471007e0213707371007e00590000c3547070707071007e021471007e0214707371007e00530000c3547372000e6a6176612e6177742e436f6c6f7201a51783108f337502000546000666616c70686149000576616c75654c0002637374001b4c6a6176612f6177742f636f6c6f722f436f6c6f7253706163653b5b00096672676276616c75657400025b465b00066676616c756571007e021a787000000000ff00000070707070707372000f6a6176612e6c616e672e466c6f6174daedc9a2db3cf0ec02000146000576616c75657871007e00493f80000071007e021471007e0214707371007e005c0000c3547070707071007e021471007e0214707371007e005e0000c3547070707071007e021471007e02147371007e00540000c3547070707071007e021370707070707400057461626c65707371007e00607070707071007e021370707070707070707070707070707070707070707070707070707371007e020e0000c354007371007e021800000000fff0f8ff7070707070707070707070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e022571007e022571007e0223707371007e00590000c3547070707071007e022571007e0225707371007e00530000c3547371007e021800000000ff00000070707070707371007e021c3f00000071007e022571007e0225707371007e005c0000c3547070707071007e022571007e0225707371007e005e0000c3547070707071007e022571007e02257371007e00540000c3547070707071007e0223707070707e7200296e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e4d6f6465456e756d00000000000000001200007871007e001d7400064f50415155457400087461626c655f5448707371007e00607070707071007e022370707070707070707070707070707070707070707070707070707371007e020e0000c354007371007e021800000000ffbfe1ff7070707070707070707070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e023571007e023571007e0233707371007e00590000c3547070707071007e023571007e0235707371007e00530000c3547371007e021800000000ff00000070707070707371007e021c3f00000071007e023571007e0235707371007e005c0000c3547070707071007e023571007e0235707371007e005e0000c3547070707071007e023571007e02357371007e00540000c3547070707071007e02337070707071007e022f7400087461626c655f4348707371007e00607070707071007e023370707070707070707070707070707070707070707070707070707371007e020e0000c354007371007e021800000000ffffffff7070707070707070707070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e024271007e024271007e0240707371007e00590000c3547070707071007e024271007e0242707371007e00530000c3547371007e021800000000ff00000070707070707371007e021c3f00000071007e024271007e0242707371007e005c0000c3547070707071007e024271007e0242707371007e005e0000c3547070707071007e024271007e02427371007e00540000c3547070707071007e02407070707071007e022f7400087461626c655f5444707371007e00607070707071007e024070707070707070707070707070707070707070707070707070707371007e020e0000c35400707070707070707070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e024e71007e024e71007e024d707371007e00590000c3547070707071007e024e71007e024e707371007e00530000c3547371007e021800000000ff00000070707070707371007e021c3f80000071007e024e71007e024e707371007e005c0000c3547070707071007e024e71007e024e707371007e005e0000c3547070707071007e024e71007e024e7371007e00540000c3547070707071007e024d70707070707400077461626c652031707371007e00607070707071007e024d70707070707070707070707070707070707070707070707070707371007e020e0000c354007371007e021800000000fff0f8ff7070707070707070707070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e025b71007e025b71007e0259707371007e00590000c3547070707071007e025b71007e025b707371007e00530000c3547371007e021800000000ff00000070707070707371007e021c3f00000071007e025b71007e025b707371007e005c0000c3547070707071007e025b71007e025b707371007e005e0000c3547070707071007e025b71007e025b7371007e00540000c3547070707071007e02597070707071007e022f74000a7461626c6520315f5448707371007e00607070707071007e025970707070707070707070707070707070707070707070707070707371007e020e0000c354007371007e021800000000ffbfe1ff7070707070707070707070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e026871007e026871007e0266707371007e00590000c3547070707071007e026871007e0268707371007e00530000c3547371007e021800000000ff00000070707070707371007e021c3f00000071007e026871007e0268707371007e005c0000c3547070707071007e026871007e0268707371007e005e0000c3547070707071007e026871007e02687371007e00540000c3547070707071007e02667070707071007e022f74000a7461626c6520315f4348707371007e00607070707071007e026670707070707070707070707070707070707070707070707070707371007e020e0000c354007371007e021800000000ffffffff7070707070707070707070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e027571007e027571007e0273707371007e00590000c3547070707071007e027571007e0275707371007e00530000c3547371007e021800000000ff00000070707070707371007e021c3f00000071007e027571007e0275707371007e005c0000c3547070707071007e027571007e0275707371007e005e0000c3547070707071007e027571007e02757371007e00540000c3547070707071007e02737070707071007e022f74000a7461626c6520315f5444707371007e00607070707071007e0273707070707070707070707070707070707070707070707070707070707371007e00117371007e001a0000000277040000000a7371007e018c0000c35400000020000100000000000002c600000000000000007071007e001071007e028070707070707071007e00417070707071007e00447371007e00468f61a735ab2074b7212194e972ca43210000c354707070707074000953616e73536572696671007e019b7071007e004c707070707071007e019d7070707371007e004e707371007e00520000c3547070707071007e028571007e028571007e0282707371007e00590000c3547070707071007e028571007e0285707371007e00530000c3547070707071007e028571007e0285707371007e005c0000c3547070707071007e028571007e0285707371007e005e0000c3547070707071007e028571007e0285707070707371007e00607070707071007e0282707070707070707070707070707070707074002d466163696c6974696573204d697373696e6720417574686f72697a65205265717569736974696f6e20526f6c657371007e002a0000c3540000002000010000000000000048000002c6000000007071007e001071007e028070707070707071007e00417070707071007e00447371007e004689ab02f2dda79bb52dd094dce4b543c00000c354707070707074000953616e73536572696671007e01ae70707070707070707070707371007e004e707371007e00520000c3547070707071007e029071007e029071007e028d707371007e00590000c3547070707071007e029071007e0290707371007e00530000c3547070707071007e029071007e0290707371007e005c0000c3547070707071007e029071007e0290707371007e005e0000c3547070707071007e029071007e0290707070707371007e00607070707071007e028d70707070707070707070707070707070700000c3540000000000000000707071007e00647371007e0066000000087571007e0069000000017371007e006b017400146e6577206a6176612e7574696c2e446174652829707070707070707070707074000a64642f4d4d2f797979797078700000c3540000002001707070707e7200336e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5768656e4e6f4461746154797065456e756d00000000000000001200007871007e001d74000f4e4f5f444154415f53454354494f4e737200366e65742e73662e6a61737065727265706f7274732e656e67696e652e64657369676e2e4a525265706f7274436f6d70696c654461746100000000000027d80200034c001363726f7373746162436f6d70696c654461746171007e00c84c001264617461736574436f6d70696c654461746171007e00c84c00166d61696e44617461736574436f6d70696c654461746171007e000178707371007e01383f4000000000000c77080000001000000000787371007e01383f4000000000000c7708000000100000000078757200025b42acf317f8060854e002000078700000182dcafebabe0000002e00f501001c7265706f7274315f313338303137383738393035385f38373837363807000101002c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a524576616c7561746f72070003010017706172616d657465725f5245504f52545f4c4f43414c450100324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c506172616d657465723b010017706172616d657465725f4a41535045525f5245504f525401001c706172616d657465725f5245504f52545f5649525455414c495a455201001a706172616d657465725f5245504f52545f54494d455f5a4f4e45010015706172616d657465725f534f52545f4649454c445301001e706172616d657465725f5245504f52545f46494c455f5245534f4c56455201001a706172616d657465725f5245504f52545f5343524950544c455401001f706172616d657465725f5245504f52545f504152414d45544552535f4d415001001b706172616d657465725f5245504f52545f434f4e4e454354494f4e010018706172616d657465725f5245504f52545f434f4e5445585401001d706172616d657465725f5245504f52545f434c4153535f4c4f41444552010024706172616d657465725f5245504f52545f55524c5f48414e444c45525f464143544f525901001c706172616d657465725f5245504f52545f444154415f534f5552434501001e706172616d657465725f49535f49474e4f52455f504147494e4154494f4e010010706172616d657465725f46494c54455201001f706172616d657465725f5245504f52545f464f524d41545f464143544f525901001a706172616d657465725f5245504f52545f4d41585f434f554e5401001a706172616d657465725f5245504f52545f54454d504c41544553010020706172616d657465725f5245504f52545f5245534f555243455f42554e444c450100176669656c645f7573657269645f756e766572696669656401002e4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c4669656c643b0100136669656c645f666163696c6974795f6e616d6501001b6669656c645f73757065727669736f72795f6e6f64655f636f64650100126669656c645f70726f6772616d5f6e616d6501001b6669656c645f73757065727669736f72795f6e6f64655f6e616d650100136669656c645f666163696c6974795f636f64650100156669656c645f666163696c6974795f6163746976650100147661726961626c655f504147455f4e554d4245520100314c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c5661726961626c653b0100167661726961626c655f434f4c554d4e5f4e554d4245520100157661726961626c655f5245504f52545f434f554e540100137661726961626c655f504147455f434f554e540100157661726961626c655f434f4c554d4e5f434f554e540100063c696e69743e010003282956010004436f64650c002700280a0004002a0c00050006090002002c0c00070006090002002e0c0008000609000200300c0009000609000200320c000a000609000200340c000b000609000200360c000c000609000200380c000d0006090002003a0c000e0006090002003c0c000f0006090002003e0c0010000609000200400c0011000609000200420c0012000609000200440c0013000609000200460c0014000609000200480c00150006090002004a0c00160006090002004c0c00170006090002004e0c0018000609000200500c0019001a09000200520c001b001a09000200540c001c001a09000200560c001d001a09000200580c001e001a090002005a0c001f001a090002005c0c0020001a090002005e0c0021002209000200600c0023002209000200620c0024002209000200640c0025002209000200660c00260022090002006801000f4c696e654e756d6265725461626c6501000e637573746f6d697a6564496e6974010030284c6a6176612f7574696c2f4d61703b4c6a6176612f7574696c2f4d61703b4c6a6176612f7574696c2f4d61703b295601000a696e6974506172616d73010012284c6a6176612f7574696c2f4d61703b29560c006d006e0a0002006f01000a696e69744669656c64730c0071006e0a00020072010008696e6974566172730c0074006e0a0002007501000d5245504f52545f4c4f43414c4508007701000d6a6176612f7574696c2f4d6170070079010003676574010026284c6a6176612f6c616e672f4f626a6563743b294c6a6176612f6c616e672f4f626a6563743b0c007b007c0b007a007d0100306e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c506172616d6574657207007f01000d4a41535045525f5245504f52540800810100125245504f52545f5649525455414c495a45520800830100105245504f52545f54494d455f5a4f4e4508008501000b534f52545f4649454c44530800870100145245504f52545f46494c455f5245534f4c5645520800890100105245504f52545f5343524950544c455408008b0100155245504f52545f504152414d45544552535f4d415008008d0100115245504f52545f434f4e4e454354494f4e08008f01000e5245504f52545f434f4e544558540800910100135245504f52545f434c4153535f4c4f4144455208009301001a5245504f52545f55524c5f48414e444c45525f464143544f52590800950100125245504f52545f444154415f534f5552434508009701001449535f49474e4f52455f504147494e4154494f4e08009901000646494c54455208009b0100155245504f52545f464f524d41545f464143544f525908009d0100105245504f52545f4d41585f434f554e5408009f0100105245504f52545f54454d504c415445530800a10100165245504f52545f5245534f555243455f42554e444c450800a30100117573657269645f756e76657269666965640800a501002c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c4669656c640700a701000d666163696c6974795f6e616d650800a901001573757065727669736f72795f6e6f64655f636f64650800ab01000c70726f6772616d5f6e616d650800ad01001573757065727669736f72795f6e6f64655f6e616d650800af01000d666163696c6974795f636f64650800b101000f666163696c6974795f6163746976650800b301000b504147455f4e554d4245520800b501002f6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c5661726961626c650700b701000d434f4c554d4e5f4e554d4245520800b901000c5245504f52545f434f554e540800bb01000a504147455f434f554e540800bd01000c434f4c554d4e5f434f554e540800bf0100086576616c756174650100152849294c6a6176612f6c616e672f4f626a6563743b01000a457863657074696f6e730100136a6176612f6c616e672f5468726f7761626c650700c40100116a6176612f6c616e672f496e74656765720700c6010004284929560c002700c80a00c700c901000e6a6176612f7574696c2f446174650700cb0a00cc002a01000867657456616c756501001428294c6a6176612f6c616e672f4f626a6563743b0c00ce00cf0a00b800d00100166a6176612f6c616e672f537472696e674275666665720700d20a00a800d00100106a6176612f6c616e672f537472696e670700d501000776616c75654f66010026284c6a6176612f6c616e672f4f626a6563743b294c6a6176612f6c616e672f537472696e673b0c00d700d80a00d600d9010015284c6a6176612f6c616e672f537472696e673b29560c002700db0a00d300dc010006617070656e6401001b2843294c6a6176612f6c616e672f537472696e674275666665723b0c00de00df0a00d300e001002c284c6a6176612f6c616e672f537472696e673b294c6a6176612f6c616e672f537472696e674275666665723b0c00de00e20a00d300e3010008746f537472696e6701001428294c6a6176612f6c616e672f537472696e673b0c00e500e60a00d300e70100116a6176612f6c616e672f426f6f6c65616e0700e901000b6576616c756174654f6c6401000b6765744f6c6456616c75650c00ec00cf0a00b800ed0a00a800ed0100116576616c75617465457374696d61746564010011676574457374696d6174656456616c75650c00f100cf0a00b800f201000a536f7572636546696c650021000200040000001f00020005000600000002000700060000000200080006000000020009000600000002000a000600000002000b000600000002000c000600000002000d000600000002000e000600000002000f0006000000020010000600000002001100060000000200120006000000020013000600000002001400060000000200150006000000020016000600000002001700060000000200180006000000020019001a00000002001b001a00000002001c001a00000002001d001a00000002001e001a00000002001f001a000000020020001a0000000200210022000000020023002200000002002400220000000200250022000000020026002200000008000100270028000100290000013800020001000000a02ab7002b2a01b5002d2a01b5002f2a01b500312a01b500332a01b500352a01b500372a01b500392a01b5003b2a01b5003d2a01b5003f2a01b500412a01b500432a01b500452a01b500472a01b500492a01b5004b2a01b5004d2a01b5004f2a01b500512a01b500532a01b500552a01b500572a01b500592a01b5005b2a01b5005d2a01b5005f2a01b500612a01b500632a01b500652a01b500672a01b50069b100000001006a00000086002100000012000400190009001a000e001b0013001c0018001d001d001e0022001f00270020002c00210031002200360023003b00240040002500450026004a0027004f0028005400290059002a005e002b0063002c0068002d006d002e0072002f00770030007c00310081003200860033008b00340090003500950036009a0037009f00120001006b006c000100290000003400020004000000102a2bb700702a2cb700732a2db70076b100000001006a0000001200040000004300050044000a0045000f00460002006d006e00010029000001bb00030002000001572a2b1278b9007e0200c00080c00080b5002d2a2b1282b9007e0200c00080c00080b5002f2a2b1284b9007e0200c00080c00080b500312a2b1286b9007e0200c00080c00080b500332a2b1288b9007e0200c00080c00080b500352a2b128ab9007e0200c00080c00080b500372a2b128cb9007e0200c00080c00080b500392a2b128eb9007e0200c00080c00080b5003b2a2b1290b9007e0200c00080c00080b5003d2a2b1292b9007e0200c00080c00080b5003f2a2b1294b9007e0200c00080c00080b500412a2b1296b9007e0200c00080c00080b500432a2b1298b9007e0200c00080c00080b500452a2b129ab9007e0200c00080c00080b500472a2b129cb9007e0200c00080c00080b500492a2b129eb9007e0200c00080c00080b5004b2a2b12a0b9007e0200c00080c00080b5004d2a2b12a2b9007e0200c00080c00080b5004f2a2b12a4b9007e0200c00080c00080b50051b100000001006a0000005200140000004e0012004f002400500036005100480052005a0053006c0054007e00550090005600a2005700b4005800c6005900d8005a00ea005b00fc005c010e005d0120005e0132005f014400600156006100020071006e00010029000000b3000300020000007f2a2b12a6b9007e0200c000a8c000a8b500532a2b12aab9007e0200c000a8c000a8b500552a2b12acb9007e0200c000a8c000a8b500572a2b12aeb9007e0200c000a8c000a8b500592a2b12b0b9007e0200c000a8c000a8b5005b2a2b12b2b9007e0200c000a8c000a8b5005d2a2b12b4b9007e0200c000a8c000a8b5005fb100000001006a000000220008000000690012006a0024006b0036006c0048006d005a006e006c006f007e007000020074006e0001002900000087000300020000005b2a2b12b6b9007e0200c000b8c000b8b500612a2b12bab9007e0200c000b8c000b8b500632a2b12bcb9007e0200c000b8c000b8b500652a2b12beb9007e0200c000b8c000b8b500672a2b12c0b9007e0200c000b8c000b8b50069b100000001006a0000001a000600000078001200790024007a0036007b0048007c005a007d000100c100c2000200c300000004000100c50029000001f6000300030000015a014d1baa00000155000000000000000f0000004d0000005900000065000000710000007d0000008900000095000000a1000000ad000000b8000000c6000000f3000001010000010f0000013c0000014abb00c75904b700ca4da700ffbb00c75904b700ca4da700f3bb00c75904b700ca4da700e7bb00c75903b700ca4da700dbbb00c75904b700ca4da700cfbb00c75903b700ca4da700c3bb00c75904b700ca4da700b7bb00c75903b700ca4da700abbb00cc59b700cd4da700a02ab40065b600d1c000c74da70092bb00d3592ab4005db600d4c000d6b800dab700dd102db600e12ab40055b600d4c000d6b600e4b600e84da700652ab4005fb600d4c000ea4da700572ab40059b600d4c000d64da70049bb00d3592ab40057b600d4c000d6b800dab700dd102db600e12ab4005bb600d4c000d6b600e4b600e84da7001c2ab40053b600d4c000d64da7000e2ab40061b600d1c000c74d2cb000000001006a0000008a002200000085000200870050008b0059008c005c00900065009100680095007100960074009a007d009b0080009f008900a0008c00a4009500a5009800a900a100aa00a400ae00ad00af00b000b300b800b400bb00b800c600b900c900bd00f300be00f600c2010100c3010400c7010f00c8011200cc013c00cd013f00d1014a00d2014d00d6015800de000100eb00c2000200c300000004000100c50029000001f6000300030000015a014d1baa00000155000000000000000f0000004d0000005900000065000000710000007d0000008900000095000000a1000000ad000000b8000000c6000000f3000001010000010f0000013c0000014abb00c75904b700ca4da700ffbb00c75904b700ca4da700f3bb00c75904b700ca4da700e7bb00c75903b700ca4da700dbbb00c75904b700ca4da700cfbb00c75903b700ca4da700c3bb00c75904b700ca4da700b7bb00c75903b700ca4da700abbb00cc59b700cd4da700a02ab40065b600eec000c74da70092bb00d3592ab4005db600efc000d6b800dab700dd102db600e12ab40055b600efc000d6b600e4b600e84da700652ab4005fb600efc000ea4da700572ab40059b600efc000d64da70049bb00d3592ab40057b600efc000d6b800dab700dd102db600e12ab4005bb600efc000d6b600e4b600e84da7001c2ab40053b600efc000d64da7000e2ab40061b600eec000c74d2cb000000001006a0000008a0022000000e7000200e9005000ed005900ee005c00f2006500f3006800f7007100f8007400fc007d00fd0080010100890102008c0106009501070098010b00a1010c00a4011000ad011100b0011500b8011600bb011a00c6011b00c9011f00f3012000f601240101012501040129010f012a0112012e013c012f013f0133014a0134014d013801580140000100f000c2000200c300000004000100c50029000001f6000300030000015a014d1baa00000155000000000000000f0000004d0000005900000065000000710000007d0000008900000095000000a1000000ad000000b8000000c6000000f3000001010000010f0000013c0000014abb00c75904b700ca4da700ffbb00c75904b700ca4da700f3bb00c75904b700ca4da700e7bb00c75903b700ca4da700dbbb00c75904b700ca4da700cfbb00c75903b700ca4da700c3bb00c75904b700ca4da700b7bb00c75903b700ca4da700abbb00cc59b700cd4da700a02ab40065b600f3c000c74da70092bb00d3592ab4005db600d4c000d6b800dab700dd102db600e12ab40055b600d4c000d6b600e4b600e84da700652ab4005fb600d4c000ea4da700572ab40059b600d4c000d64da70049bb00d3592ab40057b600d4c000d6b800dab700dd102db600e12ab4005bb600d4c000d6b600e4b600e84da7001c2ab40053b600d4c000d64da7000e2ab40061b600f3c000c74d2cb000000001006a0000008a0022000001490002014b0050014f00590150005c015400650155006801590071015a0074015e007d015f0080016300890164008c0168009501690098016d00a1016e00a4017200ad017300b0017700b8017800bb017c00c6017d00c9018100f3018200f60186010101870104018b010f018c01120190013c0191013f0195014a0196014d019a015801a2000100f40000000200017400155f313338303137383738393035385f3837383736387400326e65742e73662e6a61737065727265706f7274732e656e67696e652e64657369676e2e4a524a61766163436f6d70696c6572	\N	2014-10-27 12:28:16.537005	Consistency Report	\N
6	Supervisory Nodes Missing Approve Requisition Role	\\xaced0005737200286e65742e73662e6a61737065727265706f7274732e656e67696e652e4a61737065725265706f727400000000000027d80200034c000b636f6d70696c65446174617400164c6a6176612f696f2f53657269616c697a61626c653b4c0011636f6d70696c654e616d655375666669787400124c6a6176612f6c616e672f537472696e673b4c000d636f6d70696c6572436c61737371007e00027872002d6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655265706f727400000000000027d802002a49001950534555444f5f53455249414c5f56455253494f4e5f55494449000c626f74746f6d4d617267696e49000b636f6c756d6e436f756e7449000d636f6c756d6e53706163696e6749000b636f6c756d6e57696474685a001069676e6f7265506167696e6174696f6e5a00136973466c6f6174436f6c756d6e466f6f7465725a0010697353756d6d6172794e6577506167655a0020697353756d6d6172795769746850616765486561646572416e64466f6f7465725a000e69735469746c654e65775061676549000a6c6566744d617267696e42000b6f7269656e746174696f6e49000a7061676548656967687449000970616765576964746842000a7072696e744f7264657249000b72696768744d617267696e490009746f704d617267696e42000e7768656e4e6f44617461547970654c000a6261636b67726f756e647400244c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5242616e643b4c000f636f6c756d6e446972656374696f6e7400334c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f52756e446972656374696f6e456e756d3b4c000c636f6c756d6e466f6f74657271007e00044c000c636f6c756d6e48656164657271007e00045b000864617461736574737400285b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52446174617365743b4c000c64656661756c745374796c657400254c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525374796c653b4c000664657461696c71007e00044c000d64657461696c53656374696f6e7400274c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5253656374696f6e3b4c0012666f726d6174466163746f7279436c61737371007e00024c000a696d706f72747353657474000f4c6a6176612f7574696c2f5365743b4c00086c616e677561676571007e00024c000e6c61737450616765466f6f74657271007e00044c000b6d61696e446174617365747400274c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52446174617365743b4c00046e616d6571007e00024c00066e6f4461746171007e00044c00106f7269656e746174696f6e56616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4f7269656e746174696f6e456e756d3b4c000a70616765466f6f74657271007e00044c000a7061676548656164657271007e00044c000f7072696e744f7264657256616c75657400314c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5072696e744f72646572456e756d3b5b00067374796c65737400265b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525374796c653b4c000773756d6d61727971007e00045b000974656d706c6174657374002f5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525265706f727454656d706c6174653b4c00057469746c6571007e00044c00137768656e4e6f446174615479706556616c75657400354c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5768656e4e6f4461746154797065456e756d3b78700000c3540000000000000001000000000000030e000100000000000000000000022b0000030e000000000000000000007372002b6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736542616e6400000000000027d802000749001950534555444f5f53455249414c5f56455253494f4e5f5549444900066865696768745a000e697353706c6974416c6c6f7765644c00137072696e745768656e45787072657373696f6e74002a4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5245787072657373696f6e3b4c000d70726f706572746965734d617074002d4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250726f706572746965734d61703b4c000973706c6974547970657400104c6a6176612f6c616e672f427974653b4c000e73706c69745479706556616c75657400304c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f53706c697454797065456e756d3b787200336e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365456c656d656e7447726f757000000000000027d80200024c00086368696c6472656e7400104c6a6176612f7574696c2f4c6973743b4c000c656c656d656e7447726f757074002c4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52456c656d656e7447726f75703b7870737200136a6176612e7574696c2e41727261794c6973747881d21d99c7619d03000149000473697a6578700000000077040000000a78700000c35400000000017070707e72002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e53706c697454797065456e756d00000000000000001200007872000e6a6176612e6c616e672e456e756d00000000000000001200007870740007535452455443487e7200316e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e52756e446972656374696f6e456e756d00000000000000001200007871007e001d7400034c545270707070707372002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736553656374696f6e00000000000027d80200015b000562616e64737400255b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5242616e643b7870757200255b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5242616e643b95dd7eec8cca85350200007870000000017371007e00117371007e001a0000000677040000000a737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365546578744669656c6400000000000027d802001549001950534555444f5f53455249414c5f56455253494f4e5f55494449000d626f6f6b6d61726b4c6576656c42000e6576616c756174696f6e54696d6542000f68797065726c696e6b54617267657442000d68797065726c696e6b547970655a0015697353747265746368576974684f766572666c6f774c0014616e63686f724e616d6545787072657373696f6e71007e00124c000f6576616c756174696f6e47726f75707400254c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5247726f75703b4c00136576616c756174696f6e54696d6556616c75657400354c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4576616c756174696f6e54696d65456e756d3b4c000a65787072657373696f6e71007e00124c001968797065726c696e6b416e63686f7245787072657373696f6e71007e00124c001768797065726c696e6b5061676545787072657373696f6e71007e00125b001368797065726c696e6b506172616d65746572737400335b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5248797065726c696e6b506172616d657465723b4c001c68797065726c696e6b5265666572656e636545787072657373696f6e71007e00124c001a68797065726c696e6b546f6f6c74697045787072657373696f6e71007e00124c001768797065726c696e6b5768656e45787072657373696f6e71007e00124c000f6973426c616e6b5768656e4e756c6c7400134c6a6176612f6c616e672f426f6f6c65616e3b4c000a6c696e6b54617267657471007e00024c00086c696e6b5479706571007e00024c00077061747465726e71007e00024c00117061747465726e45787072657373696f6e71007e0012787200326e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736554657874456c656d656e7400000000000027d802002549001950534555444f5f53455249414c5f56455253494f4e5f5549444c0006626f7264657271007e00144c000b626f72646572436f6c6f727400104c6a6176612f6177742f436f6c6f723b4c000c626f74746f6d426f7264657271007e00144c0011626f74746f6d426f72646572436f6c6f7271007e00304c000d626f74746f6d50616464696e677400134c6a6176612f6c616e672f496e74656765723b4c0008666f6e744e616d6571007e00024c0008666f6e7453697a6571007e00314c0013686f72697a6f6e74616c416c69676e6d656e7471007e00144c0018686f72697a6f6e74616c416c69676e6d656e7456616c75657400364c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f486f72697a6f6e74616c416c69676e456e756d3b4c00066973426f6c6471007e002e4c000869734974616c696371007e002e4c000d6973506466456d62656464656471007e002e4c000f6973537472696b655468726f75676871007e002e4c000c69735374796c65645465787471007e002e4c000b6973556e6465726c696e6571007e002e4c000a6c656674426f7264657271007e00144c000f6c656674426f72646572436f6c6f7271007e00304c000b6c65667450616464696e6771007e00314c00076c696e65426f787400274c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a524c696e65426f783b4c000b6c696e6553706163696e6771007e00144c00106c696e6553706163696e6756616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4c696e6553706163696e67456e756d3b4c00066d61726b757071007e00024c000770616464696e6771007e00314c00097061726167726170687400294c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525061726167726170683b4c000b706466456e636f64696e6771007e00024c000b706466466f6e744e616d6571007e00024c000b7269676874426f7264657271007e00144c00107269676874426f72646572436f6c6f7271007e00304c000c726967687450616464696e6771007e00314c0008726f746174696f6e71007e00144c000d726f746174696f6e56616c756574002f4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f526f746174696f6e456e756d3b4c0009746f70426f7264657271007e00144c000e746f70426f72646572436f6c6f7271007e00304c000a746f7050616464696e6771007e00314c0011766572746963616c416c69676e6d656e7471007e00144c0016766572746963616c416c69676e6d656e7456616c75657400344c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f566572746963616c416c69676e456e756d3b7872002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365456c656d656e7400000000000027d802001b49001950534555444f5f53455249414c5f56455253494f4e5f5549444900066865696768745a001769735072696e74496e466972737457686f6c6542616e645a001569735072696e74526570656174656456616c7565735a001a69735072696e745768656e44657461696c4f766572666c6f77735a0015697352656d6f76654c696e655768656e426c616e6b42000c706f736974696f6e5479706542000b7374726574636854797065490005776964746849000178490001794c00096261636b636f6c6f7271007e00304c001464656661756c745374796c6550726f76696465727400344c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5244656661756c745374796c6550726f76696465723b4c000c656c656d656e7447726f757071007e00184c0009666f7265636f6c6f7271007e00304c00036b657971007e00024c00046d6f646571007e00144c00096d6f646556616c756574002b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4d6f6465456e756d3b4c000b706172656e745374796c6571007e00074c0018706172656e745374796c654e616d655265666572656e636571007e00024c0011706f736974696f6e5479706556616c75657400334c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f506f736974696f6e54797065456e756d3b4c00137072696e745768656e45787072657373696f6e71007e00124c00157072696e745768656e47726f75704368616e67657371007e002b4c000d70726f706572746965734d617071007e00135b001370726f706572747945787072657373696f6e737400335b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250726f706572747945787072657373696f6e3b4c0010737472657463685479706556616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5374726574636854797065456e756d3b4c0004757569647400104c6a6176612f7574696c2f555549443b78700000c354000000140001000000000000007400000023000000007071007e001071007e00287070707070707e7200316e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e506f736974696f6e54797065456e756d00000000000000001200007871007e001d7400134649585f52454c41544956455f544f5f544f50707070707e7200306e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5374726574636854797065456e756d00000000000000001200007871007e001d74000a4e4f5f535452455443487372000e6a6176612e7574696c2e55554944bc9903f7986d852f0200024a000c6c65617374536967426974734a000b6d6f7374536967426974737870a9d9fbfb06612a8f3d8316284452410d0000c354707070707074000953616e735365726966737200116a6176612e6c616e672e496e746567657212e2a0a4f781873802000149000576616c7565787200106a6176612e6c616e672e4e756d62657286ac951d0b94e08b02000078700000000c70707070707070707070707372002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173654c696e65426f7800000000000027d802000b4c000d626f74746f6d50616464696e6771007e00314c0009626f74746f6d50656e74002b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f626173652f4a52426f7850656e3b4c000c626f78436f6e7461696e657274002c4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52426f78436f6e7461696e65723b4c000b6c65667450616464696e6771007e00314c00076c65667450656e71007e004d4c000770616464696e6771007e00314c000370656e71007e004d4c000c726967687450616464696e6771007e00314c0008726967687450656e71007e004d4c000a746f7050616464696e6771007e00314c0006746f7050656e71007e004d787070737200336e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f78426f74746f6d50656e00000000000027d80200007872002d6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f7850656e00000000000027d80200014c00076c696e65426f7871007e00337872002a6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736550656e00000000000027d802000649001950534555444f5f53455249414c5f56455253494f4e5f5549444c00096c696e65436f6c6f7271007e00304c00096c696e655374796c6571007e00144c000e6c696e655374796c6556616c75657400304c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4c696e655374796c65456e756d3b4c00096c696e6557696474687400114c6a6176612f6c616e672f466c6f61743b4c000c70656e436f6e7461696e657274002c4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250656e436f6e7461696e65723b78700000c3547070707071007e004f71007e004f71007e003f70737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f784c65667450656e00000000000027d80200007871007e00510000c3547070707071007e004f71007e004f707371007e00510000c3547070707071007e004f71007e004f70737200326e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f78526967687450656e00000000000027d80200007871007e00510000c3547070707071007e004f71007e004f70737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f78546f7050656e00000000000027d80200007871007e00510000c3547070707071007e004f71007e004f70707070737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736550617261677261706800000000000027d802000a4c000f66697273744c696e65496e64656e7471007e00314c000a6c656674496e64656e7471007e00314c000b6c696e6553706163696e6771007e00344c000f6c696e6553706163696e6753697a6571007e00544c0012706172616772617068436f6e7461696e65727400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52506172616772617068436f6e7461696e65723b4c000b7269676874496e64656e7471007e00314c000c73706163696e67416674657271007e00314c000d73706163696e674265666f726571007e00314c000c74616253746f70576964746871007e00314c000874616253746f707371007e001778707070707071007e003f70707070707070707070707070707070700000c354000000000000000070707e7200336e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e4576616c756174696f6e54696d65456e756d00000000000000001200007871007e001d7400034e4f57737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736545787072657373696f6e00000000000027d802000449000269645b00066368756e6b737400305b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5245787072657373696f6e4368756e6b3b4c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e0002787000000009757200305b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5245787072657373696f6e4368756e6b3b6d59cfde694ba355020000787000000001737200366e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736545787072657373696f6e4368756e6b00000000000027d8020002420004747970654c00047465787471007e000278700374000c70726f6772616d5f6e616d65707070707070707070707070707371007e002a0000c354000000140001000000000000009200000097000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e0046980c6e20451ed89f70a35c82b9a34c1e0000c354707070707074000953616e73536572696671007e004b70707070707070707070707371007e004c707371007e00500000c3547070707071007e006f71007e006f71007e006c707371007e00570000c3547070707071007e006f71007e006f707371007e00510000c3547070707071007e006f71007e006f707371007e005a0000c3547070707071007e006f71007e006f707371007e005c0000c3547070707071007e006f71007e006f707070707371007e005e7070707071007e006c70707070707070707070707070707070700000c3540000000000000000707071007e00627371007e00640000000a7571007e0067000000017371007e00690374001573757065727669736f72795f6e6f64655f636f6465707070707070707070707070707371007e002a0000c35400000014000100000000000000a200000129000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e00468cdc613a1d372dff871fa864f59149dc0000c354707070707074000953616e73536572696671007e004b707e7200346e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e486f72697a6f6e74616c416c69676e456e756d00000000000000001200007871007e001d7400044c4546547070707070707070707371007e004c707371007e00500000c3547070707071007e008071007e008071007e007a707371007e00570000c3547070707071007e008071007e0080707371007e00510000c3547070707071007e008071007e0080707371007e005a0000c3547070707071007e008071007e0080707371007e005c0000c3547070707071007e008071007e0080707070707371007e005e7070707071007e007a70707070707070707070707070707070700000c3540000000000000000707071007e00627371007e00640000000b7571007e0067000000017371007e00690374001573757065727669736f72795f6e6f64655f6e616d65707070707070707070707070707371007e002a0000c3540000001400010000000000000098000001cb000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e004696f153581ae1e4c682939d7efb594d750000c354707070707074000953616e73536572696671007e004b7071007e007e7070707070707070707371007e004c707371007e00500000c3547070707071007e008e71007e008e71007e008b707371007e00570000c3547070707071007e008e71007e008e707371007e00510000c3547070707071007e008e71007e008e707371007e005a0000c3547070707071007e008e71007e008e707371007e005c0000c3547070707071007e008e71007e008e707070707371007e005e7070707071007e008b70707070707070707070707070707070700000c3540000000000000000707071007e00627371007e00640000000c7571007e0067000000017371007e0069037400167265717569736974696f6e5f67726f75705f636f6465707070707070707070707070707371007e002a0000c354000000140001000000000000002300000000000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e0046a3c35f9512886f9f0cb682e445b14bae0000c35470707070707071007e004b707e71007e007d74000643454e5445527070707070707070707371007e004c707371007e00500000c3547070707071007e009d71007e009d71007e0099707371007e00570000c3547070707071007e009d71007e009d707371007e00510000c3547070707071007e009d71007e009d707371007e005a0000c3547070707071007e009d71007e009d707371007e005c0000c3547070707071007e009d71007e009d707070707371007e005e7070707071007e009970707070707070707070707070707070700000c3540000000000000000707071007e00627371007e00640000000d7571007e0067000000017371007e00690474000c5245504f52545f434f554e54707070707070707070707070707371007e002a0000c35400000014000100000000000000ab00000263000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e0046a0075dece13ff4588a4112df39504aa20000c354707070707074000953616e73536572696671007e004b7071007e007e7070707070707070707371007e004c707371007e00500000c3547070707071007e00ab71007e00ab71007e00a8707371007e00570000c3547070707071007e00ab71007e00ab707371007e00510000c3547070707071007e00ab71007e00ab707371007e005a0000c3547070707071007e00ab71007e00ab707371007e005c0000c3547070707071007e00ab71007e00ab707070707371007e005e7070707071007e00a870707070707070707070707070707070700000c3540000000000000000707071007e00627371007e00640000000e7571007e0067000000017371007e0069037400167265717569736974696f6e5f67726f75705f6e616d657070707070707070707070707078700000c35400000014017070707070707400046a617661707372002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173654461746173657400000000000027d802001149001950534555444f5f53455249414c5f56455253494f4e5f5549445a000669734d61696e4200177768656e5265736f757263654d697373696e67547970655b00066669656c64737400265b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a524669656c643b4c001066696c74657245787072657373696f6e71007e00125b000667726f7570737400265b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5247726f75703b4c00046e616d6571007e00025b000a706172616d657465727374002a5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52506172616d657465723b4c000d70726f706572746965734d617071007e00134c000571756572797400254c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5251756572793b4c000e7265736f7572636542756e646c6571007e00024c000e7363726970746c6574436c61737371007e00025b000a7363726970746c65747374002a5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525363726970746c65743b5b000a736f72744669656c647374002a5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52536f72744669656c643b4c00047575696471007e003e5b00097661726961626c65737400295b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525661726961626c653b4c001c7768656e5265736f757263654d697373696e675479706556616c756574003e4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5768656e5265736f757263654d697373696e6754797065456e756d3b78700000c3540100757200265b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a524669656c643b023cdfc74e2af2700200007870000000057372002c6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173654669656c6400000000000027d80200054c000b6465736372697074696f6e71007e00024c00046e616d6571007e00024c000d70726f706572746965734d617071007e00134c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e000278707074000c70726f6772616d5f6e616d657372002b6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5250726f706572746965734d617000000000000027d80200034c00046261736571007e00134c000e70726f706572746965734c69737471007e00174c000d70726f706572746965734d617074000f4c6a6176612f7574696c2f4d61703b78707070707400106a6176612e6c616e672e537472696e67707371007e00c37074001573757065727669736f72795f6e6f64655f636f64657371007e00c67070707400106a6176612e6c616e672e537472696e67707371007e00c37074001573757065727669736f72795f6e6f64655f6e616d657371007e00c67070707400106a6176612e6c616e672e537472696e67707371007e00c3707400167265717569736974696f6e5f67726f75705f636f64657371007e00c67070707400106a6176612e6c616e672e537472696e67707371007e00c3707400167265717569736974696f6e5f67726f75705f6e616d657371007e00c67070707400106a6176612e6c616e672e537472696e677070707400077265706f7274317572002a5b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a52506172616d657465723b22000c8d2ac36021020000787000000013737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365506172616d6574657200000000000027d80200095a000e6973466f7250726f6d7074696e675a000f697353797374656d446566696e65644c001664656661756c7456616c756545787072657373696f6e71007e00124c000b6465736372697074696f6e71007e00024c00046e616d6571007e00024c000e6e6573746564547970654e616d6571007e00024c000d70726f706572746965734d617071007e00134c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e000278700101707074000e5245504f52545f434f4e54455854707371007e00c67070707400296e65742e73662e6a61737065727265706f7274732e656e67696e652e5265706f7274436f6e74657874707371007e00dd010170707400155245504f52545f504152414d45544552535f4d4150707371007e00c670707074000d6a6176612e7574696c2e4d6170707371007e00dd0101707074000d4a41535045525f5245504f5254707371007e00c67070707400286e65742e73662e6a61737065727265706f7274732e656e67696e652e4a61737065725265706f7274707371007e00dd010170707400115245504f52545f434f4e4e454354494f4e707371007e00c67070707400136a6176612e73716c2e436f6e6e656374696f6e707371007e00dd010170707400105245504f52545f4d41585f434f554e54707371007e00c67070707400116a6176612e6c616e672e496e7465676572707371007e00dd010170707400125245504f52545f444154415f534f55524345707371007e00c67070707400286e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5244617461536f75726365707371007e00dd010170707400105245504f52545f5343524950544c4554707371007e00c670707074002f6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5241627374726163745363726970746c6574707371007e00dd0101707074000d5245504f52545f4c4f43414c45707371007e00c67070707400106a6176612e7574696c2e4c6f63616c65707371007e00dd010170707400165245504f52545f5245534f555243455f42554e444c45707371007e00c67070707400186a6176612e7574696c2e5265736f7572636542756e646c65707371007e00dd010170707400105245504f52545f54494d455f5a4f4e45707371007e00c67070707400126a6176612e7574696c2e54696d655a6f6e65707371007e00dd010170707400155245504f52545f464f524d41545f464143544f5259707371007e00c670707074002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e7574696c2e466f726d6174466163746f7279707371007e00dd010170707400135245504f52545f434c4153535f4c4f41444552707371007e00c67070707400156a6176612e6c616e672e436c6173734c6f61646572707371007e00dd0101707074001a5245504f52545f55524c5f48414e444c45525f464143544f5259707371007e00c67070707400206a6176612e6e65742e55524c53747265616d48616e646c6572466163746f7279707371007e00dd010170707400145245504f52545f46494c455f5245534f4c564552707371007e00c670707074002d6e65742e73662e6a61737065727265706f7274732e656e67696e652e7574696c2e46696c655265736f6c766572707371007e00dd010170707400105245504f52545f54454d504c41544553707371007e00c67070707400146a6176612e7574696c2e436f6c6c656374696f6e707371007e00dd0101707074000b534f52545f4649454c4453707371007e00c670707074000e6a6176612e7574696c2e4c697374707371007e00dd0101707074000646494c544552707371007e00c67070707400296e65742e73662e6a61737065727265706f7274732e656e67696e652e4461746173657446696c746572707371007e00dd010170707400125245504f52545f5649525455414c495a4552707371007e00c67070707400296e65742e73662e6a61737065727265706f7274732e656e67696e652e4a525669727475616c697a6572707371007e00dd0101707074001449535f49474e4f52455f504147494e4154494f4e707371007e00c67070707400116a6176612e6c616e672e426f6f6c65616e707371007e00c6707371007e001a0000000377040000000374000c697265706f72742e7a6f6f6d740009697265706f72742e78740009697265706f72742e7978737200116a6176612e7574696c2e486173684d61700507dac1c31660d103000246000a6c6f6164466163746f724900097468726573686f6c6478703f400000000000037708000000040000000371007e012e7400013071007e012c740003312e3071007e012d74000130787372002c6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365517565727900000000000027d80200025b00066368756e6b7374002b5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5251756572794368756e6b3b4c00086c616e677561676571007e000278707572002b5b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5251756572794368756e6b3b409f00a1e8ba34a4020000787000000001737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736551756572794368756e6b00000000000027d8020003420004747970654c00047465787471007e00025b0006746f6b656e737400135b4c6a6176612f6c616e672f537472696e673b787001740a5857495448205245435552534956452073705f6e6f646528736e69642c20736e706172656e7469642920415320280a202020202020202020202020202853454c4543540a2020202020202020202020202069642c0a20202020202020202020202020706172656e7469640a2020202020202020202020202046524f4d2073757065727669736f72795f6e6f646573290a20202020202020202020202020554e494f4e20414c4c202853454c4543540a20202020202020202020202020736e2e69642c0a2020202020202020202020202073706e2e736e706172656e7469640a2020202020202020202020202046524f4d2073757065727669736f72795f6e6f64657320736e0a202020202020202020202020204a4f494e2073705f6e6f64652073706e0a202020202020202020202020204f4e20736e2e706172656e746964203d2073706e2e736e69640a20202020202020202020202020290a20202020202020202020202020292c0a20202020202020202020202020656c696d696e6174652870726f6772616d69642c2073757065726e6f646569642920415320280a2020202020202020202020202053454c4543540a20202020202020202020202020726770732e70726f6772616d69642c0a202020202020202020202020206e6f6465732e73757065726e6f646569640a2020202020202020202020202046524f4d207265717569736974696f6e5f67726f75705f70726f6772616d5f7363686564756c6573207267707320494e4e4552204a4f494e207265717569736974696f6e5f67726f7570732072670a202020202020202020202020204f4e20726770732e7265717569736974696f6e67726f75706964203d2072672e69640a20202020202020202020202020494e4e4552204a4f494e202853454c4543540a20202020202020202020202020736e69642c0a20202020202020202020202020434153450a202020202020202020202020205748454e20736e706172656e746964204953206e756c6c205448454e20736e69640a20202020202020202020202020454c534520736e706172656e74696420454e442041532073757065726e6f646569640a2020202020202020202020202046524f4d2073705f6e6f64650a2020202020202020202020202029204153206e6f6465730a202020202020202020202020204f4e2072672e73757065727669736f72796e6f64656964203d206e6f6465732e736e69640a202020202020202020202020204c454654204a4f494e20726f6c655f61737369676e6d656e74732072610a202020202020202020202020204f4e206e6f6465732e73757065726e6f64656964203d2072612e53555045525649534f52594e4f4445494420414e4420726770732e70726f6772616d6964203d2072612e70726f6772616d69640a202020202020202020202020204c454654204a4f494e20757365727320750a202020202020202020202020204f4e2072612e757365726964203d20752e69640a202020202020202020202020204c454654204a4f494e20726f6c655f7269676874732072720a202020202020202020202020204f4e2072612e726f6c656964203d2072722e726f6c6569640a2020202020202020202020202057484552452072722e72696768746e616d65203d2027415050524f56455f5245515549534954494f4e2720414e4420752e616374697665203d205452554520414e4420752e7665726966696564203d20545255450a20202020202020202020202020290a2020202020202020202020202053454c4543540a2020202020202020202020202044495354494e43540a20202020202020202020202020702e6e616d652041532070726f6772616d5f6e616d652c0a20202020202020202020202020736e2e636f64652061732073757065727669736f72795f6e6f64655f636f64652c0a20202020202020202020202020736e2e6e616d652061732073757065727669736f72795f6e6f64655f6e616d652c0a2020202020202020202020202072672e636f6465204153207265717569736974696f6e5f67726f75705f636f64652c0a2020202020202020202020202072672e6e616d65204153207265717569736974696f6e5f67726f75705f6e616d650a2020202020202020202020202046524f4d207265717569736974696f6e5f67726f75705f70726f6772616d5f7363686564756c6573207267707320494e4e4552204a4f494e207265717569736974696f6e5f67726f7570732072670a202020202020202020202020204f4e20726770732e7265717569736974696f6e67726f75706964203d2072672e69640a20202020202020202020202020494e4e4552204a4f494e202853454c4543540a20202020202020202020202020736e69642c0a20202020202020202020202020434153450a202020202020202020202020205748454e20736e706172656e746964204953206e756c6c205448454e20736e69640a20202020202020202020202020454c534520736e706172656e74696420454e442041532073757065726e6f646569640a2020202020202020202020202046524f4d2073705f6e6f64650a2020202020202020202020202029204153206e6f6465730a202020202020202020202020204f4e2072672e73757065727669736f72796e6f64656964203d206e6f6465732e736e69640a20202020202020202020202020494e4e4552204a4f494e2073757065727669736f72795f6e6f64657320736e0a202020202020202020202020204f4e206e6f6465732e73757065726e6f64656964203d20736e2e69640a202020202020202020202020204c454654204a4f494e20726f6c655f61737369676e6d656e74732072610a202020202020202020202020204f4e206e6f6465732e73757065726e6f64656964203d2072612e53555045525649534f52594e4f4445494420414e4420726770732e70726f6772616d6964203d2072612e70726f6772616d69640a20202020202020202020202020494e4e4552204a4f494e2070726f6772616d7320700a202020202020202020202020204f4e20726770732e70726f6772616d6964203d20702e69640a202020202020202020202020204c454654204a4f494e20726f6c655f7269676874732072720a202020202020202020202020204f4e2072612e726f6c656964203d2072722e726f6c6569640a2020202020202020202020202057484552452028726770732e70726f6772616d6964204e4f5420494e202853454c4543540a2020202020202020202020202070726f6772616d69640a2020202020202020202020202046524f4d20656c696d696e61746529204f52206e6f6465732e73757065726e6f64656964204e4f5420494e202853454c4543540a2020202020202020202020202073757065726e6f646569640a2020202020202020202020202046524f4d20656c696d696e6174650a2020202020202020202020202057484552452070726f6772616d6964203d20726770732e70726f6772616d6964292920616e6420702e616374697665203d207472756520616e6420702e70757368203d2066616c73650a202020202020202020202020206f7264657220627920702e6e616d652c736e2e636f64652c72672e636f64657074000373716c707070707371007e0046b3d554b1aefe96cea0a4e8610726422f757200295b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a525661726961626c653b62e6837c982cb7440200007870000000057372002f6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655661726961626c6500000000000027d802001149001950534555444f5f53455249414c5f56455253494f4e5f55494442000b63616c63756c6174696f6e42000d696e6372656d656e74547970655a000f697353797374656d446566696e65644200097265736574547970654c001063616c63756c6174696f6e56616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f43616c63756c6174696f6e456e756d3b4c000a65787072657373696f6e71007e00124c000e696e6372656d656e7447726f757071007e002b4c0012696e6372656d656e745479706556616c75657400344c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f496e6372656d656e7454797065456e756d3b4c001b696e6372656d656e746572466163746f7279436c6173734e616d6571007e00024c001f696e6372656d656e746572466163746f7279436c6173735265616c4e616d6571007e00024c0016696e697469616c56616c756545787072657373696f6e71007e00124c00046e616d6571007e00024c000a726573657447726f757071007e002b4c000e72657365745479706556616c75657400304c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f526573657454797065456e756d3b4c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e00027870000077ee000001007e7200306e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e43616c63756c6174696f6e456e756d00000000000000001200007871007e001d74000653595354454d70707e7200326e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e496e6372656d656e7454797065456e756d00000000000000001200007871007e001d7400044e4f4e4570707371007e0064000000007571007e0067000000017371007e0069017400186e6577206a6176612e6c616e672e496e7465676572283129707074000b504147455f4e554d424552707e72002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e526573657454797065456e756d00000000000000001200007871007e001d7400065245504f525471007e00f1707371007e0141000077ee0000010071007e0147707071007e014a70707371007e0064000000017571007e0067000000017371007e0069017400186e6577206a6176612e6c616e672e496e7465676572283129707074000d434f4c554d4e5f4e554d424552707e71007e01517400045041474571007e00f1707371007e0141000077ee000001007e71007e0146740005434f554e547371007e0064000000027571007e0067000000017371007e0069017400186e6577206a6176612e6c616e672e496e746567657228312970707071007e014a70707371007e0064000000037571007e0067000000017371007e0069017400186e6577206a6176612e6c616e672e496e7465676572283029707074000c5245504f52545f434f554e547071007e015271007e00f1707371007e0141000077ee0000010071007e015d7371007e0064000000047571007e0067000000017371007e0069017400186e6577206a6176612e6c616e672e496e746567657228312970707071007e014a70707371007e0064000000057571007e0067000000017371007e0069017400186e6577206a6176612e6c616e672e496e7465676572283029707074000a504147455f434f554e547071007e015a71007e00f1707371007e0141000077ee0000010071007e015d7371007e0064000000067571007e0067000000017371007e0069017400186e6577206a6176612e6c616e672e496e746567657228312970707071007e014a70707371007e0064000000077571007e0067000000017371007e0069017400186e6577206a6176612e6c616e672e496e7465676572283029707074000c434f4c554d4e5f434f554e54707e71007e0151740006434f4c554d4e71007e00f1707e72003c6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5768656e5265736f757263654d697373696e6754797065456e756d00000000000000001200007871007e001d7400044e554c4c71007e00da7371007e00117371007e001a0000000277040000000a737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655374617469635465787400000000000027d80200014c00047465787471007e00027871007e002f0000c354000000140001000000000000030e00000000000000207071007e001071007e018170707070707071007e00417070707071007e00447371007e00468769af621a8e549b488f93d8d2fe4df60000c3547070707070707371007e00490000000f7071007e009b7070707070707070707371007e004c707371007e00500000c3547070707071007e018771007e018771007e0184707371007e00570000c3547070707071007e018771007e0187707371007e00510000c3547070707071007e018771007e0187707371007e005a0000c3547070707071007e018771007e0187707371007e005c0000c3547070707071007e018771007e0187707070707371007e005e7070707071007e018470707070707070707070707070707070707400114e6f2070726f626c656d7320666f756e647371007e01830000c354000000200001000000000000030e00000000000000007071007e001071007e018170707070707071007e00417070707071007e00447371007e00469238092a1177a2f66659ba1e006b4f7f0000c354707070707074000953616e7353657269667371007e0049000000187071007e009b7070707070737200116a6176612e6c616e672e426f6f6c65616ecd207280d59cfaee0200015a000576616c75657870017070707371007e004c707371007e00500000c3547070707071007e019571007e019571007e018f707371007e00570000c3547070707071007e019571007e0195707371007e00510000c3547070707071007e019571007e0195707371007e005a0000c3547070707071007e019571007e0195707371007e005c0000c3547070707071007e019571007e0195707070707371007e005e7070707071007e018f707070707070707070707070707070707074003253757065727669736f7279204e6f646573204d697373696e6720417070726f7665205265717569736974696f6e20526f6c6578700000c3540000003401707070707e7200306e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e4f7269656e746174696f6e456e756d00000000000000001200007871007e001d7400094c414e4453434150457371007e00117371007e001a0000000277040000000a7371007e002a0000c3540000001400010000000000000048000002c6000000007071007e001071007e01a070707070707071007e00417070707071007e00447371007e0046a6cd4885e72541551abcd2c71ce14a4b0000c354707070707074000953616e7353657269667371007e00490000000870707070707070707070707371007e004c707371007e00500000c3547070707071007e01a671007e01a671007e01a2707371007e00570000c3547070707071007e01a671007e01a6707371007e00510000c3547070707071007e01a671007e01a6707371007e005a0000c3547070707071007e01a671007e01a6707371007e005c0000c3547070707071007e01a671007e01a6707070707371007e005e7070707071007e01a270707070707070707070707070707070700000c3540000000000000000707071007e00627371007e00640000000f7571007e0067000000017371007e00690474000b504147455f4e554d424552707070707070707070707070707371007e01830000c35400000014000100000000000002c600000000000000007071007e001071007e01a070707070707071007e00417070707071007e00447371007e0046b62f68c26194b7c32e4a2985b90149630000c3547070707070707070707070707070707070707371007e004c707371007e00500000c3547070707071007e01b371007e01b371007e01b1707371007e00570000c3547070707071007e01b371007e01b3707371007e00510000c3547070707071007e01b371007e01b3707371007e005a0000c3547070707071007e01b371007e01b3707371007e005c0000c3547070707071007e01b371007e01b3707070707371007e005e7070707071007e01b170707070707070707070707070707070707400012078700000c3540000001401707070707371007e00117371007e001a0000000677040000000a7371007e01830000c3540000001400010000000000000098000001cb000000007071007e001071007e01bb70707070707071007e00417070707071007e00447371007e00469b596670c74bd785ef159a2f33d942ba0000c354707070707074000953616e73536572696671007e004b707071007e01947070707071007e01947070707371007e004c707371007e00500000c3547070707071007e01c071007e01c071007e01bd707371007e00570000c3547070707071007e01c071007e01c0707371007e00510000c3547070707071007e01c071007e01c0707371007e005a0000c3547070707071007e01c071007e01c0707371007e005c0000c3547070707071007e01c071007e01c0707070707371007e005e7070707071007e01bd70707070707070707070707070707070707400165265717569736974696f6e2047726f757020436f64657371007e01830000c35400000014000100000000000000a200000129000000007071007e001071007e01bb70707070707071007e00417070707071007e00447371007e00469f72d87cd57c5a0d9a07393f55224bce0000c354707070707074000953616e73536572696671007e004b707071007e01947070707071007e01947070707371007e004c707371007e00500000c3547070707071007e01cb71007e01cb71007e01c8707371007e00570000c3547070707071007e01cb71007e01cb707371007e00510000c3547070707071007e01cb71007e01cb707371007e005a0000c3547070707071007e01cb71007e01cb707371007e005c0000c3547070707071007e01cb71007e01cb707070707371007e005e7070707071007e01c8707070707070707070707070707070707074001553757065727669736f7279204e6f6465204e616d657371007e01830000c354000000140001000000000000007400000023000000007071007e001071007e01bb70707070707071007e00417070707071007e00447371007e0046a2a43d5c0bd9170ad949733d046b41aa0000c354707070707074000953616e73536572696671007e004b707071007e01947070707071007e01947070707371007e004c707371007e00500000c3547070707071007e01d671007e01d671007e01d3707371007e00570000c3547070707071007e01d671007e01d6707371007e00510000c3547070707071007e01d671007e01d6707371007e005a0000c3547070707071007e01d671007e01d6707371007e005c0000c3547070707071007e01d671007e01d6707070707371007e005e7070707071007e01d3707070707070707070707070707070707074000c50726f6772616d204e616d657371007e01830000c354000000140001000000000000009200000097000000007071007e001071007e01bb70707070707071007e00417070707071007e00447371007e0046835adf817aa47786a3153510d28746ad0000c354707070707074000953616e73536572696671007e004b707071007e01947070707071007e01947070707371007e004c707371007e00500000c3547070707071007e01e171007e01e171007e01de707371007e00570000c3547070707071007e01e171007e01e1707371007e00510000c3547070707071007e01e171007e01e1707371007e005a0000c3547070707071007e01e171007e01e1707371007e005c0000c3547070707071007e01e171007e01e1707070707371007e005e7070707071007e01de707070707070707070707070707070707074001553757065727669736f7279204e6f646520436f64657371007e01830000c354000000140001000000000000002300000000000000007071007e001071007e01bb70707070707071007e00417070707071007e00447371007e0046b48a4feb4161ed645a7f10ba925c4ca70000c354707070707074000953616e73536572696671007e004b7071007e009b71007e01947070707071007e01947070707371007e004c707371007e00500000c3547070707071007e01ec71007e01ec71007e01e9707371007e00570000c3547070707071007e01ec71007e01ec707371007e00510000c3547070707071007e01ec71007e01ec707371007e005a0000c3547070707071007e01ec71007e01ec707371007e005c0000c3547070707071007e01ec71007e01ec707070707371007e005e7070707071007e01e97070707070707070707070707070707070740004532e4e6f7371007e01830000c35400000014000100000000000000ab00000263000000007071007e001071007e01bb70707070707071007e00417070707071007e00447371007e00469b77f060f22f067181df946c987e46e10000c354707070707074000953616e73536572696671007e004b707071007e01947070707071007e01947070707371007e004c707371007e00500000c3547070707071007e01f771007e01f771007e01f4707371007e00570000c3547070707071007e01f771007e01f7707371007e00510000c3547070707071007e01f771007e01f7707371007e005a0000c3547070707071007e01f771007e01f7707371007e005c0000c3547070707071007e01f771007e01f7707070707371007e005e7070707071007e01f470707070707070707070707070707070707400165265717569736974696f6e2047726f7570204e616d6578700000c354000000140170707071007e001e7e72002f6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5072696e744f72646572456e756d00000000000000001200007871007e001d740008564552544943414c757200265b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a525374796c653bd49cc311d90572350200007870000000087372002c6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655374796c65000000000000271102003a49001950534555444f5f53455249414c5f56455253494f4e5f5549445a0009697344656661756c744c00096261636b636f6c6f7271007e00304c0006626f7264657271007e00144c000b626f72646572436f6c6f7271007e00304c000c626f74746f6d426f7264657271007e00144c0011626f74746f6d426f72646572436f6c6f7271007e00304c000d626f74746f6d50616464696e6771007e00315b0011636f6e646974696f6e616c5374796c65737400315b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52436f6e646974696f6e616c5374796c653b4c001464656661756c745374796c6550726f766964657271007e00394c000466696c6c71007e00144c000966696c6c56616c756574002b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f46696c6c456e756d3b4c0008666f6e744e616d6571007e00024c0008666f6e7453697a6571007e00314c0009666f7265636f6c6f7271007e00304c0013686f72697a6f6e74616c416c69676e6d656e7471007e00144c0018686f72697a6f6e74616c416c69676e6d656e7456616c756571007e00324c000f6973426c616e6b5768656e4e756c6c71007e002e4c00066973426f6c6471007e002e4c000869734974616c696371007e002e4c000d6973506466456d62656464656471007e002e4c000f6973537472696b655468726f75676871007e002e4c000c69735374796c65645465787471007e002e4c000b6973556e6465726c696e6571007e002e4c000a6c656674426f7264657271007e00144c000f6c656674426f72646572436f6c6f7271007e00304c000b6c65667450616464696e6771007e00314c00076c696e65426f7871007e00334c00076c696e6550656e7400234c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250656e3b4c000b6c696e6553706163696e6771007e00144c00106c696e6553706163696e6756616c756571007e00344c00066d61726b757071007e00024c00046d6f646571007e00144c00096d6f646556616c756571007e003a4c00046e616d6571007e00024c000770616464696e6771007e00314c000970617261677261706871007e00354c000b706172656e745374796c6571007e00074c0018706172656e745374796c654e616d655265666572656e636571007e00024c00077061747465726e71007e00024c000b706466456e636f64696e6771007e00024c000b706466466f6e744e616d6571007e00024c000370656e71007e00144c000c706f736974696f6e5479706571007e00144c000672616469757371007e00314c000b7269676874426f7264657271007e00144c00107269676874426f72646572436f6c6f7271007e00304c000c726967687450616464696e6771007e00314c0008726f746174696f6e71007e00144c000d726f746174696f6e56616c756571007e00364c000a7363616c65496d61676571007e00144c000f7363616c65496d61676556616c75657400314c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5363616c65496d616765456e756d3b4c000b737472657463685479706571007e00144c0009746f70426f7264657271007e00144c000e746f70426f72646572436f6c6f7271007e00304c000a746f7050616464696e6771007e00314c0011766572746963616c416c69676e6d656e7471007e00144c0016766572746963616c416c69676e6d656e7456616c756571007e003778700000c35400707070707070707070707070707070707070707070707070707371007e004c707371007e00500000c3547070707071007e020a71007e020a71007e0209707371007e00570000c3547070707071007e020a71007e020a707371007e00510000c3547372000e6a6176612e6177742e436f6c6f7201a51783108f337502000546000666616c70686149000576616c75654c0002637374001b4c6a6176612f6177742f636f6c6f722f436f6c6f7253706163653b5b00096672676276616c75657400025b465b00066676616c756571007e0210787000000000ff00000070707070707372000f6a6176612e6c616e672e466c6f6174daedc9a2db3cf0ec02000146000576616c75657871007e004a3f80000071007e020a71007e020a707371007e005a0000c3547070707071007e020a71007e020a707371007e005c0000c3547070707071007e020a71007e020a7371007e00520000c3547070707071007e020970707070707400057461626c65707371007e005e7070707071007e020970707070707070707070707070707070707070707070707070707371007e02040000c354007371007e020e00000000fff0f8ff7070707070707070707070707070707070707070707070707070707371007e004c707371007e00500000c3547070707071007e021b71007e021b71007e0219707371007e00570000c3547070707071007e021b71007e021b707371007e00510000c3547371007e020e00000000ff00000070707070707371007e02123f00000071007e021b71007e021b707371007e005a0000c3547070707071007e021b71007e021b707371007e005c0000c3547070707071007e021b71007e021b7371007e00520000c3547070707071007e0219707070707e7200296e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e4d6f6465456e756d00000000000000001200007871007e001d7400064f50415155457400087461626c655f5448707371007e005e7070707071007e021970707070707070707070707070707070707070707070707070707371007e02040000c354007371007e020e00000000ffbfe1ff7070707070707070707070707070707070707070707070707070707371007e004c707371007e00500000c3547070707071007e022b71007e022b71007e0229707371007e00570000c3547070707071007e022b71007e022b707371007e00510000c3547371007e020e00000000ff00000070707070707371007e02123f00000071007e022b71007e022b707371007e005a0000c3547070707071007e022b71007e022b707371007e005c0000c3547070707071007e022b71007e022b7371007e00520000c3547070707071007e02297070707071007e02257400087461626c655f4348707371007e005e7070707071007e022970707070707070707070707070707070707070707070707070707371007e02040000c354007371007e020e00000000ffffffff7070707070707070707070707070707070707070707070707070707371007e004c707371007e00500000c3547070707071007e023871007e023871007e0236707371007e00570000c3547070707071007e023871007e0238707371007e00510000c3547371007e020e00000000ff00000070707070707371007e02123f00000071007e023871007e0238707371007e005a0000c3547070707071007e023871007e0238707371007e005c0000c3547070707071007e023871007e02387371007e00520000c3547070707071007e02367070707071007e02257400087461626c655f5444707371007e005e7070707071007e023670707070707070707070707070707070707070707070707070707371007e02040000c35400707070707070707070707070707070707070707070707070707371007e004c707371007e00500000c3547070707071007e024471007e024471007e0243707371007e00570000c3547070707071007e024471007e0244707371007e00510000c3547371007e020e00000000ff00000070707070707371007e02123f80000071007e024471007e0244707371007e005a0000c3547070707071007e024471007e0244707371007e005c0000c3547070707071007e024471007e02447371007e00520000c3547070707071007e024370707070707400077461626c652031707371007e005e7070707071007e024370707070707070707070707070707070707070707070707070707371007e02040000c354007371007e020e00000000fff0f8ff7070707070707070707070707070707070707070707070707070707371007e004c707371007e00500000c3547070707071007e025171007e025171007e024f707371007e00570000c3547070707071007e025171007e0251707371007e00510000c3547371007e020e00000000ff00000070707070707371007e02123f00000071007e025171007e0251707371007e005a0000c3547070707071007e025171007e0251707371007e005c0000c3547070707071007e025171007e02517371007e00520000c3547070707071007e024f7070707071007e022574000a7461626c6520315f5448707371007e005e7070707071007e024f70707070707070707070707070707070707070707070707070707371007e02040000c354007371007e020e00000000ffbfe1ff7070707070707070707070707070707070707070707070707070707371007e004c707371007e00500000c3547070707071007e025e71007e025e71007e025c707371007e00570000c3547070707071007e025e71007e025e707371007e00510000c3547371007e020e00000000ff00000070707070707371007e02123f00000071007e025e71007e025e707371007e005a0000c3547070707071007e025e71007e025e707371007e005c0000c3547070707071007e025e71007e025e7371007e00520000c3547070707071007e025c7070707071007e022574000a7461626c6520315f4348707371007e005e7070707071007e025c70707070707070707070707070707070707070707070707070707371007e02040000c354007371007e020e00000000ffffffff7070707070707070707070707070707070707070707070707070707371007e004c707371007e00500000c3547070707071007e026b71007e026b71007e0269707371007e00570000c3547070707071007e026b71007e026b707371007e00510000c3547371007e020e00000000ff00000070707070707371007e02123f00000071007e026b71007e026b707371007e005a0000c3547070707071007e026b71007e026b707371007e005c0000c3547070707071007e026b71007e026b7371007e00520000c3547070707071007e02697070707071007e022574000a7461626c6520315f5444707371007e005e7070707071007e0269707070707070707070707070707070707070707070707070707070707371007e00117371007e001a0000000277040000000a7371007e01830000c35400000020000100000000000002c600000000000000007071007e001071007e027670707070707071007e00417070707071007e00447371007e00468f61a735ab2074b7212194e972ca43210000c354707070707074000953616e73536572696671007e01927071007e009b707070707071007e01947070707371007e004c707371007e00500000c3547070707071007e027b71007e027b71007e0278707371007e00570000c3547070707071007e027b71007e027b707371007e00510000c3547070707071007e027b71007e027b707371007e005a0000c3547070707071007e027b71007e027b707371007e005c0000c3547070707071007e027b71007e027b707070707371007e005e7070707071007e0278707070707070707070707070707070707074003253757065727669736f7279204e6f646573204d697373696e6720417070726f7665205265717569736974696f6e20526f6c657371007e002a0000c3540000002000010000000000000048000002c6000000007071007e001071007e027670707070707071007e00417070707071007e00447371007e004689ab02f2dda79bb52dd094dce4b543c00000c354707070707074000953616e73536572696671007e01a570707070707070707070707371007e004c707371007e00500000c3547070707071007e028671007e028671007e0283707371007e00570000c3547070707071007e028671007e0286707371007e00510000c3547070707071007e028671007e0286707371007e005a0000c3547070707071007e028671007e0286707371007e005c0000c3547070707071007e028671007e0286707070707371007e005e7070707071007e028370707070707070707070707070707070700000c3540000000000000000707071007e00627371007e0064000000087571007e0067000000017371007e0069017400146e6577206a6176612e7574696c2e446174652829707070707070707070707074000a64642f4d4d2f797979797078700000c3540000002001707070707e7200336e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5768656e4e6f4461746154797065456e756d00000000000000001200007871007e001d74000f4e4f5f444154415f53454354494f4e737200366e65742e73662e6a61737065727265706f7274732e656e67696e652e64657369676e2e4a525265706f7274436f6d70696c654461746100000000000027d80200034c001363726f7373746162436f6d70696c654461746171007e00c74c001264617461736574436f6d70696c654461746171007e00c74c00166d61696e44617461736574436f6d70696c654461746171007e000178707371007e012f3f4000000000000c77080000001000000000787371007e012f3f4000000000000c7708000000100000000078757200025b42acf317f8060854e00200007870000015afcafebabe0000002e00d501001c7265706f7274315f313338303138383036343632375f36323530353407000101002c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a524576616c7561746f72070003010017706172616d657465725f5245504f52545f4c4f43414c450100324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c506172616d657465723b010017706172616d657465725f4a41535045525f5245504f525401001c706172616d657465725f5245504f52545f5649525455414c495a455201001a706172616d657465725f5245504f52545f54494d455f5a4f4e45010015706172616d657465725f534f52545f4649454c445301001e706172616d657465725f5245504f52545f46494c455f5245534f4c56455201001a706172616d657465725f5245504f52545f5343524950544c455401001f706172616d657465725f5245504f52545f504152414d45544552535f4d415001001b706172616d657465725f5245504f52545f434f4e4e454354494f4e010018706172616d657465725f5245504f52545f434f4e5445585401001d706172616d657465725f5245504f52545f434c4153535f4c4f41444552010024706172616d657465725f5245504f52545f55524c5f48414e444c45525f464143544f525901001c706172616d657465725f5245504f52545f444154415f534f5552434501001e706172616d657465725f49535f49474e4f52455f504147494e4154494f4e010010706172616d657465725f46494c54455201001f706172616d657465725f5245504f52545f464f524d41545f464143544f525901001a706172616d657465725f5245504f52545f4d41585f434f554e5401001a706172616d657465725f5245504f52545f54454d504c41544553010020706172616d657465725f5245504f52545f5245534f555243455f42554e444c4501001c6669656c645f7265717569736974696f6e5f67726f75705f636f646501002e4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c4669656c643b01001b6669656c645f73757065727669736f72795f6e6f64655f636f64650100126669656c645f70726f6772616d5f6e616d6501001c6669656c645f7265717569736974696f6e5f67726f75705f6e616d6501001b6669656c645f73757065727669736f72795f6e6f64655f6e616d650100147661726961626c655f504147455f4e554d4245520100314c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c5661726961626c653b0100167661726961626c655f434f4c554d4e5f4e554d4245520100157661726961626c655f5245504f52545f434f554e540100137661726961626c655f504147455f434f554e540100157661726961626c655f434f4c554d4e5f434f554e540100063c696e69743e010003282956010004436f64650c002500260a000400280c00050006090002002a0c00070006090002002c0c00080006090002002e0c0009000609000200300c000a000609000200320c000b000609000200340c000c000609000200360c000d000609000200380c000e0006090002003a0c000f0006090002003c0c00100006090002003e0c0011000609000200400c0012000609000200420c0013000609000200440c0014000609000200460c0015000609000200480c00160006090002004a0c00170006090002004c0c00180006090002004e0c0019001a09000200500c001b001a09000200520c001c001a09000200540c001d001a09000200560c001e001a09000200580c001f0020090002005a0c00210020090002005c0c00220020090002005e0c0023002009000200600c00240020090002006201000f4c696e654e756d6265725461626c6501000e637573746f6d697a6564496e6974010030284c6a6176612f7574696c2f4d61703b4c6a6176612f7574696c2f4d61703b4c6a6176612f7574696c2f4d61703b295601000a696e6974506172616d73010012284c6a6176612f7574696c2f4d61703b29560c006700680a0002006901000a696e69744669656c64730c006b00680a0002006c010008696e6974566172730c006e00680a0002006f01000d5245504f52545f4c4f43414c4508007101000d6a6176612f7574696c2f4d6170070073010003676574010026284c6a6176612f6c616e672f4f626a6563743b294c6a6176612f6c616e672f4f626a6563743b0c007500760b007400770100306e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c506172616d6574657207007901000d4a41535045525f5245504f525408007b0100125245504f52545f5649525455414c495a455208007d0100105245504f52545f54494d455f5a4f4e4508007f01000b534f52545f4649454c44530800810100145245504f52545f46494c455f5245534f4c5645520800830100105245504f52545f5343524950544c45540800850100155245504f52545f504152414d45544552535f4d41500800870100115245504f52545f434f4e4e454354494f4e08008901000e5245504f52545f434f4e5445585408008b0100135245504f52545f434c4153535f4c4f4144455208008d01001a5245504f52545f55524c5f48414e444c45525f464143544f525908008f0100125245504f52545f444154415f534f5552434508009101001449535f49474e4f52455f504147494e4154494f4e08009301000646494c5445520800950100155245504f52545f464f524d41545f464143544f52590800970100105245504f52545f4d41585f434f554e540800990100105245504f52545f54454d504c4154455308009b0100165245504f52545f5245534f555243455f42554e444c4508009d0100167265717569736974696f6e5f67726f75705f636f646508009f01002c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c4669656c640700a101001573757065727669736f72795f6e6f64655f636f64650800a301000c70726f6772616d5f6e616d650800a50100167265717569736974696f6e5f67726f75705f6e616d650800a701001573757065727669736f72795f6e6f64655f6e616d650800a901000b504147455f4e554d4245520800ab01002f6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c5661726961626c650700ad01000d434f4c554d4e5f4e554d4245520800af01000c5245504f52545f434f554e540800b101000a504147455f434f554e540800b301000c434f4c554d4e5f434f554e540800b50100086576616c756174650100152849294c6a6176612f6c616e672f4f626a6563743b01000a457863657074696f6e730100136a6176612f6c616e672f5468726f7761626c650700ba0100116a6176612f6c616e672f496e74656765720700bc010004284929560c002500be0a00bd00bf01000e6a6176612f7574696c2f446174650700c10a00c2002801000867657456616c756501001428294c6a6176612f6c616e672f4f626a6563743b0c00c400c50a00a200c60100106a6176612f6c616e672f537472696e670700c80a00ae00c601000b6576616c756174654f6c6401000b6765744f6c6456616c75650c00cc00c50a00a200cd0a00ae00cd0100116576616c75617465457374696d61746564010011676574457374696d6174656456616c75650c00d100c50a00ae00d201000a536f7572636546696c650021000200040000001d00020005000600000002000700060000000200080006000000020009000600000002000a000600000002000b000600000002000c000600000002000d000600000002000e000600000002000f0006000000020010000600000002001100060000000200120006000000020013000600000002001400060000000200150006000000020016000600000002001700060000000200180006000000020019001a00000002001b001a00000002001c001a00000002001d001a00000002001e001a00000002001f0020000000020021002000000002002200200000000200230020000000020024002000000008000100250026000100270000012600020001000000962ab700292a01b5002b2a01b5002d2a01b5002f2a01b500312a01b500332a01b500352a01b500372a01b500392a01b5003b2a01b5003d2a01b5003f2a01b500412a01b500432a01b500452a01b500472a01b500492a01b5004b2a01b5004d2a01b5004f2a01b500512a01b500532a01b500552a01b500572a01b500592a01b5005b2a01b5005d2a01b5005f2a01b500612a01b50063b10000000100640000007e001f00000012000400190009001a000e001b0013001c0018001d001d001e0022001f00270020002c00210031002200360023003b00240040002500450026004a0027004f0028005400290059002a005e002b0063002c0068002d006d002e0072002f00770030007c00310081003200860033008b00340090003500950012000100650066000100270000003400020004000000102a2bb7006a2a2cb7006d2a2db70070b10000000100640000001200040000004100050042000a0043000f004400020067006800010027000001bb00030002000001572a2b1272b900780200c0007ac0007ab5002b2a2b127cb900780200c0007ac0007ab5002d2a2b127eb900780200c0007ac0007ab5002f2a2b1280b900780200c0007ac0007ab500312a2b1282b900780200c0007ac0007ab500332a2b1284b900780200c0007ac0007ab500352a2b1286b900780200c0007ac0007ab500372a2b1288b900780200c0007ac0007ab500392a2b128ab900780200c0007ac0007ab5003b2a2b128cb900780200c0007ac0007ab5003d2a2b128eb900780200c0007ac0007ab5003f2a2b1290b900780200c0007ac0007ab500412a2b1292b900780200c0007ac0007ab500432a2b1294b900780200c0007ac0007ab500452a2b1296b900780200c0007ac0007ab500472a2b1298b900780200c0007ac0007ab500492a2b129ab900780200c0007ac0007ab5004b2a2b129cb900780200c0007ac0007ab5004d2a2b129eb900780200c0007ac0007ab5004fb10000000100640000005200140000004c0012004d0024004e0036004f00480050005a0051006c0052007e00530090005400a2005500b4005600c6005700d8005800ea005900fc005a010e005b0120005c0132005d0144005e0156005f0002006b00680001002700000087000300020000005b2a2b12a0b900780200c000a2c000a2b500512a2b12a4b900780200c000a2c000a2b500532a2b12a6b900780200c000a2c000a2b500552a2b12a8b900780200c000a2c000a2b500572a2b12aab900780200c000a2c000a2b50059b10000000100640000001a00060000006700120068002400690036006a0048006b005a006c0002006e00680001002700000087000300020000005b2a2b12acb900780200c000aec000aeb5005b2a2b12b0b900780200c000aec000aeb5005d2a2b12b2b900780200c000aec000aeb5005f2a2b12b4b900780200c000aec000aeb500612a2b12b6b900780200c000aec000aeb50063b10000000100640000001a00060000007400120075002400760036007700480078005a0079000100b700b8000200b900000004000100bb0027000001b8000300030000011c014d1baa00000117000000000000000f0000004d0000005900000065000000710000007d0000008900000095000000a1000000ad000000b8000000c6000000d4000000e2000000f0000000fe0000010cbb00bd5904b700c04da700c1bb00bd5904b700c04da700b5bb00bd5904b700c04da700a9bb00bd5903b700c04da7009dbb00bd5904b700c04da70091bb00bd5903b700c04da70085bb00bd5904b700c04da70079bb00bd5903b700c04da7006dbb00c259b700c34da700622ab40055b600c7c000c94da700542ab40053b600c7c000c94da700462ab40059b600c7c000c94da700382ab40051b600c7c000c94da7002a2ab4005fb600cac000bd4da7001c2ab40057b600c7c000c94da7000e2ab4005bb600cac000bd4d2cb00000000100640000008a002200000081000200830050008700590088005c008c0065008d006800910071009200740096007d00970080009b0089009c008c00a0009500a1009800a500a100a600a400aa00ad00ab00b000af00b800b000bb00b400c600b500c900b900d400ba00d700be00e200bf00e500c300f000c400f300c800fe00c9010100cd010c00ce010f00d2011a00da000100cb00b8000200b900000004000100bb0027000001b8000300030000011c014d1baa00000117000000000000000f0000004d0000005900000065000000710000007d0000008900000095000000a1000000ad000000b8000000c6000000d4000000e2000000f0000000fe0000010cbb00bd5904b700c04da700c1bb00bd5904b700c04da700b5bb00bd5904b700c04da700a9bb00bd5903b700c04da7009dbb00bd5904b700c04da70091bb00bd5903b700c04da70085bb00bd5904b700c04da70079bb00bd5903b700c04da7006dbb00c259b700c34da700622ab40055b600cec000c94da700542ab40053b600cec000c94da700462ab40059b600cec000c94da700382ab40051b600cec000c94da7002a2ab4005fb600cfc000bd4da7001c2ab40057b600cec000c94da7000e2ab4005bb600cfc000bd4d2cb00000000100640000008a0022000000e3000200e5005000e9005900ea005c00ee006500ef006800f3007100f4007400f8007d00f9008000fd008900fe008c0102009501030098010700a1010800a4010c00ad010d00b0011100b8011200bb011600c6011700c9011b00d4011c00d7012000e2012100e5012500f0012600f3012a00fe012b0101012f010c0130010f0134011a013c000100d000b8000200b900000004000100bb0027000001b8000300030000011c014d1baa00000117000000000000000f0000004d0000005900000065000000710000007d0000008900000095000000a1000000ad000000b8000000c6000000d4000000e2000000f0000000fe0000010cbb00bd5904b700c04da700c1bb00bd5904b700c04da700b5bb00bd5904b700c04da700a9bb00bd5903b700c04da7009dbb00bd5904b700c04da70091bb00bd5903b700c04da70085bb00bd5904b700c04da70079bb00bd5903b700c04da7006dbb00c259b700c34da700622ab40055b600c7c000c94da700542ab40053b600c7c000c94da700462ab40059b600c7c000c94da700382ab40051b600c7c000c94da7002a2ab4005fb600d3c000bd4da7001c2ab40057b600c7c000c94da7000e2ab4005bb600d3c000bd4d2cb00000000100640000008a002200000145000201470050014b0059014c005c01500065015100680155007101560074015a007d015b0080015f00890160008c0164009501650098016900a1016a00a4016e00ad016f00b0017300b8017400bb017800c6017900c9017d00d4017e00d7018200e2018300e5018700f0018800f3018c00fe018d01010191010c0192010f0196011a019e000100d40000000200017400155f313338303138383036343632375f3632353035347400326e65742e73662e6a61737065727265706f7274732e656e67696e652e64657369676e2e4a524a61766163436f6d70696c6572	\N	2014-10-27 12:28:16.541267	Consistency Report	\N
7	Requisition Groups Missing Supply Line	\\xaced0005737200286e65742e73662e6a61737065727265706f7274732e656e67696e652e4a61737065725265706f727400000000000027d80200034c000b636f6d70696c65446174617400164c6a6176612f696f2f53657269616c697a61626c653b4c0011636f6d70696c654e616d655375666669787400124c6a6176612f6c616e672f537472696e673b4c000d636f6d70696c6572436c61737371007e00027872002d6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655265706f727400000000000027d802002a49001950534555444f5f53455249414c5f56455253494f4e5f55494449000c626f74746f6d4d617267696e49000b636f6c756d6e436f756e7449000d636f6c756d6e53706163696e6749000b636f6c756d6e57696474685a001069676e6f7265506167696e6174696f6e5a00136973466c6f6174436f6c756d6e466f6f7465725a0010697353756d6d6172794e6577506167655a0020697353756d6d6172795769746850616765486561646572416e64466f6f7465725a000e69735469746c654e65775061676549000a6c6566744d617267696e42000b6f7269656e746174696f6e49000a7061676548656967687449000970616765576964746842000a7072696e744f7264657249000b72696768744d617267696e490009746f704d617267696e42000e7768656e4e6f44617461547970654c000a6261636b67726f756e647400244c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5242616e643b4c000f636f6c756d6e446972656374696f6e7400334c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f52756e446972656374696f6e456e756d3b4c000c636f6c756d6e466f6f74657271007e00044c000c636f6c756d6e48656164657271007e00045b000864617461736574737400285b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52446174617365743b4c000c64656661756c745374796c657400254c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525374796c653b4c000664657461696c71007e00044c000d64657461696c53656374696f6e7400274c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5253656374696f6e3b4c0012666f726d6174466163746f7279436c61737371007e00024c000a696d706f72747353657474000f4c6a6176612f7574696c2f5365743b4c00086c616e677561676571007e00024c000e6c61737450616765466f6f74657271007e00044c000b6d61696e446174617365747400274c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52446174617365743b4c00046e616d6571007e00024c00066e6f4461746171007e00044c00106f7269656e746174696f6e56616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4f7269656e746174696f6e456e756d3b4c000a70616765466f6f74657271007e00044c000a7061676548656164657271007e00044c000f7072696e744f7264657256616c75657400314c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5072696e744f72646572456e756d3b5b00067374796c65737400265b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525374796c653b4c000773756d6d61727971007e00045b000974656d706c6174657374002f5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525265706f727454656d706c6174653b4c00057469746c6571007e00044c00137768656e4e6f446174615479706556616c75657400354c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5768656e4e6f4461746154797065456e756d3b78700000c3540000000000000001000000000000030e000100000000000000000000022b0000030e000000000000000000007372002b6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736542616e6400000000000027d802000749001950534555444f5f53455249414c5f56455253494f4e5f5549444900066865696768745a000e697353706c6974416c6c6f7765644c00137072696e745768656e45787072657373696f6e74002a4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5245787072657373696f6e3b4c000d70726f706572746965734d617074002d4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250726f706572746965734d61703b4c000973706c6974547970657400104c6a6176612f6c616e672f427974653b4c000e73706c69745479706556616c75657400304c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f53706c697454797065456e756d3b787200336e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365456c656d656e7447726f757000000000000027d80200024c00086368696c6472656e7400104c6a6176612f7574696c2f4c6973743b4c000c656c656d656e7447726f757074002c4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52456c656d656e7447726f75703b7870737200136a6176612e7574696c2e41727261794c6973747881d21d99c7619d03000149000473697a6578700000000077040000000a78700000c35400000000017070707e72002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e53706c697454797065456e756d00000000000000001200007872000e6a6176612e6c616e672e456e756d00000000000000001200007870740007535452455443487e7200316e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e52756e446972656374696f6e456e756d00000000000000001200007871007e001d7400034c545270707070707372002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736553656374696f6e00000000000027d80200015b000562616e64737400255b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5242616e643b7870757200255b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5242616e643b95dd7eec8cca85350200007870000000017371007e00117371007e001a0000000477040000000a737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365546578744669656c6400000000000027d802001549001950534555444f5f53455249414c5f56455253494f4e5f55494449000d626f6f6b6d61726b4c6576656c42000e6576616c756174696f6e54696d6542000f68797065726c696e6b54617267657442000d68797065726c696e6b547970655a0015697353747265746368576974684f766572666c6f774c0014616e63686f724e616d6545787072657373696f6e71007e00124c000f6576616c756174696f6e47726f75707400254c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5247726f75703b4c00136576616c756174696f6e54696d6556616c75657400354c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4576616c756174696f6e54696d65456e756d3b4c000a65787072657373696f6e71007e00124c001968797065726c696e6b416e63686f7245787072657373696f6e71007e00124c001768797065726c696e6b5061676545787072657373696f6e71007e00125b001368797065726c696e6b506172616d65746572737400335b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5248797065726c696e6b506172616d657465723b4c001c68797065726c696e6b5265666572656e636545787072657373696f6e71007e00124c001a68797065726c696e6b546f6f6c74697045787072657373696f6e71007e00124c001768797065726c696e6b5768656e45787072657373696f6e71007e00124c000f6973426c616e6b5768656e4e756c6c7400134c6a6176612f6c616e672f426f6f6c65616e3b4c000a6c696e6b54617267657471007e00024c00086c696e6b5479706571007e00024c00077061747465726e71007e00024c00117061747465726e45787072657373696f6e71007e0012787200326e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736554657874456c656d656e7400000000000027d802002549001950534555444f5f53455249414c5f56455253494f4e5f5549444c0006626f7264657271007e00144c000b626f72646572436f6c6f727400104c6a6176612f6177742f436f6c6f723b4c000c626f74746f6d426f7264657271007e00144c0011626f74746f6d426f72646572436f6c6f7271007e00304c000d626f74746f6d50616464696e677400134c6a6176612f6c616e672f496e74656765723b4c0008666f6e744e616d6571007e00024c0008666f6e7453697a6571007e00314c0013686f72697a6f6e74616c416c69676e6d656e7471007e00144c0018686f72697a6f6e74616c416c69676e6d656e7456616c75657400364c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f486f72697a6f6e74616c416c69676e456e756d3b4c00066973426f6c6471007e002e4c000869734974616c696371007e002e4c000d6973506466456d62656464656471007e002e4c000f6973537472696b655468726f75676871007e002e4c000c69735374796c65645465787471007e002e4c000b6973556e6465726c696e6571007e002e4c000a6c656674426f7264657271007e00144c000f6c656674426f72646572436f6c6f7271007e00304c000b6c65667450616464696e6771007e00314c00076c696e65426f787400274c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a524c696e65426f783b4c000b6c696e6553706163696e6771007e00144c00106c696e6553706163696e6756616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4c696e6553706163696e67456e756d3b4c00066d61726b757071007e00024c000770616464696e6771007e00314c00097061726167726170687400294c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525061726167726170683b4c000b706466456e636f64696e6771007e00024c000b706466466f6e744e616d6571007e00024c000b7269676874426f7264657271007e00144c00107269676874426f72646572436f6c6f7271007e00304c000c726967687450616464696e6771007e00314c0008726f746174696f6e71007e00144c000d726f746174696f6e56616c756574002f4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f526f746174696f6e456e756d3b4c0009746f70426f7264657271007e00144c000e746f70426f72646572436f6c6f7271007e00304c000a746f7050616464696e6771007e00314c0011766572746963616c416c69676e6d656e7471007e00144c0016766572746963616c416c69676e6d656e7456616c75657400344c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f566572746963616c416c69676e456e756d3b7872002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365456c656d656e7400000000000027d802001b49001950534555444f5f53455249414c5f56455253494f4e5f5549444900066865696768745a001769735072696e74496e466972737457686f6c6542616e645a001569735072696e74526570656174656456616c7565735a001a69735072696e745768656e44657461696c4f766572666c6f77735a0015697352656d6f76654c696e655768656e426c616e6b42000c706f736974696f6e5479706542000b7374726574636854797065490005776964746849000178490001794c00096261636b636f6c6f7271007e00304c001464656661756c745374796c6550726f76696465727400344c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5244656661756c745374796c6550726f76696465723b4c000c656c656d656e7447726f757071007e00184c0009666f7265636f6c6f7271007e00304c00036b657971007e00024c00046d6f646571007e00144c00096d6f646556616c756574002b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4d6f6465456e756d3b4c000b706172656e745374796c6571007e00074c0018706172656e745374796c654e616d655265666572656e636571007e00024c0011706f736974696f6e5479706556616c75657400334c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f506f736974696f6e54797065456e756d3b4c00137072696e745768656e45787072657373696f6e71007e00124c00157072696e745768656e47726f75704368616e67657371007e002b4c000d70726f706572746965734d617071007e00135b001370726f706572747945787072657373696f6e737400335b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250726f706572747945787072657373696f6e3b4c0010737472657463685479706556616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5374726574636854797065456e756d3b4c0004757569647400104c6a6176612f7574696c2f555549443b78700000c35400000014000100000000000000e800000052000000007071007e001071007e00287070707070707e7200316e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e506f736974696f6e54797065456e756d00000000000000001200007871007e001d7400134649585f52454c41544956455f544f5f544f50707070707e7200306e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5374726574636854797065456e756d00000000000000001200007871007e001d74000a4e4f5f535452455443487372000e6a6176612e7574696c2e55554944bc9903f7986d852f0200024a000c6c65617374536967426974734a000b6d6f7374536967426974737870a9d9fbfb06612a8f3d8316284452410d0000c354707070707074000953616e735365726966737200116a6176612e6c616e672e496e746567657212e2a0a4f781873802000149000576616c7565787200106a6176612e6c616e672e4e756d62657286ac951d0b94e08b02000078700000000c70707070707070707070707372002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173654c696e65426f7800000000000027d802000b4c000d626f74746f6d50616464696e6771007e00314c0009626f74746f6d50656e74002b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f626173652f4a52426f7850656e3b4c000c626f78436f6e7461696e657274002c4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52426f78436f6e7461696e65723b4c000b6c65667450616464696e6771007e00314c00076c65667450656e71007e004d4c000770616464696e6771007e00314c000370656e71007e004d4c000c726967687450616464696e6771007e00314c0008726967687450656e71007e004d4c000a746f7050616464696e6771007e00314c0006746f7050656e71007e004d787070737200336e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f78426f74746f6d50656e00000000000027d80200007872002d6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f7850656e00000000000027d80200014c00076c696e65426f7871007e00337872002a6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736550656e00000000000027d802000649001950534555444f5f53455249414c5f56455253494f4e5f5549444c00096c696e65436f6c6f7271007e00304c00096c696e655374796c6571007e00144c000e6c696e655374796c6556616c75657400304c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4c696e655374796c65456e756d3b4c00096c696e6557696474687400114c6a6176612f6c616e672f466c6f61743b4c000c70656e436f6e7461696e657274002c4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250656e436f6e7461696e65723b78700000c3547070707071007e004f71007e004f71007e003f70737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f784c65667450656e00000000000027d80200007871007e00510000c3547070707071007e004f71007e004f707371007e00510000c3547070707071007e004f71007e004f70737200326e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f78526967687450656e00000000000027d80200007871007e00510000c3547070707071007e004f71007e004f70737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f78546f7050656e00000000000027d80200007871007e00510000c3547070707071007e004f71007e004f70707070737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736550617261677261706800000000000027d802000a4c000f66697273744c696e65496e64656e7471007e00314c000a6c656674496e64656e7471007e00314c000b6c696e6553706163696e6771007e00344c000f6c696e6553706163696e6753697a6571007e00544c0012706172616772617068436f6e7461696e65727400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52506172616772617068436f6e7461696e65723b4c000b7269676874496e64656e7471007e00314c000c73706163696e67416674657271007e00314c000d73706163696e674265666f726571007e00314c000c74616253746f70576964746871007e00314c000874616253746f707371007e001778707070707071007e003f70707070707070707070707070707070700000c354000000000000000070707e7200336e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e4576616c756174696f6e54696d65456e756d00000000000000001200007871007e001d7400034e4f57737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736545787072657373696f6e00000000000027d802000449000269645b00066368756e6b737400305b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5245787072657373696f6e4368756e6b3b4c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e0002787000000009757200305b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5245787072657373696f6e4368756e6b3b6d59cfde694ba355020000787000000001737200366e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736545787072657373696f6e4368756e6b00000000000027d8020002420004747970654c00047465787471007e0002787003740005734e6f6465707070707070707070707070707371007e002a0000c35400000014000100000000000000c70000013a000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e0046980c6e20451ed89f70a35c82b9a34c1e0000c354707070707074000953616e73536572696671007e004b70707070707070707070707371007e004c707371007e00500000c3547070707071007e006f71007e006f71007e006c707371007e00570000c3547070707071007e006f71007e006f707371007e00510000c3547070707071007e006f71007e006f707371007e005a0000c3547070707071007e006f71007e006f707371007e005c0000c3547070707071007e006f71007e006f707070707371007e005e7070707071007e006c70707070707070707070707070707070700000c3540000000000000000707071007e00627371007e00640000000a7571007e0067000000017371007e0069037400046e616d65707070707070707070707070707371007e002a0000c354000000140001000000000000010d00000201000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e00468cdc613a1d372dff871fa864f59149dc0000c354707070707074000953616e73536572696671007e004b707e7200346e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e486f72697a6f6e74616c416c69676e456e756d00000000000000001200007871007e001d7400044c4546547070707070707070707371007e004c707371007e00500000c3547070707071007e008071007e008071007e007a707371007e00570000c3547070707071007e008071007e0080707371007e00510000c3547070707071007e008071007e0080707371007e005a0000c3547070707071007e008071007e0080707371007e005c0000c3547070707071007e008071007e0080707070707371007e005e7070707071007e007a70707070707070707070707070707070700000c3540000000000000000707071007e00627371007e00640000000b7571007e0067000000017371007e0069037400107265717569736974696f6e67726f7570707070707070707070707070707371007e002a0000c354000000140001000000000000005200000000000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e0046a3c35f9512886f9f0cb682e445b14bae0000c35470707070707071007e004b707e71007e007d74000643454e5445527070707070707070707371007e004c707371007e00500000c3547070707071007e008f71007e008f71007e008b707371007e00570000c3547070707071007e008f71007e008f707371007e00510000c3547070707071007e008f71007e008f707371007e005a0000c3547070707071007e008f71007e008f707371007e005c0000c3547070707071007e008f71007e008f707070707371007e005e7070707071007e008b70707070707070707070707070707070700000c3540000000000000000707071007e00627371007e00640000000c7571007e0067000000017371007e00690474000c5245504f52545f434f554e547070707070707070707070707078700000c35400000014017070707070707400046a617661707372002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173654461746173657400000000000027d802001149001950534555444f5f53455249414c5f56455253494f4e5f5549445a000669734d61696e4200177768656e5265736f757263654d697373696e67547970655b00066669656c64737400265b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a524669656c643b4c001066696c74657245787072657373696f6e71007e00125b000667726f7570737400265b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5247726f75703b4c00046e616d6571007e00025b000a706172616d657465727374002a5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52506172616d657465723b4c000d70726f706572746965734d617071007e00134c000571756572797400254c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5251756572793b4c000e7265736f7572636542756e646c6571007e00024c000e7363726970746c6574436c61737371007e00025b000a7363726970746c65747374002a5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525363726970746c65743b5b000a736f72744669656c647374002a5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52536f72744669656c643b4c00047575696471007e003e5b00097661726961626c65737400295b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525661726961626c653b4c001c7768656e5265736f757263654d697373696e675479706556616c756574003e4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5768656e5265736f757263654d697373696e6754797065456e756d3b78700000c3540100757200265b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a524669656c643b023cdfc74e2af2700200007870000000037372002c6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173654669656c6400000000000027d80200054c000b6465736372697074696f6e71007e00024c00046e616d6571007e00024c000d70726f706572746965734d617071007e00134c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e0002787070740005734e6f64657372002b6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5250726f706572746965734d617000000000000027d80200034c00046261736571007e00134c000e70726f706572746965734c69737471007e00174c000d70726f706572746965734d617074000f4c6a6176612f7574696c2f4d61703b78707070707400106a6176612e6c616e672e537472696e67707371007e00a7707400046e616d657371007e00aa7070707400106a6176612e6c616e672e537472696e67707371007e00a7707400107265717569736974696f6e67726f75707371007e00aa7070707400106a6176612e6c616e672e537472696e677070707400077265706f7274317572002a5b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a52506172616d657465723b22000c8d2ac36021020000787000000013737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365506172616d6574657200000000000027d80200095a000e6973466f7250726f6d7074696e675a000f697353797374656d446566696e65644c001664656661756c7456616c756545787072657373696f6e71007e00124c000b6465736372697074696f6e71007e00024c00046e616d6571007e00024c000e6e6573746564547970654e616d6571007e00024c000d70726f706572746965734d617071007e00134c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e000278700101707074000e5245504f52545f434f4e54455854707371007e00aa7070707400296e65742e73662e6a61737065727265706f7274732e656e67696e652e5265706f7274436f6e74657874707371007e00b9010170707400155245504f52545f504152414d45544552535f4d4150707371007e00aa70707074000d6a6176612e7574696c2e4d6170707371007e00b90101707074000d4a41535045525f5245504f5254707371007e00aa7070707400286e65742e73662e6a61737065727265706f7274732e656e67696e652e4a61737065725265706f7274707371007e00b9010170707400115245504f52545f434f4e4e454354494f4e707371007e00aa7070707400136a6176612e73716c2e436f6e6e656374696f6e707371007e00b9010170707400105245504f52545f4d41585f434f554e54707371007e00aa7070707400116a6176612e6c616e672e496e7465676572707371007e00b9010170707400125245504f52545f444154415f534f55524345707371007e00aa7070707400286e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5244617461536f75726365707371007e00b9010170707400105245504f52545f5343524950544c4554707371007e00aa70707074002f6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5241627374726163745363726970746c6574707371007e00b90101707074000d5245504f52545f4c4f43414c45707371007e00aa7070707400106a6176612e7574696c2e4c6f63616c65707371007e00b9010170707400165245504f52545f5245534f555243455f42554e444c45707371007e00aa7070707400186a6176612e7574696c2e5265736f7572636542756e646c65707371007e00b9010170707400105245504f52545f54494d455f5a4f4e45707371007e00aa7070707400126a6176612e7574696c2e54696d655a6f6e65707371007e00b9010170707400155245504f52545f464f524d41545f464143544f5259707371007e00aa70707074002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e7574696c2e466f726d6174466163746f7279707371007e00b9010170707400135245504f52545f434c4153535f4c4f41444552707371007e00aa7070707400156a6176612e6c616e672e436c6173734c6f61646572707371007e00b90101707074001a5245504f52545f55524c5f48414e444c45525f464143544f5259707371007e00aa7070707400206a6176612e6e65742e55524c53747265616d48616e646c6572466163746f7279707371007e00b9010170707400145245504f52545f46494c455f5245534f4c564552707371007e00aa70707074002d6e65742e73662e6a61737065727265706f7274732e656e67696e652e7574696c2e46696c655265736f6c766572707371007e00b9010170707400105245504f52545f54454d504c41544553707371007e00aa7070707400146a6176612e7574696c2e436f6c6c656374696f6e707371007e00b90101707074000b534f52545f4649454c4453707371007e00aa70707074000e6a6176612e7574696c2e4c697374707371007e00b90101707074000646494c544552707371007e00aa7070707400296e65742e73662e6a61737065727265706f7274732e656e67696e652e4461746173657446696c746572707371007e00b9010170707400125245504f52545f5649525455414c495a4552707371007e00aa7070707400296e65742e73662e6a61737065727265706f7274732e656e67696e652e4a525669727475616c697a6572707371007e00b90101707074001449535f49474e4f52455f504147494e4154494f4e707371007e00aa7070707400116a6176612e6c616e672e426f6f6c65616e707371007e00aa707371007e001a0000000377040000000374000c697265706f72742e7a6f6f6d740009697265706f72742e78740009697265706f72742e7978737200116a6176612e7574696c2e486173684d61700507dac1c31660d103000246000a6c6f6164466163746f724900097468726573686f6c6478703f400000000000037708000000040000000371007e010a7400013071007e0108740003312e3071007e010974000130787372002c6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365517565727900000000000027d80200025b00066368756e6b7374002b5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5251756572794368756e6b3b4c00086c616e677561676571007e000278707572002b5b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5251756572794368756e6b3b409f00a1e8ba34a4020000787000000001737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736551756572794368756e6b00000000000027d8020003420004747970654c00047465787471007e00025b0006746f6b656e737400135b4c6a6176612f6c616e672f537472696e673b78700174002673656c656374202a2066726f6d20676574524750726f6772616d537570706c794c696e6528297074000373716c707070707371007e0046b3d554b1aefe96cea0a4e8610726422f757200295b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a525661726961626c653b62e6837c982cb7440200007870000000057372002f6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655661726961626c6500000000000027d802001149001950534555444f5f53455249414c5f56455253494f4e5f55494442000b63616c63756c6174696f6e42000d696e6372656d656e74547970655a000f697353797374656d446566696e65644200097265736574547970654c001063616c63756c6174696f6e56616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f43616c63756c6174696f6e456e756d3b4c000a65787072657373696f6e71007e00124c000e696e6372656d656e7447726f757071007e002b4c0012696e6372656d656e745479706556616c75657400344c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f496e6372656d656e7454797065456e756d3b4c001b696e6372656d656e746572466163746f7279436c6173734e616d6571007e00024c001f696e6372656d656e746572466163746f7279436c6173735265616c4e616d6571007e00024c0016696e697469616c56616c756545787072657373696f6e71007e00124c00046e616d6571007e00024c000a726573657447726f757071007e002b4c000e72657365745479706556616c75657400304c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f526573657454797065456e756d3b4c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e00027870000077ee000001007e7200306e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e43616c63756c6174696f6e456e756d00000000000000001200007871007e001d74000653595354454d70707e7200326e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e496e6372656d656e7454797065456e756d00000000000000001200007871007e001d7400044e4f4e4570707371007e0064000000007571007e0067000000017371007e0069017400186e6577206a6176612e6c616e672e496e7465676572283129707074000b504147455f4e554d424552707e72002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e526573657454797065456e756d00000000000000001200007871007e001d7400065245504f525471007e00cd707371007e011d000077ee0000010071007e0123707071007e012670707371007e0064000000017571007e0067000000017371007e0069017400186e6577206a6176612e6c616e672e496e7465676572283129707074000d434f4c554d4e5f4e554d424552707e71007e012d7400045041474571007e00cd707371007e011d000077ee000001007e71007e0122740005434f554e547371007e0064000000027571007e0067000000017371007e0069017400186e6577206a6176612e6c616e672e496e746567657228312970707071007e012670707371007e0064000000037571007e0067000000017371007e0069017400186e6577206a6176612e6c616e672e496e7465676572283029707074000c5245504f52545f434f554e547071007e012e71007e00cd707371007e011d000077ee0000010071007e01397371007e0064000000047571007e0067000000017371007e0069017400186e6577206a6176612e6c616e672e496e746567657228312970707071007e012670707371007e0064000000057571007e0067000000017371007e0069017400186e6577206a6176612e6c616e672e496e7465676572283029707074000a504147455f434f554e547071007e013671007e00cd707371007e011d000077ee0000010071007e01397371007e0064000000067571007e0067000000017371007e0069017400186e6577206a6176612e6c616e672e496e746567657228312970707071007e012670707371007e0064000000077571007e0067000000017371007e0069017400186e6577206a6176612e6c616e672e496e7465676572283029707074000c434f4c554d4e5f434f554e54707e71007e012d740006434f4c554d4e71007e00cd707e72003c6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5768656e5265736f757263654d697373696e6754797065456e756d00000000000000001200007871007e001d7400044e554c4c71007e00b67371007e00117371007e001a0000000277040000000a737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655374617469635465787400000000000027d80200014c00047465787471007e00027871007e002f0000c354000000140001000000000000030e00000000000000207071007e001071007e015d70707070707071007e00417070707071007e00447371007e00468769af621a8e549b488f93d8d2fe4df60000c3547070707070707371007e00490000000f7071007e008d7070707070707070707371007e004c707371007e00500000c3547070707071007e016371007e016371007e0160707371007e00570000c3547070707071007e016371007e0163707371007e00510000c3547070707071007e016371007e0163707371007e005a0000c3547070707071007e016371007e0163707371007e005c0000c3547070707071007e016371007e0163707070707371007e005e7070707071007e016070707070707070707070707070707070707400114e6f2070726f626c656d7320666f756e647371007e015f0000c354000000200001000000000000030e00000000000000007071007e001071007e015d70707070707071007e00417070707071007e00447371007e00469238092a1177a2f66659ba1e006b4f7f0000c354707070707074000953616e7353657269667371007e0049000000187071007e008d7070707070737200116a6176612e6c616e672e426f6f6c65616ecd207280d59cfaee0200015a000576616c75657870017070707371007e004c707371007e00500000c3547070707071007e017171007e017171007e016b707371007e00570000c3547070707071007e017171007e0171707371007e00510000c3547070707071007e017171007e0171707371007e005a0000c3547070707071007e017171007e0171707371007e005c0000c3547070707071007e017171007e0171707070707371007e005e7070707071007e016b70707070707070707070707070707070707400265265717569736974696f6e2047726f757073204d697373696e6720537570706c79204c696e6578700000c3540000003401707070707e7200306e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e4f7269656e746174696f6e456e756d00000000000000001200007871007e001d7400094c414e4453434150457371007e00117371007e001a0000000277040000000a7371007e002a0000c3540000001400010000000000000048000002c6000000007071007e001071007e017c70707070707071007e00417070707071007e00447371007e0046a6cd4885e72541551abcd2c71ce14a4b0000c354707070707074000953616e7353657269667371007e00490000000870707070707070707070707371007e004c707371007e00500000c3547070707071007e018271007e018271007e017e707371007e00570000c3547070707071007e018271007e0182707371007e00510000c3547070707071007e018271007e0182707371007e005a0000c3547070707071007e018271007e0182707371007e005c0000c3547070707071007e018271007e0182707070707371007e005e7070707071007e017e70707070707070707070707070707070700000c3540000000000000000707071007e00627371007e00640000000d7571007e0067000000017371007e00690474000b504147455f4e554d424552707070707070707070707070707371007e015f0000c35400000014000100000000000002c600000000000000007071007e001071007e017c70707070707071007e00417070707071007e00447371007e0046b62f68c26194b7c32e4a2985b90149630000c3547070707070707070707070707070707070707371007e004c707371007e00500000c3547070707071007e018f71007e018f71007e018d707371007e00570000c3547070707071007e018f71007e018f707371007e00510000c3547070707071007e018f71007e018f707371007e005a0000c3547070707071007e018f71007e018f707371007e005c0000c3547070707071007e018f71007e018f707070707371007e005e7070707071007e018d70707070707070707070707070707070707400012078700000c3540000001401707070707371007e00117371007e001a0000000477040000000a7371007e015f0000c354000000140001000000000000010d00000201000000007071007e001071007e019770707070707071007e00417070707071007e00447371007e00469f72d87cd57c5a0d9a07393f55224bce0000c354707070707074000953616e73536572696671007e004b707071007e01707070707071007e01707070707371007e004c707371007e00500000c3547070707071007e019c71007e019c71007e0199707371007e00570000c3547070707071007e019c71007e019c707371007e00510000c3547070707071007e019c71007e019c707371007e005a0000c3547070707071007e019c71007e019c707371007e005c0000c3547070707071007e019c71007e019c707070707371007e005e7070707071007e019970707070707070707070707070707070707400115265717569736974696f6e2047726f75707371007e015f0000c35400000014000100000000000000e800000052000000007071007e001071007e019770707070707071007e00417070707071007e00447371007e0046a2a43d5c0bd9170ad949733d046b41aa0000c354707070707074000953616e73536572696671007e004b707071007e01707070707071007e01707070707371007e004c707371007e00500000c3547070707071007e01a771007e01a771007e01a4707371007e00570000c3547070707071007e01a771007e01a7707371007e00510000c3547070707071007e01a771007e01a7707371007e005a0000c3547070707071007e01a771007e01a7707371007e005c0000c3547070707071007e01a771007e01a7707070707371007e005e7070707071007e01a4707070707070707070707070707070707074001053757065727669736f7279204e6f64657371007e015f0000c35400000014000100000000000000c70000013a000000007071007e001071007e019770707070707071007e00417070707071007e00447371007e0046835adf817aa47786a3153510d28746ad0000c354707070707074000953616e73536572696671007e004b707071007e01707070707071007e01707070707371007e004c707371007e00500000c3547070707071007e01b271007e01b271007e01af707371007e00570000c3547070707071007e01b271007e01b2707371007e00510000c3547070707071007e01b271007e01b2707371007e005a0000c3547070707071007e01b271007e01b2707371007e005c0000c3547070707071007e01b271007e01b2707070707371007e005e7070707071007e01af707070707070707070707070707070707074000c50726f6772616d204e616d657371007e015f0000c354000000140001000000000000005200000000000000007071007e001071007e019770707070707071007e00417070707071007e00447371007e0046b48a4feb4161ed645a7f10ba925c4ca70000c354707070707074000953616e73536572696671007e004b7071007e008d71007e01707070707071007e01707070707371007e004c707371007e00500000c3547070707071007e01bd71007e01bd71007e01ba707371007e00570000c3547070707071007e01bd71007e01bd707371007e00510000c3547070707071007e01bd71007e01bd707371007e005a0000c3547070707071007e01bd71007e01bd707371007e005c0000c3547070707071007e01bd71007e01bd707070707371007e005e7070707071007e01ba7070707070707070707070707070707070740004532e4e6f78700000c354000000140170707071007e001e7e72002f6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5072696e744f72646572456e756d00000000000000001200007871007e001d740008564552544943414c757200265b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a525374796c653bd49cc311d90572350200007870000000087372002c6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655374796c65000000000000271102003a49001950534555444f5f53455249414c5f56455253494f4e5f5549445a0009697344656661756c744c00096261636b636f6c6f7271007e00304c0006626f7264657271007e00144c000b626f72646572436f6c6f7271007e00304c000c626f74746f6d426f7264657271007e00144c0011626f74746f6d426f72646572436f6c6f7271007e00304c000d626f74746f6d50616464696e6771007e00315b0011636f6e646974696f6e616c5374796c65737400315b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52436f6e646974696f6e616c5374796c653b4c001464656661756c745374796c6550726f766964657271007e00394c000466696c6c71007e00144c000966696c6c56616c756574002b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f46696c6c456e756d3b4c0008666f6e744e616d6571007e00024c0008666f6e7453697a6571007e00314c0009666f7265636f6c6f7271007e00304c0013686f72697a6f6e74616c416c69676e6d656e7471007e00144c0018686f72697a6f6e74616c416c69676e6d656e7456616c756571007e00324c000f6973426c616e6b5768656e4e756c6c71007e002e4c00066973426f6c6471007e002e4c000869734974616c696371007e002e4c000d6973506466456d62656464656471007e002e4c000f6973537472696b655468726f75676871007e002e4c000c69735374796c65645465787471007e002e4c000b6973556e6465726c696e6571007e002e4c000a6c656674426f7264657271007e00144c000f6c656674426f72646572436f6c6f7271007e00304c000b6c65667450616464696e6771007e00314c00076c696e65426f7871007e00334c00076c696e6550656e7400234c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250656e3b4c000b6c696e6553706163696e6771007e00144c00106c696e6553706163696e6756616c756571007e00344c00066d61726b757071007e00024c00046d6f646571007e00144c00096d6f646556616c756571007e003a4c00046e616d6571007e00024c000770616464696e6771007e00314c000970617261677261706871007e00354c000b706172656e745374796c6571007e00074c0018706172656e745374796c654e616d655265666572656e636571007e00024c00077061747465726e71007e00024c000b706466456e636f64696e6771007e00024c000b706466466f6e744e616d6571007e00024c000370656e71007e00144c000c706f736974696f6e5479706571007e00144c000672616469757371007e00314c000b7269676874426f7264657271007e00144c00107269676874426f72646572436f6c6f7271007e00304c000c726967687450616464696e6771007e00314c0008726f746174696f6e71007e00144c000d726f746174696f6e56616c756571007e00364c000a7363616c65496d61676571007e00144c000f7363616c65496d61676556616c75657400314c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5363616c65496d616765456e756d3b4c000b737472657463685479706571007e00144c0009746f70426f7264657271007e00144c000e746f70426f72646572436f6c6f7271007e00304c000a746f7050616464696e6771007e00314c0011766572746963616c416c69676e6d656e7471007e00144c0016766572746963616c416c69676e6d656e7456616c756571007e003778700000c35400707070707070707070707070707070707070707070707070707371007e004c707371007e00500000c3547070707071007e01d071007e01d071007e01cf707371007e00570000c3547070707071007e01d071007e01d0707371007e00510000c3547372000e6a6176612e6177742e436f6c6f7201a51783108f337502000546000666616c70686149000576616c75654c0002637374001b4c6a6176612f6177742f636f6c6f722f436f6c6f7253706163653b5b00096672676276616c75657400025b465b00066676616c756571007e01d6787000000000ff00000070707070707372000f6a6176612e6c616e672e466c6f6174daedc9a2db3cf0ec02000146000576616c75657871007e004a3f80000071007e01d071007e01d0707371007e005a0000c3547070707071007e01d071007e01d0707371007e005c0000c3547070707071007e01d071007e01d07371007e00520000c3547070707071007e01cf70707070707400057461626c65707371007e005e7070707071007e01cf70707070707070707070707070707070707070707070707070707371007e01ca0000c354007371007e01d400000000fff0f8ff7070707070707070707070707070707070707070707070707070707371007e004c707371007e00500000c3547070707071007e01e171007e01e171007e01df707371007e00570000c3547070707071007e01e171007e01e1707371007e00510000c3547371007e01d400000000ff00000070707070707371007e01d83f00000071007e01e171007e01e1707371007e005a0000c3547070707071007e01e171007e01e1707371007e005c0000c3547070707071007e01e171007e01e17371007e00520000c3547070707071007e01df707070707e7200296e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e4d6f6465456e756d00000000000000001200007871007e001d7400064f50415155457400087461626c655f5448707371007e005e7070707071007e01df70707070707070707070707070707070707070707070707070707371007e01ca0000c354007371007e01d400000000ffbfe1ff7070707070707070707070707070707070707070707070707070707371007e004c707371007e00500000c3547070707071007e01f171007e01f171007e01ef707371007e00570000c3547070707071007e01f171007e01f1707371007e00510000c3547371007e01d400000000ff00000070707070707371007e01d83f00000071007e01f171007e01f1707371007e005a0000c3547070707071007e01f171007e01f1707371007e005c0000c3547070707071007e01f171007e01f17371007e00520000c3547070707071007e01ef7070707071007e01eb7400087461626c655f4348707371007e005e7070707071007e01ef70707070707070707070707070707070707070707070707070707371007e01ca0000c354007371007e01d400000000ffffffff7070707070707070707070707070707070707070707070707070707371007e004c707371007e00500000c3547070707071007e01fe71007e01fe71007e01fc707371007e00570000c3547070707071007e01fe71007e01fe707371007e00510000c3547371007e01d400000000ff00000070707070707371007e01d83f00000071007e01fe71007e01fe707371007e005a0000c3547070707071007e01fe71007e01fe707371007e005c0000c3547070707071007e01fe71007e01fe7371007e00520000c3547070707071007e01fc7070707071007e01eb7400087461626c655f5444707371007e005e7070707071007e01fc70707070707070707070707070707070707070707070707070707371007e01ca0000c35400707070707070707070707070707070707070707070707070707371007e004c707371007e00500000c3547070707071007e020a71007e020a71007e0209707371007e00570000c3547070707071007e020a71007e020a707371007e00510000c3547371007e01d400000000ff00000070707070707371007e01d83f80000071007e020a71007e020a707371007e005a0000c3547070707071007e020a71007e020a707371007e005c0000c3547070707071007e020a71007e020a7371007e00520000c3547070707071007e020970707070707400077461626c652031707371007e005e7070707071007e020970707070707070707070707070707070707070707070707070707371007e01ca0000c354007371007e01d400000000fff0f8ff7070707070707070707070707070707070707070707070707070707371007e004c707371007e00500000c3547070707071007e021771007e021771007e0215707371007e00570000c3547070707071007e021771007e0217707371007e00510000c3547371007e01d400000000ff00000070707070707371007e01d83f00000071007e021771007e0217707371007e005a0000c3547070707071007e021771007e0217707371007e005c0000c3547070707071007e021771007e02177371007e00520000c3547070707071007e02157070707071007e01eb74000a7461626c6520315f5448707371007e005e7070707071007e021570707070707070707070707070707070707070707070707070707371007e01ca0000c354007371007e01d400000000ffbfe1ff7070707070707070707070707070707070707070707070707070707371007e004c707371007e00500000c3547070707071007e022471007e022471007e0222707371007e00570000c3547070707071007e022471007e0224707371007e00510000c3547371007e01d400000000ff00000070707070707371007e01d83f00000071007e022471007e0224707371007e005a0000c3547070707071007e022471007e0224707371007e005c0000c3547070707071007e022471007e02247371007e00520000c3547070707071007e02227070707071007e01eb74000a7461626c6520315f4348707371007e005e7070707071007e022270707070707070707070707070707070707070707070707070707371007e01ca0000c354007371007e01d400000000ffffffff7070707070707070707070707070707070707070707070707070707371007e004c707371007e00500000c3547070707071007e023171007e023171007e022f707371007e00570000c3547070707071007e023171007e0231707371007e00510000c3547371007e01d400000000ff00000070707070707371007e01d83f00000071007e023171007e0231707371007e005a0000c3547070707071007e023171007e0231707371007e005c0000c3547070707071007e023171007e02317371007e00520000c3547070707071007e022f7070707071007e01eb74000a7461626c6520315f5444707371007e005e7070707071007e022f707070707070707070707070707070707070707070707070707070707371007e00117371007e001a0000000277040000000a7371007e015f0000c35400000020000100000000000002c600000000000000007071007e001071007e023c70707070707071007e00417070707071007e00447371007e00468f61a735ab2074b7212194e972ca43210000c354707070707074000953616e73536572696671007e016e7071007e008d707070707071007e01707070707371007e004c707371007e00500000c3547070707071007e024171007e024171007e023e707371007e00570000c3547070707071007e024171007e0241707371007e00510000c3547070707071007e024171007e0241707371007e005a0000c3547070707071007e024171007e0241707371007e005c0000c3547070707071007e024171007e0241707070707371007e005e7070707071007e023e70707070707070707070707070707070707400265265717569736974696f6e2047726f757073204d697373696e6720537570706c79204c696e657371007e002a0000c3540000002000010000000000000048000002c6000000007071007e001071007e023c70707070707071007e00417070707071007e00447371007e004689ab02f2dda79bb52dd094dce4b543c00000c354707070707074000953616e73536572696671007e018170707070707070707070707371007e004c707371007e00500000c3547070707071007e024c71007e024c71007e0249707371007e00570000c3547070707071007e024c71007e024c707371007e00510000c3547070707071007e024c71007e024c707371007e005a0000c3547070707071007e024c71007e024c707371007e005c0000c3547070707071007e024c71007e024c707070707371007e005e7070707071007e024970707070707070707070707070707070700000c3540000000000000000707071007e00627371007e0064000000087571007e0067000000017371007e0069017400146e6577206a6176612e7574696c2e446174652829707070707070707070707074000a64642f4d4d2f797979797078700000c3540000002001707070707e7200336e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5768656e4e6f4461746154797065456e756d00000000000000001200007871007e001d74000f4e4f5f444154415f53454354494f4e737200366e65742e73662e6a61737065727265706f7274732e656e67696e652e64657369676e2e4a525265706f7274436f6d70696c654461746100000000000027d80200034c001363726f7373746162436f6d70696c654461746171007e00ab4c001264617461736574436f6d70696c654461746171007e00ab4c00166d61696e44617461736574436f6d70696c654461746171007e000178707371007e010b3f4000000000000c77080000001000000000787371007e010b3f4000000000000c7708000000100000000078757200025b42acf317f8060854e0020000787000001401cafebabe0000002e00cb01001c7265706f7274315f313338303137383835343032385f33373234343707000101002c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a524576616c7561746f72070003010017706172616d657465725f5245504f52545f4c4f43414c450100324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c506172616d657465723b010017706172616d657465725f4a41535045525f5245504f525401001c706172616d657465725f5245504f52545f5649525455414c495a455201001a706172616d657465725f5245504f52545f54494d455f5a4f4e45010015706172616d657465725f534f52545f4649454c445301001e706172616d657465725f5245504f52545f46494c455f5245534f4c56455201001a706172616d657465725f5245504f52545f5343524950544c455401001f706172616d657465725f5245504f52545f504152414d45544552535f4d415001001b706172616d657465725f5245504f52545f434f4e4e454354494f4e010018706172616d657465725f5245504f52545f434f4e5445585401001d706172616d657465725f5245504f52545f434c4153535f4c4f41444552010024706172616d657465725f5245504f52545f55524c5f48414e444c45525f464143544f525901001c706172616d657465725f5245504f52545f444154415f534f5552434501001e706172616d657465725f49535f49474e4f52455f504147494e4154494f4e010010706172616d657465725f46494c54455201001f706172616d657465725f5245504f52545f464f524d41545f464143544f525901001a706172616d657465725f5245504f52545f4d41585f434f554e5401001a706172616d657465725f5245504f52545f54454d504c41544553010020706172616d657465725f5245504f52545f5245534f555243455f42554e444c450100166669656c645f7265717569736974696f6e67726f757001002e4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c4669656c643b01000a6669656c645f6e616d6501000b6669656c645f734e6f64650100147661726961626c655f504147455f4e554d4245520100314c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c5661726961626c653b0100167661726961626c655f434f4c554d4e5f4e554d4245520100157661726961626c655f5245504f52545f434f554e540100137661726961626c655f504147455f434f554e540100157661726961626c655f434f4c554d4e5f434f554e540100063c696e69743e010003282956010004436f64650c002300240a000400260c0005000609000200280c00070006090002002a0c00080006090002002c0c00090006090002002e0c000a000609000200300c000b000609000200320c000c000609000200340c000d000609000200360c000e000609000200380c000f0006090002003a0c00100006090002003c0c00110006090002003e0c0012000609000200400c0013000609000200420c0014000609000200440c0015000609000200460c0016000609000200480c00170006090002004a0c00180006090002004c0c0019001a090002004e0c001b001a09000200500c001c001a09000200520c001d001e09000200540c001f001e09000200560c0020001e09000200580c0021001e090002005a0c0022001e090002005c01000f4c696e654e756d6265725461626c6501000e637573746f6d697a6564496e6974010030284c6a6176612f7574696c2f4d61703b4c6a6176612f7574696c2f4d61703b4c6a6176612f7574696c2f4d61703b295601000a696e6974506172616d73010012284c6a6176612f7574696c2f4d61703b29560c006100620a0002006301000a696e69744669656c64730c006500620a00020066010008696e6974566172730c006800620a0002006901000d5245504f52545f4c4f43414c4508006b01000d6a6176612f7574696c2f4d617007006d010003676574010026284c6a6176612f6c616e672f4f626a6563743b294c6a6176612f6c616e672f4f626a6563743b0c006f00700b006e00710100306e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c506172616d6574657207007301000d4a41535045525f5245504f52540800750100125245504f52545f5649525455414c495a45520800770100105245504f52545f54494d455f5a4f4e4508007901000b534f52545f4649454c445308007b0100145245504f52545f46494c455f5245534f4c56455208007d0100105245504f52545f5343524950544c455408007f0100155245504f52545f504152414d45544552535f4d41500800810100115245504f52545f434f4e4e454354494f4e08008301000e5245504f52545f434f4e544558540800850100135245504f52545f434c4153535f4c4f4144455208008701001a5245504f52545f55524c5f48414e444c45525f464143544f52590800890100125245504f52545f444154415f534f5552434508008b01001449535f49474e4f52455f504147494e4154494f4e08008d01000646494c54455208008f0100155245504f52545f464f524d41545f464143544f52590800910100105245504f52545f4d41585f434f554e540800930100105245504f52545f54454d504c415445530800950100165245504f52545f5245534f555243455f42554e444c450800970100107265717569736974696f6e67726f757008009901002c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c4669656c6407009b0100046e616d6508009d010005734e6f646508009f01000b504147455f4e554d4245520800a101002f6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c5661726961626c650700a301000d434f4c554d4e5f4e554d4245520800a501000c5245504f52545f434f554e540800a701000a504147455f434f554e540800a901000c434f4c554d4e5f434f554e540800ab0100086576616c756174650100152849294c6a6176612f6c616e672f4f626a6563743b01000a457863657074696f6e730100136a6176612f6c616e672f5468726f7761626c650700b00100116a6176612f6c616e672f496e74656765720700b2010004284929560c002300b40a00b300b501000e6a6176612f7574696c2f446174650700b70a00b8002601000867657456616c756501001428294c6a6176612f6c616e672f4f626a6563743b0c00ba00bb0a009c00bc0100106a6176612f6c616e672f537472696e670700be0a00a400bc01000b6576616c756174654f6c6401000b6765744f6c6456616c75650c00c200bb0a009c00c30a00a400c30100116576616c75617465457374696d61746564010011676574457374696d6174656456616c75650c00c700bb0a00a400c801000a536f7572636546696c650021000200040000001b00020005000600000002000700060000000200080006000000020009000600000002000a000600000002000b000600000002000c000600000002000d000600000002000e000600000002000f0006000000020010000600000002001100060000000200120006000000020013000600000002001400060000000200150006000000020016000600000002001700060000000200180006000000020019001a00000002001b001a00000002001c001a00000002001d001e00000002001f001e000000020020001e000000020021001e000000020022001e000000080001002300240001002500000114000200010000008c2ab700272a01b500292a01b5002b2a01b5002d2a01b5002f2a01b500312a01b500332a01b500352a01b500372a01b500392a01b5003b2a01b5003d2a01b5003f2a01b500412a01b500432a01b500452a01b500472a01b500492a01b5004b2a01b5004d2a01b5004f2a01b500512a01b500532a01b500552a01b500572a01b500592a01b5005b2a01b5005db100000001005e00000076001d00000012000400190009001a000e001b0013001c0018001d001d001e0022001f00270020002c00210031002200360023003b00240040002500450026004a0027004f0028005400290059002a005e002b0063002c0068002d006d002e0072002f00770030007c00310081003200860033008b00120001005f0060000100250000003400020004000000102a2bb700642a2cb700672a2db7006ab100000001005e0000001200040000003f00050040000a0041000f004200020061006200010025000001bb00030002000001572a2b126cb900720200c00074c00074b500292a2b1276b900720200c00074c00074b5002b2a2b1278b900720200c00074c00074b5002d2a2b127ab900720200c00074c00074b5002f2a2b127cb900720200c00074c00074b500312a2b127eb900720200c00074c00074b500332a2b1280b900720200c00074c00074b500352a2b1282b900720200c00074c00074b500372a2b1284b900720200c00074c00074b500392a2b1286b900720200c00074c00074b5003b2a2b1288b900720200c00074c00074b5003d2a2b128ab900720200c00074c00074b5003f2a2b128cb900720200c00074c00074b500412a2b128eb900720200c00074c00074b500432a2b1290b900720200c00074c00074b500452a2b1292b900720200c00074c00074b500472a2b1294b900720200c00074c00074b500492a2b1296b900720200c00074c00074b5004b2a2b1298b900720200c00074c00074b5004db100000001005e0000005200140000004a0012004b0024004c0036004d0048004e005a004f006c0050007e00510090005200a2005300b4005400c6005500d8005600ea005700fc0058010e00590120005a0132005b0144005c0156005d000200650062000100250000005b00030002000000372a2b129ab900720200c0009cc0009cb5004f2a2b129eb900720200c0009cc0009cb500512a2b12a0b900720200c0009cc0009cb50053b100000001005e000000120004000000650012006600240067003600680002006800620001002500000087000300020000005b2a2b12a2b900720200c000a4c000a4b500552a2b12a6b900720200c000a4c000a4b500572a2b12a8b900720200c000a4c000a4b500592a2b12aab900720200c000a4c000a4b5005b2a2b12acb900720200c000a4c000a4b5005db100000001005e0000001a00060000007000120071002400720036007300480074005a0075000100ad00ae000200af00000004000100b100250000018400030003000000f8014d1baa000000f3000000000000000d00000045000000510000005d0000006900000075000000810000008d00000099000000a5000000b0000000be000000cc000000da000000e8bb00b35904b700b64da700a5bb00b35904b700b64da70099bb00b35904b700b64da7008dbb00b35903b700b64da70081bb00b35904b700b64da70075bb00b35903b700b64da70069bb00b35904b700b64da7005dbb00b35903b700b64da70051bb00b859b700b94da700462ab40053b600bdc000bf4da700382ab40051b600bdc000bf4da7002a2ab4004fb600bdc000bf4da7001c2ab40059b600c0c000b34da7000e2ab40055b600c0c000b34d2cb000000001005e0000007a001e0000007d0002007f004800830051008400540088005d00890060008d0069008e006c00920075009300780097008100980084009c008d009d009000a1009900a2009c00a600a500a700a800ab00b000ac00b300b000be00b100c100b500cc00b600cf00ba00da00bb00dd00bf00e800c000eb00c400f600cc000100c100ae000200af00000004000100b100250000018400030003000000f8014d1baa000000f3000000000000000d00000045000000510000005d0000006900000075000000810000008d00000099000000a5000000b0000000be000000cc000000da000000e8bb00b35904b700b64da700a5bb00b35904b700b64da70099bb00b35904b700b64da7008dbb00b35903b700b64da70081bb00b35904b700b64da70075bb00b35903b700b64da70069bb00b35904b700b64da7005dbb00b35903b700b64da70051bb00b859b700b94da700462ab40053b600c4c000bf4da700382ab40051b600c4c000bf4da7002a2ab4004fb600c4c000bf4da7001c2ab40059b600c5c000b34da7000e2ab40055b600c5c000b34d2cb000000001005e0000007a001e000000d5000200d7004800db005100dc005400e0005d00e1006000e5006900e6006c00ea007500eb007800ef008100f0008400f4008d00f5009000f9009900fa009c00fe00a500ff00a8010300b0010400b3010800be010900c1010d00cc010e00cf011200da011300dd011700e8011800eb011c00f60124000100c600ae000200af00000004000100b100250000018400030003000000f8014d1baa000000f3000000000000000d00000045000000510000005d0000006900000075000000810000008d00000099000000a5000000b0000000be000000cc000000da000000e8bb00b35904b700b64da700a5bb00b35904b700b64da70099bb00b35904b700b64da7008dbb00b35903b700b64da70081bb00b35904b700b64da70075bb00b35903b700b64da70069bb00b35904b700b64da7005dbb00b35903b700b64da70051bb00b859b700b94da700462ab40053b600bdc000bf4da700382ab40051b600bdc000bf4da7002a2ab4004fb600bdc000bf4da7001c2ab40059b600c9c000b34da7000e2ab40055b600c9c000b34d2cb000000001005e0000007a001e0000012d0002012f004801330051013400540138005d01390060013d0069013e006c01420075014300780147008101480084014c008d014d0090015100990152009c015600a5015700a8015b00b0015c00b3016000be016100c1016500cc016600cf016a00da016b00dd016f00e8017000eb017400f6017c000100ca0000000200017400155f313338303137383835343032385f3337323434377400326e65742e73662e6a61737065727265706f7274732e656e67696e652e64657369676e2e4a524a61766163436f6d70696c6572	\N	2014-10-27 12:28:16.544682	Consistency Report	\N
8	Order Routing Inconsistencies	\\xaced0005737200286e65742e73662e6a61737065727265706f7274732e656e67696e652e4a61737065725265706f727400000000000027d80200034c000b636f6d70696c65446174617400164c6a6176612f696f2f53657269616c697a61626c653b4c0011636f6d70696c654e616d655375666669787400124c6a6176612f6c616e672f537472696e673b4c000d636f6d70696c6572436c61737371007e00027872002d6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655265706f727400000000000027d802002a49001950534555444f5f53455249414c5f56455253494f4e5f55494449000c626f74746f6d4d617267696e49000b636f6c756d6e436f756e7449000d636f6c756d6e53706163696e6749000b636f6c756d6e57696474685a001069676e6f7265506167696e6174696f6e5a00136973466c6f6174436f6c756d6e466f6f7465725a0010697353756d6d6172794e6577506167655a0020697353756d6d6172795769746850616765486561646572416e64466f6f7465725a000e69735469746c654e65775061676549000a6c6566744d617267696e42000b6f7269656e746174696f6e49000a7061676548656967687449000970616765576964746842000a7072696e744f7264657249000b72696768744d617267696e490009746f704d617267696e42000e7768656e4e6f44617461547970654c000a6261636b67726f756e647400244c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5242616e643b4c000f636f6c756d6e446972656374696f6e7400334c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f52756e446972656374696f6e456e756d3b4c000c636f6c756d6e466f6f74657271007e00044c000c636f6c756d6e48656164657271007e00045b000864617461736574737400285b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52446174617365743b4c000c64656661756c745374796c657400254c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525374796c653b4c000664657461696c71007e00044c000d64657461696c53656374696f6e7400274c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5253656374696f6e3b4c0012666f726d6174466163746f7279436c61737371007e00024c000a696d706f72747353657474000f4c6a6176612f7574696c2f5365743b4c00086c616e677561676571007e00024c000e6c61737450616765466f6f74657271007e00044c000b6d61696e446174617365747400274c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52446174617365743b4c00046e616d6571007e00024c00066e6f4461746171007e00044c00106f7269656e746174696f6e56616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4f7269656e746174696f6e456e756d3b4c000a70616765466f6f74657271007e00044c000a7061676548656164657271007e00044c000f7072696e744f7264657256616c75657400314c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5072696e744f72646572456e756d3b5b00067374796c65737400265b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525374796c653b4c000773756d6d61727971007e00045b000974656d706c6174657374002f5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525265706f727454656d706c6174653b4c00057469746c6571007e00044c00137768656e4e6f446174615479706556616c75657400354c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5768656e4e6f4461746154797065456e756d3b78700000c3540000000000000001000000000000030e000100000000000000000000022b0000030e000000000000000000007372002b6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736542616e6400000000000027d802000749001950534555444f5f53455249414c5f56455253494f4e5f5549444900066865696768745a000e697353706c6974416c6c6f7765644c00137072696e745768656e45787072657373696f6e74002a4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5245787072657373696f6e3b4c000d70726f706572746965734d617074002d4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250726f706572746965734d61703b4c000973706c6974547970657400104c6a6176612f6c616e672f427974653b4c000e73706c69745479706556616c75657400304c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f53706c697454797065456e756d3b787200336e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365456c656d656e7447726f757000000000000027d80200024c00086368696c6472656e7400104c6a6176612f7574696c2f4c6973743b4c000c656c656d656e7447726f757074002c4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52456c656d656e7447726f75703b7870737200136a6176612e7574696c2e41727261794c6973747881d21d99c7619d03000149000473697a6578700000000077040000000a78700000c35400000000017070707e72002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e53706c697454797065456e756d00000000000000001200007872000e6a6176612e6c616e672e456e756d00000000000000001200007870740007535452455443487e7200316e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e52756e446972656374696f6e456e756d00000000000000001200007871007e001d7400034c545270707070707372002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736553656374696f6e00000000000027d80200015b000562616e64737400255b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5242616e643b7870757200255b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5242616e643b95dd7eec8cca85350200007870000000017371007e00117371007e001a0000000777040000000a737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365546578744669656c6400000000000027d802001549001950534555444f5f53455249414c5f56455253494f4e5f55494449000d626f6f6b6d61726b4c6576656c42000e6576616c756174696f6e54696d6542000f68797065726c696e6b54617267657442000d68797065726c696e6b547970655a0015697353747265746368576974684f766572666c6f774c0014616e63686f724e616d6545787072657373696f6e71007e00124c000f6576616c756174696f6e47726f75707400254c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5247726f75703b4c00136576616c756174696f6e54696d6556616c75657400354c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4576616c756174696f6e54696d65456e756d3b4c000a65787072657373696f6e71007e00124c001968797065726c696e6b416e63686f7245787072657373696f6e71007e00124c001768797065726c696e6b5061676545787072657373696f6e71007e00125b001368797065726c696e6b506172616d65746572737400335b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5248797065726c696e6b506172616d657465723b4c001c68797065726c696e6b5265666572656e636545787072657373696f6e71007e00124c001a68797065726c696e6b546f6f6c74697045787072657373696f6e71007e00124c001768797065726c696e6b5768656e45787072657373696f6e71007e00124c000f6973426c616e6b5768656e4e756c6c7400134c6a6176612f6c616e672f426f6f6c65616e3b4c000a6c696e6b54617267657471007e00024c00086c696e6b5479706571007e00024c00077061747465726e71007e00024c00117061747465726e45787072657373696f6e71007e0012787200326e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736554657874456c656d656e7400000000000027d802002549001950534555444f5f53455249414c5f56455253494f4e5f5549444c0006626f7264657271007e00144c000b626f72646572436f6c6f727400104c6a6176612f6177742f436f6c6f723b4c000c626f74746f6d426f7264657271007e00144c0011626f74746f6d426f72646572436f6c6f7271007e00304c000d626f74746f6d50616464696e677400134c6a6176612f6c616e672f496e74656765723b4c0008666f6e744e616d6571007e00024c0008666f6e7453697a6571007e00314c0013686f72697a6f6e74616c416c69676e6d656e7471007e00144c0018686f72697a6f6e74616c416c69676e6d656e7456616c75657400364c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f486f72697a6f6e74616c416c69676e456e756d3b4c00066973426f6c6471007e002e4c000869734974616c696371007e002e4c000d6973506466456d62656464656471007e002e4c000f6973537472696b655468726f75676871007e002e4c000c69735374796c65645465787471007e002e4c000b6973556e6465726c696e6571007e002e4c000a6c656674426f7264657271007e00144c000f6c656674426f72646572436f6c6f7271007e00304c000b6c65667450616464696e6771007e00314c00076c696e65426f787400274c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a524c696e65426f783b4c000b6c696e6553706163696e6771007e00144c00106c696e6553706163696e6756616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4c696e6553706163696e67456e756d3b4c00066d61726b757071007e00024c000770616464696e6771007e00314c00097061726167726170687400294c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525061726167726170683b4c000b706466456e636f64696e6771007e00024c000b706466466f6e744e616d6571007e00024c000b7269676874426f7264657271007e00144c00107269676874426f72646572436f6c6f7271007e00304c000c726967687450616464696e6771007e00314c0008726f746174696f6e71007e00144c000d726f746174696f6e56616c756574002f4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f526f746174696f6e456e756d3b4c0009746f70426f7264657271007e00144c000e746f70426f72646572436f6c6f7271007e00304c000a746f7050616464696e6771007e00314c0011766572746963616c416c69676e6d656e7471007e00144c0016766572746963616c416c69676e6d656e7456616c75657400344c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f566572746963616c416c69676e456e756d3b7872002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365456c656d656e7400000000000027d802001b49001950534555444f5f53455249414c5f56455253494f4e5f5549444900066865696768745a001769735072696e74496e466972737457686f6c6542616e645a001569735072696e74526570656174656456616c7565735a001a69735072696e745768656e44657461696c4f766572666c6f77735a0015697352656d6f76654c696e655768656e426c616e6b42000c706f736974696f6e5479706542000b7374726574636854797065490005776964746849000178490001794c00096261636b636f6c6f7271007e00304c001464656661756c745374796c6550726f76696465727400344c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5244656661756c745374796c6550726f76696465723b4c000c656c656d656e7447726f757071007e00184c0009666f7265636f6c6f7271007e00304c00036b657971007e00024c00046d6f646571007e00144c00096d6f646556616c756574002b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4d6f6465456e756d3b4c000b706172656e745374796c6571007e00074c0018706172656e745374796c654e616d655265666572656e636571007e00024c0011706f736974696f6e5479706556616c75657400334c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f506f736974696f6e54797065456e756d3b4c00137072696e745768656e45787072657373696f6e71007e00124c00157072696e745768656e47726f75704368616e67657371007e002b4c000d70726f706572746965734d617071007e00135b001370726f706572747945787072657373696f6e737400335b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250726f706572747945787072657373696f6e3b4c0010737472657463685479706556616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5374726574636854797065456e756d3b4c0004757569647400104c6a6176612f7574696c2f555549443b78700000c354000000140001000000000000002600000000000000007071007e001071007e00287070707070707e7200316e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e506f736974696f6e54797065456e756d00000000000000001200007871007e001d7400134649585f52454c41544956455f544f5f544f50707070707e7200306e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5374726574636854797065456e756d00000000000000001200007871007e001d74000a4e4f5f535452455443487372000e6a6176612e7574696c2e55554944bc9903f7986d852f0200024a000c6c65617374536967426974734a000b6d6f7374536967426974737870a3c35f9512886f9f0cb682e445b14bae0000c354707070707070737200116a6176612e6c616e672e496e746567657212e2a0a4f781873802000149000576616c7565787200106a6176612e6c616e672e4e756d62657286ac951d0b94e08b02000078700000000a707e7200346e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e486f72697a6f6e74616c416c69676e456e756d00000000000000001200007871007e001d74000643454e5445527070707070707070707372002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173654c696e65426f7800000000000027d802000b4c000d626f74746f6d50616464696e6771007e00314c0009626f74746f6d50656e74002b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f626173652f4a52426f7850656e3b4c000c626f78436f6e7461696e657274002c4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52426f78436f6e7461696e65723b4c000b6c65667450616464696e6771007e00314c00076c65667450656e71007e004f4c000770616464696e6771007e00314c000370656e71007e004f4c000c726967687450616464696e6771007e00314c0008726967687450656e71007e004f4c000a746f7050616464696e6771007e00314c0006746f7050656e71007e004f787070737200336e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f78426f74746f6d50656e00000000000027d80200007872002d6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f7850656e00000000000027d80200014c00076c696e65426f7871007e00337872002a6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736550656e00000000000027d802000649001950534555444f5f53455249414c5f56455253494f4e5f5549444c00096c696e65436f6c6f7271007e00304c00096c696e655374796c6571007e00144c000e6c696e655374796c6556616c75657400304c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4c696e655374796c65456e756d3b4c00096c696e6557696474687400114c6a6176612f6c616e672f466c6f61743b4c000c70656e436f6e7461696e657274002c4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250656e436f6e7461696e65723b78700000c3547070707071007e005171007e005171007e003f70737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f784c65667450656e00000000000027d80200007871007e00530000c3547070707071007e005171007e0051707371007e00530000c3547070707071007e005171007e005170737200326e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f78526967687450656e00000000000027d80200007871007e00530000c3547070707071007e005171007e005170737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f78546f7050656e00000000000027d80200007871007e00530000c3547070707071007e005171007e005170707070737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736550617261677261706800000000000027d802000a4c000f66697273744c696e65496e64656e7471007e00314c000a6c656674496e64656e7471007e00314c000b6c696e6553706163696e6771007e00344c000f6c696e6553706163696e6753697a6571007e00564c0012706172616772617068436f6e7461696e65727400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52506172616772617068436f6e7461696e65723b4c000b7269676874496e64656e7471007e00314c000c73706163696e67416674657271007e00314c000d73706163696e674265666f726571007e00314c000c74616253746f70576964746871007e00314c000874616253746f707371007e001778707070707071007e003f70707070707070707070707070707070700000c354000000000000000070707e7200336e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e4576616c756174696f6e54696d65456e756d00000000000000001200007871007e001d7400034e4f57737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736545787072657373696f6e00000000000027d802000449000269645b00066368756e6b737400305b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5245787072657373696f6e4368756e6b3b4c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e0002787000000009757200305b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5245787072657373696f6e4368756e6b3b6d59cfde694ba355020000787000000001737200366e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736545787072657373696f6e4368756e6b00000000000027d8020002420004747970654c00047465787471007e000278700474000c5245504f52545f434f554e54707070707070707070707070707371007e002a0000c35400000014000100000000000000a400000026000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e004698f4376032bdf48f2d97d1a7f057497d0000c3547070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e007071007e007071007e006e707371007e00590000c3547070707071007e007071007e0070707371007e00530000c3547070707071007e007071007e0070707371007e005c0000c3547070707071007e007071007e0070707371007e005e0000c3547070707071007e007071007e0070707070707371007e00607070707071007e006e70707070707070707070707070707070700000c3540000000000000000707071007e00647371007e00660000000a7571007e0069000000037371007e006b0374001573757065727669736f72795f6e6f64655f636f64657371007e006b017400052b272d272b7371007e006b0374001573757065727669736f72795f6e6f64655f6e616d65707070707070707070707070707371007e002a0000c35400000014000100000000000000f4000000ca000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e00468b47c18385282767a2f59c46025d43280000c3547070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e008171007e008171007e007f707371007e00590000c3547070707071007e008171007e0081707371007e00530000c3547070707071007e008171007e0081707371007e005c0000c3547070707071007e008171007e0081707371007e005e0000c3547070707071007e008171007e0081707070707371007e00607070707071007e007f70707070707070707070707070707070700000c3540000000000000000707071007e00647371007e00660000000b7571007e0069000000037371007e006b0374000e77617265686f7573655f636f64657371007e006b017400052b272d272b7371007e006b0374000e77617265686f7573655f6e616d65707070707070707070707070707371007e002a0000c354000000140001000000000000004f00000225000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e0046be94070ffee2354714e89f25808142c80000c3547070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e009271007e009271007e0090707371007e00590000c3547070707071007e009271007e0092707371007e00530000c3547070707071007e009271007e0092707371007e005c0000c3547070707071007e009271007e0092707371007e005e0000c3547070707071007e009271007e0092707070707371007e00607070707071007e009070707070707070707070707070707070700000c3540000000000000000707071007e00647371007e00660000000c7571007e0069000000017371007e006b0374000f6674705f63726564656e7469616c73707070707070707070707070707371007e002a0000c354000000140001000000000000002d000001be000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e0046ad15db8d78a464acdc1c17ae7dcc427f0000c3547070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e009f71007e009f71007e009d707371007e00590000c3547070707071007e009f71007e009f707371007e00530000c3547070707071007e009f71007e009f707371007e005c0000c3547070707071007e009f71007e009f707371007e005e0000c3547070707071007e009f71007e009f707070707371007e00607070707071007e009d70707070707070707070707070707070700000c3540000000000000000707071007e00647371007e00660000000d7571007e0069000000017371007e006b03740006616374697665707070707070707070707070707371007e002a0000c354000000140001000000000000003a000001eb000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e00469861a07f42fc42a53fd6951d3b9346150000c3547070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e00ac71007e00ac71007e00aa707371007e00590000c3547070707071007e00ac71007e00ac707371007e00530000c3547070707071007e00ac71007e00ac707371007e005c0000c3547070707071007e00ac71007e00ac707371007e005e0000c3547070707071007e00ac71007e00ac707070707371007e00607070707071007e00aa70707070707070707070707070707070700000c3540000000000000000707071007e00647371007e00660000000e7571007e0069000000017371007e006b03740007656e61626c6564707070707070707070707070707371007e002a0000c354000000140001000000000000009900000274000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e0046bf4b5560f753e6ae3b6201ef3bb64bb50000c3547070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e00b971007e00b971007e00b7707371007e00590000c3547070707071007e00b971007e00b9707371007e00530000c3547070707071007e00b971007e00b9707371007e005c0000c3547070707071007e00b971007e00b9707371007e005e0000c3547070707071007e00b971007e00b9707070707371007e00607070707071007e00b770707070707070707070707070707070700000c3540000000000000000707071007e00647371007e00660000000f7571007e0069000000017371007e006b0374000c70726f6772616d5f6e616d657070707070707070707070707078700000c35400000014017070707070707400046a617661707372002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173654461746173657400000000000027d802001149001950534555444f5f53455249414c5f56455253494f4e5f5549445a000669734d61696e4200177768656e5265736f757263654d697373696e67547970655b00066669656c64737400265b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a524669656c643b4c001066696c74657245787072657373696f6e71007e00125b000667726f7570737400265b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5247726f75703b4c00046e616d6571007e00025b000a706172616d657465727374002a5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52506172616d657465723b4c000d70726f706572746965734d617071007e00134c000571756572797400254c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5251756572793b4c000e7265736f7572636542756e646c6571007e00024c000e7363726970746c6574436c61737371007e00025b000a7363726970746c65747374002a5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525363726970746c65743b5b000a736f72744669656c647374002a5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52536f72744669656c643b4c00047575696471007e003e5b00097661726961626c65737400295b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525661726961626c653b4c001c7768656e5265736f757263654d697373696e675479706556616c756574003e4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5768656e5265736f757263654d697373696e6754797065456e756d3b78700000c3540100757200265b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a524669656c643b023cdfc74e2af27002000078700000000a7372002c6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173654669656c6400000000000027d80200054c000b6465736372697074696f6e71007e00024c00046e616d6571007e00024c000d70726f706572746965734d617071007e00134c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e0002787070740017737570706c795f6c696e655f6465736372697074696f6e7372002b6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5250726f706572746965734d617000000000000027d80200034c00046261736571007e00134c000e70726f706572746965734c69737471007e00174c000d70726f706572746965734d617074000f4c6a6176612f7574696c2f4d61703b78707070707400106a6176612e6c616e672e537472696e67707371007e00d17074001573757065727669736f72795f6e6f64655f636f64657371007e00d47070707400106a6176612e6c616e672e537472696e67707371007e00d17074001573757065727669736f72795f6e6f64655f6e616d657371007e00d47070707400106a6176612e6c616e672e537472696e67707371007e00d17074000e77617265686f7573655f636f64657371007e00d47070707400106a6176612e6c616e672e537472696e67707371007e00d17074000e77617265686f7573655f6e616d657371007e00d47070707400106a6176612e6c616e672e537472696e67707371007e00d1707400066163746976657371007e00d47070707400116a6176612e6c616e672e426f6f6c65616e707371007e00d170740007656e61626c65647371007e00d47070707400116a6176612e6c616e672e426f6f6c65616e707371007e00d17074000f6674705f63726564656e7469616c737371007e00d47070707400116a6176612e6c616e672e426f6f6c65616e707371007e00d17074000c70726f6772616d5f636f64657371007e00d47070707400106a6176612e6c616e672e537472696e67707371007e00d17074000c70726f6772616d5f6e616d657371007e00d47070707400106a6176612e6c616e672e537472696e677070707400077265706f7274317572002a5b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a52506172616d657465723b22000c8d2ac36021020000787000000013737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365506172616d6574657200000000000027d80200095a000e6973466f7250726f6d7074696e675a000f697353797374656d446566696e65644c001664656661756c7456616c756545787072657373696f6e71007e00124c000b6465736372697074696f6e71007e00024c00046e616d6571007e00024c000e6e6573746564547970654e616d6571007e00024c000d70726f706572746965734d617071007e00134c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e000278700101707074000e5245504f52545f434f4e54455854707371007e00d47070707400296e65742e73662e6a61737065727265706f7274732e656e67696e652e5265706f7274436f6e74657874707371007e00ff010170707400155245504f52545f504152414d45544552535f4d4150707371007e00d470707074000d6a6176612e7574696c2e4d6170707371007e00ff0101707074000d4a41535045525f5245504f5254707371007e00d47070707400286e65742e73662e6a61737065727265706f7274732e656e67696e652e4a61737065725265706f7274707371007e00ff010170707400115245504f52545f434f4e4e454354494f4e707371007e00d47070707400136a6176612e73716c2e436f6e6e656374696f6e707371007e00ff010170707400105245504f52545f4d41585f434f554e54707371007e00d47070707400116a6176612e6c616e672e496e7465676572707371007e00ff010170707400125245504f52545f444154415f534f55524345707371007e00d47070707400286e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5244617461536f75726365707371007e00ff010170707400105245504f52545f5343524950544c4554707371007e00d470707074002f6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5241627374726163745363726970746c6574707371007e00ff0101707074000d5245504f52545f4c4f43414c45707371007e00d47070707400106a6176612e7574696c2e4c6f63616c65707371007e00ff010170707400165245504f52545f5245534f555243455f42554e444c45707371007e00d47070707400186a6176612e7574696c2e5265736f7572636542756e646c65707371007e00ff010170707400105245504f52545f54494d455f5a4f4e45707371007e00d47070707400126a6176612e7574696c2e54696d655a6f6e65707371007e00ff010170707400155245504f52545f464f524d41545f464143544f5259707371007e00d470707074002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e7574696c2e466f726d6174466163746f7279707371007e00ff010170707400135245504f52545f434c4153535f4c4f41444552707371007e00d47070707400156a6176612e6c616e672e436c6173734c6f61646572707371007e00ff0101707074001a5245504f52545f55524c5f48414e444c45525f464143544f5259707371007e00d47070707400206a6176612e6e65742e55524c53747265616d48616e646c6572466163746f7279707371007e00ff010170707400145245504f52545f46494c455f5245534f4c564552707371007e00d470707074002d6e65742e73662e6a61737065727265706f7274732e656e67696e652e7574696c2e46696c655265736f6c766572707371007e00ff010170707400105245504f52545f54454d504c41544553707371007e00d47070707400146a6176612e7574696c2e436f6c6c656374696f6e707371007e00ff0101707074000b534f52545f4649454c4453707371007e00d470707074000e6a6176612e7574696c2e4c697374707371007e00ff0101707074000646494c544552707371007e00d47070707400296e65742e73662e6a61737065727265706f7274732e656e67696e652e4461746173657446696c746572707371007e00ff010170707400125245504f52545f5649525455414c495a4552707371007e00d47070707400296e65742e73662e6a61737065727265706f7274732e656e67696e652e4a525669727475616c697a6572707371007e00ff0101707074001449535f49474e4f52455f504147494e4154494f4e707371007e00d47070707400116a6176612e6c616e672e426f6f6c65616e707371007e00d4707371007e001a0000000377040000000374000c697265706f72742e7a6f6f6d740009697265706f72742e78740009697265706f72742e7978737200116a6176612e7574696c2e486173684d61700507dac1c31660d103000246000a6c6f6164466163746f724900097468726573686f6c6478703f400000000000037708000000040000000371007e01507400013071007e014e740003312e3071007e014f74000130787372002c6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365517565727900000000000027d80200025b00066368756e6b7374002b5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5251756572794368756e6b3b4c00086c616e677561676571007e000278707572002b5b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5251756572794368756e6b3b409f00a1e8ba34a4020000787000000001737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736551756572794368756e6b00000000000027d8020003420004747970654c00047465787471007e00025b0006746f6b656e737400135b4c6a6176612f6c616e672f537472696e673b78700174030c53454c4543540a2020736c2e6465736372697074696f6e20415320737570706c795f6c696e655f6465736372697074696f6e2c0a2020736e2e636f6465202020202020202041532073757065727669736f72795f6e6f64655f636f64652c0a2020736e2e6e616d65202020202020202041532073757065727669736f72795f6e6f64655f6e616d652c0a2020662e636f646520202020202020202041532077617265686f7573655f636f64652c0a2020662e6e616d6520202020202020202041532077617265686f7573655f6e616d652c0a2020662e616374697665202020202020204153206163746976652c0a2020662e656e61626c6564202020202020415320656e61626c65642c0a202043415345205748454e206666642e6964204953206e756c6c205448454e2046414c53450a2020454c5345205452554520454e4420204153206674705f63726564656e7469616c732c0a2020702e636f646520202020202020202041532070726f6772616d5f636f64652c0a2020702e6e616d6520202020202020202041532070726f6772616d5f6e616d650a46524f4d20737570706c795f6c696e657320736c20494e4e4552204a4f494e20666163696c697469657320660a202020204f4e20736c2e737570706c79696e67666163696c6974796964203d20662e69640a2020494e4e4552204a4f494e2070726f6772616d7320700a202020204f4e20736c2e70726f6772616d6964203d20702e69640a2020494e4e4552204a4f494e2073757065727669736f72795f6e6f64657320736e0a202020204f4e20736c2e73757065727669736f72796e6f64656964203d20736e2e69640a20204c454654204a4f494e20666163696c6974795f6674705f64657461696c73206666640a202020204f4e20662e6964203d206666642e666163696c69747969640a574845524520286666642e6964204953206e756c6c204f5220662e656e61626c6564203d2046414c53452920414e4420736c2e6578706f72746f7264657273203d20545255450a4f5244455220425920662e636f64652c20662e6e616d652c20702e6e616d657074000373716c707070707371007e0046b3d554b1aefe96cea0a4e8610726422f757200295b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a525661726961626c653b62e6837c982cb7440200007870000000057372002f6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655661726961626c6500000000000027d802001149001950534555444f5f53455249414c5f56455253494f4e5f55494442000b63616c63756c6174696f6e42000d696e6372656d656e74547970655a000f697353797374656d446566696e65644200097265736574547970654c001063616c63756c6174696f6e56616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f43616c63756c6174696f6e456e756d3b4c000a65787072657373696f6e71007e00124c000e696e6372656d656e7447726f757071007e002b4c0012696e6372656d656e745479706556616c75657400344c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f496e6372656d656e7454797065456e756d3b4c001b696e6372656d656e746572466163746f7279436c6173734e616d6571007e00024c001f696e6372656d656e746572466163746f7279436c6173735265616c4e616d6571007e00024c0016696e697469616c56616c756545787072657373696f6e71007e00124c00046e616d6571007e00024c000a726573657447726f757071007e002b4c000e72657365745479706556616c75657400304c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f526573657454797065456e756d3b4c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e00027870000077ee000001007e7200306e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e43616c63756c6174696f6e456e756d00000000000000001200007871007e001d74000653595354454d70707e7200326e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e496e6372656d656e7454797065456e756d00000000000000001200007871007e001d7400044e4f4e4570707371007e0066000000007571007e0069000000017371007e006b017400186e6577206a6176612e6c616e672e496e7465676572283129707074000b504147455f4e554d424552707e72002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e526573657454797065456e756d00000000000000001200007871007e001d7400065245504f525471007e0113707371007e0163000077ee0000010071007e0169707071007e016c70707371007e0066000000017571007e0069000000017371007e006b017400186e6577206a6176612e6c616e672e496e7465676572283129707074000d434f4c554d4e5f4e554d424552707e71007e01737400045041474571007e0113707371007e0163000077ee000001007e71007e0168740005434f554e547371007e0066000000027571007e0069000000017371007e006b017400186e6577206a6176612e6c616e672e496e746567657228312970707071007e016c70707371007e0066000000037571007e0069000000017371007e006b017400186e6577206a6176612e6c616e672e496e7465676572283029707074000c5245504f52545f434f554e547071007e017471007e0113707371007e0163000077ee0000010071007e017f7371007e0066000000047571007e0069000000017371007e006b017400186e6577206a6176612e6c616e672e496e746567657228312970707071007e016c70707371007e0066000000057571007e0069000000017371007e006b017400186e6577206a6176612e6c616e672e496e7465676572283029707074000a504147455f434f554e547071007e017c71007e0113707371007e0163000077ee0000010071007e017f7371007e0066000000067571007e0069000000017371007e006b017400186e6577206a6176612e6c616e672e496e746567657228312970707071007e016c70707371007e0066000000077571007e0069000000017371007e006b017400186e6577206a6176612e6c616e672e496e7465676572283029707074000c434f4c554d4e5f434f554e54707e71007e0173740006434f4c554d4e71007e0113707e72003c6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5768656e5265736f757263654d697373696e6754797065456e756d00000000000000001200007871007e001d7400044e554c4c71007e00fc7371007e00117371007e001a0000000277040000000a737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655374617469635465787400000000000027d80200014c00047465787471007e00027871007e002f0000c354000000140001000000000000030e00000000000000207071007e001071007e01a370707070707071007e00417070707071007e00447371007e00468769af621a8e549b488f93d8d2fe4df60000c3547070707070707371007e00480000000f7071007e004c7070707070707070707371007e004e707371007e00520000c3547070707071007e01a971007e01a971007e01a6707371007e00590000c3547070707071007e01a971007e01a9707371007e00530000c3547070707071007e01a971007e01a9707371007e005c0000c3547070707071007e01a971007e01a9707371007e005e0000c3547070707071007e01a971007e01a9707070707371007e00607070707071007e01a670707070707070707070707070707070707400124e6f2070726f626c656d7320666f756e642e7371007e01a50000c354000000200001000000000000030e00000000000000007071007e001071007e01a370707070707071007e00417070707071007e00447371007e00469238092a1177a2f66659ba1e006b4f7f0000c354707070707074000953616e7353657269667371007e0048000000187071007e004c7070707070737200116a6176612e6c616e672e426f6f6c65616ecd207280d59cfaee0200015a000576616c75657870017070707371007e004e707371007e00520000c3547070707071007e01b771007e01b771007e01b1707371007e00590000c3547070707071007e01b771007e01b7707371007e00530000c3547070707071007e01b771007e01b7707371007e005c0000c3547070707071007e01b771007e01b7707371007e005e0000c3547070707071007e01b771007e01b7707070707371007e00607070707071007e01b1707070707070707070707070707070707074001d4f7264657220526f7574696e6720496e636f6e73697374656e6369657378700000c3540000003401707070707e7200306e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e4f7269656e746174696f6e456e756d00000000000000001200007871007e001d7400094c414e4453434150457371007e00117371007e001a0000000277040000000a7371007e002a0000c3540000001400010000000000000048000002c6000000007071007e001071007e01c270707070707071007e00417070707071007e00447371007e0046a6cd4885e72541551abcd2c71ce14a4b0000c354707070707074000953616e7353657269667371007e00480000000870707070707070707070707371007e004e707371007e00520000c3547070707071007e01c871007e01c871007e01c4707371007e00590000c3547070707071007e01c871007e01c8707371007e00530000c3547070707071007e01c871007e01c8707371007e005c0000c3547070707071007e01c871007e01c8707371007e005e0000c3547070707071007e01c871007e01c8707070707371007e00607070707071007e01c470707070707070707070707070707070700000c3540000000000000000707071007e00647371007e0066000000107571007e0069000000017371007e006b0474000b504147455f4e554d424552707070707070707070707070707371007e01a50000c35400000014000100000000000002c600000000000000007071007e001071007e01c270707070707071007e00417070707071007e00447371007e0046b62f68c26194b7c32e4a2985b90149630000c3547070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e01d571007e01d571007e01d3707371007e00590000c3547070707071007e01d571007e01d5707371007e00530000c3547070707071007e01d571007e01d5707371007e005c0000c3547070707071007e01d571007e01d5707371007e005e0000c3547070707071007e01d571007e01d5707070707371007e00607070707071007e01d370707070707070707070707070707070707400012078700000c3540000001401707070707371007e00117371007e001a0000000777040000000a7371007e01a50000c35400000014000100000000000000f3000000cb000000007071007e001071007e01dd70707070707071007e00417070707071007e00447371007e00469f72d87cd57c5a0d9a07393f55224bce0000c354707070707074000953616e7353657269667371007e00480000000c707071007e01b67070707071007e01b67070707371007e004e707371007e00520000c3547070707071007e01e371007e01e371007e01df707371007e00590000c3547070707071007e01e371007e01e3707371007e00530000c3547070707071007e01e371007e01e3707371007e005c0000c3547070707071007e01e371007e01e3707371007e005e0000c3547070707071007e01e371007e01e3707070707371007e00607070707071007e01df707070707070707070707070707070707074000957617265686f7573657371007e01a50000c35400000014000100000000000000a500000026000000007071007e001071007e01dd70707070707071007e00417070707071007e00447371007e0046835adf817aa47786a3153510d28746ad0000c354707070707074000953616e73536572696671007e01e2707071007e01b67070707071007e01b67070707371007e004e707371007e00520000c3547070707071007e01ee71007e01ee71007e01eb707371007e00590000c3547070707071007e01ee71007e01ee707371007e00530000c3547070707071007e01ee71007e01ee707371007e005c0000c3547070707071007e01ee71007e01ee707371007e005e0000c3547070707071007e01ee71007e01ee707070707371007e00607070707071007e01eb707070707070707070707070707070707074001053757065727669736f7279204e6f64657371007e01a50000c354000000140001000000000000002600000000000000007071007e001071007e01dd70707070707071007e00417070707071007e00447371007e0046b48a4feb4161ed645a7f10ba925c4ca70000c354707070707074000953616e73536572696671007e01e27071007e004c71007e01b67070707071007e01b67070707371007e004e707371007e00520000c3547070707071007e01f971007e01f971007e01f6707371007e00590000c3547070707071007e01f971007e01f9707371007e00530000c3547070707071007e01f971007e01f9707371007e005c0000c3547070707071007e01f971007e01f9707371007e005e0000c3547070707071007e01f971007e01f9707070707371007e00607070707071007e01f67070707070707070707070707070707070740004532e4e6f7371007e01a50000c354000000140001000000000000004f00000225000000007071007e001071007e01dd70707070707071007e00417070707071007e00447371007e004695811259740284767a2bce85864e42e70000c354707070707074000953616e73536572696671007e01e2707071007e01b67070707071007e01b67070707371007e004e707371007e00520000c3547070707071007e020471007e020471007e0201707371007e00590000c3547070707071007e020471007e0204707371007e00530000c3547070707071007e020471007e0204707371007e005c0000c3547070707071007e020471007e0204707371007e005e0000c3547070707071007e020471007e0204707070707371007e00607070707071007e0201707070707070707070707070707070707074000b46545020646566696e65647371007e01a50000c354000000140001000000000000002d000001be000000007071007e001071007e01dd70707070707071007e00417070707071007e00447371007e0046b7b4b30a376656ba715dcbaedc744fa20000c354707070707074000953616e73536572696671007e01e2707071007e01b67070707071007e01b67070707371007e004e707371007e00520000c3547070707071007e020f71007e020f71007e020c707371007e00590000c3547070707071007e020f71007e020f707371007e00530000c3547070707071007e020f71007e020f707371007e005c0000c3547070707071007e020f71007e020f707371007e005e0000c3547070707071007e020f71007e020f707070707371007e00607070707071007e020c70707070707070707070707070707070707400064163746976657371007e01a50000c354000000140001000000000000003a000001eb000000007071007e001071007e01dd70707070707071007e00417070707071007e00447371007e0046a1d1003a31f7a8ed10a02754cce143370000c354707070707074000953616e73536572696671007e01e2707071007e01b67070707071007e01b67070707371007e004e707371007e00520000c3547070707071007e021a71007e021a71007e0217707371007e00590000c3547070707071007e021a71007e021a707371007e00530000c3547070707071007e021a71007e021a707371007e005c0000c3547070707071007e021a71007e021a707371007e005e0000c3547070707071007e021a71007e021a707070707371007e00607070707071007e02177070707070707070707070707070707070740007456e61626c65647371007e01a50000c354000000140001000000000000009900000274000000007071007e001071007e01dd70707070707071007e00417070707071007e00447371007e00469b596670c74bd785ef159a2f33d942ba0000c354707070707074000953616e73536572696671007e01e2707071007e01b67070707071007e01b67070707371007e004e707371007e00520000c3547070707071007e022571007e022571007e0222707371007e00590000c3547070707071007e022571007e0225707371007e00530000c3547070707071007e022571007e0225707371007e005c0000c3547070707071007e022571007e0225707371007e005e0000c3547070707071007e022571007e0225707070707371007e00607070707071007e0222707070707070707070707070707070707074000750726f6772616d78700000c354000000140170707071007e001e7e72002f6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5072696e744f72646572456e756d00000000000000001200007871007e001d740008564552544943414c757200265b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a525374796c653bd49cc311d90572350200007870000000087372002c6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655374796c65000000000000271102003a49001950534555444f5f53455249414c5f56455253494f4e5f5549445a0009697344656661756c744c00096261636b636f6c6f7271007e00304c0006626f7264657271007e00144c000b626f72646572436f6c6f7271007e00304c000c626f74746f6d426f7264657271007e00144c0011626f74746f6d426f72646572436f6c6f7271007e00304c000d626f74746f6d50616464696e6771007e00315b0011636f6e646974696f6e616c5374796c65737400315b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52436f6e646974696f6e616c5374796c653b4c001464656661756c745374796c6550726f766964657271007e00394c000466696c6c71007e00144c000966696c6c56616c756574002b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f46696c6c456e756d3b4c0008666f6e744e616d6571007e00024c0008666f6e7453697a6571007e00314c0009666f7265636f6c6f7271007e00304c0013686f72697a6f6e74616c416c69676e6d656e7471007e00144c0018686f72697a6f6e74616c416c69676e6d656e7456616c756571007e00324c000f6973426c616e6b5768656e4e756c6c71007e002e4c00066973426f6c6471007e002e4c000869734974616c696371007e002e4c000d6973506466456d62656464656471007e002e4c000f6973537472696b655468726f75676871007e002e4c000c69735374796c65645465787471007e002e4c000b6973556e6465726c696e6571007e002e4c000a6c656674426f7264657271007e00144c000f6c656674426f72646572436f6c6f7271007e00304c000b6c65667450616464696e6771007e00314c00076c696e65426f7871007e00334c00076c696e6550656e7400234c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250656e3b4c000b6c696e6553706163696e6771007e00144c00106c696e6553706163696e6756616c756571007e00344c00066d61726b757071007e00024c00046d6f646571007e00144c00096d6f646556616c756571007e003a4c00046e616d6571007e00024c000770616464696e6771007e00314c000970617261677261706871007e00354c000b706172656e745374796c6571007e00074c0018706172656e745374796c654e616d655265666572656e636571007e00024c00077061747465726e71007e00024c000b706466456e636f64696e6771007e00024c000b706466466f6e744e616d6571007e00024c000370656e71007e00144c000c706f736974696f6e5479706571007e00144c000672616469757371007e00314c000b7269676874426f7264657271007e00144c00107269676874426f72646572436f6c6f7271007e00304c000c726967687450616464696e6771007e00314c0008726f746174696f6e71007e00144c000d726f746174696f6e56616c756571007e00364c000a7363616c65496d61676571007e00144c000f7363616c65496d61676556616c75657400314c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5363616c65496d616765456e756d3b4c000b737472657463685479706571007e00144c0009746f70426f7264657271007e00144c000e746f70426f72646572436f6c6f7271007e00304c000a746f7050616464696e6771007e00314c0011766572746963616c416c69676e6d656e7471007e00144c0016766572746963616c416c69676e6d656e7456616c756571007e003778700000c35400707070707070707070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e023871007e023871007e0237707371007e00590000c3547070707071007e023871007e0238707371007e00530000c3547372000e6a6176612e6177742e436f6c6f7201a51783108f337502000546000666616c70686149000576616c75654c0002637374001b4c6a6176612f6177742f636f6c6f722f436f6c6f7253706163653b5b00096672676276616c75657400025b465b00066676616c756571007e023e787000000000ff00000070707070707372000f6a6176612e6c616e672e466c6f6174daedc9a2db3cf0ec02000146000576616c75657871007e00493f80000071007e023871007e0238707371007e005c0000c3547070707071007e023871007e0238707371007e005e0000c3547070707071007e023871007e02387371007e00540000c3547070707071007e023770707070707400057461626c65707371007e00607070707071007e023770707070707070707070707070707070707070707070707070707371007e02320000c354007371007e023c00000000fff0f8ff7070707070707070707070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e024971007e024971007e0247707371007e00590000c3547070707071007e024971007e0249707371007e00530000c3547371007e023c00000000ff00000070707070707371007e02403f00000071007e024971007e0249707371007e005c0000c3547070707071007e024971007e0249707371007e005e0000c3547070707071007e024971007e02497371007e00540000c3547070707071007e0247707070707e7200296e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e4d6f6465456e756d00000000000000001200007871007e001d7400064f50415155457400087461626c655f5448707371007e00607070707071007e024770707070707070707070707070707070707070707070707070707371007e02320000c354007371007e023c00000000ffbfe1ff7070707070707070707070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e025971007e025971007e0257707371007e00590000c3547070707071007e025971007e0259707371007e00530000c3547371007e023c00000000ff00000070707070707371007e02403f00000071007e025971007e0259707371007e005c0000c3547070707071007e025971007e0259707371007e005e0000c3547070707071007e025971007e02597371007e00540000c3547070707071007e02577070707071007e02537400087461626c655f4348707371007e00607070707071007e025770707070707070707070707070707070707070707070707070707371007e02320000c354007371007e023c00000000ffffffff7070707070707070707070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e026671007e026671007e0264707371007e00590000c3547070707071007e026671007e0266707371007e00530000c3547371007e023c00000000ff00000070707070707371007e02403f00000071007e026671007e0266707371007e005c0000c3547070707071007e026671007e0266707371007e005e0000c3547070707071007e026671007e02667371007e00540000c3547070707071007e02647070707071007e02537400087461626c655f5444707371007e00607070707071007e026470707070707070707070707070707070707070707070707070707371007e02320000c35400707070707070707070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e027271007e027271007e0271707371007e00590000c3547070707071007e027271007e0272707371007e00530000c3547371007e023c00000000ff00000070707070707371007e02403f80000071007e027271007e0272707371007e005c0000c3547070707071007e027271007e0272707371007e005e0000c3547070707071007e027271007e02727371007e00540000c3547070707071007e027170707070707400077461626c652031707371007e00607070707071007e027170707070707070707070707070707070707070707070707070707371007e02320000c354007371007e023c00000000fff0f8ff7070707070707070707070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e027f71007e027f71007e027d707371007e00590000c3547070707071007e027f71007e027f707371007e00530000c3547371007e023c00000000ff00000070707070707371007e02403f00000071007e027f71007e027f707371007e005c0000c3547070707071007e027f71007e027f707371007e005e0000c3547070707071007e027f71007e027f7371007e00540000c3547070707071007e027d7070707071007e025374000a7461626c6520315f5448707371007e00607070707071007e027d70707070707070707070707070707070707070707070707070707371007e02320000c354007371007e023c00000000ffbfe1ff7070707070707070707070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e028c71007e028c71007e028a707371007e00590000c3547070707071007e028c71007e028c707371007e00530000c3547371007e023c00000000ff00000070707070707371007e02403f00000071007e028c71007e028c707371007e005c0000c3547070707071007e028c71007e028c707371007e005e0000c3547070707071007e028c71007e028c7371007e00540000c3547070707071007e028a7070707071007e025374000a7461626c6520315f4348707371007e00607070707071007e028a70707070707070707070707070707070707070707070707070707371007e02320000c354007371007e023c00000000ffffffff7070707070707070707070707070707070707070707070707070707371007e004e707371007e00520000c3547070707071007e029971007e029971007e0297707371007e00590000c3547070707071007e029971007e0299707371007e00530000c3547371007e023c00000000ff00000070707070707371007e02403f00000071007e029971007e0299707371007e005c0000c3547070707071007e029971007e0299707371007e005e0000c3547070707071007e029971007e02997371007e00540000c3547070707071007e02977070707071007e025374000a7461626c6520315f5444707371007e00607070707071007e0297707070707070707070707070707070707070707070707070707070707371007e00117371007e001a0000000277040000000a7371007e01a50000c35400000020000100000000000002c500000000000000007071007e001071007e02a470707070707071007e00417070707071007e00447371007e00468f61a735ab2074b7212194e972ca43210000c354707070707074000953616e73536572696671007e01b47071007e004c707070707071007e01b67070707371007e004e707371007e00520000c3547070707071007e02a971007e02a971007e02a6707371007e00590000c3547070707071007e02a971007e02a9707371007e00530000c3547070707071007e02a971007e02a9707371007e005c0000c3547070707071007e02a971007e02a9707371007e005e0000c3547070707071007e02a971007e02a9707070707371007e00607070707071007e02a6707070707070707070707070707070707074001d4f7264657220526f7574696e6720496e636f6e73697374656e636965737371007e002a0000c3540000002000010000000000000048000002c5000000007071007e001071007e02a470707070707071007e00417070707071007e00447371007e004689ab02f2dda79bb52dd094dce4b543c00000c354707070707074000953616e73536572696671007e01c770707070707070707070707371007e004e707371007e00520000c3547070707071007e02b471007e02b471007e02b1707371007e00590000c3547070707071007e02b471007e02b4707371007e00530000c3547070707071007e02b471007e02b4707371007e005c0000c3547070707071007e02b471007e02b4707371007e005e0000c3547070707071007e02b471007e02b4707070707371007e00607070707071007e02b170707070707070707070707070707070700000c3540000000000000000707071007e00647371007e0066000000087571007e0069000000017371007e006b017400146e6577206a6176612e7574696c2e446174652829707070707070707070707074000a64642f4d4d2f797979797078700000c3540000002001707070707e7200336e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5768656e4e6f4461746154797065456e756d00000000000000001200007871007e001d74000f4e4f5f444154415f53454354494f4e737200366e65742e73662e6a61737065727265706f7274732e656e67696e652e64657369676e2e4a525265706f7274436f6d70696c654461746100000000000027d80200034c001363726f7373746162436f6d70696c654461746171007e00d54c001264617461736574436f6d70696c654461746171007e00d54c00166d61696e44617461736574436f6d70696c654461746171007e000178707371007e01513f4000000000000c77080000001000000000787371007e01513f4000000000000c7708000000100000000078757200025b42acf317f8060854e002000078700000197dcafebabe0000002e010401001c7265706f7274315f313338303137383732303936345f32323932373407000101002c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a524576616c7561746f72070003010017706172616d657465725f5245504f52545f4c4f43414c450100324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c506172616d657465723b010017706172616d657465725f4a41535045525f5245504f525401001c706172616d657465725f5245504f52545f5649525455414c495a455201001a706172616d657465725f5245504f52545f54494d455f5a4f4e45010015706172616d657465725f534f52545f4649454c445301001e706172616d657465725f5245504f52545f46494c455f5245534f4c56455201001a706172616d657465725f5245504f52545f5343524950544c455401001f706172616d657465725f5245504f52545f504152414d45544552535f4d415001001b706172616d657465725f5245504f52545f434f4e4e454354494f4e010018706172616d657465725f5245504f52545f434f4e5445585401001d706172616d657465725f5245504f52545f434c4153535f4c4f41444552010024706172616d657465725f5245504f52545f55524c5f48414e444c45525f464143544f525901001c706172616d657465725f5245504f52545f444154415f534f5552434501001e706172616d657465725f49535f49474e4f52455f504147494e4154494f4e010010706172616d657465725f46494c54455201001f706172616d657465725f5245504f52545f464f524d41545f464143544f525901001a706172616d657465725f5245504f52545f4d41585f434f554e5401001a706172616d657465725f5245504f52545f54454d504c41544553010020706172616d657465725f5245504f52545f5245534f555243455f42554e444c450100146669656c645f77617265686f7573655f6e616d6501002e4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c4669656c643b01000d6669656c645f656e61626c65640100126669656c645f70726f6772616d5f636f64650100126669656c645f70726f6772616d5f6e616d6501001b6669656c645f73757065727669736f72795f6e6f64655f636f646501001b6669656c645f73757065727669736f72795f6e6f64655f6e616d650100156669656c645f6674705f63726564656e7469616c7301000c6669656c645f6163746976650100146669656c645f77617265686f7573655f636f646501001d6669656c645f737570706c795f6c696e655f6465736372697074696f6e0100147661726961626c655f504147455f4e554d4245520100314c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c5661726961626c653b0100167661726961626c655f434f4c554d4e5f4e554d4245520100157661726961626c655f5245504f52545f434f554e540100137661726961626c655f504147455f434f554e540100157661726961626c655f434f4c554d4e5f434f554e540100063c696e69743e010003282956010004436f64650c002a002b0a0004002d0c00050006090002002f0c0007000609000200310c0008000609000200330c0009000609000200350c000a000609000200370c000b000609000200390c000c0006090002003b0c000d0006090002003d0c000e0006090002003f0c000f000609000200410c0010000609000200430c0011000609000200450c0012000609000200470c0013000609000200490c00140006090002004b0c00150006090002004d0c00160006090002004f0c0017000609000200510c0018000609000200530c0019001a09000200550c001b001a09000200570c001c001a09000200590c001d001a090002005b0c001e001a090002005d0c001f001a090002005f0c0020001a09000200610c0021001a09000200630c0022001a09000200650c0023001a09000200670c0024002509000200690c00260025090002006b0c00270025090002006d0c00280025090002006f0c00290025090002007101000f4c696e654e756d6265725461626c6501000e637573746f6d697a6564496e6974010030284c6a6176612f7574696c2f4d61703b4c6a6176612f7574696c2f4d61703b4c6a6176612f7574696c2f4d61703b295601000a696e6974506172616d73010012284c6a6176612f7574696c2f4d61703b29560c007600770a0002007801000a696e69744669656c64730c007a00770a0002007b010008696e6974566172730c007d00770a0002007e01000d5245504f52545f4c4f43414c4508008001000d6a6176612f7574696c2f4d6170070082010003676574010026284c6a6176612f6c616e672f4f626a6563743b294c6a6176612f6c616e672f4f626a6563743b0c008400850b008300860100306e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c506172616d6574657207008801000d4a41535045525f5245504f525408008a0100125245504f52545f5649525455414c495a455208008c0100105245504f52545f54494d455f5a4f4e4508008e01000b534f52545f4649454c44530800900100145245504f52545f46494c455f5245534f4c5645520800920100105245504f52545f5343524950544c45540800940100155245504f52545f504152414d45544552535f4d41500800960100115245504f52545f434f4e4e454354494f4e08009801000e5245504f52545f434f4e5445585408009a0100135245504f52545f434c4153535f4c4f4144455208009c01001a5245504f52545f55524c5f48414e444c45525f464143544f525908009e0100125245504f52545f444154415f534f555243450800a001001449535f49474e4f52455f504147494e4154494f4e0800a201000646494c5445520800a40100155245504f52545f464f524d41545f464143544f52590800a60100105245504f52545f4d41585f434f554e540800a80100105245504f52545f54454d504c415445530800aa0100165245504f52545f5245534f555243455f42554e444c450800ac01000e77617265686f7573655f6e616d650800ae01002c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c4669656c640700b0010007656e61626c65640800b201000c70726f6772616d5f636f64650800b401000c70726f6772616d5f6e616d650800b601001573757065727669736f72795f6e6f64655f636f64650800b801001573757065727669736f72795f6e6f64655f6e616d650800ba01000f6674705f63726564656e7469616c730800bc0100066163746976650800be01000e77617265686f7573655f636f64650800c0010017737570706c795f6c696e655f6465736372697074696f6e0800c201000b504147455f4e554d4245520800c401002f6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c5661726961626c650700c601000d434f4c554d4e5f4e554d4245520800c801000c5245504f52545f434f554e540800ca01000a504147455f434f554e540800cc01000c434f4c554d4e5f434f554e540800ce0100086576616c756174650100152849294c6a6176612f6c616e672f4f626a6563743b01000a457863657074696f6e730100136a6176612f6c616e672f5468726f7761626c650700d30100116a6176612f6c616e672f496e74656765720700d5010004284929560c002a00d70a00d600d801000e6a6176612f7574696c2f446174650700da0a00db002d01000867657456616c756501001428294c6a6176612f6c616e672f4f626a6563743b0c00dd00de0a00c700df0100166a6176612f6c616e672f537472696e674275666665720700e10a00b100df0100106a6176612f6c616e672f537472696e670700e401000776616c75654f66010026284c6a6176612f6c616e672f4f626a6563743b294c6a6176612f6c616e672f537472696e673b0c00e600e70a00e500e8010015284c6a6176612f6c616e672f537472696e673b29560c002a00ea0a00e200eb010006617070656e6401001b2843294c6a6176612f6c616e672f537472696e674275666665723b0c00ed00ee0a00e200ef01002c284c6a6176612f6c616e672f537472696e673b294c6a6176612f6c616e672f537472696e674275666665723b0c00ed00f10a00e200f2010008746f537472696e6701001428294c6a6176612f6c616e672f537472696e673b0c00f400f50a00e200f60100116a6176612f6c616e672f426f6f6c65616e0700f801000b6576616c756174654f6c6401000b6765744f6c6456616c75650c00fb00de0a00c700fc0a00b100fc0100116576616c75617465457374696d61746564010011676574457374696d6174656456616c75650c010000de0a00c7010101000a536f7572636546696c650021000200040000002200020005000600000002000700060000000200080006000000020009000600000002000a000600000002000b000600000002000c000600000002000d000600000002000e000600000002000f0006000000020010000600000002001100060000000200120006000000020013000600000002001400060000000200150006000000020016000600000002001700060000000200180006000000020019001a00000002001b001a00000002001c001a00000002001d001a00000002001e001a00000002001f001a000000020020001a000000020021001a000000020022001a000000020023001a00000002002400250000000200260025000000020027002500000002002800250000000200290025000000080001002a002b0001002c0000015300020001000000af2ab7002e2a01b500302a01b500322a01b500342a01b500362a01b500382a01b5003a2a01b5003c2a01b5003e2a01b500402a01b500422a01b500442a01b500462a01b500482a01b5004a2a01b5004c2a01b5004e2a01b500502a01b500522a01b500542a01b500562a01b500582a01b5005a2a01b5005c2a01b5005e2a01b500602a01b500622a01b500642a01b500662a01b500682a01b5006a2a01b5006c2a01b5006e2a01b500702a01b50072b100000001007300000092002400000012000400190009001a000e001b0013001c0018001d001d001e0022001f00270020002c00210031002200360023003b00240040002500450026004a0027004f0028005400290059002a005e002b0063002c0068002d006d002e0072002f00770030007c00310081003200860033008b00340090003500950036009a0037009f003800a4003900a9003a00ae00120001007400750001002c0000003400020004000000102a2bb700792a2cb7007c2a2db7007fb10000000100730000001200040000004600050047000a0048000f00490002007600770001002c000001bb00030002000001572a2b1281b900870200c00089c00089b500302a2b128bb900870200c00089c00089b500322a2b128db900870200c00089c00089b500342a2b128fb900870200c00089c00089b500362a2b1291b900870200c00089c00089b500382a2b1293b900870200c00089c00089b5003a2a2b1295b900870200c00089c00089b5003c2a2b1297b900870200c00089c00089b5003e2a2b1299b900870200c00089c00089b500402a2b129bb900870200c00089c00089b500422a2b129db900870200c00089c00089b500442a2b129fb900870200c00089c00089b500462a2b12a1b900870200c00089c00089b500482a2b12a3b900870200c00089c00089b5004a2a2b12a5b900870200c00089c00089b5004c2a2b12a7b900870200c00089c00089b5004e2a2b12a9b900870200c00089c00089b500502a2b12abb900870200c00089c00089b500522a2b12adb900870200c00089c00089b50054b10000000100730000005200140000005100120052002400530036005400480055005a0056006c0057007e00580090005900a2005a00b4005b00c6005c00d8005d00ea005e00fc005f010e0060012000610132006201440063015600640002007a00770001002c000000f500030002000000b52a2b12afb900870200c000b1c000b1b500562a2b12b3b900870200c000b1c000b1b500582a2b12b5b900870200c000b1c000b1b5005a2a2b12b7b900870200c000b1c000b1b5005c2a2b12b9b900870200c000b1c000b1b5005e2a2b12bbb900870200c000b1c000b1b500602a2b12bdb900870200c000b1c000b1b500622a2b12bfb900870200c000b1c000b1b500642a2b12c1b900870200c000b1c000b1b500662a2b12c3b900870200c000b1c000b1b50068b10000000100730000002e000b0000006c0012006d0024006e0036006f00480070005a0071006c0072007e00730090007400a2007500b400760002007d00770001002c00000087000300020000005b2a2b12c5b900870200c000c7c000c7b5006a2a2b12c9b900870200c000c7c000c7b5006c2a2b12cbb900870200c000c7c000c7b5006e2a2b12cdb900870200c000c7c000c7b500702a2b12cfb900870200c000c7c000c7b50072b10000000100730000001a00060000007e0012007f002400800036008100480082005a0083000100d000d1000200d200000004000100d4002c00000210000300030000016c014d1baa000001670000000000000010000000510000005d0000006900000075000000810000008d00000099000000a5000000b1000000bc000000ca000000f70000012400000132000001400000014e0000015cbb00d65904b700d94da7010dbb00d65904b700d94da70101bb00d65904b700d94da700f5bb00d65903b700d94da700e9bb00d65904b700d94da700ddbb00d65903b700d94da700d1bb00d65904b700d94da700c5bb00d65903b700d94da700b9bb00db59b700dc4da700ae2ab4006eb600e0c000d64da700a0bb00e2592ab4005eb600e3c000e5b800e9b700ec102db600f02ab40060b600e3c000e5b600f3b600f74da70073bb00e2592ab40066b600e3c000e5b800e9b700ec102db600f02ab40056b600e3c000e5b600f3b600f74da700462ab40062b600e3c000f94da700382ab40064b600e3c000f94da7002a2ab40058b600e3c000f94da7001c2ab4005cb600e3c000e54da7000e2ab4006ab600e0c000d64d2cb00000000100730000009200240000008b0002008d00540091005d00920060009600690097006c009b0075009c007800a0008100a1008400a5008d00a6009000aa009900ab009c00af00a500b000a800b400b100b500b400b900bc00ba00bf00be00ca00bf00cd00c300f700c400fa00c8012400c9012700cd013200ce013500d2014000d3014300d7014e00d8015100dc015c00dd015f00e1016a00e9000100fa00d1000200d200000004000100d4002c00000210000300030000016c014d1baa000001670000000000000010000000510000005d0000006900000075000000810000008d00000099000000a5000000b1000000bc000000ca000000f70000012400000132000001400000014e0000015cbb00d65904b700d94da7010dbb00d65904b700d94da70101bb00d65904b700d94da700f5bb00d65903b700d94da700e9bb00d65904b700d94da700ddbb00d65903b700d94da700d1bb00d65904b700d94da700c5bb00d65903b700d94da700b9bb00db59b700dc4da700ae2ab4006eb600fdc000d64da700a0bb00e2592ab4005eb600fec000e5b800e9b700ec102db600f02ab40060b600fec000e5b600f3b600f74da70073bb00e2592ab40066b600fec000e5b800e9b700ec102db600f02ab40056b600fec000e5b600f3b600f74da700462ab40062b600fec000f94da700382ab40064b600fec000f94da7002a2ab40058b600fec000f94da7001c2ab4005cb600fec000e54da7000e2ab4006ab600fdc000d64d2cb0000000010073000000920024000000f2000200f4005400f8005d00f9006000fd006900fe006c01020075010300780107008101080084010c008d010d0090011100990112009c011600a5011700a8011b00b1011c00b4012000bc012100bf012500ca012600cd012a00f7012b00fa012f012401300127013401320135013501390140013a0143013e014e013f01510143015c0144015f0148016a0150000100ff00d1000200d200000004000100d4002c00000210000300030000016c014d1baa000001670000000000000010000000510000005d0000006900000075000000810000008d00000099000000a5000000b1000000bc000000ca000000f70000012400000132000001400000014e0000015cbb00d65904b700d94da7010dbb00d65904b700d94da70101bb00d65904b700d94da700f5bb00d65903b700d94da700e9bb00d65904b700d94da700ddbb00d65903b700d94da700d1bb00d65904b700d94da700c5bb00d65903b700d94da700b9bb00db59b700dc4da700ae2ab4006eb60102c000d64da700a0bb00e2592ab4005eb600e3c000e5b800e9b700ec102db600f02ab40060b600e3c000e5b600f3b600f74da70073bb00e2592ab40066b600e3c000e5b800e9b700ec102db600f02ab40056b600e3c000e5b600f3b600f74da700462ab40062b600e3c000f94da700382ab40064b600e3c000f94da7002a2ab40058b600e3c000f94da7001c2ab4005cb600e3c000e54da7000e2ab4006ab60102c000d64d2cb0000000010073000000920024000001590002015b0054015f005d01600060016400690165006c01690075016a0078016e0081016f00840173008d01740090017800990179009c017d00a5017e00a8018200b1018300b4018700bc018800bf018c00ca018d00cd019100f7019200fa0196012401970127019b0132019c013501a0014001a1014301a5014e01a6015101aa015c01ab015f01af016a01b7000101030000000200017400155f313338303137383732303936345f3232393237347400326e65742e73662e6a61737065727265706f7274732e656e67696e652e64657369676e2e4a524a61766163436f6d70696c6572	\N	2014-10-27 12:28:16.5479	Consistency Report	\N
9	Delivery Zones Missing Manage Distribution Role	\\xaced0005737200286e65742e73662e6a61737065727265706f7274732e656e67696e652e4a61737065725265706f727400000000000027d80200034c000b636f6d70696c65446174617400164c6a6176612f696f2f53657269616c697a61626c653b4c0011636f6d70696c654e616d655375666669787400124c6a6176612f6c616e672f537472696e673b4c000d636f6d70696c6572436c61737371007e00027872002d6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655265706f727400000000000027d802002a49001950534555444f5f53455249414c5f56455253494f4e5f55494449000c626f74746f6d4d617267696e49000b636f6c756d6e436f756e7449000d636f6c756d6e53706163696e6749000b636f6c756d6e57696474685a001069676e6f7265506167696e6174696f6e5a00136973466c6f6174436f6c756d6e466f6f7465725a0010697353756d6d6172794e6577506167655a0020697353756d6d6172795769746850616765486561646572416e64466f6f7465725a000e69735469746c654e65775061676549000a6c6566744d617267696e42000b6f7269656e746174696f6e49000a7061676548656967687449000970616765576964746842000a7072696e744f7264657249000b72696768744d617267696e490009746f704d617267696e42000e7768656e4e6f44617461547970654c000a6261636b67726f756e647400244c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5242616e643b4c000f636f6c756d6e446972656374696f6e7400334c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f52756e446972656374696f6e456e756d3b4c000c636f6c756d6e466f6f74657271007e00044c000c636f6c756d6e48656164657271007e00045b000864617461736574737400285b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52446174617365743b4c000c64656661756c745374796c657400254c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525374796c653b4c000664657461696c71007e00044c000d64657461696c53656374696f6e7400274c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5253656374696f6e3b4c0012666f726d6174466163746f7279436c61737371007e00024c000a696d706f72747353657474000f4c6a6176612f7574696c2f5365743b4c00086c616e677561676571007e00024c000e6c61737450616765466f6f74657271007e00044c000b6d61696e446174617365747400274c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52446174617365743b4c00046e616d6571007e00024c00066e6f4461746171007e00044c00106f7269656e746174696f6e56616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4f7269656e746174696f6e456e756d3b4c000a70616765466f6f74657271007e00044c000a7061676548656164657271007e00044c000f7072696e744f7264657256616c75657400314c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5072696e744f72646572456e756d3b5b00067374796c65737400265b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525374796c653b4c000773756d6d61727971007e00045b000974656d706c6174657374002f5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525265706f727454656d706c6174653b4c00057469746c6571007e00044c00137768656e4e6f446174615479706556616c75657400354c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5768656e4e6f4461746154797065456e756d3b78700000c3540000000000000001000000000000030e000100000000000000000000022b0000030e000000000000000000007372002b6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736542616e6400000000000027d802000749001950534555444f5f53455249414c5f56455253494f4e5f5549444900066865696768745a000e697353706c6974416c6c6f7765644c00137072696e745768656e45787072657373696f6e74002a4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5245787072657373696f6e3b4c000d70726f706572746965734d617074002d4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250726f706572746965734d61703b4c000973706c6974547970657400104c6a6176612f6c616e672f427974653b4c000e73706c69745479706556616c75657400304c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f53706c697454797065456e756d3b787200336e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365456c656d656e7447726f757000000000000027d80200024c00086368696c6472656e7400104c6a6176612f7574696c2f4c6973743b4c000c656c656d656e7447726f757074002c4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52456c656d656e7447726f75703b7870737200136a6176612e7574696c2e41727261794c6973747881d21d99c7619d03000149000473697a6578700000000077040000000a78700000c35400000000017070707e72002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e53706c697454797065456e756d00000000000000001200007872000e6a6176612e6c616e672e456e756d00000000000000001200007870740007535452455443487e7200316e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e52756e446972656374696f6e456e756d00000000000000001200007871007e001d7400034c545270707070707372002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736553656374696f6e00000000000027d80200015b000562616e64737400255b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5242616e643b7870757200255b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5242616e643b95dd7eec8cca85350200007870000000017371007e00117371007e001a0000000577040000000a737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365546578744669656c6400000000000027d802001549001950534555444f5f53455249414c5f56455253494f4e5f55494449000d626f6f6b6d61726b4c6576656c42000e6576616c756174696f6e54696d6542000f68797065726c696e6b54617267657442000d68797065726c696e6b547970655a0015697353747265746368576974684f766572666c6f774c0014616e63686f724e616d6545787072657373696f6e71007e00124c000f6576616c756174696f6e47726f75707400254c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5247726f75703b4c00136576616c756174696f6e54696d6556616c75657400354c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4576616c756174696f6e54696d65456e756d3b4c000a65787072657373696f6e71007e00124c001968797065726c696e6b416e63686f7245787072657373696f6e71007e00124c001768797065726c696e6b5061676545787072657373696f6e71007e00125b001368797065726c696e6b506172616d65746572737400335b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5248797065726c696e6b506172616d657465723b4c001c68797065726c696e6b5265666572656e636545787072657373696f6e71007e00124c001a68797065726c696e6b546f6f6c74697045787072657373696f6e71007e00124c001768797065726c696e6b5768656e45787072657373696f6e71007e00124c000f6973426c616e6b5768656e4e756c6c7400134c6a6176612f6c616e672f426f6f6c65616e3b4c000a6c696e6b54617267657471007e00024c00086c696e6b5479706571007e00024c00077061747465726e71007e00024c00117061747465726e45787072657373696f6e71007e0012787200326e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736554657874456c656d656e7400000000000027d802002549001950534555444f5f53455249414c5f56455253494f4e5f5549444c0006626f7264657271007e00144c000b626f72646572436f6c6f727400104c6a6176612f6177742f436f6c6f723b4c000c626f74746f6d426f7264657271007e00144c0011626f74746f6d426f72646572436f6c6f7271007e00304c000d626f74746f6d50616464696e677400134c6a6176612f6c616e672f496e74656765723b4c0008666f6e744e616d6571007e00024c0008666f6e7453697a6571007e00314c0013686f72697a6f6e74616c416c69676e6d656e7471007e00144c0018686f72697a6f6e74616c416c69676e6d656e7456616c75657400364c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f486f72697a6f6e74616c416c69676e456e756d3b4c00066973426f6c6471007e002e4c000869734974616c696371007e002e4c000d6973506466456d62656464656471007e002e4c000f6973537472696b655468726f75676871007e002e4c000c69735374796c65645465787471007e002e4c000b6973556e6465726c696e6571007e002e4c000a6c656674426f7264657271007e00144c000f6c656674426f72646572436f6c6f7271007e00304c000b6c65667450616464696e6771007e00314c00076c696e65426f787400274c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a524c696e65426f783b4c000b6c696e6553706163696e6771007e00144c00106c696e6553706163696e6756616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4c696e6553706163696e67456e756d3b4c00066d61726b757071007e00024c000770616464696e6771007e00314c00097061726167726170687400294c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525061726167726170683b4c000b706466456e636f64696e6771007e00024c000b706466466f6e744e616d6571007e00024c000b7269676874426f7264657271007e00144c00107269676874426f72646572436f6c6f7271007e00304c000c726967687450616464696e6771007e00314c0008726f746174696f6e71007e00144c000d726f746174696f6e56616c756574002f4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f526f746174696f6e456e756d3b4c0009746f70426f7264657271007e00144c000e746f70426f72646572436f6c6f7271007e00304c000a746f7050616464696e6771007e00314c0011766572746963616c416c69676e6d656e7471007e00144c0016766572746963616c416c69676e6d656e7456616c75657400344c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f566572746963616c416c69676e456e756d3b7872002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365456c656d656e7400000000000027d802001b49001950534555444f5f53455249414c5f56455253494f4e5f5549444900066865696768745a001769735072696e74496e466972737457686f6c6542616e645a001569735072696e74526570656174656456616c7565735a001a69735072696e745768656e44657461696c4f766572666c6f77735a0015697352656d6f76654c696e655768656e426c616e6b42000c706f736974696f6e5479706542000b7374726574636854797065490005776964746849000178490001794c00096261636b636f6c6f7271007e00304c001464656661756c745374796c6550726f76696465727400344c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5244656661756c745374796c6550726f76696465723b4c000c656c656d656e7447726f757071007e00184c0009666f7265636f6c6f7271007e00304c00036b657971007e00024c00046d6f646571007e00144c00096d6f646556616c756574002b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4d6f6465456e756d3b4c000b706172656e745374796c6571007e00074c0018706172656e745374796c654e616d655265666572656e636571007e00024c0011706f736974696f6e5479706556616c75657400334c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f506f736974696f6e54797065456e756d3b4c00137072696e745768656e45787072657373696f6e71007e00124c00157072696e745768656e47726f75704368616e67657371007e002b4c000d70726f706572746965734d617071007e00135b001370726f706572747945787072657373696f6e737400335b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250726f706572747945787072657373696f6e3b4c0010737472657463685479706556616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5374726574636854797065456e756d3b4c0004757569647400104c6a6176612f7574696c2f555549443b78700000c35400000014000100000000000000970000006f000000007071007e001071007e00287070707070707e7200316e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e506f736974696f6e54797065456e756d00000000000000001200007871007e001d7400134649585f52454c41544956455f544f5f544f50707070707e7200306e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5374726574636854797065456e756d00000000000000001200007871007e001d74000a4e4f5f535452455443487372000e6a6176612e7574696c2e55554944bc9903f7986d852f0200024a000c6c65617374536967426974734a000b6d6f7374536967426974737870a9d9fbfb06612a8f3d8316284452410d0000c354707070707074000953616e735365726966737200116a6176612e6c616e672e496e746567657212e2a0a4f781873802000149000576616c7565787200106a6176612e6c616e672e4e756d62657286ac951d0b94e08b02000078700000000c70707070707070707070707372002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173654c696e65426f7800000000000027d802000b4c000d626f74746f6d50616464696e6771007e00314c0009626f74746f6d50656e74002b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f626173652f4a52426f7850656e3b4c000c626f78436f6e7461696e657274002c4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52426f78436f6e7461696e65723b4c000b6c65667450616464696e6771007e00314c00076c65667450656e71007e004d4c000770616464696e6771007e00314c000370656e71007e004d4c000c726967687450616464696e6771007e00314c0008726967687450656e71007e004d4c000a746f7050616464696e6771007e00314c0006746f7050656e71007e004d787070737200336e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f78426f74746f6d50656e00000000000027d80200007872002d6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f7850656e00000000000027d80200014c00076c696e65426f7871007e00337872002a6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736550656e00000000000027d802000649001950534555444f5f53455249414c5f56455253494f4e5f5549444c00096c696e65436f6c6f7271007e00304c00096c696e655374796c6571007e00144c000e6c696e655374796c6556616c75657400304c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f4c696e655374796c65456e756d3b4c00096c696e6557696474687400114c6a6176612f6c616e672f466c6f61743b4c000c70656e436f6e7461696e657274002c4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250656e436f6e7461696e65723b78700000c3547070707071007e004f71007e004f71007e003f70737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f784c65667450656e00000000000027d80200007871007e00510000c3547070707071007e004f71007e004f707371007e00510000c3547070707071007e004f71007e004f70737200326e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f78526967687450656e00000000000027d80200007871007e00510000c3547070707071007e004f71007e004f70737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365426f78546f7050656e00000000000027d80200007871007e00510000c3547070707071007e004f71007e004f70707070737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736550617261677261706800000000000027d802000a4c000f66697273744c696e65496e64656e7471007e00314c000a6c656674496e64656e7471007e00314c000b6c696e6553706163696e6771007e00344c000f6c696e6553706163696e6753697a6571007e00544c0012706172616772617068436f6e7461696e65727400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52506172616772617068436f6e7461696e65723b4c000b7269676874496e64656e7471007e00314c000c73706163696e67416674657271007e00314c000d73706163696e674265666f726571007e00314c000c74616253746f70576964746871007e00314c000874616253746f707371007e001778707070707071007e003f70707070707070707070707070707070700000c354000000000000000070707e7200336e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e4576616c756174696f6e54696d65456e756d00000000000000001200007871007e001d7400034e4f57737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736545787072657373696f6e00000000000027d802000449000269645b00066368756e6b737400305b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5245787072657373696f6e4368756e6b3b4c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e0002787000000009757200305b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5245787072657373696f6e4368756e6b3b6d59cfde694ba355020000787000000001737200366e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736545787072657373696f6e4368756e6b00000000000027d8020002420004747970654c00047465787471007e000278700374001064656c69766572795a6f6e65436f6465707070707070707070707070707371007e002a0000c35400000014000100000000000000b600000106000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e0046980c6e20451ed89f70a35c82b9a34c1e0000c354707070707074000953616e73536572696671007e004b70707070707070707070707371007e004c707371007e00500000c3547070707071007e006f71007e006f71007e006c707371007e00570000c3547070707071007e006f71007e006f707371007e00510000c3547070707071007e006f71007e006f707371007e005a0000c3547070707071007e006f71007e006f707371007e005c0000c3547070707071007e006f71007e006f707070707371007e005e7070707071007e006c70707070707070707070707070707070700000c3540000000000000000707071007e00627371007e00640000000a7571007e0067000000017371007e00690374001064656c69766572795a6f6e654e616d65707070707070707070707070707371007e002a0000c35400000014000100000000000000ac000001bc000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e00468cdc613a1d372dff871fa864f59149dc0000c354707070707074000953616e73536572696671007e004b707e7200346e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e486f72697a6f6e74616c416c69676e456e756d00000000000000001200007871007e001d7400044c4546547070707070707070707371007e004c707371007e00500000c3547070707071007e008071007e008071007e007a707371007e00570000c3547070707071007e008071007e0080707371007e00510000c3547070707071007e008071007e0080707371007e005a0000c3547070707071007e008071007e0080707371007e005c0000c3547070707071007e008071007e0080707070707371007e005e7070707071007e007a70707070707070707070707070707070700000c3540000000000000000707071007e00627371007e00640000000b7571007e0067000000017371007e00690374000b70726f6772616d436f6465707070707070707070707070707371007e002a0000c35400000014000100000000000000a600000268000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e004696f153581ae1e4c682939d7efb594d750000c354707070707074000953616e73536572696671007e004b7071007e007e7070707070707070707371007e004c707371007e00500000c3547070707071007e008e71007e008e71007e008b707371007e00570000c3547070707071007e008e71007e008e707371007e00510000c3547070707071007e008e71007e008e707371007e005a0000c3547070707071007e008e71007e008e707371007e005c0000c3547070707071007e008e71007e008e707070707371007e005e7070707071007e008b70707070707070707070707070707070700000c3540000000000000000707071007e00627371007e00640000000c7571007e0067000000017371007e00690374000b70726f6772616d4e616d65707070707070707070707070707371007e002a0000c354000000140001000000000000006f00000000000000007071007e001071007e002870707070707071007e00417070707071007e00447371007e0046a3c35f9512886f9f0cb682e445b14bae0000c35470707070707071007e004b707e71007e007d74000643454e5445527070707070707070707371007e004c707371007e00500000c3547070707071007e009d71007e009d71007e0099707371007e00570000c3547070707071007e009d71007e009d707371007e00510000c3547070707071007e009d71007e009d707371007e005a0000c3547070707071007e009d71007e009d707371007e005c0000c3547070707071007e009d71007e009d707070707371007e005e7070707071007e009970707070707070707070707070707070700000c3540000000000000000707071007e00627371007e00640000000d7571007e0067000000017371007e00690474000c5245504f52545f434f554e547070707070707070707070707078700000c35400000014017070707070707400046a617661707372002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173654461746173657400000000000027d802001149001950534555444f5f53455249414c5f56455253494f4e5f5549445a000669734d61696e4200177768656e5265736f757263654d697373696e67547970655b00066669656c64737400265b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a524669656c643b4c001066696c74657245787072657373696f6e71007e00125b000667726f7570737400265b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5247726f75703b4c00046e616d6571007e00025b000a706172616d657465727374002a5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52506172616d657465723b4c000d70726f706572746965734d617071007e00134c000571756572797400254c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5251756572793b4c000e7265736f7572636542756e646c6571007e00024c000e7363726970746c6574436c61737371007e00025b000a7363726970746c65747374002a5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525363726970746c65743b5b000a736f72744669656c647374002a5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52536f72744669656c643b4c00047575696471007e003e5b00097661726961626c65737400295b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a525661726961626c653b4c001c7768656e5265736f757263654d697373696e675479706556616c756574003e4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5768656e5265736f757263654d697373696e6754797065456e756d3b78700000c3540100757200265b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a524669656c643b023cdfc74e2af2700200007870000000047372002c6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173654669656c6400000000000027d80200054c000b6465736372697074696f6e71007e00024c00046e616d6571007e00024c000d70726f706572746965734d617071007e00134c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e000278707074001064656c69766572795a6f6e65436f64657372002b6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5250726f706572746965734d617000000000000027d80200034c00046261736571007e00134c000e70726f706572746965734c69737471007e00174c000d70726f706572746965734d617074000f4c6a6176612f7574696c2f4d61703b78707070707400106a6176612e6c616e672e537472696e67707371007e00b57074001064656c69766572795a6f6e654e616d657371007e00b87070707400106a6176612e6c616e672e537472696e67707371007e00b57074000b70726f6772616d436f64657371007e00b87070707400106a6176612e6c616e672e537472696e67707371007e00b57074000b70726f6772616d4e616d657371007e00b87070707400106a6176612e6c616e672e537472696e677070707400077265706f7274317572002a5b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a52506172616d657465723b22000c8d2ac36021020000787000000013737200306e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365506172616d6574657200000000000027d80200095a000e6973466f7250726f6d7074696e675a000f697353797374656d446566696e65644c001664656661756c7456616c756545787072657373696f6e71007e00124c000b6465736372697074696f6e71007e00024c00046e616d6571007e00024c000e6e6573746564547970654e616d6571007e00024c000d70726f706572746965734d617071007e00134c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e000278700101707074000e5245504f52545f434f4e54455854707371007e00b87070707400296e65742e73662e6a61737065727265706f7274732e656e67696e652e5265706f7274436f6e74657874707371007e00cb010170707400155245504f52545f504152414d45544552535f4d4150707371007e00b870707074000d6a6176612e7574696c2e4d6170707371007e00cb0101707074000d4a41535045525f5245504f5254707371007e00b87070707400286e65742e73662e6a61737065727265706f7274732e656e67696e652e4a61737065725265706f7274707371007e00cb010170707400115245504f52545f434f4e4e454354494f4e707371007e00b87070707400136a6176612e73716c2e436f6e6e656374696f6e707371007e00cb010170707400105245504f52545f4d41585f434f554e54707371007e00b87070707400116a6176612e6c616e672e496e7465676572707371007e00cb010170707400125245504f52545f444154415f534f55524345707371007e00b87070707400286e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5244617461536f75726365707371007e00cb010170707400105245504f52545f5343524950544c4554707371007e00b870707074002f6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5241627374726163745363726970746c6574707371007e00cb0101707074000d5245504f52545f4c4f43414c45707371007e00b87070707400106a6176612e7574696c2e4c6f63616c65707371007e00cb010170707400165245504f52545f5245534f555243455f42554e444c45707371007e00b87070707400186a6176612e7574696c2e5265736f7572636542756e646c65707371007e00cb010170707400105245504f52545f54494d455f5a4f4e45707371007e00b87070707400126a6176612e7574696c2e54696d655a6f6e65707371007e00cb010170707400155245504f52545f464f524d41545f464143544f5259707371007e00b870707074002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e7574696c2e466f726d6174466163746f7279707371007e00cb010170707400135245504f52545f434c4153535f4c4f41444552707371007e00b87070707400156a6176612e6c616e672e436c6173734c6f61646572707371007e00cb0101707074001a5245504f52545f55524c5f48414e444c45525f464143544f5259707371007e00b87070707400206a6176612e6e65742e55524c53747265616d48616e646c6572466163746f7279707371007e00cb010170707400145245504f52545f46494c455f5245534f4c564552707371007e00b870707074002d6e65742e73662e6a61737065727265706f7274732e656e67696e652e7574696c2e46696c655265736f6c766572707371007e00cb010170707400105245504f52545f54454d504c41544553707371007e00b87070707400146a6176612e7574696c2e436f6c6c656374696f6e707371007e00cb0101707074000b534f52545f4649454c4453707371007e00b870707074000e6a6176612e7574696c2e4c697374707371007e00cb0101707074000646494c544552707371007e00b87070707400296e65742e73662e6a61737065727265706f7274732e656e67696e652e4461746173657446696c746572707371007e00cb010170707400125245504f52545f5649525455414c495a4552707371007e00b87070707400296e65742e73662e6a61737065727265706f7274732e656e67696e652e4a525669727475616c697a6572707371007e00cb0101707074001449535f49474e4f52455f504147494e4154494f4e707371007e00b87070707400116a6176612e6c616e672e426f6f6c65616e707371007e00b8707371007e001a0000000377040000000374000c697265706f72742e7a6f6f6d740009697265706f72742e78740009697265706f72742e7978737200116a6176612e7574696c2e486173684d61700507dac1c31660d103000246000a6c6f6164466163746f724900097468726573686f6c6478703f400000000000037708000000040000000371007e011c7400013071007e011a740003312e3071007e011b74000130787372002c6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a5242617365517565727900000000000027d80200025b00066368756e6b7374002b5b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5251756572794368756e6b3b4c00086c616e677561676571007e000278707572002b5b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a5251756572794368756e6b3b409f00a1e8ba34a4020000787000000001737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a524261736551756572794368756e6b00000000000027d8020003420004747970654c00047465787471007e00025b0006746f6b656e737400135b4c6a6176612f6c616e672f537472696e673b7870017403a773656c65637420647a2e636f64652061732064656c69766572795a6f6e65436f64652c20647a2e6e616d652061732064656c69766572795a6f6e654e616d652c20702e636f64652061732070726f6772616d436f64652c20702e6e616d652061732070726f6772616d4e616d652066726f6d2064656c69766572795f7a6f6e657320647a2c2064656c69766572795f7a6f6e655f70726f6772616d5f7363686564756c657320647a70732c20726f6c655f61737369676e6d656e74732072612c202070726f6772616d7320702c207573657273207520776865726520647a2e69643d647a70732e64656c69766572797a6f6e65696420616e6420647a70732e64656c69766572797a6f6e6569643d72612e64656c69766572797a6f6e65696420616e6420752e69643d72612e75736572696420616e64202072612e64656c69766572797a6f6e6569643d647a2e696420616e6420702e69643d647a70732e70726f6772616d696420616e6420702e69643d72612e70726f6772616d696420616e6420752e6163746976653d2766616c73652720616e6420702e6163746976653d2774727565270a2020202020202020202020202020202020756e696f6e0a202020202020202020202020202020202073656c65637420647a2e636f64652061732064656c69766572795a6f6e65436f64652c20647a2e6e616d652061732064656c69766572795a6f6e654e616d652c20702e636f64652061732070726f6772616d436f64652c20702e6e616d652061732070726f6772616d4e616d652066726f6d2064656c69766572795f7a6f6e657320647a2c2064656c69766572795f7a6f6e655f70726f6772616d5f7363686564756c657320647a70732c2070726f6772616d7320702c726f6c655f61737369676e6d656e74732072612077686572652020647a2e69643d647a70732e64656c69766572797a6f6e65696420616e6420702e69643d647a70732e70726f6772616d696420616e6420702e69643d72612e70726f6772616d696420616e6420647a70732e64656c69766572797a6f6e656964206e6f7420696e202873656c6563742064697374696e63742864656c69766572797a6f6e656964292066726f6d20726f6c655f61737369676e6d656e74732077686572652064656c69766572797a6f6e656964206973206e6f74206e756c6c292067726f757020627920647a2e6e616d652c20647a2e636f64652c20702e636f64652c702e6e616d65206f726465722062792064656c69766572795a6f6e654e616d65206173637074000373716c707070707371007e0046b3d554b1aefe96cea0a4e8610726422f757200295b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a525661726961626c653b62e6837c982cb7440200007870000000057372002f6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655661726961626c6500000000000027d802001149001950534555444f5f53455249414c5f56455253494f4e5f55494442000b63616c63756c6174696f6e42000d696e6372656d656e74547970655a000f697353797374656d446566696e65644200097265736574547970654c001063616c63756c6174696f6e56616c75657400324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f43616c63756c6174696f6e456e756d3b4c000a65787072657373696f6e71007e00124c000e696e6372656d656e7447726f757071007e002b4c0012696e6372656d656e745479706556616c75657400344c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f496e6372656d656e7454797065456e756d3b4c001b696e6372656d656e746572466163746f7279436c6173734e616d6571007e00024c001f696e6372656d656e746572466163746f7279436c6173735265616c4e616d6571007e00024c0016696e697469616c56616c756545787072657373696f6e71007e00124c00046e616d6571007e00024c000a726573657447726f757071007e002b4c000e72657365745479706556616c75657400304c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f526573657454797065456e756d3b4c000e76616c7565436c6173734e616d6571007e00024c001276616c7565436c6173735265616c4e616d6571007e00027870000077ee000001007e7200306e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e43616c63756c6174696f6e456e756d00000000000000001200007871007e001d74000653595354454d70707e7200326e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e496e6372656d656e7454797065456e756d00000000000000001200007871007e001d7400044e4f4e4570707371007e0064000000007571007e0067000000017371007e0069017400186e6577206a6176612e6c616e672e496e7465676572283129707074000b504147455f4e554d424552707e72002e6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e526573657454797065456e756d00000000000000001200007871007e001d7400065245504f525471007e00df707371007e012f000077ee0000010071007e0135707071007e013870707371007e0064000000017571007e0067000000017371007e0069017400186e6577206a6176612e6c616e672e496e7465676572283129707074000d434f4c554d4e5f4e554d424552707e71007e013f7400045041474571007e00df707371007e012f000077ee000001007e71007e0134740005434f554e547371007e0064000000027571007e0067000000017371007e0069017400186e6577206a6176612e6c616e672e496e746567657228312970707071007e013870707371007e0064000000037571007e0067000000017371007e0069017400186e6577206a6176612e6c616e672e496e7465676572283029707074000c5245504f52545f434f554e547071007e014071007e00df707371007e012f000077ee0000010071007e014b7371007e0064000000047571007e0067000000017371007e0069017400186e6577206a6176612e6c616e672e496e746567657228312970707071007e013870707371007e0064000000057571007e0067000000017371007e0069017400186e6577206a6176612e6c616e672e496e7465676572283029707074000a504147455f434f554e547071007e014871007e00df707371007e012f000077ee0000010071007e014b7371007e0064000000067571007e0067000000017371007e0069017400186e6577206a6176612e6c616e672e496e746567657228312970707071007e013870707371007e0064000000077571007e0067000000017371007e0069017400186e6577206a6176612e6c616e672e496e7465676572283029707074000c434f4c554d4e5f434f554e54707e71007e013f740006434f4c554d4e71007e00df707e72003c6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5768656e5265736f757263654d697373696e6754797065456e756d00000000000000001200007871007e001d7400044e554c4c71007e00c87371007e00117371007e001a0000000277040000000a737200316e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655374617469635465787400000000000027d80200014c00047465787471007e00027871007e002f0000c354000000140001000000000000030e00000000000000207071007e001071007e016f70707070707071007e00417070707071007e00447371007e00468769af621a8e549b488f93d8d2fe4df60000c3547070707070707371007e00490000000f7071007e009b7070707070707070707371007e004c707371007e00500000c3547070707071007e017571007e017571007e0172707371007e00570000c3547070707071007e017571007e0175707371007e00510000c3547070707071007e017571007e0175707371007e005a0000c3547070707071007e017571007e0175707371007e005c0000c3547070707071007e017571007e0175707070707371007e005e7070707071007e01727070707070707070707070707070707070740065416c6c2064656c6976657279207a6f6e65732063757272656e746c792068617665206163746976652073746166662061737369676e656420746f206d616e61676520746865206163746976652070726f6772616d7320696e207468657365207a6f6e65732e7371007e01710000c354000000200001000000000000030e00000000000000007071007e001071007e016f70707070707071007e00417070707071007e00447371007e00469238092a1177a2f66659ba1e006b4f7f0000c354707070707074000953616e7353657269667371007e0049000000187071007e009b7070707070737200116a6176612e6c616e672e426f6f6c65616ecd207280d59cfaee0200015a000576616c75657870017070707371007e004c707371007e00500000c3547070707071007e018371007e018371007e017d707371007e00570000c3547070707071007e018371007e0183707371007e00510000c3547070707071007e018371007e0183707371007e005a0000c3547070707071007e018371007e0183707371007e005c0000c3547070707071007e018371007e0183707070707371007e005e7070707071007e017d707070707070707070707070707070707074002f44656c6976657279205a6f6e6573204d697373696e67204d616e61676520446973747269627574696f6e20526f6c6578700000c3540000003401707070707e7200306e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e4f7269656e746174696f6e456e756d00000000000000001200007871007e001d7400094c414e4453434150457371007e00117371007e001a0000000277040000000a7371007e002a0000c3540000001400010000000000000048000002c6000000007071007e001071007e018e70707070707071007e00417070707071007e00447371007e0046a6cd4885e72541551abcd2c71ce14a4b0000c354707070707074000953616e7353657269667371007e00490000000870707070707070707070707371007e004c707371007e00500000c3547070707071007e019471007e019471007e0190707371007e00570000c3547070707071007e019471007e0194707371007e00510000c3547070707071007e019471007e0194707371007e005a0000c3547070707071007e019471007e0194707371007e005c0000c3547070707071007e019471007e0194707070707371007e005e7070707071007e019070707070707070707070707070707070700000c3540000000000000000707071007e00627371007e00640000000e7571007e0067000000017371007e00690474000b504147455f4e554d424552707070707070707070707070707371007e01710000c35400000014000100000000000002c600000000000000007071007e001071007e018e70707070707071007e00417070707071007e00447371007e0046b62f68c26194b7c32e4a2985b90149630000c3547070707070707070707070707070707070707371007e004c707371007e00500000c3547070707071007e01a171007e01a171007e019f707371007e00570000c3547070707071007e01a171007e01a1707371007e00510000c3547070707071007e01a171007e01a1707371007e005a0000c3547070707071007e01a171007e01a1707371007e005c0000c3547070707071007e01a171007e01a1707070707371007e005e7070707071007e019f70707070707070707070707070707070707400012078700000c3540000001401707070707371007e00117371007e001a0000000577040000000a7371007e01710000c35400000014000100000000000000a600000268000000007071007e001071007e01a970707070707071007e00417070707071007e00447371007e00469b596670c74bd785ef159a2f33d942ba0000c354707070707074000953616e73536572696671007e004b707071007e01827070707071007e01827070707371007e004c707371007e00500000c3547070707071007e01ae71007e01ae71007e01ab707371007e00570000c3547070707071007e01ae71007e01ae707371007e00510000c3547070707071007e01ae71007e01ae707371007e005a0000c3547070707071007e01ae71007e01ae707371007e005c0000c3547070707071007e01ae71007e01ae707070707371007e005e7070707071007e01ab707070707070707070707070707070707074000c50726f6772616d204e616d657371007e01710000c35400000014000100000000000000ac000001bc000000007071007e001071007e01a970707070707071007e00417070707071007e00447371007e00469f72d87cd57c5a0d9a07393f55224bce0000c354707070707074000953616e73536572696671007e004b707071007e01827070707071007e01827070707371007e004c707371007e00500000c3547070707071007e01b971007e01b971007e01b6707371007e00570000c3547070707071007e01b971007e01b9707371007e00510000c3547070707071007e01b971007e01b9707371007e005a0000c3547070707071007e01b971007e01b9707371007e005c0000c3547070707071007e01b971007e01b9707070707371007e005e7070707071007e01b6707070707070707070707070707070707074000c50726f6772616d20436f64657371007e01710000c35400000014000100000000000000970000006f000000007071007e001071007e01a970707070707071007e00417070707071007e00447371007e0046a2a43d5c0bd9170ad949733d046b41aa0000c354707070707074000953616e73536572696671007e004b707071007e01827070707071007e01827070707371007e004c707371007e00500000c3547070707071007e01c471007e01c471007e01c1707371007e00570000c3547070707071007e01c471007e01c4707371007e00510000c3547070707071007e01c471007e01c4707371007e005a0000c3547070707071007e01c471007e01c4707371007e005c0000c3547070707071007e01c471007e01c4707070707371007e005e7070707071007e01c1707070707070707070707070707070707074001244656c6976657279205a6f6e6520436f64657371007e01710000c35400000014000100000000000000b600000106000000007071007e001071007e01a970707070707071007e00417070707071007e00447371007e0046835adf817aa47786a3153510d28746ad0000c354707070707074000953616e73536572696671007e004b707071007e01827070707071007e01827070707371007e004c707371007e00500000c3547070707071007e01cf71007e01cf71007e01cc707371007e00570000c3547070707071007e01cf71007e01cf707371007e00510000c3547070707071007e01cf71007e01cf707371007e005a0000c3547070707071007e01cf71007e01cf707371007e005c0000c3547070707071007e01cf71007e01cf707070707371007e005e7070707071007e01cc707070707070707070707070707070707074001244656c6976657279205a6f6e65204e616d657371007e01710000c354000000140001000000000000006f00000000000000007071007e001071007e01a970707070707071007e00417070707071007e00447371007e0046b48a4feb4161ed645a7f10ba925c4ca70000c354707070707074000953616e73536572696671007e004b7071007e009b71007e01827070707071007e01827070707371007e004c707371007e00500000c3547070707071007e01da71007e01da71007e01d7707371007e00570000c3547070707071007e01da71007e01da707371007e00510000c3547070707071007e01da71007e01da707371007e005a0000c3547070707071007e01da71007e01da707371007e005c0000c3547070707071007e01da71007e01da707070707371007e005e7070707071007e01d77070707070707070707070707070707070740004532e4e6f78700000c354000000140170707071007e001e7e72002f6e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5072696e744f72646572456e756d00000000000000001200007871007e001d740008564552544943414c757200265b4c6e65742e73662e6a61737065727265706f7274732e656e67696e652e4a525374796c653bd49cc311d90572350200007870000000087372002c6e65742e73662e6a61737065727265706f7274732e656e67696e652e626173652e4a52426173655374796c65000000000000271102003a49001950534555444f5f53455249414c5f56455253494f4e5f5549445a0009697344656661756c744c00096261636b636f6c6f7271007e00304c0006626f7264657271007e00144c000b626f72646572436f6c6f7271007e00304c000c626f74746f6d426f7264657271007e00144c0011626f74746f6d426f72646572436f6c6f7271007e00304c000d626f74746f6d50616464696e6771007e00315b0011636f6e646974696f6e616c5374796c65737400315b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a52436f6e646974696f6e616c5374796c653b4c001464656661756c745374796c6550726f766964657271007e00394c000466696c6c71007e00144c000966696c6c56616c756574002b4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f46696c6c456e756d3b4c0008666f6e744e616d6571007e00024c0008666f6e7453697a6571007e00314c0009666f7265636f6c6f7271007e00304c0013686f72697a6f6e74616c416c69676e6d656e7471007e00144c0018686f72697a6f6e74616c416c69676e6d656e7456616c756571007e00324c000f6973426c616e6b5768656e4e756c6c71007e002e4c00066973426f6c6471007e002e4c000869734974616c696371007e002e4c000d6973506466456d62656464656471007e002e4c000f6973537472696b655468726f75676871007e002e4c000c69735374796c65645465787471007e002e4c000b6973556e6465726c696e6571007e002e4c000a6c656674426f7264657271007e00144c000f6c656674426f72646572436f6c6f7271007e00304c000b6c65667450616464696e6771007e00314c00076c696e65426f7871007e00334c00076c696e6550656e7400234c6e65742f73662f6a61737065727265706f7274732f656e67696e652f4a5250656e3b4c000b6c696e6553706163696e6771007e00144c00106c696e6553706163696e6756616c756571007e00344c00066d61726b757071007e00024c00046d6f646571007e00144c00096d6f646556616c756571007e003a4c00046e616d6571007e00024c000770616464696e6771007e00314c000970617261677261706871007e00354c000b706172656e745374796c6571007e00074c0018706172656e745374796c654e616d655265666572656e636571007e00024c00077061747465726e71007e00024c000b706466456e636f64696e6771007e00024c000b706466466f6e744e616d6571007e00024c000370656e71007e00144c000c706f736974696f6e5479706571007e00144c000672616469757371007e00314c000b7269676874426f7264657271007e00144c00107269676874426f72646572436f6c6f7271007e00304c000c726967687450616464696e6771007e00314c0008726f746174696f6e71007e00144c000d726f746174696f6e56616c756571007e00364c000a7363616c65496d61676571007e00144c000f7363616c65496d61676556616c75657400314c6e65742f73662f6a61737065727265706f7274732f656e67696e652f747970652f5363616c65496d616765456e756d3b4c000b737472657463685479706571007e00144c0009746f70426f7264657271007e00144c000e746f70426f72646572436f6c6f7271007e00304c000a746f7050616464696e6771007e00314c0011766572746963616c416c69676e6d656e7471007e00144c0016766572746963616c416c69676e6d656e7456616c756571007e003778700000c35400707070707070707070707070707070707070707070707070707371007e004c707371007e00500000c3547070707071007e01ed71007e01ed71007e01ec707371007e00570000c3547070707071007e01ed71007e01ed707371007e00510000c3547372000e6a6176612e6177742e436f6c6f7201a51783108f337502000546000666616c70686149000576616c75654c0002637374001b4c6a6176612f6177742f636f6c6f722f436f6c6f7253706163653b5b00096672676276616c75657400025b465b00066676616c756571007e01f3787000000000ff00000070707070707372000f6a6176612e6c616e672e466c6f6174daedc9a2db3cf0ec02000146000576616c75657871007e004a3f80000071007e01ed71007e01ed707371007e005a0000c3547070707071007e01ed71007e01ed707371007e005c0000c3547070707071007e01ed71007e01ed7371007e00520000c3547070707071007e01ec70707070707400057461626c65707371007e005e7070707071007e01ec70707070707070707070707070707070707070707070707070707371007e01e70000c354007371007e01f100000000fff0f8ff7070707070707070707070707070707070707070707070707070707371007e004c707371007e00500000c3547070707071007e01fe71007e01fe71007e01fc707371007e00570000c3547070707071007e01fe71007e01fe707371007e00510000c3547371007e01f100000000ff00000070707070707371007e01f53f00000071007e01fe71007e01fe707371007e005a0000c3547070707071007e01fe71007e01fe707371007e005c0000c3547070707071007e01fe71007e01fe7371007e00520000c3547070707071007e01fc707070707e7200296e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e4d6f6465456e756d00000000000000001200007871007e001d7400064f50415155457400087461626c655f5448707371007e005e7070707071007e01fc70707070707070707070707070707070707070707070707070707371007e01e70000c354007371007e01f100000000ffbfe1ff7070707070707070707070707070707070707070707070707070707371007e004c707371007e00500000c3547070707071007e020e71007e020e71007e020c707371007e00570000c3547070707071007e020e71007e020e707371007e00510000c3547371007e01f100000000ff00000070707070707371007e01f53f00000071007e020e71007e020e707371007e005a0000c3547070707071007e020e71007e020e707371007e005c0000c3547070707071007e020e71007e020e7371007e00520000c3547070707071007e020c7070707071007e02087400087461626c655f4348707371007e005e7070707071007e020c70707070707070707070707070707070707070707070707070707371007e01e70000c354007371007e01f100000000ffffffff7070707070707070707070707070707070707070707070707070707371007e004c707371007e00500000c3547070707071007e021b71007e021b71007e0219707371007e00570000c3547070707071007e021b71007e021b707371007e00510000c3547371007e01f100000000ff00000070707070707371007e01f53f00000071007e021b71007e021b707371007e005a0000c3547070707071007e021b71007e021b707371007e005c0000c3547070707071007e021b71007e021b7371007e00520000c3547070707071007e02197070707071007e02087400087461626c655f5444707371007e005e7070707071007e021970707070707070707070707070707070707070707070707070707371007e01e70000c35400707070707070707070707070707070707070707070707070707371007e004c707371007e00500000c3547070707071007e022771007e022771007e0226707371007e00570000c3547070707071007e022771007e0227707371007e00510000c3547371007e01f100000000ff00000070707070707371007e01f53f80000071007e022771007e0227707371007e005a0000c3547070707071007e022771007e0227707371007e005c0000c3547070707071007e022771007e02277371007e00520000c3547070707071007e022670707070707400077461626c652031707371007e005e7070707071007e022670707070707070707070707070707070707070707070707070707371007e01e70000c354007371007e01f100000000fff0f8ff7070707070707070707070707070707070707070707070707070707371007e004c707371007e00500000c3547070707071007e023471007e023471007e0232707371007e00570000c3547070707071007e023471007e0234707371007e00510000c3547371007e01f100000000ff00000070707070707371007e01f53f00000071007e023471007e0234707371007e005a0000c3547070707071007e023471007e0234707371007e005c0000c3547070707071007e023471007e02347371007e00520000c3547070707071007e02327070707071007e020874000a7461626c6520315f5448707371007e005e7070707071007e023270707070707070707070707070707070707070707070707070707371007e01e70000c354007371007e01f100000000ffbfe1ff7070707070707070707070707070707070707070707070707070707371007e004c707371007e00500000c3547070707071007e024171007e024171007e023f707371007e00570000c3547070707071007e024171007e0241707371007e00510000c3547371007e01f100000000ff00000070707070707371007e01f53f00000071007e024171007e0241707371007e005a0000c3547070707071007e024171007e0241707371007e005c0000c3547070707071007e024171007e02417371007e00520000c3547070707071007e023f7070707071007e020874000a7461626c6520315f4348707371007e005e7070707071007e023f70707070707070707070707070707070707070707070707070707371007e01e70000c354007371007e01f100000000ffffffff7070707070707070707070707070707070707070707070707070707371007e004c707371007e00500000c3547070707071007e024e71007e024e71007e024c707371007e00570000c3547070707071007e024e71007e024e707371007e00510000c3547371007e01f100000000ff00000070707070707371007e01f53f00000071007e024e71007e024e707371007e005a0000c3547070707071007e024e71007e024e707371007e005c0000c3547070707071007e024e71007e024e7371007e00520000c3547070707071007e024c7070707071007e020874000a7461626c6520315f5444707371007e005e7070707071007e024c707070707070707070707070707070707070707070707070707070707371007e00117371007e001a0000000277040000000a7371007e01710000c35400000020000100000000000002c600000000000000007071007e001071007e025970707070707071007e00417070707071007e00447371007e00468f61a735ab2074b7212194e972ca43210000c354707070707074000953616e73536572696671007e01807071007e009b707070707071007e01827070707371007e004c707371007e00500000c3547070707071007e025e71007e025e71007e025b707371007e00570000c3547070707071007e025e71007e025e707371007e00510000c3547070707071007e025e71007e025e707371007e005a0000c3547070707071007e025e71007e025e707371007e005c0000c3547070707071007e025e71007e025e707070707371007e005e7070707071007e025b707070707070707070707070707070707074002f44656c6976657279205a6f6e6573204d697373696e67204d616e61676520446973747269627574696f6e20526f6c657371007e002a0000c3540000002000010000000000000048000002c6000000007071007e001071007e025970707070707071007e00417070707071007e00447371007e004689ab02f2dda79bb52dd094dce4b543c00000c354707070707074000953616e73536572696671007e019370707070707070707070707371007e004c707371007e00500000c3547070707071007e026971007e026971007e0266707371007e00570000c3547070707071007e026971007e0269707371007e00510000c3547070707071007e026971007e0269707371007e005a0000c3547070707071007e026971007e0269707371007e005c0000c3547070707071007e026971007e0269707070707371007e005e7070707071007e026670707070707070707070707070707070700000c3540000000000000000707071007e00627371007e0064000000087571007e0067000000017371007e0069017400146e6577206a6176612e7574696c2e446174652829707070707070707070707074000a64642f4d4d2f797979797078700000c3540000002001707070707e7200336e65742e73662e6a61737065727265706f7274732e656e67696e652e747970652e5768656e4e6f4461746154797065456e756d00000000000000001200007871007e001d74000f4e4f5f444154415f53454354494f4e737200366e65742e73662e6a61737065727265706f7274732e656e67696e652e64657369676e2e4a525265706f7274436f6d70696c654461746100000000000027d80200034c001363726f7373746162436f6d70696c654461746171007e00b94c001264617461736574436f6d70696c654461746171007e00b94c00166d61696e44617461736574436f6d70696c654461746171007e000178707371007e011d3f4000000000000c77080000001000000000787371007e011d3f4000000000000c7708000000100000000078757200025b42acf317f8060854e00200007870000014c8cafebabe0000002e00d001001b7265706f7274315f313338303137383931343230345f383838373607000101002c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a524576616c7561746f72070003010017706172616d657465725f5245504f52545f4c4f43414c450100324c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c506172616d657465723b010017706172616d657465725f4a41535045525f5245504f525401001c706172616d657465725f5245504f52545f5649525455414c495a455201001a706172616d657465725f5245504f52545f54494d455f5a4f4e45010015706172616d657465725f534f52545f4649454c445301001e706172616d657465725f5245504f52545f46494c455f5245534f4c56455201001a706172616d657465725f5245504f52545f5343524950544c455401001f706172616d657465725f5245504f52545f504152414d45544552535f4d415001001b706172616d657465725f5245504f52545f434f4e4e454354494f4e010018706172616d657465725f5245504f52545f434f4e5445585401001d706172616d657465725f5245504f52545f434c4153535f4c4f41444552010024706172616d657465725f5245504f52545f55524c5f48414e444c45525f464143544f525901001c706172616d657465725f5245504f52545f444154415f534f5552434501001e706172616d657465725f49535f49474e4f52455f504147494e4154494f4e010010706172616d657465725f46494c54455201001f706172616d657465725f5245504f52545f464f524d41545f464143544f525901001a706172616d657465725f5245504f52545f4d41585f434f554e5401001a706172616d657465725f5245504f52545f54454d504c41544553010020706172616d657465725f5245504f52545f5245534f555243455f42554e444c450100116669656c645f70726f6772616d436f646501002e4c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c4669656c643b0100166669656c645f64656c69766572795a6f6e654e616d650100166669656c645f64656c69766572795a6f6e65436f64650100116669656c645f70726f6772616d4e616d650100147661726961626c655f504147455f4e554d4245520100314c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c5661726961626c653b0100167661726961626c655f434f4c554d4e5f4e554d4245520100157661726961626c655f5245504f52545f434f554e540100137661726961626c655f504147455f434f554e540100157661726961626c655f434f4c554d4e5f434f554e540100063c696e69743e010003282956010004436f64650c002400250a000400270c0005000609000200290c00070006090002002b0c00080006090002002d0c00090006090002002f0c000a000609000200310c000b000609000200330c000c000609000200350c000d000609000200370c000e000609000200390c000f0006090002003b0c00100006090002003d0c00110006090002003f0c0012000609000200410c0013000609000200430c0014000609000200450c0015000609000200470c0016000609000200490c00170006090002004b0c00180006090002004d0c0019001a090002004f0c001b001a09000200510c001c001a09000200530c001d001a09000200550c001e001f09000200570c0020001f09000200590c0021001f090002005b0c0022001f090002005d0c0023001f090002005f01000f4c696e654e756d6265725461626c6501000e637573746f6d697a6564496e6974010030284c6a6176612f7574696c2f4d61703b4c6a6176612f7574696c2f4d61703b4c6a6176612f7574696c2f4d61703b295601000a696e6974506172616d73010012284c6a6176612f7574696c2f4d61703b29560c006400650a0002006601000a696e69744669656c64730c006800650a00020069010008696e6974566172730c006b00650a0002006c01000d5245504f52545f4c4f43414c4508006e01000d6a6176612f7574696c2f4d6170070070010003676574010026284c6a6176612f6c616e672f4f626a6563743b294c6a6176612f6c616e672f4f626a6563743b0c007200730b007100740100306e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c506172616d6574657207007601000d4a41535045525f5245504f52540800780100125245504f52545f5649525455414c495a455208007a0100105245504f52545f54494d455f5a4f4e4508007c01000b534f52545f4649454c445308007e0100145245504f52545f46494c455f5245534f4c5645520800800100105245504f52545f5343524950544c45540800820100155245504f52545f504152414d45544552535f4d41500800840100115245504f52545f434f4e4e454354494f4e08008601000e5245504f52545f434f4e544558540800880100135245504f52545f434c4153535f4c4f4144455208008a01001a5245504f52545f55524c5f48414e444c45525f464143544f525908008c0100125245504f52545f444154415f534f5552434508008e01001449535f49474e4f52455f504147494e4154494f4e08009001000646494c5445520800920100155245504f52545f464f524d41545f464143544f52590800940100105245504f52545f4d41585f434f554e540800960100105245504f52545f54454d504c415445530800980100165245504f52545f5245534f555243455f42554e444c4508009a01000b70726f6772616d436f646508009c01002c6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c4669656c6407009e01001064656c69766572795a6f6e654e616d650800a001001064656c69766572795a6f6e65436f64650800a201000b70726f6772616d4e616d650800a401000b504147455f4e554d4245520800a601002f6e65742f73662f6a61737065727265706f7274732f656e67696e652f66696c6c2f4a5246696c6c5661726961626c650700a801000d434f4c554d4e5f4e554d4245520800aa01000c5245504f52545f434f554e540800ac01000a504147455f434f554e540800ae01000c434f4c554d4e5f434f554e540800b00100086576616c756174650100152849294c6a6176612f6c616e672f4f626a6563743b01000a457863657074696f6e730100136a6176612f6c616e672f5468726f7761626c650700b50100116a6176612f6c616e672f496e74656765720700b7010004284929560c002400b90a00b800ba01000e6a6176612f7574696c2f446174650700bc0a00bd002701000867657456616c756501001428294c6a6176612f6c616e672f4f626a6563743b0c00bf00c00a009f00c10100106a6176612f6c616e672f537472696e670700c30a00a900c101000b6576616c756174654f6c6401000b6765744f6c6456616c75650c00c700c00a009f00c80a00a900c80100116576616c75617465457374696d61746564010011676574457374696d6174656456616c75650c00cc00c00a00a900cd01000a536f7572636546696c650021000200040000001c00020005000600000002000700060000000200080006000000020009000600000002000a000600000002000b000600000002000c000600000002000d000600000002000e000600000002000f0006000000020010000600000002001100060000000200120006000000020013000600000002001400060000000200150006000000020016000600000002001700060000000200180006000000020019001a00000002001b001a00000002001c001a00000002001d001a00000002001e001f000000020020001f000000020021001f000000020022001f000000020023001f00000008000100240025000100260000011d00020001000000912ab700282a01b5002a2a01b5002c2a01b5002e2a01b500302a01b500322a01b500342a01b500362a01b500382a01b5003a2a01b5003c2a01b5003e2a01b500402a01b500422a01b500442a01b500462a01b500482a01b5004a2a01b5004c2a01b5004e2a01b500502a01b500522a01b500542a01b500562a01b500582a01b5005a2a01b5005c2a01b5005e2a01b50060b10000000100610000007a001e00000012000400190009001a000e001b0013001c0018001d001d001e0022001f00270020002c00210031002200360023003b00240040002500450026004a0027004f0028005400290059002a005e002b0063002c0068002d006d002e0072002f00770030007c00310081003200860033008b003400900012000100620063000100260000003400020004000000102a2bb700672a2cb7006a2a2db7006db10000000100610000001200040000004000050041000a0042000f004300020064006500010026000001bb00030002000001572a2b126fb900750200c00077c00077b5002a2a2b1279b900750200c00077c00077b5002c2a2b127bb900750200c00077c00077b5002e2a2b127db900750200c00077c00077b500302a2b127fb900750200c00077c00077b500322a2b1281b900750200c00077c00077b500342a2b1283b900750200c00077c00077b500362a2b1285b900750200c00077c00077b500382a2b1287b900750200c00077c00077b5003a2a2b1289b900750200c00077c00077b5003c2a2b128bb900750200c00077c00077b5003e2a2b128db900750200c00077c00077b500402a2b128fb900750200c00077c00077b500422a2b1291b900750200c00077c00077b500442a2b1293b900750200c00077c00077b500462a2b1295b900750200c00077c00077b500482a2b1297b900750200c00077c00077b5004a2a2b1299b900750200c00077c00077b5004c2a2b129bb900750200c00077c00077b5004eb10000000100610000005200140000004b0012004c0024004d0036004e0048004f005a0050006c0051007e00520090005300a2005400b4005500c6005600d8005700ea005800fc0059010e005a0120005b0132005c0144005d0156005e000200680065000100260000007100030002000000492a2b129db900750200c0009fc0009fb500502a2b12a1b900750200c0009fc0009fb500522a2b12a3b900750200c0009fc0009fb500542a2b12a5b900750200c0009fc0009fb50056b1000000010061000000160005000000660012006700240068003600690048006a0002006b00650001002600000087000300020000005b2a2b12a7b900750200c000a9c000a9b500582a2b12abb900750200c000a9c000a9b5005a2a2b12adb900750200c000a9c000a9b5005c2a2b12afb900750200c000a9c000a9b5005e2a2b12b1b900750200c000a9c000a9b50060b10000000100610000001a00060000007200120073002400740036007500480076005a0077000100b200b3000200b400000004000100b600260000019e000300030000010a014d1baa00000105000000000000000e0000004900000055000000610000006d0000007900000085000000910000009d000000a9000000b4000000c2000000d0000000de000000ec000000fabb00b85904b700bb4da700b3bb00b85904b700bb4da700a7bb00b85904b700bb4da7009bbb00b85903b700bb4da7008fbb00b85904b700bb4da70083bb00b85903b700bb4da70077bb00b85904b700bb4da7006bbb00b85903b700bb4da7005fbb00bd59b700be4da700542ab40054b600c2c000c44da700462ab40052b600c2c000c44da700382ab40050b600c2c000c44da7002a2ab40056b600c2c000c44da7001c2ab4005cb600c5c000b84da7000e2ab40058b600c5c000b84d2cb00000000100610000008200200000007f00020081004c0085005500860058008a0061008b0064008f006d00900070009400790095007c00990085009a0088009e0091009f009400a3009d00a400a000a800a900a900ac00ad00b400ae00b700b200c200b300c500b700d000b800d300bc00de00bd00e100c100ec00c200ef00c600fa00c700fd00cb010800d3000100c600b3000200b400000004000100b600260000019e000300030000010a014d1baa00000105000000000000000e0000004900000055000000610000006d0000007900000085000000910000009d000000a9000000b4000000c2000000d0000000de000000ec000000fabb00b85904b700bb4da700b3bb00b85904b700bb4da700a7bb00b85904b700bb4da7009bbb00b85903b700bb4da7008fbb00b85904b700bb4da70083bb00b85903b700bb4da70077bb00b85904b700bb4da7006bbb00b85903b700bb4da7005fbb00bd59b700be4da700542ab40054b600c9c000c44da700462ab40052b600c9c000c44da700382ab40050b600c9c000c44da7002a2ab40056b600c9c000c44da7001c2ab4005cb600cac000b84da7000e2ab40058b600cac000b84d2cb0000000010061000000820020000000dc000200de004c00e2005500e3005800e7006100e8006400ec006d00ed007000f1007900f2007c00f6008500f7008800fb009100fc00940100009d010100a0010500a9010600ac010a00b4010b00b7010f00c2011000c5011400d0011500d3011900de011a00e1011e00ec011f00ef012300fa012400fd012801080130000100cb00b3000200b400000004000100b600260000019e000300030000010a014d1baa00000105000000000000000e0000004900000055000000610000006d0000007900000085000000910000009d000000a9000000b4000000c2000000d0000000de000000ec000000fabb00b85904b700bb4da700b3bb00b85904b700bb4da700a7bb00b85904b700bb4da7009bbb00b85903b700bb4da7008fbb00b85904b700bb4da70083bb00b85903b700bb4da70077bb00b85904b700bb4da7006bbb00b85903b700bb4da7005fbb00bd59b700be4da700542ab40054b600c2c000c44da700462ab40052b600c2c000c44da700382ab40050b600c2c000c44da7002a2ab40056b600c2c000c44da7001c2ab4005cb600cec000b84da7000e2ab40058b600cec000b84d2cb0000000010061000000820020000001390002013b004c013f00550140005801440061014500640149006d014a0070014e0079014f007c01530085015400880158009101590094015d009d015e00a0016200a9016300ac016700b4016800b7016c00c2016d00c5017100d0017200d3017600de017700e1017b00ec017c00ef018000fa018100fd01850108018d000100cf0000000200017400145f313338303137383931343230345f38383837367400326e65742e73662e6a61737065727265706f7274732e656e67696e652e64657369676e2e4a524a61766163436f6d70696c6572	\N	2014-10-27 12:28:16.551171	Consistency Report	\N
\.


--
-- Data for Name: user_password_reset_tokens; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY user_password_reset_tokens (userid, token, createddate) FROM stdin;
2	V1Wis4fIY0mzuPHg4YZipdEO3iiNqvALoRhC4qgl1u4o1xvOmRsYfskGe24Niiipqx825uglaMTSOhaeipyNQrExw3NAieie	2014-10-27 13:35:52.643614
3	mfRo0WqJK8ONulCyKzGcz3ipOYBsU1MTXdBLBpgMxTGisGLfDnf2Ju6ytQtqnyo5wJsoHoWWyLnpgCjiiVnn0b6hwieie	2014-10-27 14:55:45.687696
4	j88mpKoCtlby30iigygYsNEipEOQ8F1M87II3xmyakWWQ9g1obLdii0MgnOWipEAA5WKxrENgqoRRKIMpisRxSzjwKQieie	2014-10-27 14:58:43.752873
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY users (id, username, password, firstname, lastname, employeeid, restrictlogin, jobtitle, primarynotificationmethod, officephone, cellphone, email, supervisorid, facilityid, verified, active, createdby, createddate, modifiedby, modifieddate) FROM stdin;
1	Admin123	TQskzK3iiLfbRVHeM1muvBCiiKriibfl6lh8ipo91hb74G3OvsybvkzpPI4S3KIeWTXAiiwlUU0iiSxWii4wSuS8mokSAieie	John	Doe	\N	f	\N	\N	\N	\N	John_Doe@openlmis.com	\N	\N	t	t	\N	2014-10-27 12:27:35.693982	\N	2014-10-27 12:27:35.693982
3	VendorUser1	7PeHR1RRpFgisbb5AnqfisdtFnKb8OR6R0AoWEHAisQeJkDFIIRn8nfuPm8qBTZipisuDAjIBq0mEx7vmYP5yITF3GQieie	Vladimir	Vendor	\N	f	\N	\N	\N	\N	vendor_user_1@ahf.co.ug	\N	2	t	t	1	2014-10-27 14:55:45.687696	1	2014-10-27 15:11:48.936692
2	ClinicUser1	ghXUbjym8TrsHxHhRs9r68FpCnFzipllUisipzslHk8JnVn3OhBwfILissuqjLurQAFFCisgQVdARDAispzcvenIU4pwieie	Clyde	Clinic	\N	f	\N	\N	\N	\N	clinic_user_1@ahf.co.ug	\N	1	t	t	1	2014-10-27 13:35:52.643614	1	2014-10-27 15:25:47.408293
4	SecretariatUser1	uOgl3riphodb6bcyIgQryTMvn34ipsbYipiihKC7iskwIPpuC8QaHX0BtipL471Zl6PhWFd7CipZxTtZxNpkfbDDiicFZgieie	Steven	Secretariat	\N	f	\N	\N	\N	\N	secretariat_user_1@ahf.co.ug	\N	\N	t	t	1	2014-10-27 14:58:43.752873	1	2014-10-27 15:57:25.56362
\.


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('users_id_seq', 4, true);


--
-- Data for Name: vaccination_adult_coverage_line_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY vaccination_adult_coverage_line_items (id, facilityvisitid, demographicgroup, targetgroup, createdby, createddate, modifiedby, modifieddate, healthcentertetanus1, outreachtetanus1, healthcentertetanus2to5, outreachtetanus2to5) FROM stdin;
\.


--
-- Name: vaccination_adult_coverage_line_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('vaccination_adult_coverage_line_items_id_seq', 1, false);


--
-- Data for Name: vaccination_child_coverage_line_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY vaccination_child_coverage_line_items (id, facilityvisitid, vaccination, targetgroup, healthcenter11months, outreach11months, healthcenter23months, outreach23months, createdby, createddate, modifiedby, modifieddate) FROM stdin;
\.


--
-- Name: vaccination_child_coverage_line_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('vaccination_child_coverage_line_items_id_seq', 1, false);


--
-- Name: vaccination_full_coverages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('vaccination_full_coverages_id_seq', 1, false);


SET search_path = atomfeed, pg_catalog;

--
-- Name: chunking_history_pkey; Type: CONSTRAINT; Schema: atomfeed; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY chunking_history
    ADD CONSTRAINT chunking_history_pkey PRIMARY KEY (id);


--
-- Name: event_records_pkey; Type: CONSTRAINT; Schema: atomfeed; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY event_records
    ADD CONSTRAINT event_records_pkey PRIMARY KEY (id);


SET search_path = public, pg_catalog;

--
-- Name: adult_coverage_opened_vial_line_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY adult_coverage_opened_vial_line_items
    ADD CONSTRAINT adult_coverage_opened_vial_line_items_pkey PRIMARY KEY (id);


--
-- Name: budget_file_columns_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY budget_file_columns
    ADD CONSTRAINT budget_file_columns_pkey PRIMARY KEY (id);


--
-- Name: budget_file_info_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY budget_file_info
    ADD CONSTRAINT budget_file_info_pkey PRIMARY KEY (id);


--
-- Name: budget_line_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY budget_line_items
    ADD CONSTRAINT budget_line_items_pkey PRIMARY KEY (id);


--
-- Name: comments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (id);


--
-- Name: configurable_rnr_options_label_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY configurable_rnr_options
    ADD CONSTRAINT configurable_rnr_options_label_key UNIQUE (label);


--
-- Name: configurable_rnr_options_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY configurable_rnr_options
    ADD CONSTRAINT configurable_rnr_options_name_key UNIQUE (name);


--
-- Name: configurable_rnr_options_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY configurable_rnr_options
    ADD CONSTRAINT configurable_rnr_options_pkey PRIMARY KEY (id);


--
-- Name: coverage_product_vials_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY coverage_product_vials
    ADD CONSTRAINT coverage_product_vials_pkey PRIMARY KEY (id);


--
-- Name: coverage_product_vials_vial_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY coverage_product_vials
    ADD CONSTRAINT coverage_product_vials_vial_key UNIQUE (vial);


--
-- Name: coverage_vaccination_products_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY coverage_target_group_products
    ADD CONSTRAINT coverage_vaccination_products_pkey PRIMARY KEY (id);


--
-- Name: delivery_zone_members_deliveryzoneid_facilityid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY delivery_zone_members
    ADD CONSTRAINT delivery_zone_members_deliveryzoneid_facilityid_key UNIQUE (deliveryzoneid, facilityid);


--
-- Name: delivery_zone_members_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY delivery_zone_members
    ADD CONSTRAINT delivery_zone_members_pkey PRIMARY KEY (id);


--
-- Name: delivery_zone_program_schedules_deliveryzoneid_programid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY delivery_zone_program_schedules
    ADD CONSTRAINT delivery_zone_program_schedules_deliveryzoneid_programid_key UNIQUE (deliveryzoneid, programid);


--
-- Name: delivery_zone_program_schedules_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY delivery_zone_program_schedules
    ADD CONSTRAINT delivery_zone_program_schedules_pkey PRIMARY KEY (id);


--
-- Name: delivery_zone_warehouses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY delivery_zone_warehouses
    ADD CONSTRAINT delivery_zone_warehouses_pkey PRIMARY KEY (id);


--
-- Name: delivery_zones_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY delivery_zones
    ADD CONSTRAINT delivery_zones_code_key UNIQUE (code);


--
-- Name: delivery_zones_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY delivery_zones
    ADD CONSTRAINT delivery_zones_pkey PRIMARY KEY (id);


--
-- Name: distribution_refrigerator_readings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY refrigerator_readings
    ADD CONSTRAINT distribution_refrigerator_readings_pkey PRIMARY KEY (id);


--
-- Name: distributions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY distributions
    ADD CONSTRAINT distributions_pkey PRIMARY KEY (id);


--
-- Name: dosage_units_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY dosage_units
    ADD CONSTRAINT dosage_units_pkey PRIMARY KEY (id);


--
-- Name: email_notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY email_notifications
    ADD CONSTRAINT email_notifications_pkey PRIMARY KEY (id);


--
-- Name: epi_inventory_line_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY epi_inventory_line_items
    ADD CONSTRAINT epi_inventory_line_items_pkey PRIMARY KEY (id);


--
-- Name: epi_use_line_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY epi_use_line_items
    ADD CONSTRAINT epi_use_line_items_pkey PRIMARY KEY (id);


--
-- Name: facilities_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY facilities
    ADD CONSTRAINT facilities_code_key UNIQUE (code);


--
-- Name: facilities_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY facilities
    ADD CONSTRAINT facilities_pkey PRIMARY KEY (id);


--
-- Name: facility_approved_products_facilitytypeid_programproductid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY facility_approved_products
    ADD CONSTRAINT facility_approved_products_facilitytypeid_programproductid_key UNIQUE (facilitytypeid, programproductid);


--
-- Name: facility_approved_products_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY facility_approved_products
    ADD CONSTRAINT facility_approved_products_pkey PRIMARY KEY (id);


--
-- Name: facility_ftp_details_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY facility_ftp_details
    ADD CONSTRAINT facility_ftp_details_pkey PRIMARY KEY (id);


--
-- Name: facility_operators_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY facility_operators
    ADD CONSTRAINT facility_operators_code_key UNIQUE (code);


--
-- Name: facility_operators_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY facility_operators
    ADD CONSTRAINT facility_operators_pkey PRIMARY KEY (id);


--
-- Name: facility_program_products_facilityid_programproductid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY facility_program_products
    ADD CONSTRAINT facility_program_products_facilityid_programproductid_key UNIQUE (facilityid, programproductid);


--
-- Name: facility_program_products_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY facility_program_products
    ADD CONSTRAINT facility_program_products_pkey PRIMARY KEY (id);


--
-- Name: facility_types_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY facility_types
    ADD CONSTRAINT facility_types_code_key UNIQUE (code);


--
-- Name: facility_types_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY facility_types
    ADD CONSTRAINT facility_types_name_key UNIQUE (name);


--
-- Name: facility_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY facility_types
    ADD CONSTRAINT facility_types_pkey PRIMARY KEY (id);


--
-- Name: facility_visits_distributionid_facilityid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY facility_visits
    ADD CONSTRAINT facility_visits_distributionid_facilityid_key UNIQUE (distributionid, facilityid);


--
-- Name: facility_visits_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY facility_visits
    ADD CONSTRAINT facility_visits_pkey PRIMARY KEY (id);


--
-- Name: geographic_levels_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY geographic_levels
    ADD CONSTRAINT geographic_levels_code_key UNIQUE (code);


--
-- Name: geographic_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY geographic_levels
    ADD CONSTRAINT geographic_levels_pkey PRIMARY KEY (id);


--
-- Name: geographic_zones_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY geographic_zones
    ADD CONSTRAINT geographic_zones_code_key UNIQUE (code);


--
-- Name: geographic_zones_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY geographic_zones
    ADD CONSTRAINT geographic_zones_pkey PRIMARY KEY (id);


--
-- Name: losses_adjustments_types_description_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY losses_adjustments_types
    ADD CONSTRAINT losses_adjustments_types_description_key UNIQUE (description);


--
-- Name: losses_adjustments_types_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY losses_adjustments_types
    ADD CONSTRAINT losses_adjustments_types_name_key UNIQUE (name);


--
-- Name: master_rnr_column_options_masterrnrcolumnid_rnroptionid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY master_rnr_column_options
    ADD CONSTRAINT master_rnr_column_options_masterrnrcolumnid_rnroptionid_key UNIQUE (masterrnrcolumnid, rnroptionid);


--
-- Name: master_rnr_column_options_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY master_rnr_column_options
    ADD CONSTRAINT master_rnr_column_options_pkey PRIMARY KEY (id);


--
-- Name: master_rnr_columns_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY master_rnr_columns
    ADD CONSTRAINT master_rnr_columns_name_key UNIQUE (name);


--
-- Name: master_rnr_columns_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY master_rnr_columns
    ADD CONSTRAINT master_rnr_columns_pkey PRIMARY KEY (id);


--
-- Name: opened_vial_line_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY child_coverage_opened_vial_line_items
    ADD CONSTRAINT opened_vial_line_items_pkey PRIMARY KEY (id);


--
-- Name: order_file_columns_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY order_file_columns
    ADD CONSTRAINT order_file_columns_pkey PRIMARY KEY (id);


--
-- Name: orders_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY orders
    ADD CONSTRAINT orders_id_key UNIQUE (id);


--
-- Name: pod_line_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY pod_line_items
    ADD CONSTRAINT pod_line_items_pkey PRIMARY KEY (id);


--
-- Name: pod_orderid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY pod
    ADD CONSTRAINT pod_orderid_key UNIQUE (orderid);


--
-- Name: pod_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY pod
    ADD CONSTRAINT pod_pkey PRIMARY KEY (id);


--
-- Name: processing_periods_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY processing_periods
    ADD CONSTRAINT processing_periods_pkey PRIMARY KEY (id);


--
-- Name: processing_schedules_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY processing_schedules
    ADD CONSTRAINT processing_schedules_code_key UNIQUE (code);


--
-- Name: processing_schedules_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY processing_schedules
    ADD CONSTRAINT processing_schedules_pkey PRIMARY KEY (id);


--
-- Name: product_categories_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY product_categories
    ADD CONSTRAINT product_categories_code_key UNIQUE (code);


--
-- Name: product_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY product_categories
    ADD CONSTRAINT product_categories_pkey PRIMARY KEY (id);


--
-- Name: product_forms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY product_forms
    ADD CONSTRAINT product_forms_pkey PRIMARY KEY (id);


--
-- Name: product_groups_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY product_groups
    ADD CONSTRAINT product_groups_code_key UNIQUE (code);


--
-- Name: product_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY product_groups
    ADD CONSTRAINT product_groups_pkey PRIMARY KEY (id);


--
-- Name: products_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY products
    ADD CONSTRAINT products_code_key UNIQUE (code);


--
-- Name: products_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY products
    ADD CONSTRAINT products_pkey PRIMARY KEY (id);


--
-- Name: program_product_isa_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY program_product_isa
    ADD CONSTRAINT program_product_isa_pkey PRIMARY KEY (id);


--
-- Name: program_product_price_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY program_product_price_history
    ADD CONSTRAINT program_product_price_history_pkey PRIMARY KEY (id);


--
-- Name: program_products_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY program_products
    ADD CONSTRAINT program_products_pkey PRIMARY KEY (id);


--
-- Name: program_products_productid_programid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY program_products
    ADD CONSTRAINT program_products_productid_programid_key UNIQUE (productid, programid);


--
-- Name: program_regimen_columns_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY program_regimen_columns
    ADD CONSTRAINT program_regimen_columns_pkey PRIMARY KEY (id);


--
-- Name: program_rnr_columns_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY program_rnr_columns
    ADD CONSTRAINT program_rnr_columns_pkey PRIMARY KEY (id);


--
-- Name: program_rnr_columns_programid_mastercolumnid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY program_rnr_columns
    ADD CONSTRAINT program_rnr_columns_programid_mastercolumnid_key UNIQUE (programid, mastercolumnid);


--
-- Name: programs_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY programs
    ADD CONSTRAINT programs_code_key UNIQUE (code);


--
-- Name: programs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY programs
    ADD CONSTRAINT programs_pkey PRIMARY KEY (id);


--
-- Name: programs_supported_facilityid_programid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY programs_supported
    ADD CONSTRAINT programs_supported_facilityid_programid_key UNIQUE (facilityid, programid);


--
-- Name: programs_supported_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY programs_supported
    ADD CONSTRAINT programs_supported_pkey PRIMARY KEY (id);


--
-- Name: refrigerator_problems_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY refrigerator_problems
    ADD CONSTRAINT refrigerator_problems_pkey PRIMARY KEY (id);


--
-- Name: refrigerators_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY refrigerators
    ADD CONSTRAINT refrigerators_pkey PRIMARY KEY (id);


--
-- Name: regimen_categories_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY regimen_categories
    ADD CONSTRAINT regimen_categories_code_key UNIQUE (code);


--
-- Name: regimen_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY regimen_categories
    ADD CONSTRAINT regimen_categories_pkey PRIMARY KEY (id);


--
-- Name: regimen_line_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY regimen_line_items
    ADD CONSTRAINT regimen_line_items_pkey PRIMARY KEY (id);


--
-- Name: regimens_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY regimens
    ADD CONSTRAINT regimens_pkey PRIMARY KEY (id);


--
-- Name: report_rights_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY report_rights
    ADD CONSTRAINT report_rights_pkey PRIMARY KEY (id);


--
-- Name: report_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY templates
    ADD CONSTRAINT report_templates_pkey PRIMARY KEY (id);


--
-- Name: requisition_group_members_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY requisition_group_members
    ADD CONSTRAINT requisition_group_members_pkey PRIMARY KEY (id);


--
-- Name: requisition_group_members_requisitiongroupid_facilityid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY requisition_group_members
    ADD CONSTRAINT requisition_group_members_requisitiongroupid_facilityid_key UNIQUE (requisitiongroupid, facilityid);


--
-- Name: requisition_group_program_sche_requisitiongroupid_programid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY requisition_group_program_schedules
    ADD CONSTRAINT requisition_group_program_sche_requisitiongroupid_programid_key UNIQUE (requisitiongroupid, programid);


--
-- Name: requisition_group_program_schedules_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY requisition_group_program_schedules
    ADD CONSTRAINT requisition_group_program_schedules_pkey PRIMARY KEY (id);


--
-- Name: requisition_groups_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY requisition_groups
    ADD CONSTRAINT requisition_groups_code_key UNIQUE (code);


--
-- Name: requisition_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY requisition_groups
    ADD CONSTRAINT requisition_groups_pkey PRIMARY KEY (id);


--
-- Name: requisition_line_item_losses_adjustments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY requisition_line_item_losses_adjustments
    ADD CONSTRAINT requisition_line_item_losses_adjustments_pkey PRIMARY KEY (requisitionlineitemid, type);


--
-- Name: requisition_line_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY requisition_line_items
    ADD CONSTRAINT requisition_line_items_pkey PRIMARY KEY (id);


--
-- Name: requisition_status_changes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY requisition_status_changes
    ADD CONSTRAINT requisition_status_changes_pkey PRIMARY KEY (id);


--
-- Name: requisitions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY requisitions
    ADD CONSTRAINT requisitions_pkey PRIMARY KEY (id);


--
-- Name: rights_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY rights
    ADD CONSTRAINT rights_pkey PRIMARY KEY (name);


--
-- Name: roles_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY roles
    ADD CONSTRAINT roles_name_key UNIQUE (name);


--
-- Name: roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: schema_version_primary_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY schema_version
    ADD CONSTRAINT schema_version_primary_key PRIMARY KEY (version);


--
-- Name: schema_version_script_unique; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY schema_version
    ADD CONSTRAINT schema_version_script_unique UNIQUE (script);


--
-- Name: shipment_file_columns_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY shipment_file_columns
    ADD CONSTRAINT shipment_file_columns_pkey PRIMARY KEY (id);


--
-- Name: shipment_file_info_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY shipment_file_info
    ADD CONSTRAINT shipment_file_info_pkey PRIMARY KEY (id);


--
-- Name: shipment_line_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY shipment_line_items
    ADD CONSTRAINT shipment_line_items_pkey PRIMARY KEY (id);


--
-- Name: supervisory_nodes_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY supervisory_nodes
    ADD CONSTRAINT supervisory_nodes_code_key UNIQUE (code);


--
-- Name: supervisory_nodes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY supervisory_nodes
    ADD CONSTRAINT supervisory_nodes_pkey PRIMARY KEY (id);


--
-- Name: supply_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY supply_lines
    ADD CONSTRAINT supply_lines_pkey PRIMARY KEY (id);


--
-- Name: template_parameters_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY template_parameters
    ADD CONSTRAINT template_parameters_pkey PRIMARY KEY (id);


--
-- Name: uc_productgroupid_facilityvisitid_epi_use_line_items; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY epi_use_line_items
    ADD CONSTRAINT uc_productgroupid_facilityvisitid_epi_use_line_items UNIQUE (productgroupid, facilityvisitid);


--
-- Name: uc_programproductid_facilityvisitid_epi_inventory_line_items; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY epi_inventory_line_items
    ADD CONSTRAINT uc_programproductid_facilityvisitid_epi_inventory_line_items UNIQUE (programproductid, facilityvisitid);


--
-- Name: uc_refrigeratorid_facilityvisitid_refrigerator_readings; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY refrigerator_readings
    ADD CONSTRAINT uc_refrigeratorid_facilityvisitid_refrigerator_readings UNIQUE (refrigeratorid, facilityvisitid);


--
-- Name: uc_serialnumber_facilityid_refrigerators; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY refrigerators
    ADD CONSTRAINT uc_serialnumber_facilityid_refrigerators UNIQUE (serialnumber, facilityid);


--
-- Name: uc_vaccination_coverage_vaccination_products; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY coverage_target_group_products
    ADD CONSTRAINT uc_vaccination_coverage_vaccination_products UNIQUE (targetgroupentity);


--
-- Name: unique_fulfillment_role_assignments; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY fulfillment_role_assignments
    ADD CONSTRAINT unique_fulfillment_role_assignments UNIQUE (userid, roleid, facilityid);


--
-- Name: unique_role_assignment; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY role_assignments
    ADD CONSTRAINT unique_role_assignment UNIQUE (userid, roleid, programid, supervisorynodeid);


--
-- Name: unique_role_right; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY role_rights
    ADD CONSTRAINT unique_role_right UNIQUE (roleid, rightname);


--
-- Name: unique_supply_line; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY supply_lines
    ADD CONSTRAINT unique_supply_line UNIQUE (supervisorynodeid, programid);


--
-- Name: user_password_reset_tokens_userid_token_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY user_password_reset_tokens
    ADD CONSTRAINT user_password_reset_tokens_userid_token_key UNIQUE (userid, token);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: vaccination_adult_coverage_line_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY vaccination_adult_coverage_line_items
    ADD CONSTRAINT vaccination_adult_coverage_line_items_pkey PRIMARY KEY (id);


--
-- Name: vaccination_child_coverage_line_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY vaccination_child_coverage_line_items
    ADD CONSTRAINT vaccination_child_coverage_line_items_pkey PRIMARY KEY (id);


--
-- Name: vaccination_full_coverages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY full_coverages
    ADD CONSTRAINT vaccination_full_coverages_pkey PRIMARY KEY (id);


--
-- Name: i_comments_rnrid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX i_comments_rnrid ON comments USING btree (rnrid);


--
-- Name: i_delivery_zone_members_facilityid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX i_delivery_zone_members_facilityid ON delivery_zone_members USING btree (facilityid);


--
-- Name: i_delivery_zone_program_schedules_deliveryzoneid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX i_delivery_zone_program_schedules_deliveryzoneid ON delivery_zone_program_schedules USING btree (deliveryzoneid);


--
-- Name: i_delivery_zone_warehouses_deliveryzoneid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX i_delivery_zone_warehouses_deliveryzoneid ON delivery_zone_warehouses USING btree (deliveryzoneid);


--
-- Name: i_facility_approved_product_programproductid_facilitytypeid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX i_facility_approved_product_programproductid_facilitytypeid ON facility_approved_products USING btree (programproductid, facilitytypeid);


--
-- Name: i_facility_name; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX i_facility_name ON facilities USING btree (name);


--
-- Name: i_processing_period_startdate_enddate; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX i_processing_period_startdate_enddate ON processing_periods USING btree (startdate, enddate);


--
-- Name: i_program_product_isa_programproductid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX i_program_product_isa_programproductid ON program_product_isa USING btree (programproductid);


--
-- Name: i_program_product_price_history_programproductid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX i_program_product_price_history_programproductid ON program_product_price_history USING btree (programproductid);


--
-- Name: i_program_product_programid_productid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX i_program_product_programid_productid ON program_products USING btree (programid, productid);


--
-- Name: i_program_regimens_name; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX i_program_regimens_name ON program_regimen_columns USING btree (programid, name);


--
-- Name: i_program_supported_facilityid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX i_program_supported_facilityid ON programs_supported USING btree (facilityid);


--
-- Name: i_regimens_code_programid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX i_regimens_code_programid ON regimens USING btree (code, programid);


--
-- Name: i_requisition_group_member_facilityid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX i_requisition_group_member_facilityid ON requisition_group_members USING btree (facilityid);


--
-- Name: i_requisition_group_program_schedules_requisitiongroupid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX i_requisition_group_program_schedules_requisitiongroupid ON requisition_group_program_schedules USING btree (requisitiongroupid);


--
-- Name: i_requisition_group_supervisorynodeid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX i_requisition_group_supervisorynodeid ON requisition_groups USING btree (supervisorynodeid);


--
-- Name: i_requisition_line_item_losses_adjustments_lineitemid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX i_requisition_line_item_losses_adjustments_lineitemid ON requisition_line_item_losses_adjustments USING btree (requisitionlineitemid);


--
-- Name: i_requisition_line_items_rnrid_fullsupply_f; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX i_requisition_line_items_rnrid_fullsupply_f ON requisition_line_items USING btree (rnrid) WHERE (fullsupply = false);


--
-- Name: i_requisition_line_items_rnrid_fullsupply_t; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX i_requisition_line_items_rnrid_fullsupply_t ON requisition_line_items USING btree (rnrid) WHERE (fullsupply = true);


--
-- Name: i_requisitions_programid_supervisorynodeid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX i_requisitions_programid_supervisorynodeid ON requisitions USING btree (programid, supervisorynodeid);


--
-- Name: i_requisitions_status; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX i_requisitions_status ON requisitions USING btree (lower((status)::text));


--
-- Name: i_supervisory_node_parentid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX i_supervisory_node_parentid ON supervisory_nodes USING btree (parentid);


--
-- Name: i_users_firstname_lastname_email; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX i_users_firstname_lastname_email ON users USING btree (lower((firstname)::text), lower((lastname)::text), lower((email)::text));


--
-- Name: program_id_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX program_id_index ON program_rnr_columns USING btree (programid);


--
-- Name: schema_version_current_version_index; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX schema_version_current_version_index ON schema_version USING btree (current_version);


--
-- Name: uc_budget_line_items_facilityid_programid_periodid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX uc_budget_line_items_facilityid_programid_periodid ON budget_line_items USING btree (facilityid, programid, periodid);


--
-- Name: uc_delivery_zones_lower_code; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX uc_delivery_zones_lower_code ON delivery_zones USING btree (lower((code)::text));


--
-- Name: uc_dosage_units_lower_code; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX uc_dosage_units_lower_code ON dosage_units USING btree (lower((code)::text));


--
-- Name: uc_dz_program_period; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX uc_dz_program_period ON distributions USING btree (deliveryzoneid, programid, periodid);


--
-- Name: uc_facilities_lower_code; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX uc_facilities_lower_code ON facilities USING btree (lower((code)::text));


--
-- Name: uc_facility_operators_lower_code; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX uc_facility_operators_lower_code ON facility_operators USING btree (lower((code)::text));


--
-- Name: uc_facility_program_products_overriddenisa_programproductid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX uc_facility_program_products_overriddenisa_programproductid ON facility_program_products USING btree (facilityid, programproductid);


--
-- Name: uc_facility_types_lower_code; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX uc_facility_types_lower_code ON facility_types USING btree (lower((code)::text));


--
-- Name: uc_geographic_levels_lower_code; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX uc_geographic_levels_lower_code ON geographic_levels USING btree (lower((code)::text));


--
-- Name: uc_geographic_zones_lower_code; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX uc_geographic_zones_lower_code ON geographic_zones USING btree (lower((code)::text));


--
-- Name: uc_processing_period_name_scheduleid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX uc_processing_period_name_scheduleid ON processing_periods USING btree (lower((name)::text), scheduleid);


--
-- Name: uc_processing_schedules_lower_code; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX uc_processing_schedules_lower_code ON processing_schedules USING btree (lower((code)::text));


--
-- Name: uc_product_categories_lower_code; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX uc_product_categories_lower_code ON product_categories USING btree (lower((code)::text));


--
-- Name: uc_product_forms_lower_code; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX uc_product_forms_lower_code ON product_forms USING btree (lower((code)::text));


--
-- Name: uc_product_groups_lower_code; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX uc_product_groups_lower_code ON product_groups USING btree (lower((code)::text));


--
-- Name: uc_products_lower_code; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX uc_products_lower_code ON products USING btree (lower((code)::text));


--
-- Name: uc_programs_lower_code; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX uc_programs_lower_code ON programs USING btree (lower((code)::text));


--
-- Name: uc_report_templates_name; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX uc_report_templates_name ON templates USING btree (lower((name)::text));


--
-- Name: uc_requisition_groups_lower_code; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX uc_requisition_groups_lower_code ON requisition_groups USING btree (lower((code)::text));


--
-- Name: uc_roles_lower_name; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX uc_roles_lower_name ON roles USING btree (lower((name)::text));


--
-- Name: uc_supervisory_nodes_lower_code; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX uc_supervisory_nodes_lower_code ON supervisory_nodes USING btree (lower((code)::text));


--
-- Name: uc_users_email; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX uc_users_email ON users USING btree (lower((email)::text));


--
-- Name: uc_users_employeeid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX uc_users_employeeid ON users USING btree (lower((employeeid)::text));


--
-- Name: uc_users_username; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX uc_users_username ON users USING btree (lower((username)::text));


--
-- Name: adult_coverage_opened_vial_line_items_facilityvisitid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY adult_coverage_opened_vial_line_items
    ADD CONSTRAINT adult_coverage_opened_vial_line_items_facilityvisitid_fkey FOREIGN KEY (facilityvisitid) REFERENCES facility_visits(id);


--
-- Name: budget_line_items_budgetfileid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY budget_line_items
    ADD CONSTRAINT budget_line_items_budgetfileid_fkey FOREIGN KEY (budgetfileid) REFERENCES budget_file_info(id);


--
-- Name: budget_line_items_facilityid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY budget_line_items
    ADD CONSTRAINT budget_line_items_facilityid_fkey FOREIGN KEY (facilityid) REFERENCES facilities(id);


--
-- Name: budget_line_items_periodid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY budget_line_items
    ADD CONSTRAINT budget_line_items_periodid_fkey FOREIGN KEY (periodid) REFERENCES processing_periods(id);


--
-- Name: budget_line_items_programid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY budget_line_items
    ADD CONSTRAINT budget_line_items_programid_fkey FOREIGN KEY (programid) REFERENCES programs(id);


--
-- Name: comments_createdby_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY comments
    ADD CONSTRAINT comments_createdby_fkey FOREIGN KEY (createdby) REFERENCES users(id);


--
-- Name: comments_modifiedby_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY comments
    ADD CONSTRAINT comments_modifiedby_fkey FOREIGN KEY (modifiedby) REFERENCES users(id);


--
-- Name: comments_rnrid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY comments
    ADD CONSTRAINT comments_rnrid_fkey FOREIGN KEY (rnrid) REFERENCES requisitions(id);


--
-- Name: coverage_product_vials_productcode_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY coverage_product_vials
    ADD CONSTRAINT coverage_product_vials_productcode_fkey FOREIGN KEY (productcode) REFERENCES products(code);


--
-- Name: coverage_vaccination_products_productcode_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY coverage_target_group_products
    ADD CONSTRAINT coverage_vaccination_products_productcode_fkey FOREIGN KEY (productcode) REFERENCES products(code);


--
-- Name: delivery_zone_members_deliveryzoneid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY delivery_zone_members
    ADD CONSTRAINT delivery_zone_members_deliveryzoneid_fkey FOREIGN KEY (deliveryzoneid) REFERENCES delivery_zones(id);


--
-- Name: delivery_zone_members_facilityid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY delivery_zone_members
    ADD CONSTRAINT delivery_zone_members_facilityid_fkey FOREIGN KEY (facilityid) REFERENCES facilities(id);


--
-- Name: delivery_zone_program_schedules_deliveryzoneid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY delivery_zone_program_schedules
    ADD CONSTRAINT delivery_zone_program_schedules_deliveryzoneid_fkey FOREIGN KEY (deliveryzoneid) REFERENCES delivery_zones(id);


--
-- Name: delivery_zone_program_schedules_programid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY delivery_zone_program_schedules
    ADD CONSTRAINT delivery_zone_program_schedules_programid_fkey FOREIGN KEY (programid) REFERENCES programs(id);


--
-- Name: delivery_zone_program_schedules_scheduleid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY delivery_zone_program_schedules
    ADD CONSTRAINT delivery_zone_program_schedules_scheduleid_fkey FOREIGN KEY (scheduleid) REFERENCES processing_schedules(id);


--
-- Name: delivery_zone_warehouses_deliveryzoneid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY delivery_zone_warehouses
    ADD CONSTRAINT delivery_zone_warehouses_deliveryzoneid_fkey FOREIGN KEY (deliveryzoneid) REFERENCES delivery_zones(id);


--
-- Name: delivery_zone_warehouses_warehouseid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY delivery_zone_warehouses
    ADD CONSTRAINT delivery_zone_warehouses_warehouseid_fkey FOREIGN KEY (warehouseid) REFERENCES facilities(id);


--
-- Name: distributions_createdby_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY distributions
    ADD CONSTRAINT distributions_createdby_fkey FOREIGN KEY (createdby) REFERENCES users(id);


--
-- Name: distributions_deliveryzoneid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY distributions
    ADD CONSTRAINT distributions_deliveryzoneid_fkey FOREIGN KEY (deliveryzoneid) REFERENCES delivery_zones(id);


--
-- Name: distributions_modifiedby_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY distributions
    ADD CONSTRAINT distributions_modifiedby_fkey FOREIGN KEY (modifiedby) REFERENCES users(id);


--
-- Name: distributions_periodid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY distributions
    ADD CONSTRAINT distributions_periodid_fkey FOREIGN KEY (periodid) REFERENCES processing_periods(id);


--
-- Name: distributions_programid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY distributions
    ADD CONSTRAINT distributions_programid_fkey FOREIGN KEY (programid) REFERENCES programs(id);


--
-- Name: epi_inventory_line_items_facilityvisitid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY epi_inventory_line_items
    ADD CONSTRAINT epi_inventory_line_items_facilityvisitid_fkey FOREIGN KEY (facilityvisitid) REFERENCES facility_visits(id);


--
-- Name: epi_inventory_line_items_programproductid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY epi_inventory_line_items
    ADD CONSTRAINT epi_inventory_line_items_programproductid_fkey FOREIGN KEY (programproductid) REFERENCES program_products(id);


--
-- Name: epi_use_line_items_createdby_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY epi_use_line_items
    ADD CONSTRAINT epi_use_line_items_createdby_fkey FOREIGN KEY (createdby) REFERENCES users(id);


--
-- Name: epi_use_line_items_facilityvisitid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY epi_use_line_items
    ADD CONSTRAINT epi_use_line_items_facilityvisitid_fkey FOREIGN KEY (facilityvisitid) REFERENCES facility_visits(id);


--
-- Name: epi_use_line_items_modifiedby_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY epi_use_line_items
    ADD CONSTRAINT epi_use_line_items_modifiedby_fkey FOREIGN KEY (modifiedby) REFERENCES users(id);


--
-- Name: epi_use_line_items_productgroupid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY epi_use_line_items
    ADD CONSTRAINT epi_use_line_items_productgroupid_fkey FOREIGN KEY (productgroupid) REFERENCES product_groups(id);


--
-- Name: facilities_geographiczoneid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY facilities
    ADD CONSTRAINT facilities_geographiczoneid_fkey FOREIGN KEY (geographiczoneid) REFERENCES geographic_zones(id);


--
-- Name: facilities_operatedbyid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY facilities
    ADD CONSTRAINT facilities_operatedbyid_fkey FOREIGN KEY (operatedbyid) REFERENCES facility_operators(id);


--
-- Name: facilities_parentfacilityid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY facilities
    ADD CONSTRAINT facilities_parentfacilityid_fkey FOREIGN KEY (parentfacilityid) REFERENCES facilities(id);


--
-- Name: facilities_typeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY facilities
    ADD CONSTRAINT facilities_typeid_fkey FOREIGN KEY (typeid) REFERENCES facility_types(id);


--
-- Name: facility_approved_products_facilitytypeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY facility_approved_products
    ADD CONSTRAINT facility_approved_products_facilitytypeid_fkey FOREIGN KEY (facilitytypeid) REFERENCES facility_types(id);


--
-- Name: facility_approved_products_programproductid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY facility_approved_products
    ADD CONSTRAINT facility_approved_products_programproductid_fkey FOREIGN KEY (programproductid) REFERENCES program_products(id);


--
-- Name: facility_ftp_details_facilityid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY facility_ftp_details
    ADD CONSTRAINT facility_ftp_details_facilityid_fkey FOREIGN KEY (facilityid) REFERENCES facilities(id);


--
-- Name: facility_program_products_facilityid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY facility_program_products
    ADD CONSTRAINT facility_program_products_facilityid_fkey FOREIGN KEY (facilityid) REFERENCES facilities(id);


--
-- Name: facility_program_products_programproductid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY facility_program_products
    ADD CONSTRAINT facility_program_products_programproductid_fkey FOREIGN KEY (programproductid) REFERENCES program_products(id);


--
-- Name: facility_visits_distributionid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY facility_visits
    ADD CONSTRAINT facility_visits_distributionid_fkey FOREIGN KEY (distributionid) REFERENCES distributions(id);


--
-- Name: facility_visits_facilityid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY facility_visits
    ADD CONSTRAINT facility_visits_facilityid_fkey FOREIGN KEY (facilityid) REFERENCES facilities(id);


--
-- Name: fulfillment_role_assignments_facilityid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY fulfillment_role_assignments
    ADD CONSTRAINT fulfillment_role_assignments_facilityid_fkey FOREIGN KEY (facilityid) REFERENCES facilities(id);


--
-- Name: fulfillment_role_assignments_roleid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY fulfillment_role_assignments
    ADD CONSTRAINT fulfillment_role_assignments_roleid_fkey FOREIGN KEY (roleid) REFERENCES roles(id);


--
-- Name: fulfillment_role_assignments_userid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY fulfillment_role_assignments
    ADD CONSTRAINT fulfillment_role_assignments_userid_fkey FOREIGN KEY (userid) REFERENCES users(id);


--
-- Name: full_coverages_facilityvisitid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY full_coverages
    ADD CONSTRAINT full_coverages_facilityvisitid_fkey FOREIGN KEY (facilityvisitid) REFERENCES facility_visits(id);


--
-- Name: geographic_zones_levelid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY geographic_zones
    ADD CONSTRAINT geographic_zones_levelid_fkey FOREIGN KEY (levelid) REFERENCES geographic_levels(id);


--
-- Name: geographic_zones_parentid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY geographic_zones
    ADD CONSTRAINT geographic_zones_parentid_fkey FOREIGN KEY (parentid) REFERENCES geographic_zones(id);


--
-- Name: master_rnr_column_options_masterrnrcolumnid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY master_rnr_column_options
    ADD CONSTRAINT master_rnr_column_options_masterrnrcolumnid_fkey FOREIGN KEY (masterrnrcolumnid) REFERENCES master_rnr_columns(id);


--
-- Name: master_rnr_column_options_rnroptionid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY master_rnr_column_options
    ADD CONSTRAINT master_rnr_column_options_rnroptionid_fkey FOREIGN KEY (rnroptionid) REFERENCES configurable_rnr_options(id);


--
-- Name: opened_vial_line_items_facilityvisitid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY child_coverage_opened_vial_line_items
    ADD CONSTRAINT opened_vial_line_items_facilityvisitid_fkey FOREIGN KEY (facilityvisitid) REFERENCES facility_visits(id);


--
-- Name: orders_createdby_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orders
    ADD CONSTRAINT orders_createdby_fkey FOREIGN KEY (createdby) REFERENCES users(id);


--
-- Name: orders_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orders
    ADD CONSTRAINT orders_id_fkey FOREIGN KEY (id) REFERENCES requisitions(id);


--
-- Name: orders_modifiedby_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orders
    ADD CONSTRAINT orders_modifiedby_fkey FOREIGN KEY (modifiedby) REFERENCES users(id);


--
-- Name: orders_shipmentid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orders
    ADD CONSTRAINT orders_shipmentid_fkey FOREIGN KEY (shipmentid) REFERENCES shipment_file_info(id);


--
-- Name: orders_supplylineid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orders
    ADD CONSTRAINT orders_supplylineid_fkey FOREIGN KEY (supplylineid) REFERENCES supply_lines(id);


--
-- Name: pod_facilityid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pod
    ADD CONSTRAINT pod_facilityid_fkey FOREIGN KEY (facilityid) REFERENCES facilities(id);


--
-- Name: pod_line_items_podid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pod_line_items
    ADD CONSTRAINT pod_line_items_podid_fkey FOREIGN KEY (podid) REFERENCES pod(id);


--
-- Name: pod_line_items_productcode_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pod_line_items
    ADD CONSTRAINT pod_line_items_productcode_fkey FOREIGN KEY (productcode) REFERENCES products(code);


--
-- Name: pod_orderid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pod
    ADD CONSTRAINT pod_orderid_fkey FOREIGN KEY (orderid) REFERENCES orders(id);


--
-- Name: pod_periodid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pod
    ADD CONSTRAINT pod_periodid_fkey FOREIGN KEY (periodid) REFERENCES processing_periods(id);


--
-- Name: pod_programid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pod
    ADD CONSTRAINT pod_programid_fkey FOREIGN KEY (programid) REFERENCES programs(id);


--
-- Name: processing_periods_scheduleid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY processing_periods
    ADD CONSTRAINT processing_periods_scheduleid_fkey FOREIGN KEY (scheduleid) REFERENCES processing_schedules(id);


--
-- Name: products_dosageunitid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY products
    ADD CONSTRAINT products_dosageunitid_fkey FOREIGN KEY (dosageunitid) REFERENCES dosage_units(id);


--
-- Name: products_formid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY products
    ADD CONSTRAINT products_formid_fkey FOREIGN KEY (formid) REFERENCES product_forms(id);


--
-- Name: products_productgroupid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY products
    ADD CONSTRAINT products_productgroupid_fkey FOREIGN KEY (productgroupid) REFERENCES product_groups(id);


--
-- Name: program_product_isa_programproductid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY program_product_isa
    ADD CONSTRAINT program_product_isa_programproductid_fkey FOREIGN KEY (programproductid) REFERENCES program_products(id);


--
-- Name: program_product_price_history_programproductid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY program_product_price_history
    ADD CONSTRAINT program_product_price_history_programproductid_fkey FOREIGN KEY (programproductid) REFERENCES program_products(id);


--
-- Name: program_products_productcategoryid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY program_products
    ADD CONSTRAINT program_products_productcategoryid_fkey FOREIGN KEY (productcategoryid) REFERENCES product_categories(id);


--
-- Name: program_products_productid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY program_products
    ADD CONSTRAINT program_products_productid_fkey FOREIGN KEY (productid) REFERENCES products(id);


--
-- Name: program_products_programid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY program_products
    ADD CONSTRAINT program_products_programid_fkey FOREIGN KEY (programid) REFERENCES programs(id);


--
-- Name: program_regimen_columns_programid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY program_regimen_columns
    ADD CONSTRAINT program_regimen_columns_programid_fkey FOREIGN KEY (programid) REFERENCES programs(id);


--
-- Name: program_rnr_columns_mastercolumnid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY program_rnr_columns
    ADD CONSTRAINT program_rnr_columns_mastercolumnid_fkey FOREIGN KEY (mastercolumnid) REFERENCES master_rnr_columns(id);


--
-- Name: program_rnr_columns_rnroptionid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY program_rnr_columns
    ADD CONSTRAINT program_rnr_columns_rnroptionid_fkey FOREIGN KEY (rnroptionid) REFERENCES configurable_rnr_options(id);


--
-- Name: programs_supported_facilityid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY programs_supported
    ADD CONSTRAINT programs_supported_facilityid_fkey FOREIGN KEY (facilityid) REFERENCES facilities(id);


--
-- Name: programs_supported_programid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY programs_supported
    ADD CONSTRAINT programs_supported_programid_fkey FOREIGN KEY (programid) REFERENCES programs(id);


--
-- Name: refrigerator_problems_readingid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY refrigerator_problems
    ADD CONSTRAINT refrigerator_problems_readingid_fkey FOREIGN KEY (readingid) REFERENCES refrigerator_readings(id);


--
-- Name: refrigerator_readings_facilityvisitid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY refrigerator_readings
    ADD CONSTRAINT refrigerator_readings_facilityvisitid_fkey FOREIGN KEY (facilityvisitid) REFERENCES facility_visits(id);


--
-- Name: refrigerator_readings_refrigeratorid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY refrigerator_readings
    ADD CONSTRAINT refrigerator_readings_refrigeratorid_fkey FOREIGN KEY (refrigeratorid) REFERENCES refrigerators(id);


--
-- Name: refrigerators_createdby_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY refrigerators
    ADD CONSTRAINT refrigerators_createdby_fkey FOREIGN KEY (createdby) REFERENCES users(id);


--
-- Name: refrigerators_facilityid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY refrigerators
    ADD CONSTRAINT refrigerators_facilityid_fkey FOREIGN KEY (facilityid) REFERENCES facilities(id);


--
-- Name: refrigerators_modifiedby_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY refrigerators
    ADD CONSTRAINT refrigerators_modifiedby_fkey FOREIGN KEY (modifiedby) REFERENCES users(id);


--
-- Name: regimen_line_items_rnrid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY regimen_line_items
    ADD CONSTRAINT regimen_line_items_rnrid_fkey FOREIGN KEY (rnrid) REFERENCES requisitions(id);


--
-- Name: regimens_categoryid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY regimens
    ADD CONSTRAINT regimens_categoryid_fkey FOREIGN KEY (categoryid) REFERENCES regimen_categories(id);


--
-- Name: regimens_programid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY regimens
    ADD CONSTRAINT regimens_programid_fkey FOREIGN KEY (programid) REFERENCES programs(id);


--
-- Name: report_rights_rightname_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY report_rights
    ADD CONSTRAINT report_rights_rightname_fkey FOREIGN KEY (rightname) REFERENCES rights(name);


--
-- Name: report_rights_templateid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY report_rights
    ADD CONSTRAINT report_rights_templateid_fkey FOREIGN KEY (templateid) REFERENCES templates(id);


--
-- Name: requisition_group_members_facilityid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY requisition_group_members
    ADD CONSTRAINT requisition_group_members_facilityid_fkey FOREIGN KEY (facilityid) REFERENCES facilities(id);


--
-- Name: requisition_group_members_requisitiongroupid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY requisition_group_members
    ADD CONSTRAINT requisition_group_members_requisitiongroupid_fkey FOREIGN KEY (requisitiongroupid) REFERENCES requisition_groups(id);


--
-- Name: requisition_group_program_schedules_dropofffacilityid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY requisition_group_program_schedules
    ADD CONSTRAINT requisition_group_program_schedules_dropofffacilityid_fkey FOREIGN KEY (dropofffacilityid) REFERENCES facilities(id);


--
-- Name: requisition_group_program_schedules_programid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY requisition_group_program_schedules
    ADD CONSTRAINT requisition_group_program_schedules_programid_fkey FOREIGN KEY (programid) REFERENCES programs(id);


--
-- Name: requisition_group_program_schedules_requisitiongroupid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY requisition_group_program_schedules
    ADD CONSTRAINT requisition_group_program_schedules_requisitiongroupid_fkey FOREIGN KEY (requisitiongroupid) REFERENCES requisition_groups(id);


--
-- Name: requisition_group_program_schedules_scheduleid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY requisition_group_program_schedules
    ADD CONSTRAINT requisition_group_program_schedules_scheduleid_fkey FOREIGN KEY (scheduleid) REFERENCES processing_schedules(id);


--
-- Name: requisition_groups_supervisorynodeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY requisition_groups
    ADD CONSTRAINT requisition_groups_supervisorynodeid_fkey FOREIGN KEY (supervisorynodeid) REFERENCES supervisory_nodes(id);


--
-- Name: requisition_line_item_losses_adjustm_requisitionlineitemid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY requisition_line_item_losses_adjustments
    ADD CONSTRAINT requisition_line_item_losses_adjustm_requisitionlineitemid_fkey FOREIGN KEY (requisitionlineitemid) REFERENCES requisition_line_items(id);


--
-- Name: requisition_line_item_losses_adjustments_type_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY requisition_line_item_losses_adjustments
    ADD CONSTRAINT requisition_line_item_losses_adjustments_type_fkey FOREIGN KEY (type) REFERENCES losses_adjustments_types(name);


--
-- Name: requisition_line_items_productcode_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY requisition_line_items
    ADD CONSTRAINT requisition_line_items_productcode_fkey FOREIGN KEY (productcode) REFERENCES products(code);


--
-- Name: requisition_line_items_rnrid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY requisition_line_items
    ADD CONSTRAINT requisition_line_items_rnrid_fkey FOREIGN KEY (rnrid) REFERENCES requisitions(id);


--
-- Name: requisition_status_changes_createdby_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY requisition_status_changes
    ADD CONSTRAINT requisition_status_changes_createdby_fkey FOREIGN KEY (createdby) REFERENCES users(id);


--
-- Name: requisition_status_changes_modifiedby_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY requisition_status_changes
    ADD CONSTRAINT requisition_status_changes_modifiedby_fkey FOREIGN KEY (modifiedby) REFERENCES users(id);


--
-- Name: requisition_status_changes_rnrid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY requisition_status_changes
    ADD CONSTRAINT requisition_status_changes_rnrid_fkey FOREIGN KEY (rnrid) REFERENCES requisitions(id);


--
-- Name: requisitions_facilityid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY requisitions
    ADD CONSTRAINT requisitions_facilityid_fkey FOREIGN KEY (facilityid) REFERENCES facilities(id);


--
-- Name: requisitions_periodid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY requisitions
    ADD CONSTRAINT requisitions_periodid_fkey FOREIGN KEY (periodid) REFERENCES processing_periods(id);


--
-- Name: requisitions_programid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY requisitions
    ADD CONSTRAINT requisitions_programid_fkey FOREIGN KEY (programid) REFERENCES programs(id);


--
-- Name: requisitions_supervisorynodeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY requisitions
    ADD CONSTRAINT requisitions_supervisorynodeid_fkey FOREIGN KEY (supervisorynodeid) REFERENCES supervisory_nodes(id);


--
-- Name: role_assignments_deliveryzoneid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY role_assignments
    ADD CONSTRAINT role_assignments_deliveryzoneid_fkey FOREIGN KEY (deliveryzoneid) REFERENCES delivery_zones(id);


--
-- Name: role_assignments_programid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY role_assignments
    ADD CONSTRAINT role_assignments_programid_fkey FOREIGN KEY (programid) REFERENCES programs(id);


--
-- Name: role_assignments_roleid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY role_assignments
    ADD CONSTRAINT role_assignments_roleid_fkey FOREIGN KEY (roleid) REFERENCES roles(id);


--
-- Name: role_assignments_supervisorynodeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY role_assignments
    ADD CONSTRAINT role_assignments_supervisorynodeid_fkey FOREIGN KEY (supervisorynodeid) REFERENCES supervisory_nodes(id);


--
-- Name: role_assignments_userid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY role_assignments
    ADD CONSTRAINT role_assignments_userid_fkey FOREIGN KEY (userid) REFERENCES users(id);


--
-- Name: role_rights_rightname_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY role_rights
    ADD CONSTRAINT role_rights_rightname_fkey FOREIGN KEY (rightname) REFERENCES rights(name);


--
-- Name: role_rights_roleid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY role_rights
    ADD CONSTRAINT role_rights_roleid_fkey FOREIGN KEY (roleid) REFERENCES roles(id);


--
-- Name: shipment_line_items_orderid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY shipment_line_items
    ADD CONSTRAINT shipment_line_items_orderid_fkey FOREIGN KEY (orderid) REFERENCES orders(id);


--
-- Name: shipment_line_items_productcode_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY shipment_line_items
    ADD CONSTRAINT shipment_line_items_productcode_fkey FOREIGN KEY (productcode) REFERENCES products(code);


--
-- Name: supervisory_nodes_facilityid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY supervisory_nodes
    ADD CONSTRAINT supervisory_nodes_facilityid_fkey FOREIGN KEY (facilityid) REFERENCES facilities(id);


--
-- Name: supervisory_nodes_parentid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY supervisory_nodes
    ADD CONSTRAINT supervisory_nodes_parentid_fkey FOREIGN KEY (parentid) REFERENCES supervisory_nodes(id);


--
-- Name: supply_lines_programid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY supply_lines
    ADD CONSTRAINT supply_lines_programid_fkey FOREIGN KEY (programid) REFERENCES programs(id);


--
-- Name: supply_lines_supervisorynodeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY supply_lines
    ADD CONSTRAINT supply_lines_supervisorynodeid_fkey FOREIGN KEY (supervisorynodeid) REFERENCES supervisory_nodes(id);


--
-- Name: supply_lines_supplyingfacilityid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY supply_lines
    ADD CONSTRAINT supply_lines_supplyingfacilityid_fkey FOREIGN KEY (supplyingfacilityid) REFERENCES facilities(id);


--
-- Name: template_parameters_templateid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY template_parameters
    ADD CONSTRAINT template_parameters_templateid_fkey FOREIGN KEY (templateid) REFERENCES templates(id);


--
-- Name: user_password_reset_tokens_userid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY user_password_reset_tokens
    ADD CONSTRAINT user_password_reset_tokens_userid_fkey FOREIGN KEY (userid) REFERENCES users(id);


--
-- Name: users_facilityid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_facilityid_fkey FOREIGN KEY (facilityid) REFERENCES facilities(id);


--
-- Name: users_supervisorid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_supervisorid_fkey FOREIGN KEY (supervisorid) REFERENCES users(id);


--
-- Name: vaccination_adult_coverage_line_items_facilityvisitid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY vaccination_adult_coverage_line_items
    ADD CONSTRAINT vaccination_adult_coverage_line_items_facilityvisitid_fkey FOREIGN KEY (facilityvisitid) REFERENCES facility_visits(id);


--
-- Name: vaccination_child_coverage_line_items_facilityvisitid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY vaccination_child_coverage_line_items
    ADD CONSTRAINT vaccination_child_coverage_line_items_facilityvisitid_fkey FOREIGN KEY (facilityvisitid) REFERENCES facility_visits(id);


--
-- Name: public; Type: ACL; Schema: -; Owner: twer
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
-- REVOKE ALL ON SCHEMA public FROM twer;
-- GRANT ALL ON SCHEMA public TO twer;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

