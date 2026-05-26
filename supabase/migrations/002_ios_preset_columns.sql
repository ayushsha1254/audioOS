-- Migration: Add iOS Preset Studio columns to sound_presets
-- These columns are additive — they do NOT break the existing web app.
-- Run this once in Supabase Dashboard > SQL Editor.

ALTER TABLE public.sound_presets
  ADD COLUMN IF NOT EXISTS hpf_cutoff        float DEFAULT 120,
  ADD COLUMN IF NOT EXISTS eq_low_mid_q      float DEFAULT 1.0,
  ADD COLUMN IF NOT EXISTS eq_high_mid_q     float DEFAULT 1.0,
  ADD COLUMN IF NOT EXISTS reverb_preset_val float DEFAULT 0,
  ADD COLUMN IF NOT EXISTS voice_type        text;

-- Reload PostgREST schema cache so the new columns are immediately visible
NOTIFY pgrst, 'reload schema';
