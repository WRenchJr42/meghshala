-- slide child table
CREATE TABLE public.slides (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),                            -- ID
  lesson_id uuid NOT NULL REFERENCES public.lessons(id) ON DELETE RESTRICT,   -- lesson_id
  
  page_id text,                                                             -- read‐only in the app
  type public.slide_types NOT NULL,
  attachment text,                                                          -- storage path or URL
  video_id text,                                                            -- read‐only in the app
  number integer,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_by uuid references auth.users(id),
	created_by uuid references auth.users(id) 
);

-- Trigger for INSERT (for created_by)
CREATE TRIGGER slides_set_user_ids_insert
  BEFORE INSERT OR UPDATE ON public.slides
  FOR EACH ROW
  EXECUTE FUNCTION public.set_user_ids();

-- Trigger for UPDATE (for updated_at)
CREATE TRIGGER slides_set_updated_at
  BEFORE UPDATE ON public.slides
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();
