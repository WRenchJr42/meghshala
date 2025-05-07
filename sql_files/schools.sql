-- school table

CREATE TABLE public.schools (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),             -- ID
  title text NOT NULL UNIQUE,                                -- name of school
  code text UNIQUE,                                          -- optional short code school_code
  type school_types NOT NULL,
  address_line_1 text,
  address_line_2 text, 
  city text,
  state uuid references public.states(id),
  pincode text,
  district text,
  phone text,
  email text,
  website text,
  established_date date,
  principal_name text,
  number_of_students integer DEFAULT 0,

  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_by uuid references auth.users(id),
  created_by uuid references auth.users(id)
);


-- Trigger for INSERT (for created_by)

CREATE TRIGGER schools_set_user_ids_insert
  BEFORE INSERT OR UPDATE ON public.schools
  FOR EACH ROW
  EXECUTE FUNCTION public.set_user_ids();


-- Trigger for UPDATE (for updated_at)

CREATE TRIGGER schools_set_updated_at
  BEFORE UPDATE ON public.schools
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();
