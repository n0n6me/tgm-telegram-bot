--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: cam; Type: TABLE; Schema: public; Owner: pgsql
--

CREATE TABLE cam (
    shop character varying(4) NOT NULL,
    url character varying(255)
);


ALTER TABLE cam OWNER TO pgsql;

--
-- Name: chat_id_name; Type: TABLE; Schema: public; Owner: pgsql
--

CREATE TABLE chat_id_name (
    chat_id integer NOT NULL,
    login integer
);


ALTER TABLE chat_id_name OWNER TO pgsql;

--
-- Name: retail_stat; Type: TABLE; Schema: public; Owner: pgsql
--

CREATE TABLE retail_stat (
    data timestamp without time zone,
    shop character varying(255),
    gross integer,
    cheks integer,
    goods integer,
    depart_name character varying(255),
    depart_code integer
);


ALTER TABLE retail_stat OWNER TO pgsql;

--
-- Name: users; Type: TABLE; Schema: public; Owner: pgsql
--

CREATE TABLE users (
    login integer,
    name character varying(255),
    depart_name character varying(255),
    depart_code integer,
    phone character varying(11)
);


ALTER TABLE users OWNER TO pgsql;

--
-- Name: cam_pkey; Type: CONSTRAINT; Schema: public; Owner: pgsql
--

ALTER TABLE ONLY cam
    ADD CONSTRAINT cam_pkey PRIMARY KEY (shop);


--
-- Name: chat_id_name_login_key; Type: CONSTRAINT; Schema: public; Owner: pgsql
--

ALTER TABLE ONLY chat_id_name
    ADD CONSTRAINT chat_id_name_login_key UNIQUE (login);


--
-- Name: chat_id_name_pkey; Type: CONSTRAINT; Schema: public; Owner: pgsql
--

ALTER TABLE ONLY chat_id_name
    ADD CONSTRAINT chat_id_name_pkey PRIMARY KEY (chat_id);


--
-- Name: public; Type: ACL; Schema: -; Owner: pgsql
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM pgsql;
GRANT ALL ON SCHEMA public TO pgsql;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

