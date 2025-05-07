-- Create Table

CREATE TABLE public.languages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),                -- ID
  title text NOT NULL UNIQUE,                                   -- Language Name

  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  created_by uuid REFERENCES auth.users(id),
  updated_by uuid REFERENCES auth.users(id) 
);


-- Trigger for INSERT (for created_by)

CREATE TRIGGER languages_set_user_ids_insert
  BEFORE INSERT OR UPDATE ON public.languages
  FOR EACH ROW
  EXECUTE FUNCTION public.set_user_ids();


-- Trigger for UPDATE (for updated_at)

CREATE TRIGGER languages_set_updated_at
  BEFORE UPDATE ON public.languages
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();
