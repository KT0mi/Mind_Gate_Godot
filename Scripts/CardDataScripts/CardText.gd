class_name CardText extends RefCounted

#Helper for formatting dynamic per-instance injected text in displayed card text
#Uses BBcode for rich text labels

const DYNAMIC_COLOR := "#ffcc4d"  ## placeholder
const KEYWORD_COLOR := "#4b95de"

static func dynamic(value) -> String:
	return "[b][color=%s]%s[/color][/b]" % [DYNAMIC_COLOR, str(value)]

static func keyword(keyword_id: StringName, context : bool) -> String:
	var keywrd : CardKeywords.Keyword = CardKeywords.get_keyword(keyword_id)
	if keywrd == null:
		push_error("CardText.keyword(): unknown keyword id '%s'" % keyword_id)
		return str(keyword_id)
	var text := "[b][color=%s]%s[/color][/b]" % [KEYWORD_COLOR, str(keywrd.name)]
	if context:
		text += " (" + keywrd.description + ")"
	return text
