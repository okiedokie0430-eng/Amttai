#!/usr/bin/env python3
"""
Convert recipes.parquet to a lean CSV for Node.js ingestion.
Parses ISO 8601 durations, extracts first image, flattens lists.
Usage: python convert_parquet.py recipes.parquet output.csv
"""
import sys
import re
import json
import pandas as pd


def parse_iso8601_duration(dur):
    """PT1H30M -> 90 minutes. PT45M -> 45. PT2H -> 120."""
    if pd.isna(dur) or not isinstance(dur, str):
        return 30
    dur = dur.strip()
    if not dur.startswith('PT'):
        return 30
    dur = dur[2:]
    total = 0
    m = re.search(r'(\d+)H', dur)
    if m:
        total += int(m.group(1)) * 60
    m = re.search(r'(\d+)M', dur)
    if m:
        total += int(m.group(1))
    if total == 0:
        return 30
    return total


def parse_py_list(val):
    """Parse Python c(...) string or JSON string into list."""
    if pd.isna(val):
        return []
    s = str(val).strip()
    # Remove leading c() wrapper if present
    if s.startswith('c(') and s.endswith(')'):
        s = s[2:-1]
    # Try JSON parse first
    try:
        return json.loads(s)
    except:
        pass
    # Split by commas if it looks like a list
    if ',' in s:
        return [x.strip().strip('"\'') for x in s.split(',')]
    if s:
        return [s]
    return []


def extract_first_image(val):
    """Extract first URL from Images column."""
    if pd.isna(val):
        return None
    urls = parse_py_list(val)
    for u in urls:
        if u.startswith('http'):
            return u
    return None


def main():
    parquet_path = sys.argv[1] if len(sys.argv) > 1 else 'recipes.parquet'
    csv_path = sys.argv[2] if len(sys.argv) > 2 else 'recipes_converted.csv'

    print(f"Reading {parquet_path}...")
    df = pd.read_parquet(parquet_path)
    print(f"Rows: {len(df)}, Cols: {len(df.columns)}")

    # Parse durations
    df['total_minutes'] = df['TotalTime'].apply(parse_iso8601_duration)
    df['prep_minutes']  = df['PrepTime'].apply(parse_iso8601_duration)
    df['cook_minutes']  = df['CookTime'].apply(parse_iso8601_duration)

    # Parse lists
    df['tags']         = df['Keywords'].apply(parse_py_list)
    df['ingredients']  = df['RecipeIngredientParts'].apply(parse_py_list)
    df['steps']        = df['RecipeInstructions'].apply(parse_py_list)
    df['image_url']    = df['Images'].apply(extract_first_image)

    # Nutrition
    df['calories'] = df['Calories'].fillna(0).astype(float)
    df['fat']      = df['FatContent'].fillna(0).astype(float)
    df['protein']  = df['ProteinContent'].fillna(0).astype(float)
    df['carbs']    = df['CarbohydrateContent'].fillna(0).astype(float)

    # Servings
    df['servings'] = df['RecipeServings'].fillna(4).astype(int)

    # Category
    df['category'] = df['RecipeCategory'].fillna('')

    # Build lean CSV
    out = pd.DataFrame({
        'id':            df['RecipeId'],
        'name':          df['Name'],
        'minutes':       df['total_minutes'],
        'prep_minutes':  df['prep_minutes'],
        'cook_minutes':  df['cook_minutes'],
        'tags':          df['tags'].apply(json.dumps),
        'ingredients':   df['ingredients'].apply(json.dumps),
        'steps':         df['steps'].apply(json.dumps),
        'image_url':     df['image_url'],
        'servings':      df['servings'],
        'calories':      df['calories'],
        'fat':           df['fat'],
        'protein':       df['protein'],
        'carbs':         df['carbs'],
        'category':      df['category'],
        'description':   df['Description'].fillna(''),
    })

    out.to_csv(csv_path, index=False, encoding='utf-8-sig')
    print(f"Wrote {len(out)} rows to {csv_path}")


if __name__ == '__main__':
    main()
