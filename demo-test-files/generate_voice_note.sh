#!/bin/zsh
# Generate the ~18s Hinglish voice note for path A2 (data pack 7.4).
# Dictates the same 8 lines as the handwritten list, so all downstream totals match.
# Uses macOS `say` (en_IN voice "Rishi") -> AIFF, then afconvert -> AAC .m4a.
set -e
HERE="${0:A:h}"
OUT_M4A="$HERE/dealer_order_note.m4a"
TMP_AIFF="$HERE/.dealer_order_note.aiff"

# 7.4 transcript, verbatim. Romanised Hinglish read by an Indian-English voice.
SCRIPT='Haan likh lo. Fieldcoat TE1 bees litre ka chhe. Fieldcoat Supwhite bees litre baarah. Fieldcoat TE1 chaar litre bees. Glosscoat gloss black chaar litre chaar. Gloss enamel brown chaar litre pandrah. Glosscoat gloss black ek litre aath. Wall putty bees kilo paanch. Aur Hueline wall putty paanch kilo teen. Bas itna hi.'

# rate ~148 wpm lands the clip near the scripted 18 seconds
say -v Rishi -r 150 -o "$TMP_AIFF" "$SCRIPT"
afconvert "$TMP_AIFF" "$OUT_M4A" -d aac -f m4af
rm -f "$TMP_AIFF"

echo "wrote $OUT_M4A"
afinfo "$OUT_M4A" 2>/dev/null | grep -iE "duration|data format" || true
