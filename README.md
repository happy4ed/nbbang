# Receipt Splitter

Flutter MVP for on-device receipt OCR and split calculation.

## Flow

1. Import a receipt from camera or gallery.
2. Run Google ML Kit text recognition on device.
3. Parse OCR rows with rule-based receipt heuristics.
4. Review/edit items, assign people, and copy the split summary.

## Notes

- No server API or LLM call is used.
- Unassigned items are shared by all participants.
- Tax, service charge, and global discounts are allocated by each participant's item subtotal ratio.
- `flutter pub get` requires access to `pub.dev`; the current sandbox has network disabled.
