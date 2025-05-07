-- chapter_lesson table

CREATE TABLE public.chapter_lessons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chapter_id uuid NOT NULL REFERENCES public.chapters(id) ON DELETE restrict,
  lesson_id uuid NOT NULL REFERENCES public.lessons(id),                         --lesson_id title
  unique (chapter_id, lesson_id),                                                --ask
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_by uuid references auth.users(id),
	created_by uuid references auth.users(id) 
);


-- Trigger for INSERT (for created_by)

CREATE TRIGGER chapter_lessons_set_user_ids
  BEFORE INSERT or UPDATE ON public.chapter_lessons
  FOR EACH ROW
  EXECUTE FUNCTION public.set_user_ids();


-- Trigger for UPDATE (for updated_at)

CREATE TRIGGER chapter_lessons_set_updated_at
  BEFORE UPDATE ON public.chapter_lessons
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();
