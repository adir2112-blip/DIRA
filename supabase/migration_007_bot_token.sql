-- DIRA-CHANGE migration 007 (20.11.2026): send to the WhatsApp bot with its secret
-- Project: dira-change (ref bjicskzwuiojhqdwfyov) only.
-- The bot is closing its open /api/send: without the secret it will only
-- deliver to the owner, so reminders to reminder_extra_phone need it.
-- The secret lives in Vault under the name whatsapp_bot_token (value = the
-- bot's EXTERNAL_SEND_SECRET). Until it is added the header is simply left
-- out and everything works as before.

create or replace function public.wa_bot_headers()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('Content-Type', 'application/json')
    || coalesce((select jsonb_build_object('Authorization', 'Bearer ' || decrypted_secret)
                 from vault.decrypted_secrets where name = 'whatsapp_bot_token' limit 1), '{}'::jsonb)
$$;
revoke all on function public.wa_bot_headers() from public, anon, authenticated;

create or replace function public.send_due_reminders()
returns void
language sql
security definer
set search_path = public, extensions
as $$
  -- 24h — primary number
  select net.http_post(
    url := 'https://whatsapp-bot-production-120a.up.railway.app/api/send',
    headers := public.wa_bot_headers(),
    body := jsonb_build_object(
      'phone', '972509143496',
      'message', format('תזכורת (24 שעות מראש): %s — %s ב-%s בשעה %s',
        t.title, a.display_name, to_char(t.due_date,'DD/MM'), to_char(t.due_time,'HH24:MI')),
      'source', 'רכישת דירה'
    )
  )
  from tasks t join apartments a on a.id = t.apartment_id
  where t.remind_24h and t.reminder_24h_sent_at is null and t.status <> 'done'
    and t.due_date is not null and t.due_time is not null
    and (t.due_date + t.due_time) - interval '24 hours' <= now()
    and (t.due_date + t.due_time) > now() - interval '2 hours';

  -- 24h — optional extra number
  select net.http_post(
    url := 'https://whatsapp-bot-production-120a.up.railway.app/api/send',
    headers := public.wa_bot_headers(),
    body := jsonb_build_object(
      'phone', t.reminder_extra_phone,
      'message', format('תזכורת (24 שעות מראש): %s — %s ב-%s בשעה %s',
        t.title, a.display_name, to_char(t.due_date,'DD/MM'), to_char(t.due_time,'HH24:MI')),
      'source', 'רכישת דירה'
    )
  )
  from tasks t join apartments a on a.id = t.apartment_id
  where t.remind_24h and t.reminder_24h_sent_at is null and t.status <> 'done'
    and t.reminder_extra_phone is not null
    and t.due_date is not null and t.due_time is not null
    and (t.due_date + t.due_time) - interval '24 hours' <= now()
    and (t.due_date + t.due_time) > now() - interval '2 hours';

  update tasks set reminder_24h_sent_at = now()
  where remind_24h and reminder_24h_sent_at is null and status <> 'done'
    and due_date is not null and due_time is not null
    and (due_date + due_time) - interval '24 hours' <= now()
    and (due_date + due_time) > now() - interval '2 hours';

  -- 12h — primary number
  select net.http_post(
    url := 'https://whatsapp-bot-production-120a.up.railway.app/api/send',
    headers := public.wa_bot_headers(),
    body := jsonb_build_object(
      'phone', '972509143496',
      'message', format('תזכורת (12 שעות מראש): %s — %s ב-%s בשעה %s',
        t.title, a.display_name, to_char(t.due_date,'DD/MM'), to_char(t.due_time,'HH24:MI')),
      'source', 'רכישת דירה'
    )
  )
  from tasks t join apartments a on a.id = t.apartment_id
  where t.remind_12h and t.reminder_12h_sent_at is null and t.status <> 'done'
    and t.due_date is not null and t.due_time is not null
    and (t.due_date + t.due_time) - interval '12 hours' <= now()
    and (t.due_date + t.due_time) > now() - interval '2 hours';

  -- 12h — optional extra number
  select net.http_post(
    url := 'https://whatsapp-bot-production-120a.up.railway.app/api/send',
    headers := public.wa_bot_headers(),
    body := jsonb_build_object(
      'phone', t.reminder_extra_phone,
      'message', format('תזכורת (12 שעות מראש): %s — %s ב-%s בשעה %s',
        t.title, a.display_name, to_char(t.due_date,'DD/MM'), to_char(t.due_time,'HH24:MI')),
      'source', 'רכישת דירה'
    )
  )
  from tasks t join apartments a on a.id = t.apartment_id
  where t.remind_12h and t.reminder_12h_sent_at is null and t.status <> 'done'
    and t.reminder_extra_phone is not null
    and t.due_date is not null and t.due_time is not null
    and (t.due_date + t.due_time) - interval '12 hours' <= now()
    and (t.due_date + t.due_time) > now() - interval '2 hours';

  update tasks set reminder_12h_sent_at = now()
  where remind_12h and reminder_12h_sent_at is null and status <> 'done'
    and due_date is not null and due_time is not null
    and (due_date + due_time) - interval '12 hours' <= now()
    and (due_date + due_time) > now() - interval '2 hours';

  -- 3h — primary number
  select net.http_post(
    url := 'https://whatsapp-bot-production-120a.up.railway.app/api/send',
    headers := public.wa_bot_headers(),
    body := jsonb_build_object(
      'phone', '972509143496',
      'message', format('תזכורת (3 שעות מראש): %s — %s ב-%s בשעה %s',
        t.title, a.display_name, to_char(t.due_date,'DD/MM'), to_char(t.due_time,'HH24:MI')),
      'source', 'רכישת דירה'
    )
  )
  from tasks t join apartments a on a.id = t.apartment_id
  where t.remind_3h and t.reminder_3h_sent_at is null and t.status <> 'done'
    and t.due_date is not null and t.due_time is not null
    and (t.due_date + t.due_time) - interval '3 hours' <= now()
    and (t.due_date + t.due_time) > now() - interval '2 hours';

  -- 3h — optional extra number
  select net.http_post(
    url := 'https://whatsapp-bot-production-120a.up.railway.app/api/send',
    headers := public.wa_bot_headers(),
    body := jsonb_build_object(
      'phone', t.reminder_extra_phone,
      'message', format('תזכורת (3 שעות מראש): %s — %s ב-%s בשעה %s',
        t.title, a.display_name, to_char(t.due_date,'DD/MM'), to_char(t.due_time,'HH24:MI')),
      'source', 'רכישת דירה'
    )
  )
  from tasks t join apartments a on a.id = t.apartment_id
  where t.remind_3h and t.reminder_3h_sent_at is null and t.status <> 'done'
    and t.reminder_extra_phone is not null
    and t.due_date is not null and t.due_time is not null
    and (t.due_date + t.due_time) - interval '3 hours' <= now()
    and (t.due_date + t.due_time) > now() - interval '2 hours';

  update tasks set reminder_3h_sent_at = now()
  where remind_3h and reminder_3h_sent_at is null and status <> 'done'
    and due_date is not null and due_time is not null
    and (due_date + due_time) - interval '3 hours' <= now()
    and (due_date + due_time) > now() - interval '2 hours';
$$;

create or replace function public.send_task_reminder_now(p_task_id uuid)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_caller uuid;
  v_msg text;
  v_task record;
begin
  select member_id into v_caller from sessions where auth_uid = auth.uid() and expires_at > now();
  if v_caller is null then
    raise exception 'לא מחובר' using errcode = 'P0001';
  end if;

  select t.title, t.due_date, t.due_time, t.reminder_extra_phone, a.display_name as apt_name
  into v_task
  from tasks t join apartments a on a.id = t.apartment_id
  where t.id = p_task_id;

  if v_task.title is null then
    raise exception 'משימה לא נמצאה' using errcode = 'P0001';
  end if;

  v_msg := format('עדכון: %s — %s%s',
    v_task.title, v_task.apt_name,
    case when v_task.due_date is not null then format(' (%s%s)',
      to_char(v_task.due_date, 'DD/MM'),
      case when v_task.due_time is not null then ' בשעה ' || to_char(v_task.due_time, 'HH24:MI') else '' end)
    else '' end);

  perform net.http_post(
    url := 'https://whatsapp-bot-production-120a.up.railway.app/api/send',
    headers := public.wa_bot_headers(),
    body := jsonb_build_object('phone', '972509143496', 'message', v_msg, 'source', 'רכישת דירה')
  );

  if v_task.reminder_extra_phone is not null then
    perform net.http_post(
      url := 'https://whatsapp-bot-production-120a.up.railway.app/api/send',
      headers := public.wa_bot_headers(),
      body := jsonb_build_object('phone', v_task.reminder_extra_phone, 'message', v_msg, 'source', 'רכישת דירה')
    );
  end if;
end;
$$;

revoke all on function public.send_task_reminder_now(uuid) from public;
grant execute on function public.send_task_reminder_now(uuid) to anon, authenticated;
