extends "res://addons/gut/test.gd"


func test_child_to_list():
	var root := Node.new()
	root.name = "root"
	for i in range(5):
		var child = Node.new()
		child.name = "child%d" % i
		for j in range(2):
			var subchild = Node.new()
			subchild.name = "subchild%d-%d" % [i, j]
			child.add_child(subchild)
		root.add_child(child)
	add_child(root)
	var nodes = Util.children_to_list(root)
	assert_eq(nodes.size(), 15, "Wrong number of child nodes.")
	root.queue_free()
