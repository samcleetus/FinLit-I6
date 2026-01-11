extends Resource
class_name Indicator

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""

# Semantic anchor points for this indicator; ordering validation can be added later.
@export var low_value: float = 0.0
@export var mid_value: float = 0.0
@export var high_value: float = 0.0
