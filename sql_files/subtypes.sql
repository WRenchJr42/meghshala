-- create table
CREATE TABLE public.subtypes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  subject_id uuid NOT NULL REFERENCES public.subjects(id),
  title text , 
  
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_by uuid references auth.users(id),
  created_by uuid references auth.users(id)
);


-- Trigger for INSERT (for created_by)

CREATE TRIGGER subtypes_set_user_ids_insert
  BEFORE INSERT OR UPDATE ON public.subtypes
  FOR EACH ROW
  EXECUTE FUNCTION public.set_user_ids();


-- Trigger for UPDATE (for updated_at)

CREATE TRIGGER subtypes_set_updated_at
  BEFORE UPDATE ON public.subtypes
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();
