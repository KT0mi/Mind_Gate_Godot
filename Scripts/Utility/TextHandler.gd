class_name TextHandler extends RefCounted

const SMALL_TEXT_THEME := preload("res://Theme/card_text_small_theme.tres")

## Smallest piece of a word allowed before / after a hyphen break.
const MIN_HEAD := 2
const MIN_TAIL := 2

# Metadata keys used to remember the original text/theme on each label,
# so calling fit_name_label() again never wraps already-wrapped text.
const META_RAW := &"_th_raw"
const META_WRAPPED := &"_th_wrapped"
const META_THEME := &"_th_orig_theme"
const META_SMALL := &"_th_is_small"


## Wraps the label's text with hyphenated word breaks. If it doesn't fit
## the label's rect in the current font, switches to the small theme and
## wraps again. Safe to call repeatedly (e.g. after the text changes).
## The label's autowrap is turned off afterwards, because the text then
## already contains its own line breaks.
static func fit_name_label(label: Label) -> void:
	if label.text == "":
		return

	var available: Vector2 = label.size
	if available.x <= 0.0 or available.y <= 0.0:
		return  # not laid out yet -- caller should retry after layout

	# Only handle labels that were set to wrap (or that we already manage).
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF and not label.has_meta(META_RAW):
		return

	# Recover the unwrapped text. If label.text differs from what we last
	# wrote, the caller assigned new text, so treat it as the new raw text.
	var raw: String = label.text
	if label.has_meta(META_WRAPPED) and label.text == label.get_meta(META_WRAPPED):
		raw = label.get_meta(META_RAW)

	# Remember the original theme once, and restore it before re-measuring.
	if not label.has_meta(META_THEME):
		label.set_meta(META_THEME, label.theme)
	if label.get_meta(META_SMALL, false):
		label.theme = label.get_meta(META_THEME)
		label.set_meta(META_SMALL, false)

	# 1) Try the normal font.
	var wrapped := _wrap_for_label(label, raw, available.x)
	if not _fits(label, wrapped, available):
		# 2) Too big: switch to the small theme and wrap again.
		label.theme = SMALL_TEXT_THEME
		label.set_meta(META_SMALL, true)
		wrapped = _wrap_for_label(label, raw, available.x)

	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text = wrapped
	label.set_meta(META_RAW, raw)
	label.set_meta(META_WRAPPED, wrapped)


static func _wrap_for_label(label: Label, raw: String, max_w: float) -> String:
	var font: Font = label.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var size: int = label.get_theme_font_size("font_size")
	return wrap_hyphenate(raw, font, size, max_w)


static func _fits(label: Label, wrapped: String, available: Vector2) -> bool:
	var font: Font = label.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var size: int = label.get_theme_font_size("font_size")

	var text_size := font.get_multiline_string_size(
			wrapped, label.horizontal_alignment, -1.0, size)
	var lines := wrapped.count("\n") + 1
	text_size.y += (lines - 1) * label.get_theme_constant("line_spacing")
	return text_size.x <= available.x and text_size.y <= available.y


## Word wrap that breaks only words longer than a full line, adding "-".
## Words that fit on a line by themselves are moved down intact (like Smart mode).
static func wrap_hyphenate(text: String, font: Font, size: int, max_w: float) -> String:
	var out: PackedStringArray = []

	for paragraph in text.split("\n"):
		var line := ""
		for word in paragraph.split(" "):
			var candidate := word if line == "" else line + " " + word
			if _w(candidate, font, size) <= max_w:
				line = candidate
				continue

			# Doesn't fit on the current line, but fits on a fresh one.
			if _w(word, font, size) <= max_w:
				out.append(line)
				line = word
				continue

			# Word is longer than a whole line: split it with hyphens,
			# first filling whatever space is left on the current line.
			var prefix := line + " " if line != "" else ""
			while _w(prefix + word, font, size) > max_w:
				var max_n := maxi(1, word.length() - MIN_TAIL)
				var n := 0
				for i in range(1, max_n + 1):
					if _w(prefix + word.substr(0, i) + "-", font, size) <= max_w:
						n = i
					else:
						break

				if n < MIN_HEAD and prefix != "":
					# Not enough room on this line for a decent fragment.
					out.append(line)
					line = ""
					prefix = ""
					continue
				if n == 0:
					n = 1  # label narrower than one glyph + "-": force progress

				out.append(prefix + word.substr(0, n) + "-")
				word = word.substr(n)
				prefix = ""
				line = ""
			line = prefix + word

		out.append(line)

	return "\n".join(out)


static func _w(s: String, font: Font, size: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
