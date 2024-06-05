dashboard "schema_dependency" {
  title = "[4] Schema Dependency Explorer"

  input "domain" {
    title = "Application Domain"
    type  = "combo"
    width = 4

    sql = <<-EOQ
      select name as label, id as value
      from solace_application_domain
    EOQ
  }

  input "schema" {
    title = "Schema"
    type  = "combo"
    width = 4

    sql = <<-EOQ
      select name as label, id as value
      from solace_schema
      where application_domain_id = $1
    EOQ
    args = [self.input.domain.value]
  }

  
  graph {
    title = "Schema Dependency Graph"

    node "graph_node_schema" {
      category = category.schema_dep_graph_schema
      sql = <<-EOQ
        SELECT
          s.id AS id,
          s.name AS title,
          json_build_object(
            'id', s.id,
            'domain', d.name,
            'event', s.name
          ) AS properties
        FROM
          solace_schema s
        JOIN solace_application_domain d ON d.id = s.application_domain_id
        WHERE
          s.application_domain_id = $1
          AND s.id = $2
      EOQ

      args = [self.input.domain.value, self.input.schema.value]        
    }

    node "graph_node_schema_version" {
      category = category.schema_dep_graph_schema_version
      sql = <<-EOQ
        SELECT DISTINCT ON (sv.id)
          sv.id AS id,
          CONCAT('v', sv.version) AS title,
          JSON_BUILD_OBJECT(
            'id', sv.id,
            'domain', d.name,
            'schema', s.name,
            'version', sv.version
          ) AS properties
        FROM
          solace_schema_version sv
        JOIN solace_schema s ON sv.schema_id = s.id
        JOIN solace_application_domain d ON d.id = s.application_domain_id
        WHERE
          sv.schema_id = $1
      EOQ

      args = [self.input.schema.value]        
    }

    edge "graph_edge_schema_to_schemaversion" {
      category = category.schema_dep_graph_schema_version
      sql = <<-EOQ
        SELECT DISTINCT ON (s.id, sv.id)
          s.id AS from_id,
          sv.id AS to_id
        FROM solace_schema s
        JOIN solace_schema_version sv ON sv.schema_id = s.id
        WHERE sv.schema_id = $1;
      EOQ

      args = [self.input.schema.value]        
    }

    node "graph_node_static_event_version" {
      category = category.schema_dep_graph_static_event_versions
      sql = <<-EOQ
          SELECT DISTINCT ON (e.id)
            'EV-' || e.id AS id,
            'Event Versions' AS title,
            JSON_BUILD_OBJECT(
              'id', e.id,
              'domain', d.name,
              'event', e.name
            ) AS properties
          FROM solace_event_version ev
          JOIN solace_event e ON ev.event_id = e.id
          JOIN solace_application_domain d ON d.id = e.application_domain_id
          JOIN solace_schema s ON s.application_domain_id = d.id
          JOIN solace_schema_version sv ON ev.schema_version_id = sv.id and s.id = sv.schema_id
          WHERE s.id = $2 and d.id = $1
      EOQ

      args = [self.input.domain.value, self.input.schema.value]                
    }

    node "graph_node_event_version" {
      category = category.schema_dep_graph_event_version

      sql = <<-EOQ
        SELECT 
          ev.id AS id,
          concat(e.name, ' v', ev.version) AS title,
          json_build_object(
            'id', ev.id,
            'domain', d.name,
            'event', e.name,
            'version', ev.version
          ) AS properties
        FROM solace_event_version ev
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        JOIN solace_schema s ON s.application_domain_id = d.id
        JOIN solace_schema_version sv ON ev.schema_version_id = sv.id and s.id = sv.schema_id
        WHERE s.id = $2 and d.id = $1
        ORDER BY e.name, ev.version
      EOQ

      args = [self.input.domain.value, self.input.schema.value]                
    }

    edge "graph_node_eventversion_to_static_event_version" {
      category = category.schema_dep_graph_static_event_versions
      sql = <<-EOQ
        SELECT 
            'EV-' || e.id AS from_id,
            ev.id AS to_id
          FROM solace_event_version ev
          JOIN solace_event e ON ev.event_id = e.id
          JOIN solace_application_domain d ON d.id = e.application_domain_id
          JOIN solace_schema_version sv ON ev.schema_version_id = sv.id
          JOIN solace_schema s ON s.application_domain_id = d.id
          WHERE s.id = $2 and d.id = $1
          ORDER BY e.name, ev.version          
      EOQ

      args = [self.input.domain.value, self.input.schema.value]                
    }

    edge "graph_node_schemaversion_to_static_event_version" {
      category = category.schema_dep_graph_static_event_versions
      sql = <<-EOQ
        SELECT 
            sv.id AS from_id,
            'EV-' || e.id AS to_id
          FROM solace_event_version ev
          JOIN solace_event e ON ev.event_id = e.id
          JOIN solace_application_domain d ON d.id = e.application_domain_id
          JOIN solace_schema_version sv ON ev.schema_version_id = sv.id
          JOIN solace_schema s ON s.application_domain_id = d.id
          WHERE s.id = $2 and d.id = $1
          ORDER BY e.name, ev.version          
      EOQ

      args = [self.input.domain.value, self.input.schema.value]                
    }

    node "graph_node_application" {
      category = category.schema_dep_graph_application
      sql = <<-EOQ
          SELECT DISTINCT ON (a.id)
            a.id AS id, 
            a.name AS title,
            JSON_BUILD_OBJECT(
              'id', a.id,
              'domain', d.name,
              'application', a.name
            ) AS properties
          FROM solace_event_version ev
          JOIN solace_event e ON ev.event_id = e.id
          JOIN solace_application_domain d ON d.id = e.application_domain_id
          JOIN solace_schema_version sv ON ev.schema_version_id = sv.id
          JOIN solace_schema s ON s.application_domain_id = d.id and s.id = sv.schema_id
          JOIN solace_application_version av ON (av.declared_consumed_event_version_ids LIKE '%' || ev.id || '%' 
            OR av.declared_produced_event_version_ids LIKE '%' || ev.id || '%')
          JOIN solace_application a ON a.id = av.application_id
          WHERE s.id = $2 and s.application_domain_id = $1
          ORDER BY a.id, e.name, ev.version           
      EOQ

      args = [self.input.domain.value, self.input.schema.value]                
    }

    node "graph_node_application_version" {
      category = category.schema_dep_graph_application_version

      sql = <<-EOQ
        SELECT 
          av.id AS id,
          concat(a.name, ' v', av.version) AS title,
          json_build_object(
            'id', av.id,
            'domain', da.name,
            'application', a.name,
            'version', av.version
          ) AS properties
        FROM solace_event_version ev
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        JOIN solace_schema s ON s.application_domain_id = d.id
        JOIN solace_schema_version sv ON ev.schema_version_id = sv.id and sv.schema_id = s.id
        JOIN solace_application_version av ON (av.declared_consumed_event_version_ids LIKE '%' || ev.id || '%' 
            OR av.declared_produced_event_version_ids LIKE '%' || ev.id || '%')
        JOIN solace_application a ON a.id = av.application_id
        JOIN solace_application_domain da ON da.id = a.application_domain_id
        WHERE s.id = $2 and s.application_domain_id = $1
      EOQ

      args = [self.input.domain.value, self.input.schema.value]                
    }

    edge "graph_edge_application_version_to_application" {
      category = category.schema_dep_graph_application
      sql = <<-EOQ
        SELECT 
          av.id AS from_id,
          a.id to_id
        FROM solace_event_version ev
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        JOIN solace_schema_version sv ON ev.schema_version_id = sv.id
        JOIN solace_schema s ON s.application_domain_id = d.id
        JOIN solace_application_version av ON (av.declared_consumed_event_version_ids LIKE '%' || ev.id || '%' 
            OR av.declared_produced_event_version_ids LIKE '%' || ev.id || '%')
        JOIN solace_application a ON a.id = av.application_id
        WHERE s.id = $2 and s.application_domain_id = $1
      EOQ

      args = [self.input.domain.value, self.input.schema.value]                

    }

    edge "graph_node_eventversion_to_application" {
      category = category.schema_dep_graph_application_version

      sql = <<-EOQ
        SELECT DISTINCT ON (sv.id, av.id)
          ev.id from_id,
          av.id AS to_id
        FROM solace_event_version ev
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        JOIN solace_schema s ON s.application_domain_id = d.id
        JOIN solace_schema_version sv ON ev.schema_version_id = sv.id and sv.schema_id = s.id
        JOIN solace_application_version av ON (av.declared_consumed_event_version_ids LIKE '%' || ev.id || '%' 
            OR av.declared_produced_event_version_ids LIKE '%' || ev.id || '%')
        JOIN solace_application a ON a.id = av.application_id
        WHERE s.id = $2 and s.application_domain_id = $1
      EOQ

      args = [self.input.domain.value, self.input.schema.value]                
    }

    node "graph_node_application_domain" {
      category = category.schema_dep_graph_application_domain

      sql = <<-EOQ
        SELECT DISTINCT ON (d.id)
          d.id AS id,
          d.name as title,
          json_build_object(
            'id', d.id,
            'domain', d.name
          ) AS properties
        FROM solace_event_version ev
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        JOIN solace_schema s ON s.application_domain_id = d.id
        JOIN solace_schema_version sv ON ev.schema_version_id = sv.id and sv.schema_id = s.id
        JOIN solace_application_version av ON (av.declared_consumed_event_version_ids LIKE '%' || ev.id || '%' 
            OR av.declared_produced_event_version_ids LIKE '%' || ev.id || '%')
        JOIN solace_application a ON a.id = av.application_id
        JOIN solace_application_domain da ON da.id = a.application_domain_id
        WHERE s.id = $2 and s.application_domain_id = $1
      EOQ

      args = [self.input.domain.value, self.input.schema.value]                
    }

    edge "graph_edge_application_to_application_domain" {
      category = category.schema_dep_graph_application_domain
      sql = <<-EOQ
        SELECT 
          a.id AS from_id,
          d.id to_id
        FROM solace_event_version ev
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        JOIN solace_schema_version sv ON ev.schema_version_id = sv.id
        JOIN solace_schema s ON s.application_domain_id = d.id
        JOIN solace_application_version av ON (av.declared_consumed_event_version_ids LIKE '%' || ev.id || '%' 
            OR av.declared_produced_event_version_ids LIKE '%' || ev.id || '%')
        JOIN solace_application a ON a.id = av.application_id
        WHERE s.id = $2 and s.application_domain_id = $1
      EOQ

      args = [self.input.domain.value, self.input.schema.value]                

    }

  }

  flow {
    title = "Schema Dependency Flow"

    node "flow_node_schema" {
      category = category.schema_dep_flow_schema
      sql = <<-EOQ
        SELECT
          s.id AS id,
          s.name AS title,
          json_build_object(
            'id', s.id,
            'domain', d.name,
            'event', s.name
          ) AS properties, 0 as depth
        FROM
          solace_schema s
        JOIN solace_application_domain d ON d.id = s.application_domain_id
        WHERE
          s.application_domain_id = $1
          AND s.id = $2
      EOQ

      args = [self.input.domain.value, self.input.schema.value]        
    }

    node "flow_node_schema_version" {
      category = category.schema_dep_flow_schema_version
      sql = <<-EOQ
        SELECT DISTINCT ON (sv.id)
          sv.id AS id,
          CONCAT('v', sv.version) AS title,
          JSON_BUILD_OBJECT(
            'id', sv.id,
            'domain', d.name,
            'schema', s.name,
            'version', sv.version
          ) AS properties, 1 as depth
        FROM
          solace_schema_version sv
        JOIN solace_schema s ON sv.schema_id = s.id
        JOIN solace_application_domain d ON d.id = s.application_domain_id
        WHERE
          sv.schema_id = $1
      EOQ

      args = [self.input.schema.value]        
    }

    edge "flow_edge_schema_to_schemaversion" {
      category = category.schema_dep_flow_schema_version
      sql = <<-EOQ
        SELECT DISTINCT ON (s.id, sv.id)
          s.id AS from_id,
          sv.id AS to_id
        FROM solace_schema s
        JOIN solace_schema_version sv ON sv.schema_id = s.id
        WHERE sv.schema_id = $1;
      EOQ

      args = [self.input.schema.value]        
    }
/*
    node "flow_node_static_event_version" {
      category = category.schema_dep_flow_static_event_versions
      sql = <<-EOQ
          SELECT DISTINCT ON (e.id)
            'EV-' || e.id AS id,
            'Event Versions' AS title,
            JSON_BUILD_OBJECT(
              'id', e.id,
              'domain', d.name,
              'event', e.name
            ) AS properties, 3 as depth
          FROM solace_event_version ev
          JOIN solace_event e ON ev.event_id = e.id
          JOIN solace_application_domain d ON d.id = e.application_domain_id
          JOIN solace_schema s ON s.application_domain_id = d.id
          JOIN solace_schema_version sv ON ev.schema_version_id = sv.id and s.id = sv.schema_id
          WHERE s.id = $2 and d.id = $1
      EOQ

      args = [self.input.domain.value, self.input.schema.value]                
    }
*/
    node "flow_node_event_version" {
      category = category.schema_dep_flow_event_version

      sql = <<-EOQ
        SELECT 
          ev.id AS id,
          concat(e.name, ' v', ev.version) AS title,
          json_build_object(
            'id', ev.id,
            'domain', d.name,
            'event', e.name,
            'version', ev.version
          ) AS properties, 4 as depth
        FROM solace_event_version ev
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        JOIN solace_schema s ON s.application_domain_id = d.id
        JOIN solace_schema_version sv ON ev.schema_version_id = sv.id and s.id = sv.schema_id
        WHERE s.id = $2 and d.id = $1
        ORDER BY e.name, ev.version
      EOQ

      args = [self.input.domain.value, self.input.schema.value]                
    }
/*
    edge "flow_node_eventversion_to_static_event_version" {
      category = category.schema_dep_flow_static_event_versions
      sql = <<-EOQ
        SELECT 
            'EV-' || e.id AS from_id,
            ev.id AS to_id
          FROM solace_event_version ev
          JOIN solace_event e ON ev.event_id = e.id
          JOIN solace_application_domain d ON d.id = e.application_domain_id
          JOIN solace_schema_version sv ON ev.schema_version_id = sv.id
          JOIN solace_schema s ON s.application_domain_id = d.id
          WHERE s.id = $2 and d.id = $1
          ORDER BY e.name, ev.version          
      EOQ

      args = [self.input.domain.value, self.input.schema.value]                
    }

    edge "flow_node_schemaversion_to_static_event_version" {
      category = category.schema_dep_flow_static_event_versions
      sql = <<-EOQ
        SELECT 
            sv.id AS from_id,
            'EV-' || e.id AS to_id
          FROM solace_event_version ev
          JOIN solace_event e ON ev.event_id = e.id
          JOIN solace_application_domain d ON d.id = e.application_domain_id
          JOIN solace_schema_version sv ON ev.schema_version_id = sv.id
          JOIN solace_schema s ON s.application_domain_id = d.id
          WHERE s.id = $2 and d.id = $1
          ORDER BY e.name, ev.version          
      EOQ

      args = [self.input.domain.value, self.input.schema.value]                
    }
*/

    edge "flow_node_schemaversion_to_event_version" {
      category = category.schema_dep_flow_event_version
      sql = <<-EOQ
        SELECT 
            sv.id AS from_id,
            ev.id AS to_id
          FROM solace_event_version ev
          JOIN solace_event e ON ev.event_id = e.id
          JOIN solace_application_domain d ON d.id = e.application_domain_id
          JOIN solace_schema_version sv ON ev.schema_version_id = sv.id
          JOIN solace_schema s ON s.application_domain_id = d.id
          WHERE s.id = $2 and d.id = $1
          ORDER BY e.name, ev.version          
      EOQ

      args = [self.input.domain.value, self.input.schema.value]                
    }

    node "flow_node_application" {
      category = category.schema_dep_flow_application
      sql = <<-EOQ
          SELECT DISTINCT ON (a.id)
            a.id AS id, 
            a.name AS title,
            JSON_BUILD_OBJECT(
              'id', a.id,
              'domain', d.name,
              'application', a.name
            ) AS properties, 8 as depth
          FROM solace_event_version ev
          JOIN solace_event e ON ev.event_id = e.id
          JOIN solace_application_domain d ON d.id = e.application_domain_id
          JOIN solace_schema_version sv ON ev.schema_version_id = sv.id
          JOIN solace_schema s ON s.application_domain_id = d.id and s.id = sv.schema_id
          JOIN solace_application_version av ON (av.declared_consumed_event_version_ids LIKE '%' || ev.id || '%' 
            OR av.declared_produced_event_version_ids LIKE '%' || ev.id || '%')
          JOIN solace_application a ON a.id = av.application_id
          WHERE s.id = $2 and s.application_domain_id = $1
          ORDER BY a.id, e.name, ev.version           
      EOQ

      args = [self.input.domain.value, self.input.schema.value]                
    }

    node "flow_node_application_version" {
      category = category.schema_dep_flow_application_version

      sql = <<-EOQ
        SELECT 
          av.id AS id,
          concat(a.name, ' v', av.version) AS title,
          json_build_object(
            'id', av.id,
            'domain', da.name,
            'application', a.name,
            'version', av.version
          ) AS properties, 6 as depth
        FROM solace_event_version ev
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        JOIN solace_schema s ON s.application_domain_id = d.id
        JOIN solace_schema_version sv ON ev.schema_version_id = sv.id and sv.schema_id = s.id
        JOIN solace_application_version av ON (av.declared_consumed_event_version_ids LIKE '%' || ev.id || '%' 
            OR av.declared_produced_event_version_ids LIKE '%' || ev.id || '%')
        JOIN solace_application a ON a.id = av.application_id
        JOIN solace_application_domain da ON da.id = a.application_domain_id
        WHERE s.id = $2 and s.application_domain_id = $1
      EOQ

      args = [self.input.domain.value, self.input.schema.value]                
    }

    edge "flow_edge_application_version_to_application" {
      category = category.schema_dep_flow_application_version
      sql = <<-EOQ
        SELECT 
          av.id AS from_id,
          a.id to_id
        FROM solace_event_version ev
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        JOIN solace_schema_version sv ON ev.schema_version_id = sv.id
        JOIN solace_schema s ON s.application_domain_id = d.id
        JOIN solace_application_version av ON (av.declared_consumed_event_version_ids LIKE '%' || ev.id || '%' 
            OR av.declared_produced_event_version_ids LIKE '%' || ev.id || '%')
        JOIN solace_application a ON a.id = av.application_id
        WHERE s.id = $2 and s.application_domain_id = $1
      EOQ

      args = [self.input.domain.value, self.input.schema.value]                

    }

    edge "flow_node_eventversion_to_application" {
      category = category.schema_dep_flow_application

      sql = <<-EOQ
        SELECT DISTINCT ON (sv.id, av.id)
          ev.id from_id,
          av.id AS to_id
        FROM solace_event_version ev
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        JOIN solace_schema s ON s.application_domain_id = d.id
        JOIN solace_schema_version sv ON ev.schema_version_id = sv.id and sv.schema_id = s.id
        JOIN solace_application_version av ON (av.declared_consumed_event_version_ids LIKE '%' || ev.id || '%' 
            OR av.declared_produced_event_version_ids LIKE '%' || ev.id || '%')
        JOIN solace_application a ON a.id = av.application_id
        WHERE s.id = $2 and s.application_domain_id = $1
      EOQ

      args = [self.input.domain.value, self.input.schema.value]                
    }

    node "flow_node_application_domain" {
      category = category.schema_dep_flow_application_domain

      sql = <<-EOQ
        SELECT DISTINCT ON (d.id)
          d.id AS id,
          d.name as title,
          json_build_object(
            'id', d.id,
            'domain', d.name
          ) AS properties, 10 as depth
        FROM solace_event_version ev
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        JOIN solace_schema s ON s.application_domain_id = d.id
        JOIN solace_schema_version sv ON ev.schema_version_id = sv.id and sv.schema_id = s.id
        JOIN solace_application_version av ON (av.declared_consumed_event_version_ids LIKE '%' || ev.id || '%' 
            OR av.declared_produced_event_version_ids LIKE '%' || ev.id || '%')
        JOIN solace_application a ON a.id = av.application_id
        JOIN solace_application_domain da ON da.id = a.application_domain_id
        WHERE s.id = $2 and s.application_domain_id = $1
      EOQ

      args = [self.input.domain.value, self.input.schema.value]                
    }

    edge "flow_edge_application_to_application_domain" {
      category = category.schema_dep_flow_application_domain
      sql = <<-EOQ
        SELECT 
          a.id AS from_id,
          d.id to_id
        FROM solace_event_version ev
        JOIN solace_event e ON ev.event_id = e.id
        JOIN solace_application_domain d ON d.id = e.application_domain_id
        JOIN solace_schema_version sv ON ev.schema_version_id = sv.id
        JOIN solace_schema s ON s.application_domain_id = d.id
        JOIN solace_application_version av ON (av.declared_consumed_event_version_ids LIKE '%' || ev.id || '%' 
            OR av.declared_produced_event_version_ids LIKE '%' || ev.id || '%')
        JOIN solace_application a ON a.id = av.application_id
        WHERE s.id = $2 and s.application_domain_id = $1
      EOQ

      args = [self.input.domain.value, self.input.schema.value]                

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

category "schema_dep_graph_application_domain" {
  title = "Application Domain"
  color = "black"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-app-domain.png"
}

category "schema_dep_graph_static_applications" {
  title = "Applications"
  color = "black"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-application.png"
}

category "schema_dep_graph_application" {
  title = "Application"
  color = "black"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-application.png"
}

category "schema_dep_graph_static_application_versions" {
  title = "Application Versions"
  color = "black"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-application.png"
}

category "schema_dep_graph_application_version" {
  title = "Application Version"
  color = "black"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-application.png"
}

category "schema_dep_graph_event" {
  title = "Event"
  color = "black"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-event.png"
}

category "schema_dep_graph_static_event_versions" {
  title = "Event Versions"
  color = "black"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-event.png"
}

category "schema_dep_graph_event_version" {
  title = "Event Version"
  color = "black"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-event.png"
}

category "schema_dep_graph_enum" {
  color = "black"
  icon = "https://cdn-icons-png.freepik.com/512/9447/9447665.png"
}

category "schema_dep_graph_enum_version" {
  title = "Enum Version"
  color = "black"
  icon = "https://cdn-icons-png.freepik.com/512/9447/9447665.png"
}

category "schema_dep_graph_schema" {
  title = "Schema"
  color = "black"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-schema.png"
}

category "schema_dep_graph_schema_version" {
  title = "Schema Version"
  color = "black"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-schema.png"
}

category "schema_dep_graph_eventapi" {
  title = "EventAPI"
  icon = "https://cdn-icons-png.freepik.com/512/7549/7549551.png"
  color = "black"
}

category "schema_dep_graph_eventapi_version" {
  title = "EventAPI Version"
  icon = "https://cdn-icons-png.freepik.com/512/7549/7549551.png"
  color = "black"
}

category "schema_dep_graph_eventapi_product" {
  title = "EventAPI Product"
  icon = "https://cdn-icons-png.freepik.com/512/10169/10169724.png"
  color = "black"
}

category "schema_dep_graph_eventapi_product_version" {
  title = "EventAPI Product Version"
  icon = "https://cdn-icons-png.freepik.com/512/10169/10169724.png"
  color = "black"
}

category "schema_dep_flow_application_domain" {
  title = "Application Domain"
  color = "#ff0000"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-app-domain.png"
}

category "schema_dep_flow_static_applications" {
  title = "Applications"
  color = "#ff8700"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-application.png"
}

category "schema_dep_flow_application" {
  title = "Application"
  color = "#ff8700"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-application.png"
}

category "schema_dep_flow_static_application_versions" {
  title = "Application Versions"
  color = "#ff8700"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-application.png"
}

category "schema_dep_flow_application_version" {
  title = "Application Version"
  color = "#ff8700"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-application.png"
}

category "schema_dep_flow_event" {
  title = "Event"
  color = "#ffd300"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-event.png"
}

category "schema_dep_flow_static_event_versions" {
  title = "Event Versions"
  color = "#ffd300"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-event.png"
}

category "schema_dep_flow_event_version" {
  title = "Event Version"
  color = "#ffd300"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-event.png"
}

category "schema_dep_flow_enum" {
  color = "#ffd300"
  icon = "https://cdn-icons-png.freepik.com/512/9447/9447665.png"
}

category "schema_dep_flow_enum_version" {
  title = "Enum Version"
  color = "#0aff99"
  icon = "https://cdn-icons-png.freepik.com/512/9447/9447665.png"
}

category "schema_dep_flow_schema" {
  title = "Schema"
  color = "#0aefff"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-schema.png"
}

category "schema_dep_flow_schema_version" {
  title = "Schema Version"
  color = "#0aefff"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-schema.png"
}

category "schema_dep_flow_eventapi" {
  title = "EventAPI"
  icon = "https://cdn-icons-png.freepik.com/512/7549/7549551.png"
  color = "#147df5"
}

category "schema_dep_flow_eventapi_version" {
  title = "EventAPI Version"
  icon = "https://cdn-icons-png.freepik.com/512/7549/7549551.png"
  color = "#147df5"
}

category "schema_dep_flow_eventapi_product" {
  title = "EventAPI Product"
  icon = "https://cdn-icons-png.freepik.com/512/10169/10169724.png"
  color = "#580aff"
}

category "schema_dep_flow_eventapi_product_version" {
  title = "EventAPI Product Version"
  icon = "https://cdn-icons-png.freepik.com/512/10169/10169724.png"
  color = "#580aff"
}