dashboard "application_domain" {
  title = "[2] Application Domain Summary"
  text {
    value = "Dashboard of Solace Event Portal - Application Domain"
  }

  input "domain" {
    title = "Application Domain"
    type  = "combo"
    width = 4

    sql = <<-EOQ
      select name as label, id as value
      from solace_application_domain
    EOQ
  }

  input "application" {
    title = "Application"
    type  = "combo"
    width = 4

    sql = <<-EOQ
      select name as label, id as value
      from solace_application
      where application_domain_id = $1
    EOQ
    args = [self.input.domain.value]
  }

  flow {
    title = "Application Domain Summary"

    node domains {
      category = category.application_domain

      sql = <<-EOQ
        select id as id, name as title, 0 as depth
        from solace_application_domain
        where id = $1
      EOQ
      args = [self.input.domain.value]
    }

    node applications {
      category = category.application
      
      sql = <<-EOQ
        select id as id, name as title, 1 as depth
        from solace_application
        where application_domain_id = $1
      EOQ
      args = [self.input.domain.value]
    }

    edge domain_to_application {
      title = "Application"

      sql = <<-EOQ
        select id as to_id, application_domain_id as from_id
          from solace_application
          where application_domain_id = $1
      EOQ

      args = [self.input.domain.value]
    }

    node {
      category = category.application_version

      sql = <<-EOQ
        select a.id as id, a.version as title, 4 as depth
          from solace_application_version a
          JOIN solace_application b on a.application_id = b.id
          where b.id = $1
      EOQ
      args = [self.input.application.value]
    }

    edge application_to_applicationversion {
      category = category.application
      sql = <<-EOQ
        SELECT a.id AS from_id, b.id AS to_id
          FROM solace_application AS a
          JOIN solace_application_version AS b ON b.application_id = a.id
          WHERE a.id = $1

      EOQ

      args = [self.input.application.value]
    }

    node {
      category = category.event

      sql = <<-EOQ
        select a.id as id, a.name as title, 3 as depth
          from solace_event a
          where a.application_domain_id = $1
      EOQ
      args = [self.input.domain.value]
    }

    node {
      category = category.event_version

      sql = <<-EOQ
        SELECT a.id AS id, a.version AS title, 6 AS depth
          FROM solace_event_version a
          JOIN solace_event b ON a.event_id = b.id
          WHERE b.application_domain_id = $1
      EOQ
      args = [self.input.domain.value]
    }

    edge event_to_eventversion {
      sql = <<-EOQ
        SELECT a.id AS from_id, b.id AS to_id
          FROM solace_event a
          JOIN solace_event_version b ON b.event_id = a.id
          WHERE a.application_domain_id = $1
      EOQ

      args = [self.input.domain.value]
    }

    edge applicationversion_to_eventversion {
      title = "Application -> Event"

      sql = <<-EOQ
        WITH avids AS (
            SELECT DISTINCT string_to_table(TRIM(BOTH FROM(
              REPLACE(CONCAT(ev.declared_consuming_application_version_ids, ', ', ev.declared_producing_application_version_ids), '''', '')
            )), ', ') AS aid, ev.id AS evid
            FROM solace_event_version ev
            JOIN solace_event e ON e.id = ev.event_id
            JOIN solace_application_domain ad ON ad.id = e.application_domain_id
            WHERE ad.id = $1
        )
        SELECT a.id AS from_id, b.id AS to_id
        FROM avids
        JOIN solace_application_version AS a ON a.id = avids.aid
        JOIN solace_event_version AS b ON b.id = avids.evid
        WHERE a.application_id = $2
      EOQ

      args = [self.input.domain.value, self.input.application.value]
    }

    node {
      category = category.enum

      sql = <<-EOQ
      select a.id as id, a.name as title, 4 as depth
        from solace_enum a
        where a.application_domain_id = $1
      EOQ
      args = [self.input.domain.value]
    }

    node {
      category = category.enum_version

      sql = <<-EOQ
        select a.id as id, a.version as title, 5 as depth
          from solace_enum_version a, solace_enum b
          where b.application_domain_id = $1 and a.enum_id = b.id
      EOQ
      args = [self.input.domain.value]
    }

    edge enum_to_enumversion {
      sql = <<-EOQ
        select b.id as from_id, a.id as to_id
          from solace_enum_version a, solace_enum b
          where b.application_domain_id = $1 and a.enum_id = b.id
      EOQ

      args = [self.input.domain.value]
    }

    edge enumversion_to_eventversion {
      sql = <<-EOQ
        select env.id as from_id, ev.id as to_id
          from solace_application a,
                solace_application_version av,
                solace_event e,
                solace_event_version ev,
                solace_enum en,
                solace_enum_version env
          where 
            a.id = $1
            and av.application_id = a.id
            and e.application_domain_id = a.application_domain_id
            and ev.event_id = e.id
            and concat(ev.declared_consuming_application_version_ids, ev.declared_producing_application_version_ids) like '%' || av.id || '%'  
            and env.referenced_by_event_version_ids like '%' || ev.id || '%'  
            and en.id = env.enum_id
      EOQ

      args = [self.input.application.value]
    }

    node {
      category = category.schema

      sql = <<-EOQ
      select a.id as id, a.name as title, 4 as depth
        from solace_schema a
        where a.application_domain_id = $1
      EOQ
      args = [self.input.domain.value]
    }

    node {
      category = category.schema_version

      sql = <<-EOQ
        select a.id as id, a.version as title, 5 as depth
          from solace_schema_version a, solace_schema b
          where b.application_domain_id = $1 and a.schema_id = b.id
      EOQ
      args = [self.input.domain.value]
    }

    edge schema_to_schemaversion {
      sql = <<-EOQ
        select b.id as from_id, a.id as to_id
          from solace_schema_version a, solace_schema b
          where b.application_domain_id = $1 and a.schema_id = b.id
      EOQ

      args = [self.input.domain.value]
    }

    edge schemaversion_to_eventversion {
      sql = <<-EOQ
        select sv.id as from_id, ev.id as to_id
          from solace_application a,
                solace_application_version av,
                solace_event e,
                solace_event_version ev,
                solace_schema s,
                solace_schema_version sv
          where 
            a.id = $1
            and av.application_id = a.id
            and e.application_domain_id = a.application_domain_id
            and ev.event_id = e.id
            and concat(ev.declared_consuming_application_version_ids, ev.declared_producing_application_version_ids) like '%' || av.id || '%'  
            and sv.referenced_by_event_version_ids like '%' || ev.id || '%'  
            and s.id = sv.schema_id      
      EOQ

      args = [self.input.application.value]
    }

    node "eventapi" {
      category = category.eventapi

      sql = <<-EOQ
        select a.id AS id, a.name as title, 7 as depth
          from solace_eventapi a
          where a.application_domain_id = $1
      EOQ
      args = [self.input.domain.value]        
    }

    node "eventapi_version" {
      category = category.eventapi_version

      sql = <<-EOQ
        WITH evapids AS (
          SELECT concat(evapi.produced_event_version_ids || ', ' || evapi.consumed_event_version_ids) AS evpcid, 
            evapi.id AS id, evapi.version as version, evapi.event_api_id as eapid, eapi.name as eapiname, ev.id AS eid
          FROM solace_eventapi_version evapi
          JOIN solace_eventapi eapi ON evapi.event_api_id = eapi.id
          JOIN solace_event_version ev ON concat(evapi.produced_event_version_ids || ', ' || evapi.consumed_event_version_ids) LIKE '%' || ev.id || '%'
          WHERE eapi.application_domain_id = $1
        )
        SELECT
          evapids.id AS id,
          concat(evapids.eapiname, ' v', evapids.version) AS title, 8 as depth,
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
      args = [self.input.domain.value]        
    }

    edge "eventapiversion_to_eventapi" {
      category = category.eventapi_version

      sql = <<-EOQ
        select b.id as from_id, a.id as to_id
          from solace_eventapi_version a, solace_eventapi b
          where b.application_domain_id = $1 and a.event_api_id = b.id
      EOQ
      args = [self.input.domain.value]        
    }

    edge "eventversion_to_eventapiversion" {
      category = category.eventapi_version

      sql = <<-EOQ
        WITH evapids AS (
          SELECT concat(evapi.produced_event_version_ids || ', ' || evapi.consumed_event_version_ids) AS evpcid, 
            evapi.id AS id, evapi.version as version, evapi.event_api_id as eapid, eapi.name as eapiname, ev.id AS eid
          FROM solace_eventapi_version evapi
          JOIN solace_eventapi eapi ON evapi.event_api_id = eapi.id
          JOIN solace_event_version ev ON concat(evapi.produced_event_version_ids || ', ' || evapi.consumed_event_version_ids) LIKE '%' || ev.id || '%'
          WHERE eapi.application_domain_id = $1
        )
        SELECT
          evapids.eid AS from_id,
          evapids.id AS to_id
        FROM evapids
      EOQ
      args = [self.input.domain.value]        
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


category "application_domain" {
  color = "#ff0000"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-app-domain.png"
}

category "application" {
  color = "#ff8700"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-application.png"
}

category "application_version" {
  title = "Application Version"
  color = "#ff8700"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-application.png"
}

category "event" {
  title = "Event"
  color = "#ffd300"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-event.png"
}

category "event_version" {
  title = "Event Version"
  color = "#ffd300"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-event.png"
}

category "enum" {
  color = "#0aff99"
  icon = "https://cdn-icons-png.freepik.com/512/9447/9447665.png"
}

category "enum_version" {
  title = "Enum Version"
  color = "#0aff99"
  icon = "https://cdn-icons-png.freepik.com/512/9447/9447665.png"
}

category "schema" {
  color = "#0aefff"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-schema.png"
}

category "schema_version" {
  title = "Schema Version"
  color = "#0aefff"
  icon = "https://docs.solace.com/Resources/Images/Event-Portal/graph-icons/graph-schema.png"
}

category "eventapi" {
  title = "EventAPI"
  icon = "https://cdn-icons-png.freepik.com/512/7549/7549551.png"
  color = "#147df5"
}

category "eventapi_version" {
  title = "EventAPI Version"
  icon = "https://cdn-icons-png.freepik.com/512/7549/7549551.png"
  color = "#147df5"
}

category "eventapi_product" {
  title = "EventAPI Product"
  icon = "https://cdn-icons-png.freepik.com/512/10169/10169724.png"
  color = "#580aff"
}

category "eventapi_product_version" {
  title = "EventAPI Product Version"
  icon = "https://cdn-icons-png.freepik.com/512/10169/10169724.png"
  color = "#580aff"
}