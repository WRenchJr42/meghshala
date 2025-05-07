CREATE TABLE public.states (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL UNIQUE,

  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  created_by uuid REFERENCES auth.users(id),
  updated_by uuid REFERENCES auth.users(id)
);

-- Trigger for INSERT (for created_by)
CREATE TRIGGER states_set_user_ids_insert
  BEFORE INSERT OR UPDATE ON public.states
  FOR EACH ROW
  EXECUTE FUNCTION public.set_user_ids();


-- Trigger for UPDATE (for updated_at)
CREATE TRIGGER states_set_updated_at
  BEFORE UPDATE ON public.states
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

  --SEED DATA for India

INSERT INTO public.states (title) VALUES
  ('ANDHRA PRADESH'),
  ('ARUNACHAL PRADESH'),
  ('ASSAM'),
  ('BIHAR'),
  ('CHHATTISGARH'),
  ('GOA'),
  ('GUJARAT'),
  ('HARYANA'),
  ('HIMACHAL PRADESH'),
  ('JHARKHAND'),
  ('KARNATAKA'),
  ('KERALA'),
  ('MADHYA PRADESH'),
  ('MAHARASHTRA'),
  ('MANIPUR'),
  ('MEGHALAYA'),
  ('MIZORAM'),
  ('NAGALAND'),
  ('ODISHA'),
  ('PUNJAB'),
  ('RAJASTHAN'),
  ('SIKKIM'),
  ('TAMIL NADU'),
  ('TELANGANA'),
  ('TRIPURA'),
  ('UTTAR PRADESH'),
  ('UTTARAKHAND'),
  ('WEST BENGAL');
