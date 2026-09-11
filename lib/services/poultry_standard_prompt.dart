class PoultryStandardPrompt {
  static const text = r'''Act as an expert poultry data scientist and structural systems engineer. Generate a highly structured, valid JSON schema containing the comprehensive operational standard benchmarks for the [INSERT STRAIN, e.g., BV300] commercial layer hen lifecycle.

Your output must be strictly valid JSON code block only, without any markdown text, conversational introductions, or conclusions outside the markdown code fence. Ensure all data objects utilize specific, age-based array tracking to prevent data skewing when parsed by automated logic.

### Structural Schema Requirements

1. Use JSON snake_case formatting for all keys.
2. Group the data into the following distinct root arrays/objects:
   - `breed_metadata`: Standard identifiers (breed name, total lifecycle weeks, target cumulative metrics).
   - `weekly_performance_matrix`: An array of objects from Week 1 to Week [INSERT END WEEK, e.g., 72], tracking discrete parameters mapped exactly to that week.
   - `environmental_correction_matrix`: A temperature-indexed matrix containing dynamic multipliers for feed, water, and ventilation adjustments.
   - `diagnostic_health_indicators`: Categorized thresholds for structural, fecal, and management alerts.

3. Within the `weekly_performance_matrix`, you must explicitly separate discrete values from daily calculated values to maintain accurate application logic. For every week object, include:
   - `week_number`: (Integer)
   - `life_stage`: (String)
   - `target_body_weight_g`: (Float - current mean weight in grams for that exact week)
   - `target_uniformity_percentage`: (Float)
   - `daily_feed_intake_g_per_bird`: (Float - non-cumulative feed target for a single day during this week)
   - `cumulative_feed_intake_kg_per_bird`: (Float - total feed consumed since Day 0 up to this week)
   - `daily_water_intake_ml_per_bird`: (Float - baseline consumption at 21°C)
   - `daily_grit_intake_g_per_bird`: (Float)
   - `target_hen_day_production_percentage`: (Float - expected daily laying rate for this week)
   - `target_individual_egg_weight_g`: (Float - expected weight of a single egg at this age)
   - `target_daily_egg_mass_g`: (Float - calculated as HDEP% * Egg Weight / 100)
   - `target_flock_livability_percentage`: (Float - expected cumulative survival rate)
   - `target_fcr_per_dozen_eggs`: (Float)
   - `target_fcr_per_kg_egg_mass`: (Float)
   - `lighting_photoperiod_hours`: (Float)
   - `lighting_intensity_lux`: (Float)
   - `anatomical_benchmarks`: { `pin_bone_spread_fingers`: Float, `abdominal_capacity_fingers`: Float }

### Data Quality Rules
- Do not compress weeks into wide ranges. Provide data points matching standard management guide progressions.
- Ensure chronological and metabolic consistency (e.g., cumulative feed must strictly increase, egg weight must track up with age, HDEP must show a realistic peak curve and gradual post-peak decline).
- All numeric elements must be raw floats or integers; do not append unit characters (e.g., use 115, not "115g").

Output the complete, syntactically perfect JSON block below:''';
}
