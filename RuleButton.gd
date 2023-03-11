extends Button

@export var rule_i : int

func _pressed():
	%RuleManager.set_to_rule(self.rule_i)
