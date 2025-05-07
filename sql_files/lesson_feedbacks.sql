-- lesson_feedback table
CREATE TABLE public.lesson_feedbacks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),                          -- ID
  lesson_id uuid NOT NULL REFERENCES public.lessons(id),                   -- lesson_id
  
  could_complete boolean NOT NULL DEFAULT FALSE,
  liked_teacher_instructions boolean NOT NULL DEFAULT FALSE,
  liked_concept_explanations boolean NOT NULL DEFAULT FALSE,
  liked_activities boolean NOT NULL DEFAULT FALSE,
  liked_language_simplicity boolean NOT NULL DEFAULT FALSE,
  liked_practice_questions boolean NOT NULL DEFAULT FALSE,
  will_recommend boolean NOT NULL DEFAULT FALSE,
  
  feedback_note text,
  
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_by uuid references auth.users(id),
	created_by uuid references auth.users(id) 

);

-- Trigger for INSERT (for created_by)
CREATE TRIGGER lesson_feedbacks_set_user_ids_insert
  BEFORE INSERT OR UPDATE ON public.lesson_feedbacks
  FOR EACH ROW
  EXECUTE FUNCTION public.set_user_ids();


-- Trigger for UPDATE (for updated_at)
CREATE TRIGGER lesson_feedbacks_set_updated_at
  BEFORE UPDATE ON public.lesson_feedbacks
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();
