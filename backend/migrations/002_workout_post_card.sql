-- Workout activity cards keep only allow-listed presentation keys.  A local
-- photo is intentionally not persisted here: friends on another device must
-- never receive an arbitrary filesystem path or an oversized base64 payload.
ALTER TABLE friend_workout_posts
  ADD COLUMN card_style TEXT NOT NULL DEFAULT 'coral';
ALTER TABLE friend_workout_posts
  ADD COLUMN card_image_key TEXT NOT NULL DEFAULT 'brand';
