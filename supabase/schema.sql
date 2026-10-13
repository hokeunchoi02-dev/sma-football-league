-- Run in Supabase SQL Editor. Uses Supabase Auth for password hashing, sessions and email verification.
create extension if not exists pgcrypto;
create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null check(char_length(display_name) between 1 and 45),
 role text not null default 'member' check(role in ('admin','member')),
 active boolean not null default true,
 created_at timestamptz not null default now()
);
create table if not exists public.matches (
 id uuid primary key default gen_random_uuid(),
 league text not null check(char_length(league) between 1 and 100),
 home_team text not null check(char_length(home_team) between 1 and 100),
 away_team text not null check(char_length(away_team) between 1 and 100),
 kickoff_at timestamptz not null,
 deadline_at timestamptz not null,
 home_goals integer check(home_goals >= 0),
 away_goals integer check(away_goals >= 0),
 created_at timestamptz not null default now(),
 check(home_team <> away_team),
 check(deadline_at <= kickoff_at),
 check((home_goals is null) = (away_goals is null))
);
create table if not exists public.predictions (
 id uuid primary key default gen_random_uuid(),
 match_id uuid not null references public.matches(id) on delete restrict,
 user_id uuid not null references public.profiles(id) on delete cascade,
 p_home integer not null check(p_home between 0 and 100),
 p_draw integer not null check(p_draw between 0 and 100),
 p_away integer not null check(p_away between 0 and 100),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(user_id,match_id),
 check(p_home+p_draw+p_away=100)
);
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path = '' as $$ select exists(select 1 from public.profiles where id=auth.uid() and role='admin' and active) $$;
create or replace function public.is_active() returns boolean language sql stable security definer set search_path = '' as $$ select exists(select 1 from public.profiles where id=auth.uid() and active) $$;
create or replace function public.create_profile() returns trigger language plpgsql security definer set search_path = '' as $$ begin insert into public.profiles(id,display_name) values(new.id,left(coalesce(nullif(trim(new.raw_user_meta_data->>'display_name'),''),split_part(new.email,'@',1)),45)); return new; end $$;
drop trigger if exists new_auth_user on auth.users;
create trigger new_auth_user after insert on auth.users for each row execute procedure public.create_profile();
create or replace function public.guard_profile() returns trigger language plpgsql security definer set search_path = '' as $$ begin if not public.is_admin() then if new.role is distinct from old.role or new.active is distinct from old.active then raise exception 'Only admins can change role or active status'; end if; if new.id<>auth.uid() then raise exception 'Only edit own profile'; end if; end if; return new; end $$;
drop trigger if exists guard_profile_update on public.profiles;
create trigger guard_profile_update before update on public.profiles for each row execute function public.guard_profile();
create or replace function public.guard_match() returns trigger language plpgsql security definer set search_path = '' as $$ begin
 if tg_op='DELETE' then if exists(select 1 from public.predictions where match_id=old.id) then raise exception 'Cannot delete a match with predictions'; end if; return old; end if;
 if new.home_goals is not null and clock_timestamp() < new.kickoff_at then raise exception 'Cannot enter results before kickoff'; end if;
 if tg_op='UPDATE' and exists(select 1 from public.predictions where match_id=old.id) then
 if row(new.league,new.home_team,new.away_team,new.kickoff_at,new.deadline_at) is distinct from row(old.league,old.home_team,old.away_team,old.kickoff_at,old.deadline_at) then raise exception 'Cannot change match details after predictions exist'; end if;
 end if;
 return new; end $$;
drop trigger if exists guard_match_changes on public.matches;
create trigger guard_match_changes before insert or update or delete on public.matches for each row execute function public.guard_match();
create or replace function public.guard_prediction() returns trigger language plpgsql security definer set search_path = '' as $$ begin
 if new.user_id<>auth.uid() or not public.is_active() then raise exception 'Unauthorized member'; end if;
 if not exists(select 1 from public.profiles where id=auth.uid() and role='member') then raise exception 'Only members may submit predictions'; end if;
 if not exists(select 1 from public.matches where id=new.match_id and clock_timestamp()<deadline_at and home_goals is null) then raise exception 'Prediction deadline passed'; end if;
 if tg_op='UPDATE' then if new.user_id<>old.user_id or new.match_id<>old.match_id or new.created_at<>old.created_at then raise exception 'Cannot change prediction ownership'; end if; end if;
 new.updated_at=now();return new; end $$;
drop trigger if exists guard_prediction_write on public.predictions;
create trigger guard_prediction_write before insert or update on public.predictions for each row execute function public.guard_prediction();
alter table public.profiles enable row level security;
alter table public.matches enable row level security;
alter table public.predictions enable row level security;
create policy "active users view profiles" on public.profiles for select to authenticated using (public.is_active());
create policy "self or admin edit profile" on public.profiles for update to authenticated using ((id=auth.uid() and public.is_active()) or public.is_admin()) with check ((id=auth.uid() and public.is_active()) or public.is_admin());
create policy "active users view matches" on public.matches for select to authenticated using (public.is_active());
create policy "admin creates matches" on public.matches for insert to authenticated with check (public.is_admin());
create policy "admin updates matches" on public.matches for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admin deletes matches" on public.matches for delete to authenticated using(public.is_admin());
-- All authenticated active members can view predictions for leaderboard / calibration.
-- NOTE: member forecast privacy requires a separate aggregate server-side view/RPC if needed.
create policy "active users view predictions" on public.predictions for select to authenticated using(public.is_active());
create policy "member submits" on public.predictions for insert to authenticated with check(user_id=auth.uid() and public.is_active());
create policy "member edits own" on public.predictions for update to authenticated using(user_id=auth.uid() and public.is_active()) with check(user_id=auth.uid() and public.is_active());
create index if not exists predictions_match_idx on public.predictions(match_id);
create index if not exists predictions_user_idx on public.predictions(user_id);
create index if not exists matches_kickoff_idx on public.matches(kickoff_at);
-- Promote an existing registered account explicitly through SQL editor, NEVER from browser:
-- update public.profiles set role='admin' where id=(select id from auth.users where email='YOUR_EMAIL');
