-- chapters table

create table public.chapters (
  id uuid primary key default gen_random_uuid(),                            -- ID
  title text not null,                                                      -- chapter name
  number integer not null,                                                  -- chapter number 
  is_published boolean not null default false,
  language_id uuid not null references public.languages(id),
  curriculum_id uuid not null references public.curricula(id),
  grade_id uuid not null references public.grades(id),
  semester_id uuid not null references public.semesters(id),
  subject_id uuid not null references public.subjects(id),
  unit_plan_created boolean not null default false,
  unit_plan_reviewed boolean not null default false,
  unit_plan_finalised boolean not null default false,
  copy_written boolean not null default false,
  layout_created boolean not null default false,
  illustrations_created boolean not null default false,
  videos_created boolean not null default false,
  google_slides_created boolean not null default false,
  review_1_completed boolean not null default false,
  review_2_completed boolean not null default false,
  final_review_completed boolean not null default false,
  
  editing_status editing_status,                                            -- URL or storage path for the attachment
  
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  updated_by uuid references auth.users(id),
	created_by uuid references auth.users(id) 
);


-- Trigger for INSERT (for created_by)

CREATE TRIGGER chapters_set_user_ids_insert
  BEFORE INSERT OR UPDATE ON public.chapters
  FOR EACH ROW
  EXECUTE FUNCTION public.set_user_ids();


-- Trigger for UPDATE (for updated_at)

CREATE TRIGGER chapters_set_updated_at
  BEFORE UPDATE ON public.chapters
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();
