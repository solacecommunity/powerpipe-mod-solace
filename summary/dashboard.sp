dashboard "solace_dashboard" {
  title = "[1] Summary"

  text {
    value = "Dashboard of Solace Event Portal"
  }

  container {
    title = "Event Portal - Designer Objects"

    card {
      sql = <<-EOQ
        select
          count(*) as "Total Application Domains"
        from
          solace_application_domain
      EOQ
      icon  = "hashtag"
      width = 3
    }
    card {
      sql = <<-EOQ
        select
          count(*) as "Total Applications"
        from
          solace_application
      EOQ
      icon  = "hashtag"
      width = 3
    }
    card {
      sql = <<-EOQ
        select
          count(*) as "Total Events"
        from
          solace_event
      EOQ
      icon  = "hashtag"
      width = 3
    }
    card {
      sql = <<-EOQ
        select
          count(*) as "Total Schemas"
        from
          solace_schema
      EOQ
      icon  = "hashtag"
      width = 3
    }
    card {
      sql = <<-EOQ
        select
          count(*) as "Total Enums"
        from
          solace_enum
      EOQ
      icon  = "hashtag"
      width = 3
    }
    card {
      sql = <<-EOQ
        select
          count(*) as "Total Event Apis"
        from
          solace_eventapi
      EOQ
      icon  = "hashtag"
      width = 3
    }
    card {
      sql = <<-EOQ
        select
          count(*) as "Total EventApi Products"
        from
          solace_eventapi_product
      EOQ
      icon  = "hashtag"
      width = 3
    }
  }

  container {
    table {
      sql = <<-EOQ
        select
          name as "Domain Name",
          COALESCE(stats->>'applicationCount', '0') as "Applications",
          COALESCE(stats->>'eventCount', '0') as "Events",
          COALESCE(stats->>'schemaCount', '0') as "Schemas",
          COALESCE(stats->>'enumCount', '0') as "Enums",
          COALESCE(stats->>'eventApiCount', '0') as "EventApis",
          COALESCE(stats->>'eventApiProdcutCount', '0') as "EventApi Products"
        from
          solace_application_domain
      EOQ
    }
  }

}