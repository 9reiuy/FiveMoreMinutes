class_name DisplayFormat
extends RefCounted


static func format_currency(amount: int) -> String:
	var negative := amount < 0
	var digits := str(absi(amount))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	grouped = digits + grouped
	return ("-" if negative else "") + "¥" + grouped
