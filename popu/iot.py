import csv
import uuid
import random
from supabase import create_client, Client, SupabaseException
from datetime import datetime

# 1) Supabase client setup
SUPABASE_URL = "https://wcbgyhgfqazujftqxmez.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndjYmd5aGdmcWF6dWpmdHF4bWV6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDU5MDM4MzQsImV4cCI6MjA2MTQ3OTgzNH0.KVWaXdQt-vDduTlWENKTduZRiJyMemIp3Tmz2K8OiLA"
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

CSV_PATH = "/home/wrench/Desktop/usrlsndeets/KASB-Lesson_Details.csv"

# Function to generate random hex color
def generate_random_color():
    # Predefined colors for subjects
    colors = [
        "#FF5733", "#33FF57", "#3357FF", "#F033FF", "#FF33A8",
        "#33FFF0", "#FFD433", "#4CAF50", "#2196F3", "#FF9800",
        "#9C27B0", "#E91E63", "#00BCD4", "#8BC34A", "#FFC107"
    ]
    return random.choice(colors)

# Step 1: Fetch all languages and build a map from title -> id
print("📥 Fetching languages...")
language_map = {}

try:
    response = supabase.table("languages").select("id", "title").execute()
    for lang in response.data:
        language_map[lang["title"].strip().lower()] = lang["id"]
    print(f"✅ Found {len(language_map)} languages.")
except Exception as e:
    print("❌ Error fetching languages:", e)
    exit(1)

# Step 2: Process subjects from CSV (upsert operation)
print("\n📤 Upserting subjects from CSV...")
subjects_map = {}  # Store subject names to prevent duplicates
success = 0
fail = 0

