-- Supabase setup for ئاژاوەچیەکانی ئەکتیڤ
-- Run this whole file once in Supabase > SQL Editor > Run.

create table if not exists public.aktif_state (
  id integer primary key check (id = 1),
  current_index integer not null default 0 check (current_index between 0 and 31),
  done_indices integer[] not null default '{}'
);

insert into public.aktif_state (id, current_index, done_indices)
values (1, 0, '{}')
on conflict (id) do nothing;

alter table public.aktif_state enable row level security;

drop policy if exists "public can read aktif state" on public.aktif_state;
create policy "public can read aktif state"
on public.aktif_state
for select
to anon, authenticated
using (true);

create or replace function public.mark_aktif_done(p_member_index integer)
returns public.aktif_state
language plpgsql
security definer
set search_path = public
as $$
declare
  s public.aktif_state;
  new_done integer[];
begin
  if p_member_index < 0 or p_member_index > 31 then
    raise exception 'Invalid member index';
  end if;

  select * into s
  from public.aktif_state
  where id = 1
  for update;

  if p_member_index <> s.current_index then
    raise exception 'It is not this member''s turn';
  end if;

  if p_member_index = any(s.done_indices) then
    return s;
  end if;

  new_done := array_append(s.done_indices, p_member_index);

  if cardinality(new_done) >= 12 then
    update public.aktif_state
    set current_index = (s.current_index + 1) % 32,
        done_indices = '{}'
    where id = 1
    returning * into s;
  else
    update public.aktif_state
    set done_indices = new_done
    where id = 1
    returning * into s;
  end if;

  return s;
end;
$$;

grant select on public.aktif_state to anon, authenticated;
grant execute on function public.mark_aktif_done(integer) to anon, authenticated;

-- Realtime بۆ ئەوەی هەموو مۆبایلەکان خۆکارانە نوێ ببنەوە.
alter table public.aktif_state replica identity full;
alter publication supabase_realtime add table public.aktif_state;
