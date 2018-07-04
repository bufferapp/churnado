select
    user_id
    , {{ dbt_utils.pivot(
            'week_number',
             dbt_utils.get_column_values('{{ ref("churnado_update_weekly_features") }}', 'week_number'),
             prefix='number_of_updates_week_',
             then_value='number_of_updates')
       }}
    , {{ dbt_utils.pivot(
            'week_number',
             dbt_utils.get_column_values('{{ ref("churnado_update_weekly_features") }}', 'week_number'),
             prefix='number_of_days_with_updates_week_',
             then_value='number_of_days_with_updates')
       }}
   , {{ dbt_utils.pivot(
           'week_number',
            dbt_utils.get_column_values('{{ ref("churnado_update_weekly_features") }}', 'week_number'),
            prefix='number_of_extension_updates_week_',
            then_value='number_of_extension_updates')
      }}
  , {{ dbt_utils.pivot(
          'week_number',
           dbt_utils.get_column_values('{{ ref("churnado_update_weekly_features") }}', 'week_number'),
           prefix='number_of_update_errors_week_',
           then_value='number_of_update_errors')
     }}
from {{ ref('churnado_update_weekly_features') }}
group by 1
