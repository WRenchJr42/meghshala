-- user_profile table
CREATE TABLE public.user_profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE RESTRICT,  --user_id

  -- denormalized from auth.users
  phone text NOT NULL,
  first_name text NOT NULL,
  last_name text,

  user_type user_types NOT NULL,
  qualification qualifications,
  experience experiences,
  assessment_enabled boolean NOT NULL DEFAULT FALSE,
  school_id uuid references public.schools(id),
  dob date,
  gender genders,
  language_id uuid REFERENCES public.languages(id),
  block text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_by uuid references auth.users(id),
	created_by uuid references auth.users(id) 
);

-- Trigger for INSERT (for created_by)
CREATE TRIGGER user_profiles_set_user_ids_insert
  BEFORE INSERT OR UPDATE ON public.user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.set_user_ids();


-- Trigger for UPDATE (for updated_at)
CREATE TRIGGER user_profiles_set_updated_at
  BEFORE UPDATE ON public.user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();
