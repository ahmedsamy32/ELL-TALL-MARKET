-- GoTrue owns public signups. The existing AFTER INSERT trigger provisions the
-- profile and related rows from this normalized role. Admin provisioning RPCs
-- insert as the database owner after checking the caller's permissions.
create function public.normalize_market_signup_role()
returns trigger
language plpgsql security invoker set search_path = ''
as $$
declare
  assigned_role text := new.raw_app_meta_data ->> 'market_role';
begin
  if current_user in ('postgres', 'service_role') then
    return new;
  end if;
  if assigned_role is null or assigned_role not in
     ('client', 'merchant', 'captain', 'delivery_company_admin', 'admin') then
    assigned_role := case when new.raw_user_meta_data ->> 'role' = 'merchant'
                          then 'merchant' else 'client' end;
  end if;
  new.raw_user_meta_data := jsonb_set(coalesce(new.raw_user_meta_data, '{}'::jsonb),
                                      '{role}', to_jsonb(assigned_role));
  return new;
end;
$$;

revoke all on function public.normalize_market_signup_role() from public, anon, authenticated;
create trigger normalize_market_signup_role before insert on auth.users
for each row execute function public.normalize_market_signup_role();

-- RLS controls which profile a caller may edit. Keep its authorization fields
-- server-managed while allowing normal edits and the existing admin workflows.
create function public.guard_market_profile_access()
returns trigger
language plpgsql security invoker set search_path = ''
as $$
begin
  if current_user not in ('anon', 'authenticated') then
    return new;
  end if;
  if tg_op = 'UPDATE' then
    if (new.id, new.role, new.is_active) is not distinct from
       (old.id, old.role, old.is_active) then
      return new;
    end if;
  elsif new.id = auth.uid() and new.role = 'client' and new.is_active is true then
    return new;
  end if;
  if public.is_admin() then
    return new;
  end if;
  raise exception 'Account permissions must be assigned by an administrator'
    using errcode = '42501';
end;
$$;

revoke all on function public.guard_market_profile_access() from public, anon, authenticated;
create trigger guard_market_profile_access before insert or update on public.profiles
for each row execute function public.guard_market_profile_access();
