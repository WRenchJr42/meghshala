-- lesson table

CREATE TABLE public.lessons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),                              -- ID
  chapter_id uuid NOT NULL REFERENCES public.chapters(id) ON DELETE RESTRICT,
  
  title text NOT NULL,                                                        -- lesson name
  number integer NOT NULL,                                                    -- lesson number
  is_published boolean NOT NULL DEFAULT FALSE,
  is_broken boolean NOT NULL DEFAULT FALSE,
  google_slides_link text,
  google_slides_id text,
  normal_pdf text,                                                            -- path or URL
  encrypted_pdf text,                                                         -- path or URL
  password text,
  tags text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_by uuid references auth.users(id),
	created_by uuid references auth.users(id) 
);


-- Trigger for INSERT (for created_by)

CREATE TRIGGER lessons_set_user_ids_insert
  BEFORE INSERT OR UPDATE ON public.lessons
  FOR EACH ROW
  EXECUTE FUNCTION public.set_user_ids();


-- Trigger for UPDATE (for updated_at)

CREATE TRIGGER lessons_set_updated_at
  BEFORE UPDATE ON public.lessons
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();
