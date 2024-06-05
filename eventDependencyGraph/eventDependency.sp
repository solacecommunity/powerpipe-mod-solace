dashboard "event_dependency" {
  title = "[3] Event Dependency Explorer"

  input "domain" {
    title = "Application Domain"
    type  = "combo"
    width = 4

    sql = <<-EOQ
      select name as label, id as value
      from solace_application_domain
    EOQ
  }

  input "event" {
    title = "Event"
    type  = "combo"
    width = 4

    sql = <<-EOQ
      select name as label, id as value
      from solace_event
      where application_domain_id = $1
    EOQ
    args = [self.input.domain.value]
  }

  
  graph {
    title = "Event Dependency Graph"

    node "event_graph_node_event" {
      category = category.event_dep_graph_event

      sql = <<-EOQ
        SELECT
          e.id AS id,
          e.name AS title,
          json_build_object(
            'id', e.id,
            'domain', d.name,
            'event', e.name
          ) AS properties
        FROM
          solace_event e
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        WHERE
          e.application_domain_id = $1
          AND e.id = $2
      EOQ

      args = [self.input.domain.value, self.input.event.value]        
    }

    node "event_graph_node_event_version" {
      category = category.event_dep_graph_event_version
      sql = <<-EOQ
        SELECT DISTINCT ON (ev.id)
          ev.id AS id,
          CONCAT('v', ev.version) AS title,
          JSON_BUILD_OBJECT(
            'id', ev.id,
            'domain', d.name,
            'event', e.name,
            'version', ev.version
          ) AS properties
        FROM
          solace_event_version ev
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        WHERE
          ev.event_id = $1
      EOQ

      args = [self.input.event.value]        
    }

    edge "event_graph_edge_event_to_eventversion" {
      category = category.event_dep_graph_event_version
      sql = <<-EOQ
        SELECT DISTINCT ON (e.id, ev.id)
          e.id AS from_id,
          ev.id AS to_id
        FROM solace_event e
        JOIN solace_event_version ev ON ev.event_id = e.id
        WHERE ev.event_id = $1;
      EOQ

      args = [self.input.event.value]        
    }
    
    node "event_graph_node_application_version" {
      category = category.event_dep_graph_application_version

      sql = <<-EOQ
        WITH avids AS (
          SELECT DISTINCT string_to_table(ev.declared_consuming_application_version_ids || ', ' || ev.declared_producing_application_version_ids, ', ') AS aid, ev.id AS evid
          FROM solace_event_version ev
          WHERE ev.event_id = $1
        )
        SELECT DISTINCT ON (av.id, ev.id)
          av.id AS id,
          concat(a.name, ' v', av.version) AS title,
          json_build_object(
            'id', av.id,
            'domain', d.name,
            'application', a.name,
            'version', av.version
          ) AS properties
        FROM avids
        JOIN solace_event_version ev ON avids.evid = ev.id
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        JOIN solace_application_version av ON avids.aid LIKE '%' || av.id || '%'
        JOIN solace_application a ON av.application_id = a.id
        WHERE avids.aid <> ''
          AND EXISTS (
            SELECT 1
            FROM avids
            WHERE avids.aid LIKE '%' || av.id || '%'
          )
        ORDER BY av.id, ev.id

      EOQ

      args = [self.input.event.value]                
    }

    node "event_graph_node_static_application_version" {
      category = category.event_dep_graph_application_version
      sql = <<-EOQ
        SELECT DISTINCT ON (e.id, ev.id)
          'AV-' || ev.id AS id,
          'Application Versions' AS title
        FROM solace_event e
        JOIN solace_event_version ev ON ev.event_id = e.id
        WHERE ev.event_id = $1 AND ev.declared_consuming_application_version_ids || ' ' || ev.declared_producing_application_version_ids <> ' ';
      EOQ

      args = [self.input.event.value]                
    }

    edge "event_graph_node_eventversion_to_static_application_version" {
      category = category.event_dep_graph_application_version
      sql = <<-EOQ
        SELECT DISTINCT ON (e.id, ev.id)
          'AV-' || ev.id AS to_id,
          ev.id AS from_id
        FROM solace_event e
        JOIN solace_event_version ev ON ev.event_id = e.id
        WHERE ev.event_id = $1;
      EOQ

      args = [self.input.event.value]                
    }

    edge "event_graph_edge_static_application_version_to_application_version" {
      category = category.event_dep_graph_application_version
      sql = <<-EOQ
        WITH avids AS (
          SELECT DISTINCT string_to_table(ev.declared_consuming_application_version_ids || ', ' || ev.declared_producing_application_version_ids, ', ') AS aid, ev.id AS evid
          FROM solace_event_version ev
          WHERE ev.event_id = $1
        )
        SELECT
          'AV-' || ev.id AS from_id,
          av.id AS to_id
        FROM 
          avids
        JOIN solace_event_version ev ON ev.id = avids.evid
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        JOIN solace_application_version av ON avids.aid LIKE '%' || av.id || '%'
        JOIN solace_application a ON av.application_id = a.id
        WHERE 
          ev.event_id = $1
          AND avids.aid <> ''
        
      EOQ

      args = [self.input.event.value]        

    }

    node "event_graph_node_schema_version" {
      category = category.event_dep_graph_schema_version

      sql = <<-EOQ
        SELECT sv.id AS id,
          CONCAT(s.name, ' v', sv.version) AS title,
          json_build_object(
              'id', sv.id,
              'domain', d.name,
              'schema', s.name,
              'version', sv.version
          ) AS properties
        FROM solace_event_version ev
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        JOIN solace_schema_version sv ON ev.schema_version_id = sv.id
        JOIN solace_schema s ON s.id = sv.schema_id
        WHERE ev.event_id = $1
        
      EOQ
      args = [self.input.event.value]        
    }

    edge "event_graph_edge_eventversion_to_schemaversion" {
      category = category.event_dep_graph_schema_version

      sql = <<-EOQ
        SELECT ev.id AS from_id, sv.id AS to_id
        FROM solace_event_version ev
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_schema_version sv ON ev.schema_version_id = sv.id
        JOIN solace_schema s ON s.id = sv.schema_id
        WHERE ev.event_id = $1;        
      EOQ
      args = [self.input.event.value]        
    }

    node "event_graph_node_enum_version" {
      category = category.event_dep_graph_enum_version

      sql = <<-EOQ
        WITH evids AS (
          SELECT DISTINCT
            TRIM(BOTH FROM REPLACE(REPLACE(env.referenced_by_event_version_ids, '[', ''), ']', ''), ' ') AS revids,
            env.enum_id AS enid,
            env.id AS envid
          FROM solace_enum_version env
        )
        SELECT DISTINCT ON (env.id, evid)
          env.id AS id,
          ev.id AS evid,
          ev.event_id AS event_id,
          CONCAT(en.name, ' v', env.version) AS title,
          JSON_BUILD_OBJECT(
            'id', env.id,
            'domain', d.name,
            'application', a.name,
            'version', env.version
          ) AS properties
        FROM evids
        JOIN solace_enum_version env ON env.id = evids.envid
        JOIN solace_enum en ON env.enum_id = en.id
        JOIN solace_application a ON en.application_domain_id = a.application_domain_id
        JOIN solace_application_domain d ON d.id = a.application_domain_id
        JOIN solace_application_version av ON av.application_id = a.id
        JOIN solace_event e ON e.id = $1
        JOIN solace_event_version ev ON ev.event_id = e.id
        WHERE evids.revids LIKE '%' || ev.id || '%'
          AND CONCAT(ev.declared_consuming_application_version_ids, ev.declared_producing_application_version_ids) LIKE '%' || av.id || '%'
        
      EOQ
      args = [self.input.event.value]        
    }

    edge "event_graph_edge_eventversion_to_enumversion" {
      category = category.event_dep_graph_enum_version

      sql = <<-EOQ
        WITH evids AS (
          SELECT DISTINCT
            TRIM(BOTH FROM REPLACE(REPLACE(env.referenced_by_event_version_ids, '[', ''), ']', ''), ' ') AS revids,
            env.enum_id AS enid,
            env.id AS envid
          FROM solace_enum_version env
        )
        SELECT DISTINCT ON (env.id, ev.id)
          ev.id AS from_id,
          env.id AS to_id
        FROM evids
        JOIN solace_enum_version env ON env.id = evids.envid
        JOIN solace_enum en ON env.enum_id = en.id
        JOIN solace_application a ON en.application_domain_id = a.application_domain_id
        JOIN solace_application_version av ON av.application_id = a.id
        JOIN solace_application_domain d ON d.id = a.application_domain_id
        JOIN solace_event e ON e.id = $1
        JOIN solace_event_version ev ON ev.event_id = e.id
        WHERE evids.revids LIKE '%' || ev.id || '%'
          AND CONCAT(ev.declared_consuming_application_version_ids, ev.declared_producing_application_version_ids) LIKE '%' || av.id || '%'
        
      EOQ
      args = [self.input.event.value]        
    }

    node "event_graph_node_eventapi_version" {
      category = category.event_dep_graph_eventapi_version

      sql = <<-EOQ
        WITH evapids AS (
          SELECT concat(evapi.produced_event_version_ids || ', ' || evapi.consumed_event_version_ids) AS evpcid, 
            evapi.id AS id, evapi.version as version, evapi.event_api_id as eapid, eapi.name as eapiname, ev.id AS eid
          FROM solace_eventapi_version evapi
          JOIN solace_eventapi eapi ON evapi.event_api_id = eapi.id
          JOIN solace_event_version ev ON concat(evapi.produced_event_version_ids || ', ' || evapi.consumed_event_version_ids) LIKE '%' || ev.id || '%'
          WHERE ev.event_id = $1
        )
        SELECT
          evapids.id AS id,
          concat(evapids.eapiname, ' v', evapids.version) AS title,
          json_build_object(
            'id', evapids.id,
            'domain', d.name,
            'eventapi', evapids.eapiname,
            'version', evapids.version
          ) AS properties
        FROM evapids
        JOIN solace_event_version ev ON evapids.eid = ev.id
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        
      EOQ
      args = [self.input.event.value]        
    }

    edge "event_graph_edge_eventversion_to_eventapiversion" {
      category = category.event_dep_graph_eventapi_version

      sql = <<-EOQ
        WITH evapids AS (
          SELECT concat(evapi.produced_event_version_ids || ', ' || evapi.consumed_event_version_ids) AS evpcid, 
            evapi.id AS id, evapi.version as version, evapi.event_api_id as eapid, eapi.name as eapiname, ev.id AS eid
          FROM solace_eventapi_version evapi
          JOIN solace_eventapi eapi ON evapi.event_api_id = eapi.id
          JOIN solace_event_version ev ON concat(evapi.produced_event_version_ids || ', ' || evapi.consumed_event_version_ids) LIKE '%' || ev.id || '%'
          WHERE ev.event_id = $1
        )
        SELECT
          evapids.eid AS from_id,
          evapids.id AS to_id
        FROM evapids
      EOQ
      args = [self.input.event.value]        
    }

    node "event_graph_node_eventapi_product_version" {
      category = category.event_dep_graph_eventapi_product_version

      sql = <<-EOQ
        WITH evapipids AS (
          SELECT evapip.event_api_version_ids  AS evapids, 
            evapip.id AS evapipid, evapip.version as evapipversion, evapip.event_api_product_id as evapip_eapipid,  eapip.name as eapipname, 
            CONCAT(ev.consuming_event_api_version_ids, ' ', ev.producing_event_api_version_ids) as evapiversions,
            ev.id AS evid, e.id as eid, e.name as ename
          FROM solace_eventapi_product_version evapip 
          JOIN solace_eventapi_product eapip ON evapip.event_api_product_id = eapip.id
          JOIN solace_eventapi_version evapi on evapip.event_api_version_ids LIKE '%' || evapi.id || '%'
          JOIN solace_event_version ev ON CONCAT(ev.consuming_event_api_version_ids, ' ', ev.producing_event_api_version_ids) LIKE '%' || evapi.id || '%'
          JOIN solace_event e ON ev.event_id = e.id
          WHERE ev.event_id = $1
        )
        SELECT
          evapipids.evapipid AS id,
          concat(evapipids.eapipname, ' v', evapipids.evapipversion) AS title,
          json_build_object(
            'id', evapipids.evapipid,
            'domain', d.name,
            'eventapi_product', evapipids.eapipname,
            'version', evapipids.evapipversion
          ) AS properties
        FROM evapipids
        JOIN solace_event e ON e.id = evapipids.eid
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        
      EOQ
      args = [self.input.event.value]        
    }

    edge "event_graph_edge_eventversion_to_eventapiproductversion" {
      category = category.event_dep_graph_eventapi_product_version

      sql = <<-EOQ
        WITH evapipids AS (
          SELECT evapip.event_api_version_ids  AS evapids, 
            evapip.id AS evapipid, evapip.version as evapipversion, evapip.event_api_product_id as evapip_eapipid,  
            eapip.id as eapipid, eapip.name as eapipname, 
            CONCAT(ev.consuming_event_api_version_ids, ' ', ev.producing_event_api_version_ids) as evapiversions,            
            ev.id AS evid, e.id as eid, e.name as ename
          FROM solace_eventapi_product_version evapip 
          JOIN solace_eventapi_product eapip ON evapip.event_api_product_id = eapip.id
          JOIN solace_eventapi_version evapi on evapip.event_api_version_ids LIKE '%' || evapi.id || '%'
          JOIN solace_event_version ev ON CONCAT(ev.consuming_event_api_version_ids, ' ', ev.producing_event_api_version_ids) LIKE '%' || evapi.id || '%'
          JOIN solace_event e ON ev.event_id = e.id
          WHERE ev.event_id = $1
        )
        SELECT
          evapipids.evid AS from_id,
          evapipids.evapipid AS to_id
        FROM evapipids
      EOQ
      args = [self.input.event.value]        
    }
  
    node "event_graph_node_application" {
      category = category.event_dep_graph_application

      sql = <<-EOQ
        WITH avids AS (
          SELECT DISTINCT string_to_table(ev.declared_consuming_application_version_ids || ', ' || ev.declared_producing_application_version_ids, ', ') AS aid, ev.id AS evid
          FROM solace_event_version ev
          WHERE ev.event_id = $1
        )
        SELECT DISTINCT ON (a.id)
          a.id AS id,
          a.name AS title,
          json_build_object(
            'id', av.id,
            'domain', d.name,
            'application', a.name
          ) AS properties
        FROM avids
        JOIN solace_event_version ev ON avids.evid = ev.id
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        JOIN solace_application_version av ON avids.aid LIKE '%' || av.id || '%'
        JOIN solace_application a ON av.application_id = a.id
        WHERE avids.aid <> ''
          AND EXISTS (
            SELECT 1
            FROM avids
            WHERE avids.aid LIKE '%' || av.id || '%'
          )
        ORDER BY a.id

      EOQ

      args = [self.input.event.value]                
    }

    edge "event_graph_edge_application_version_to_application" {
      category = category.event_dep_graph_application
      sql = <<-EOQ
        WITH avids AS (
          SELECT DISTINCT string_to_table(ev.declared_consuming_application_version_ids || ', ' || ev.declared_producing_application_version_ids, ', ') AS aid, ev.id AS evid
          FROM solace_event_version ev
          WHERE ev.event_id = $1
        )
        SELECT DISTINCT ON (av.id)
          av.id as from_id,
          a.id as to_id
        FROM avids
        JOIN solace_event_version ev ON avids.evid = ev.id
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        JOIN solace_application_version av ON avids.aid LIKE '%' || av.id || '%'
        JOIN solace_application a ON av.application_id = a.id
        WHERE avids.aid <> ''
          AND EXISTS (
            SELECT 1
            FROM avids
            WHERE avids.aid LIKE '%' || av.id || '%'
          )
        ORDER BY av.id
      EOQ

      args = [self.input.event.value]                
    }

    node "event_graph_node_application_domain" {
      category = category.event_dep_graph_application_domain

      sql = <<-EOQ
        WITH avids AS (
          SELECT DISTINCT string_to_table(ev.declared_consuming_application_version_ids || ', ' || ev.declared_producing_application_version_ids, ', ') AS aid, ev.id AS evid
          FROM solace_event_version ev
          WHERE ev.event_id = $1
        )
        SELECT DISTINCT ON (d.id)
          d.id AS id,
          d.name AS title,
          json_build_object(
            'id', av.id,
            'domain', d.name,
            'application', a.name
          ) AS properties
        FROM avids
        JOIN solace_event_version ev ON avids.evid = ev.id
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        JOIN solace_application_version av ON avids.aid LIKE '%' || av.id || '%'
        JOIN solace_application a ON av.application_id = a.id
        WHERE avids.aid <> ''
          AND EXISTS (
            SELECT 1
            FROM avids
            WHERE avids.aid LIKE '%' || av.id || '%'
          )
        ORDER BY d.id

      EOQ

      args = [self.input.event.value]                
    }

    edge "event_graph_edge_application_to_application_domain" {
      category = category.event_dep_graph_application_domain
      sql = <<-EOQ
        WITH avids AS (
          SELECT DISTINCT string_to_table(ev.declared_consuming_application_version_ids || ', ' || ev.declared_producing_application_version_ids, ', ') AS aid, ev.id AS evid
          FROM solace_event_version ev
          WHERE ev.event_id = $1
        )
        SELECT DISTINCT ON (a.id)
          a.id as from_id,
          d.id as to_id
        FROM avids
        JOIN solace_event_version ev ON avids.evid = ev.id
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        JOIN solace_application_version av ON avids.aid LIKE '%' || av.id || '%'
        JOIN solace_application a ON av.application_id = a.id
        WHERE avids.aid <> ''
          AND EXISTS (
            SELECT 1
            FROM avids
            WHERE avids.aid LIKE '%' || av.id || '%'
          )
        ORDER BY a.id
      EOQ

      args = [self.input.event.value]                
    }
  }

  flow {
    title = "Event Dependency Flow"

    node "event_flow_node_event" {
      category = category.event_dep_flow_event

      sql = <<-EOQ
        SELECT
          e.id AS id,
          e.name AS title, 0 as depth,
          json_build_object(
            'id', e.id,
            'domain', d.name,
            'event', e.name
          ) AS properties
        FROM
          solace_event e
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        WHERE
          e.application_domain_id = $1
          AND e.id = $2
      EOQ

      args = [self.input.domain.value, self.input.event.value]        
    }

    node "event_flow_node_event_version" {
      category = category.event_dep_flow_event_version
      sql = <<-EOQ
        SELECT DISTINCT ON (ev.id)
          ev.id AS id, 1 as depth,
          CONCAT('v', ev.version) AS title,
          JSON_BUILD_OBJECT(
            'id', ev.id,
            'domain', d.name,
            'event', e.name,
            'version', ev.version
          ) AS properties
        FROM
          solace_event_version ev
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        WHERE
          ev.event_id = $1
      EOQ

      args = [self.input.event.value]        
    }

    edge "event_flow_edge_event_to_eventversion" {
      category = category.event_dep_flow_event_version
      sql = <<-EOQ
        SELECT DISTINCT ON (e.id, ev.id)
          e.id AS from_id,
          ev.id AS to_id
        FROM solace_event e
        JOIN solace_event_version ev ON ev.event_id = e.id
        WHERE ev.event_id = $1;
      EOQ

      args = [self.input.event.value]        
    }
    
    node "event_flow_node_application_version" {
      category = category.event_dep_flow_application_version

      sql = <<-EOQ
        WITH avids AS (
          SELECT DISTINCT string_to_table(ev.declared_consuming_application_version_ids || ', ' || ev.declared_producing_application_version_ids, ', ') AS aid, ev.id AS evid
          FROM solace_event_version ev
          WHERE ev.event_id = $1
        )
        SELECT DISTINCT ON (av.id, ev.id)
          av.id AS id, 4 as depth,
          concat(a.name, ' v', av.version) AS title,
          json_build_object(
            'id', av.id,
            'domain', d.name,
            'application', a.name,
            'version', av.version
          ) AS properties
        FROM avids
        JOIN solace_event_version ev ON avids.evid = ev.id
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        JOIN solace_application_version av ON avids.aid LIKE '%' || av.id || '%'
        JOIN solace_application a ON av.application_id = a.id
        WHERE avids.aid <> ''
          AND EXISTS (
            SELECT 1
            FROM avids
            WHERE avids.aid LIKE '%' || av.id || '%'
          )
        ORDER BY av.id, ev.id

      EOQ

      args = [self.input.event.value]                
    }

    node "event_flow_node_static_application_version" {
      category = category.event_dep_flow_application_version
      sql = <<-EOQ
        SELECT DISTINCT ON (e.id, ev.id)
          'AV-' || ev.id AS id, 3 as depth,
          'Application Versions' AS title
        FROM solace_event e
        JOIN solace_event_version ev ON ev.event_id = e.id
        WHERE ev.event_id = $1 AND ev.declared_consuming_application_version_ids || ' ' || ev.declared_producing_application_version_ids <> ' ';
      EOQ

      args = [self.input.event.value]                
    }

    edge "event_flow_node_eventversion_to_static_application_version" {
      category = category.event_dep_flow_application_version
      sql = <<-EOQ
        SELECT DISTINCT ON (e.id, ev.id)
          'AV-' || ev.id AS to_id,
          ev.id AS from_id
        FROM solace_event e
        JOIN solace_event_version ev ON ev.event_id = e.id
        WHERE ev.event_id = $1;
      EOQ

      args = [self.input.event.value]                
    }

    edge "event_flow_edge_static_application_version_to_application_version" {
      category = category.event_dep_flow_application_version
      sql = <<-EOQ
        WITH avids AS (
          SELECT DISTINCT string_to_table(ev.declared_consuming_application_version_ids || ', ' || ev.declared_producing_application_version_ids, ', ') AS aid, ev.id AS evid
          FROM solace_event_version ev
          WHERE ev.event_id = $1
        )
        SELECT
          'AV-' || ev.id AS from_id,
          av.id AS to_id
        FROM 
          avids
        JOIN solace_event_version ev ON ev.id = avids.evid
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        JOIN solace_application_version av ON avids.aid LIKE '%' || av.id || '%'
        JOIN solace_application a ON av.application_id = a.id
        WHERE 
          ev.event_id = $1
          AND avids.aid <> ''
        
      EOQ

      args = [self.input.event.value]        

    }

    node "event_flow_node_schema_version" {
      category = category.event_dep_flow_schema_version

      sql = <<-EOQ
        SELECT sv.id AS id, 2 as depth,
          CONCAT(s.name, ' v', sv.version) AS title,
          json_build_object(
              'id', sv.id,
              'domain', d.name,
              'schema', s.name,
              'version', sv.version
          ) AS properties
        FROM solace_event_version ev
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        JOIN solace_schema_version sv ON ev.schema_version_id = sv.id
        JOIN solace_schema s ON s.id = sv.schema_id
        WHERE ev.event_id = $1
        
      EOQ
      args = [self.input.event.value]        
    }

    edge "event_flow_edge_eventversion_to_schemaversion" {
      category = category.event_dep_flow_schema_version

      sql = <<-EOQ
        SELECT ev.id AS from_id, sv.id AS to_id
        FROM solace_event_version ev
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_schema_version sv ON ev.schema_version_id = sv.id
        JOIN solace_schema s ON s.id = sv.schema_id
        WHERE ev.event_id = $1;        
      EOQ
      args = [self.input.event.value]        
    }

    node "event_flow_node_enum_version" {
      category = category.event_dep_flow_enum_version

      sql = <<-EOQ
        WITH evids AS (
          SELECT DISTINCT
            TRIM(BOTH FROM REPLACE(REPLACE(env.referenced_by_event_version_ids, '[', ''), ']', ''), ' ') AS revids,
            env.enum_id AS enid,
            env.id AS envid
          FROM solace_enum_version env
        )
        SELECT DISTINCT ON (env.id, evid)
          env.id AS id,
          ev.id AS evid,
          ev.event_id AS event_id,
          CONCAT(en.name, ' v', env.version) AS title,
          JSON_BUILD_OBJECT(
            'id', env.id,
            'domain', d.name,
            'application', a.name,
            'version', env.version
          ) AS properties
        FROM evids
        JOIN solace_enum_version env ON env.id = evids.envid
        JOIN solace_enum en ON env.enum_id = en.id
        JOIN solace_application a ON en.application_domain_id = a.application_domain_id
        JOIN solace_application_domain d ON d.id = a.application_domain_id
        JOIN solace_application_version av ON av.application_id = a.id
        JOIN solace_event e ON e.id = $1
        JOIN solace_event_version ev ON ev.event_id = e.id
        WHERE evids.revids LIKE '%' || ev.id || '%'
          AND CONCAT(ev.declared_consuming_application_version_ids, ev.declared_producing_application_version_ids) LIKE '%' || av.id || '%'
        
      EOQ
      args = [self.input.event.value]        
    }

    edge "event_flow_edge_eventversion_to_enumversion" {
      category = category.event_dep_flow_enum_version

      sql = <<-EOQ
        WITH evids AS (
          SELECT DISTINCT
            TRIM(BOTH FROM REPLACE(REPLACE(env.referenced_by_event_version_ids, '[', ''), ']', ''), ' ') AS revids,
            env.enum_id AS enid,
            env.id AS envid
          FROM solace_enum_version env
        )
        SELECT DISTINCT ON (env.id, ev.id)
          ev.id AS from_id,
          env.id AS to_id
        FROM evids
        JOIN solace_enum_version env ON env.id = evids.envid
        JOIN solace_enum en ON env.enum_id = en.id
        JOIN solace_application a ON en.application_domain_id = a.application_domain_id
        JOIN solace_application_version av ON av.application_id = a.id
        JOIN solace_application_domain d ON d.id = a.application_domain_id
        JOIN solace_event e ON e.id = $1
        JOIN solace_event_version ev ON ev.event_id = e.id
        WHERE evids.revids LIKE '%' || ev.id || '%'
          AND CONCAT(ev.declared_consuming_application_version_ids, ev.declared_producing_application_version_ids) LIKE '%' || av.id || '%'
        
      EOQ
      args = [self.input.event.value]        
    }

    node "event_flow_node_eventapi_version" {
      category = category.event_dep_flow_eventapi_version

      sql = <<-EOQ
        WITH evapids AS (
          SELECT concat(evapi.produced_event_version_ids || ', ' || evapi.consumed_event_version_ids) AS evpcid, 
            evapi.id AS id, evapi.version as version, evapi.event_api_id as eapid, eapi.name as eapiname, ev.id AS eid
          FROM solace_eventapi_version evapi
          JOIN solace_eventapi eapi ON evapi.event_api_id = eapi.id
          JOIN solace_event_version ev ON concat(evapi.produced_event_version_ids || ', ' || evapi.consumed_event_version_ids) LIKE '%' || ev.id || '%'
          WHERE ev.event_id = $1
        )
        SELECT
          evapids.id AS id,
          concat(evapids.eapiname, ' v', evapids.version) AS title,
          json_build_object(
            'id', evapids.id,
            'domain', d.name,
            'eventapi', evapids.eapiname,
            'version', evapids.version
          ) AS properties
        FROM evapids
        JOIN solace_event_version ev ON evapids.eid = ev.id
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        
      EOQ
      args = [self.input.event.value]        
    }

    edge "event_flow_edge_eventversion_to_eventapiversion" {
      category = category.event_dep_flow_eventapi_version

      sql = <<-EOQ
        WITH evapids AS (
          SELECT concat(evapi.produced_event_version_ids || ', ' || evapi.consumed_event_version_ids) AS evpcid, 
            evapi.id AS id, evapi.version as version, evapi.event_api_id as eapid, eapi.name as eapiname, ev.id AS eid
          FROM solace_eventapi_version evapi
          JOIN solace_eventapi eapi ON evapi.event_api_id = eapi.id
          JOIN solace_event_version ev ON concat(evapi.produced_event_version_ids || ', ' || evapi.consumed_event_version_ids) LIKE '%' || ev.id || '%'
          WHERE ev.event_id = $1
        )
        SELECT
          evapids.eid AS from_id,
          evapids.id AS to_id
        FROM evapids
      EOQ
      args = [self.input.event.value]        
    }

    node "event_flow_node_eventapi_product_version" {
      category = category.event_dep_flow_eventapi_product_version

      sql = <<-EOQ
        WITH evapipids AS (
          SELECT evapip.event_api_version_ids  AS evapids, 
            evapip.id AS evapipid, evapip.version as evapipversion, evapip.event_api_product_id as evapip_eapipid,  eapip.name as eapipname, 
            CONCAT(ev.consuming_event_api_version_ids, ' ', ev.producing_event_api_version_ids) as evapiversions,
            ev.id AS evid, e.id as eid, e.name as ename
          FROM solace_eventapi_product_version evapip 
          JOIN solace_eventapi_product eapip ON evapip.event_api_product_id = eapip.id
          JOIN solace_eventapi_version evapi on evapip.event_api_version_ids LIKE '%' || evapi.id || '%'
          JOIN solace_event_version ev ON CONCAT(ev.consuming_event_api_version_ids, ' ', ev.producing_event_api_version_ids) LIKE '%' || evapi.id || '%'
          JOIN solace_event e ON ev.event_id = e.id
          WHERE ev.event_id = $1
        )
        SELECT
          evapipids.evapipid AS id,
          concat(evapipids.eapipname, ' v', evapipids.evapipversion) AS title,
          json_build_object(
            'id', evapipids.evapipid,
            'domain', d.name,
            'eventapi_product', evapipids.eapipname,
            'version', evapipids.evapipversion
          ) AS properties
        FROM evapipids
        JOIN solace_event e ON e.id = evapipids.eid
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        
      EOQ
      args = [self.input.event.value]        
    }

    edge "event_flow_edge_eventversion_to_eventapiproductversion" {
      category = category.event_dep_flow_eventapi_product_version

      sql = <<-EOQ
        WITH evapipids AS (
          SELECT evapip.event_api_version_ids  AS evapids, 
            evapip.id AS evapipid, evapip.version as evapipversion, evapip.event_api_product_id as evapip_eapipid,  
            eapip.id as eapipid, eapip.name as eapipname, 
            CONCAT(ev.consuming_event_api_version_ids, ' ', ev.producing_event_api_version_ids) as evapiversions,            
            ev.id AS evid, e.id as eid, e.name as ename
          FROM solace_eventapi_product_version evapip 
          JOIN solace_eventapi_product eapip ON evapip.event_api_product_id = eapip.id
          JOIN solace_eventapi_version evapi on evapip.event_api_version_ids LIKE '%' || evapi.id || '%'
          JOIN solace_event_version ev ON CONCAT(ev.consuming_event_api_version_ids, ' ', ev.producing_event_api_version_ids) LIKE '%' || evapi.id || '%'
          JOIN solace_event e ON ev.event_id = e.id
          WHERE ev.event_id = $1
        )
        SELECT
          evapipids.evid AS from_id,
          evapipids.evapipid AS to_id
        FROM evapipids
      EOQ
      args = [self.input.event.value]        
    }
  
    node "event_flow_node_application" {
      category = category.event_dep_flow_application

      sql = <<-EOQ
        WITH avids AS (
          SELECT DISTINCT string_to_table(ev.declared_consuming_application_version_ids || ', ' || ev.declared_producing_application_version_ids, ', ') AS aid, ev.id AS evid
          FROM solace_event_version ev
          WHERE ev.event_id = $1
        )
        SELECT DISTINCT ON (a.id)
          a.id AS id, 6 as depth,
          a.name AS title,
          json_build_object(
            'id', av.id,
            'domain', d.name,
            'application', a.name
          ) AS properties
        FROM avids
        JOIN solace_event_version ev ON avids.evid = ev.id
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        JOIN solace_application_version av ON avids.aid LIKE '%' || av.id || '%'
        JOIN solace_application a ON av.application_id = a.id
        WHERE avids.aid <> ''
          AND EXISTS (
            SELECT 1
            FROM avids
            WHERE avids.aid LIKE '%' || av.id || '%'
          )
        ORDER BY a.id

      EOQ

      args = [self.input.event.value]                
    }

    edge "event_flow_edge_application_version_to_application" {
      category = category.event_dep_flow_application
      sql = <<-EOQ
        WITH avids AS (
          SELECT DISTINCT string_to_table(ev.declared_consuming_application_version_ids || ', ' || ev.declared_producing_application_version_ids, ', ') AS aid, ev.id AS evid
          FROM solace_event_version ev
          WHERE ev.event_id = $1
        )
        SELECT DISTINCT ON (av.id)
          av.id as from_id,
          a.id as to_id
        FROM avids
        JOIN solace_event_version ev ON avids.evid = ev.id
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        JOIN solace_application_version av ON avids.aid LIKE '%' || av.id || '%'
        JOIN solace_application a ON av.application_id = a.id
        WHERE avids.aid <> ''
          AND EXISTS (
            SELECT 1
            FROM avids
            WHERE avids.aid LIKE '%' || av.id || '%'
          )
        ORDER BY av.id
      EOQ

      args = [self.input.event.value]                
    }

    node "event_flow_node_application_domain" {
      category = category.event_dep_flow_application_domain

      sql = <<-EOQ
        WITH avids AS (
          SELECT DISTINCT string_to_table(ev.declared_consuming_application_version_ids || ', ' || ev.declared_producing_application_version_ids, ', ') AS aid, ev.id AS evid
          FROM solace_event_version ev
          WHERE ev.event_id = $1
        )
        SELECT DISTINCT ON (d.id)
          d.id AS id, 7 as depth,
          d.name AS title,
          json_build_object(
            'id', av.id,
            'domain', d.name,
            'application', a.name
          ) AS properties
        FROM avids
        JOIN solace_event_version ev ON avids.evid = ev.id
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        JOIN solace_application_version av ON avids.aid LIKE '%' || av.id || '%'
        JOIN solace_application a ON av.application_id = a.id
        WHERE avids.aid <> ''
          AND EXISTS (
            SELECT 1
            FROM avids
            WHERE avids.aid LIKE '%' || av.id || '%'
          )
        ORDER BY d.id

      EOQ

      args = [self.input.event.value]                
    }

    edge "event_flow_edge_application_to_application_domain" {
      category = category.event_dep_flow_application_domain
      sql = <<-EOQ
        WITH avids AS (
          SELECT DISTINCT string_to_table(ev.declared_consuming_application_version_ids || ', ' || ev.declared_producing_application_version_ids, ', ') AS aid, ev.id AS evid
          FROM solace_event_version ev
          WHERE ev.event_id = $1
        )
        SELECT DISTINCT ON (a.id)
          a.id as from_id,
          d.id as to_id
        FROM avids
        JOIN solace_event_version ev ON avids.evid = ev.id
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        JOIN solace_application_version av ON avids.aid LIKE '%' || av.id || '%'
        JOIN solace_application a ON av.application_id = a.id
        WHERE avids.aid <> ''
          AND EXISTS (
            SELECT 1
            FROM avids
            WHERE avids.aid LIKE '%' || av.id || '%'
          )
        ORDER BY a.id
      EOQ

      args = [self.input.event.value]                
    }


  }


  container {
    title = "Legend"
      text {
        width = 2
        value = <<-EOM
          Application Domain ![#ff0000](https://placehold.co/15x15/ff0000/ff0000.png) 
        EOM
      }
      text {
        width = 1
        value = <<-EOM
          Application ![#ff8700](https://placehold.co/15x15/ff8700/ff8700.png) 
        EOM
      }
      text {
        width = 1
        value = <<-EOM
          Event ![#ffd300](https://placehold.co/15x15/ffd300/ffd300.png) 
        EOM
      }
      text {
        width = 1
        value = <<-EOM
          Schema ![#0aefff](https://placehold.co/15x15/0aefff/0aefff.png) 
        EOM
      }
      text {
        width = 1
        value = <<-EOM
          Enum ![#0aff99](https://placehold.co/15x15/0aff99/0aff99.png) 
        EOM
      }
      text {
        width = 1
        value = <<-EOM
          EventAPI ![#147df5](https://placehold.co/15x15/147df5/147df5.png) 
        EOM
      }
      text {
        width = 1
        value = <<-EOM
          EventAPI Product ![#580aff](https://placehold.co/15x15/580aff/580aff.png) 
        EOM
      }

  }

}

category "event_dep_graph_application_domain" {
  title = "Application Domain"
  color = "black"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-app-domain.png"
}

category "event_dep_graph_static_applications" {
  title = "Applications"
  color = "black"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-application.png"
}

category "event_dep_graph_application" {
  title = "Application"
  color = "black"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-application.png"
}

category "event_dep_graph_static_application_versions" {
  title = "Application Versions"
  color = "black"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-application.png"
}

category "event_dep_graph_application_version" {
  title = "Application Version"
  color = "black"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-application.png"
}

category "event_dep_graph_event" {
  title = "Event"
  color = "black"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-event.png"
}

category "event_dep_graph_static_event_versions" {
  title = "Event Versions"
  color = "black"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-event.png"
}

category "event_dep_graph_event_version" {
  title = "Event Version"
  color = "black"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-event.png"
}

category "event_dep_graph_enum" {
  color = "black"
  icon = "https://cdn-icons-png.freepik.com/512/9447/9447665.png"
}

category "event_dep_graph_enum_version" {
  title = "Enum Version"
  color = "black"
  icon = "https://cdn-icons-png.freepik.com/512/9447/9447665.png"
}

category "event_dep_graph_schema" {
  title = "Schema"
  color = "black"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-schema.png"
}

category "event_dep_graph_schema_version" {
  title = "Schema Version"
  color = "black"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-schema.png"
}

category "event_dep_graph_eventapi" {
  title = "EventAPI"
  icon = "https://cdn-icons-png.freepik.com/512/7549/7549551.png"
  color = "black"
}

category "event_dep_graph_eventapi_version" {
  title = "EventAPI Version"
  icon = "https://cdn-icons-png.freepik.com/512/7549/7549551.png"
  color = "black"
}

category "event_dep_graph_eventapi_product" {
  title = "EventAPI Product"
  icon = "https://cdn-icons-png.freepik.com/512/10169/10169724.png"
  color = "black"
}

category "event_dep_graph_eventapi_product_version" {
  title = "EventAPI Product Version"
  icon = "https://cdn-icons-png.freepik.com/512/10169/10169724.png"
  color = "black"
}

category "event_dep_flow_application_domain" {
  title = "Application Domain"
  color = "#ff0000"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-app-domain.png"
}

category "event_dep_flow_static_applications" {
  title = "Applications"
  color = "#ff8700"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-application.png"
}

category "event_dep_flow_application" {
  title = "Application"
  color = "#ff8700"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-application.png"
}

category "event_dep_flow_static_application_versions" {
  title = "Application Versions"
  color = "#ff8700"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-application.png"
}

category "event_dep_flow_application_version" {
  title = "Application Version"
  color = "#ff8700"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-application.png"
}

category "event_dep_flow_event" {
  title = "Event"
  color = "#ffd300"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-event.png"
}

category "event_dep_flow_static_event_versions" {
  title = "Event Versions"
  color = "#ffd300"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-event.png"
}

category "event_dep_flow_event_version" {
  title = "Event Version"
  color = "#ffd300"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-event.png"
}

category "event_dep_flow_enum" {
  color = "#ffd300"
  icon = "https://cdn-icons-png.freepik.com/512/9447/9447665.png"
}

category "event_dep_flow_enum_version" {
  title = "Enum Version"
  color = "#0aff99"
  icon = "https://cdn-icons-png.freepik.com/512/9447/9447665.png"
}

category "event_dep_flow_schema" {
  title = "Schema"
  color = "#0aefff"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-schema.png"
}

category "event_dep_flow_schema_version" {
  title = "Schema Version"
  color = "#0aefff"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-schema.png"
}

category "event_dep_flow_eventapi" {
  title = "EventAPI"
  icon = "https://cdn-icons-png.freepik.com/512/7549/7549551.png"
  color = "#147df5"
}

category "event_dep_flow_eventapi_version" {
  title = "EventAPI Version"
  icon = "https://cdn-icons-png.freepik.com/512/7549/7549551.png"
  color = "#147df5"
}

category "event_dep_flow_eventapi_product" {
  title = "EventAPI Product"
  icon = "https://cdn-icons-png.freepik.com/512/10169/10169724.png"
  color = "#580aff"
}

category "event_dep_flow_eventapi_product_version" {
  title = "EventAPI Product Version"
  icon = "https://cdn-icons-png.freepik.com/512/10169/10169724.png"
  color = "#580aff"
}