with open(CSV_PATH, newline='', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for row in reader:
        # Extract subject from CSV
        subject_name = row.get("Subject", "").strip()
        
        if not subject_name:
            print(f"⚠️ Skipping row: Missing subject")
            continue
            
        # Skip if we've already processed this subject
        if subject_name in subjects_map:
            continue
            
        # Mark this subject as processed
        subjects_map[subject_name] = True
        
        # Check if subject already exists
        try:
            existing_subject = supabase.table("subjects").select("id", "color").eq("title", subject_name).execute()
            
            if existing_subject.data and len(existing_subject.data) > 0:
                # Subject exists, update it
                subject_id = existing_subject.data[0]["id"]
                existing_color = existing_subject.data[0]["color"]
                
                # Prepare payload for update operation
                payload = {
                    "title": subject_name,
                    "updated_at": datetime.now().isoformat()
                }
                
                print(f"→ Updating subject: '{subject_name}' (ID: {subject_id})")
                try:
                    res = supabase.table("subjects").update(payload).eq("id", subject_id).execute()
                    if res.status_code == 200:
                        print(f"   ✔ Success: Updated subject '{subject_name}'")
                        subjects_map[subject_name] = subject_id  # Store ID for reference
                        success += 1
                    else:
                        print(f"   ✖ Status {res.status_code}: {res.data}")
                        fail += 1
                except Exception as e:
                    print(f"   ✖ Error updating subject: {e}")
                    fail += 1
            else:
                # Subject doesn't exist, insert it
                color = generate_random_color()
                
                # Prepare payload for insert operation
                payload = {
                    "id": str(uuid.uuid4()),
                    "title": subject_name,
                    "color": color,
                    "created_at": datetime.now().isoformat(),
                    "updated_at": datetime.now().isoformat()
                }
                
                print(f"→ Inserting subject: '{subject_name}' with color {color}")
                try:
                    res = supabase.table("subjects").insert(payload).execute()
                    if res.status_code == 201:
                        print(f"   ✔ Success: Added subject '{subject_name}'")
                        subjects_map[subject_name] = payload["id"]  # Store ID for reference
                        success += 1
                    else:
                        print(f"   ✖ Status {res.status_code}: {res.data}")
                        fail += 1
                except Exception as e:
                    print(f"   ✖ Error inserting subject: {e}")
                    fail += 1
                    
        except Exception as e:
            print(f"   ✖ Error checking for existing subject: {e}")
            fail += 1

print(f"\n✅ Subject Upsert Complete — Success: {success}, Failed: {fail}")

# Step 3: Process grades from CSV (upsert operation)
print("\n📤 Upserting grades from CSV...")
grades_map = {}  # Store grade names to prevent duplicates
success = 0
fail = 0

with open(CSV_PATH, newline='', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for row in reader:
        # Extract grade from CSV
        grade_name = row.get("Grade", "").strip()
        
        if not grade_name:
            print(f"⚠️ Skipping row: Missing grade")
            continue
            
        # Skip if we've already processed this grade
        if grade_name in grades_map:
            continue
            
        # Mark this grade as processed
        grades_map[grade_name] = True
        
        # Prepare payload for upsert operation
        payload = {
            "title": grade_name,
            "updated_at": datetime.now().isoformat()
        }
        
        # Check if grade already exists
        try:
            existing_grade = supabase.table("grades").select("id").eq("title", grade_name).execute()
            
            if existing_grade.data and len(existing_grade.data) > 0:
                # Grade exists, update it
                grade_id = existing_grade.data[0]["id"]
                print(f"→ Updating grade: '{grade_name}' (ID: {grade_id})")
                
                try:
                    res = supabase.table("grades").update(payload).eq("id", grade_id).execute()
                    if res.status_code == 200:
                        print(f"   ✔ Success: Updated grade '{grade_name}'")
                        success += 1
                    else:
                        print(f"   ✖ Status {res.status_code}: {res.data}")
                        fail += 1
                except Exception as e:
                    print(f"   ✖ Error updating grade: {e}")
                    fail += 1
            else:
                # Grade doesn't exist, insert it
                payload["id"] = str(uuid.uuid4())
                payload["created_at"] = datetime.now().isoformat()
                
                print(f"→ Inserting grade: '{grade_name}'")
                try:
                    res = supabase.table("grades").insert(payload).execute()
                    if res.status_code == 201:
                        print(f"   ✔ Success: Added grade '{grade_name}'")
                        success += 1
                    else:
                        print(f"   ✖ Status {res.status_code}: {res.data}")
                        fail += 1
                except Exception as e:
                    print(f"   ✖ Error inserting grade: {e}")
                    fail += 1
                    
        except Exception as e:
            print(f"   ✖ Error checking for existing grade: {e}")
            fail += 1

print(f"\n✅ Grade Upsert Complete — Success: {success}, Failed: {fail}")

# Step 4: Process chapters from CSV with all required fields
print("\n📤 Inserting chapters from CSV...")
success = 0
fail = 0

# First, fetch required reference data
print("📥 Fetching required reference data...")

# Fetch grades
grades_data = {}
try:
    res = supabase.table("grades").select("id, title").execute()
    for grade in res.data:
        grades_data[grade["title"].strip().lower()] = grade["id"]
    print(f"✅ Found {len(grades_data)} grades")
except Exception as e:
    print(f"❌ Error fetching grades: {e}")
    exit(1)

# Fetch subjects
subjects_data = {}
try:
    res = supabase.table("subjects").select("id, title").execute()
    for subject in res.data:
        subjects_data[subject["title"].strip().lower()] = subject["id"]
    print(f"✅ Found {len(subjects_data)} subjects")
except Exception as e:
    print(f"❌ Error fetching subjects: {e}")
    exit(1)

# Fetch semesters
semesters_data = {}
try:
    res = supabase.table("semesters").select("id, title").execute()
    for semester in res.data:
        semesters_data[semester["title"].strip().lower()] = semester["id"]
    print(f"✅ Found {len(semesters_data)} semesters")
    # If no semesters found, provide a fallback
    if len(semesters_data) == 0:
        print("⚠️ No semesters found. Using default semester.")
        # Get or create a default semester
        default_id = str(uuid.uuid4())
        res = supabase.table("semesters").insert({
            "id": default_id,
            "title": "Default Semester",
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        }).execute()
        semesters_data["default semester"] = default_id
except Exception as e:
    print(f"❌ Error fetching semesters: {e}")
    exit(1)

# Fetch curricula
curricula_data = {}
try:
    res = supabase.table("curricula").select("id, title").execute()
    for curriculum in res.data:
        curricula_data[curriculum["title"].strip().lower()] = curriculum["id"]
    print(f"✅ Found {len(curricula_data)} curricula")
    # If no curricula found, provide a fallback
    if len(curricula_data) == 0:
        print("⚠️ No curricula found. Using default curriculum.")
        # Get or create a default curriculum
        default_id = str(uuid.uuid4())
        res = supabase.table("curricula").insert({
            "id": default_id,
            "title": "Default Curriculum",
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        }).execute()
        curricula_data["default curriculum"] = default_id
except Exception as e:
    print(f"❌ Error fetching curricula: {e}")
    exit(1)

# Get default IDs for missing data
default_semester_id = semesters_data.get("default semester") or next(iter(semesters_data.values()), None)
default_curriculum_id = curricula_data.get("default curriculum") or next(iter(curricula_data.values()), None)

with open(CSV_PATH, newline='', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for row in reader:
        # Extract data from CSV
        title = row.get("title", "").strip()
        sr = row.get("Sr", "").strip()
        lang = row.get("Language", "").strip().lower()
        grade = row.get("Grade", "").strip().lower()
        subject = row.get("Subject", "").strip().lower()
        semester = row.get("Semester", "").strip().lower() if "Semester" in row else None
        curriculum = row.get("Curriculum", "").strip().lower() if "Curriculum" in row else None

        # Convert Sr to number
        number = int(sr) if sr.isdigit() else None
        
        # Get required IDs from reference data
        language_id = language_map.get(lang)
        grade_id = grades_data.get(grade)
        subject_id = subjects_data.get(subject)
        semester_id = semesters_data.get(semester) if semester else default_semester_id
        curriculum_id = curricula_data.get(curriculum) if curriculum else default_curriculum_id

        # Validate required fields
        missing_fields = []
        if not title:
            missing_fields.append("title")
        if not number:
            missing_fields.append("number (Sr)")
        if not language_id:
            missing_fields.append(f"language '{lang}'")
        if not grade_id:
            missing_fields.append(f"grade '{grade}'")
        if not subject_id:
            missing_fields.append(f"subject '{subject}'")
        if not semester_id:
            missing_fields.append("semester")
        if not curriculum_id:
            missing_fields.append("curriculum")
            
        if missing_fields:
            print(f"⚠️ Skipping row: Missing {', '.join(missing_fields)}")
            fail += 1
            continue

        # Prepare payload for chapter insertion
        payload = {
            "id": str(uuid.uuid4()),
            "title": title,
            "number": number,
            "is_published": False,
            "language_id": language_id,
            "curriculum_id": curriculum_id,
            "grade_id": grade_id,
            "semester_id": semester_id,
            "subject_id": subject_id,
            # Set all boolean fields to false by default
            "unit_plan_created": False,
            "unit_plan_reviewed": False,
            "unit_plan_finalised": False,
            "copy_written": False,
            "layout_created": False,
            "illustrations_created": False,
            "videos_created": False,
            "google_slides_created": False,
            "review_1_completed": False,
            "review_2_completed": False,
            "final_review_completed": False,
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        }

        print(f"→ Inserting chapter: '{title}' with number {number}")
        try:
            res = supabase.table("chapters").insert(payload).execute()
            if res.status_code == 201:
                print(f"   ✔ Success: Added chapter '{title}' with number {number}")
                success += 1
            else:
                print(f"   ✖ Status {res.status_code}: {res.data}")
                fail += 1
        except Exception as e:
            print(f"   ✖ Error inserting chapter: {e}")
            fail += 1

print(f"\n✅ Chapter Insert Complete — Success: {success}, Failed: {fail}")

# Step 5: Process lessons from CSV
print("\n📤 Inserting lessons from CSV...")
success = 0
fail = 0

# Fetch chapters for reference
chapters_map = {}
try:
    res = supabase.table("chapters").select("id, title").execute()
    for chapter in res.data:
        chapters_map[chapter["title"].strip().lower()] = chapter["id"]
    print(f"✅ Found {len(chapters_map)} chapters for lesson mapping")
except Exception as e:
    print(f"❌ Error fetching chapters: {e}")
    exit(1)

with open(CSV_PATH, newline='', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for row in reader:
        # Extract data from CSV
        title = row.get("title", "").strip()
        
        if not title:
            print(f"⚠️ Skipping row: Missing title")
            fail += 1
            continue
        
        # Look up the chapter by title (since lesson name and chapter name will be the same)
        chapter_id = chapters_map.get(title.lower())
        
        if not chapter_id:
            print(f"⚠️ Skipping row: No matching chapter found for '{title}'")
            fail += 1
            continue
        
        # Prepare payload for lesson insertion
        payload = {
            "id": str(uuid.uuid4()),
            "chapter_id": chapter_id,
            "title": title,
            "number": 1,  # Fixed value as requested
            "is_published": False,
            "is_broken": False,
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        }
        
        # Check if optional fields are present in the CSV and add them to payload
        for field in ["google_slides_link", "google_slides_id", "normal_pdf", "encrypted_pdf", "password", "tags"]:
            if field in row and row[field]:
                payload[field] = row[field].strip()
        
        print(f"→ Inserting lesson: '{title}' for chapter ID {chapter_id}")
        try:
            res = supabase.table("lessons").insert(payload).execute()
            if res.status_code == 201:
                print(f"   ✔ Success: Added lesson '{title}'")
                success += 1
            else:
                print(f"   ✖ Status {res.status_code}: {res.data}")
                fail += 1
        except Exception as e:
            print(f"   ✖ Error inserting lesson: {e}")
            fail += 1

print(f"\n✅ Lesson Insert Complete — Success: {success}, Failed: {fail}")
