-- semester table

CREATE TABLE public.semesters (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text,                                                         --ask
  --name text NOT NULL UNIQUE,
  
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_by uuid references auth.users(id),
  created_by uuid references auth.users(id)
);


-- Trigger for INSERT (for created_by)

CREATE TRIGGER semesters_set_user_ids_insert
  BEFORE INSERT OR UPDATE ON public.semesters
  FOR EACH ROW
  EXECUTE FUNCTION public.set_user_ids();


-- Trigger for UPDATE (for updated_at)

CREATE TRIGGER semesters_set_updated_at
  BEFORE UPDATE ON public.semesters
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();
