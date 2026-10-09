# Integration sources

## wger exercise data

Source: https://wger.de/api/v2/exerciseinfo/ and https://github.com/wger-project/wger

Retrieved 2026-10-03: 916 exercise objects, including translations, authors,
images/videos metadata and the individual Creative Commons license objects.
Keep attribution, source links and individual licenses when redistributing.
The snapshot is data obtained through the public REST API. wger application
code (AGPL-3.0-or-later) is not embedded in the KILO backend.
Refresh with `node scripts/update_wger_knowledge.mjs`.

## H1an1/health-coach

Source: https://github.com/H1an1/health-coach

Revision: 9c2da9483eb826d0ff4b42cb96f79e1218071215

The upstream reference files, report templates, original SKILL.md and MIT
license are retained under `health-coach/`. Upstream attribution to
MedClaw-Org/OpenClaw-Medical-Skills / WellAlly Tech remains in those files.
The original skill is preserved for provenance, not executed as a shell
script. KILO's adapted skills access authorized backend data via MCP; they
do not inherit upstream's claim that all personal data remains local.
Upstream medical content is informational and is not a verified current
clinical guideline or a prescription engine. Food estimates must be checked
against the actual product label and portion size.

## Integration boundary

KILO remains the source of member records. wger supplies public exercise
knowledge; health-coach supplies instruction/reference material. No member
data is uploaded to wger. A remote software account is connected only through
the user's login, and password is not persisted. Its session is encrypted
with the server session pepper; production must configure a private pepper.
