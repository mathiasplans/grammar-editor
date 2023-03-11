extends Button

var rule_i

func _pressed():
	%RuleManager.set_to_rule(self.rule_i)
