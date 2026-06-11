extends Node

# These signals will be connected in later steps
signal on_health_changed(entity, old_health, new_health)
signal on_student_hit(student)
signal on_student_dead(student)
