---------------------------------------------------------------------------------------------------------
-- generic
---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger function to auto-set created_by and updated_by using auth.uid()
CREATE OR REPLACE FUNCTION public.set_user_ids()
RETURNS TRIGGER AS $$
BEGIN
  -- Set created_by only on INSERT
  IF TG_OP = 'INSERT' AND NEW.created_by IS NULL THEN
    NEW.created_by := auth.uid();
  END IF;

  -- Set updated_by on INSERT and UPDATE
  NEW.updated_by := auth.uid();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;



---------------------------------------------------------------------------------------------------------
--fallback
---------------------------------------------------------------------------------------------------------
--CREATE OR REPLACE FUNCTION public.set_created_and_updated_metadata()
--RETURNS TRIGGER AS $$
--DECLARE
-- v_uid uuid := 'ADMINISTRATOR';
--BEGIN
--  BEGIN
--    v_uid := auth.uid();  -- Supabase helper
--  EXCEPTION WHEN OTHERS THEN
    -- Keep default ADMINISTRATOR
--  END;

--  IF TG_OP = 'INSERT' THEN
--    IF NEW.created_by IS NULL THEN
--      NEW.created_by := v_uid;
--    END IF;
--    IF NEW.created_at IS NULL THEN
--      NEW.created_at := now();
--    END IF;
--  END IF;

--  IF TG_OP = 'UPDATE' THEN
--    NEW.updated_at := now();
--    NEW.updated_by := v_uid;
--  END IF;

--  RETURN NEW;
--END;
--$$ LANGUAGE plpgsql;

