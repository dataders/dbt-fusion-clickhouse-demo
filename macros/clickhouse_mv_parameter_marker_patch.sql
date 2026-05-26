{#-
  Project-local override for the Fusion ClickHouse adapter macro.
  The bundled version uses regex groups like (?i) and (?:...), which this
  preview driver currently treats as unbound query parameter markers during
  materialization switches. dbt resolves this macro by name from ./macros when
  the adapter calls clickhouse__search_associated_mvs_to_target().
-#}
{% macro clickhouse__associated_mvs_to_target_sql(relation_schema, relation_name) -%}
  {% set normalized_schema_target = relation_schema ~ '.' ~ relation_name %}
  {% set tables_query %}
    select name
    from system.tables
    where engine = 'MaterializedView'
      and database = '{{ relation_schema }}'
      and lower(replaceRegexpAll(
        extract(
          lower(create_table_query),
          '\\bto\\s+((`[^`]+`|"[^"]+"|[^\\s.()]+)(\\s*\\.\\s*(`[^`]+`|"[^"]+"|[^\\s.()]+))*)'
        ),
        '[`"\\s]',
        ''
      )) in (
        lower(replaceRegexpAll('{{ normalized_schema_target }}', '[`"\\s]', '')),
        lower(replaceRegexpAll('{{ relation_name }}', '[`"\\s]', ''))
      )
  {% endset %}
  {{ return(tables_query) }}
{%- endmacro %}
