with hs_json as (--extract json data
  select
    *
    , nullif(json_extract_path_text(customer,'email'), '') created_by_email
    , nullif(json_extract_path_text(createdby,'firstName'), '') created_by_first_name
    , nullif(json_extract_path_text(createdby,'lastName'), '') created_by_last_name
    , nullif(json_extract_path_text(createdby,'type'),'') created_by_type_raw
    , json_extract_path_text(mailbox, 'id') mailbox_id
    , json_extract_path_text(mailbox, 'name') mailbox_name
  from helpscout_conversations
),

hs_emails as (
  select
    id
    , createdat as created_at
    , type
    , mailbox_name
    , func_sha1(created_by_email) created_by_email_hash
    , nullif(trim(created_by_first_name || ' ' || created_by_last_name), '') created_by
    , case created_by_type_raw
        when 'user' then 'hero'
        else 'customer'
      end created_by_type
  from hs_json
  where created_by_type_raw = 'customer'
  and isdraft = false
  and type = 'email'
  and mailbox_name != 'Tracking emails'
  and mailbox_name != 'Join Us'
  and mailbox_name not like 'The Next%'
)

select
  created_by_email_hash
  , count(distinct id) as hs_emails
from hs_emails
where created_at >= dateadd(week, -8, '{{ var('t') }}')
and created_at <= '{{ var('t') }}'
group by 1
