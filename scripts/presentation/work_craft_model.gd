class_name WorkCraftModel
extends ShipModel
## Work craft keep the Wayfarer's industrial fittings, with task-specific silhouettes.
var crewed: bool = false

func _init(tug: bool = false) -> void:
	crewed = tug

func _ready() -> void:
	var width := 1.4 if crewed else 0.9
	var length := 3.4 if crewed else 1.7
	IndustrialDetail.armor(self, Vector3.ZERO, Vector3(width, 0.6, length), MeshKit.GOLD)
	MeshKit.box(self, Vector3(0, -0.28, 0), Vector3(width * 0.8, 0.32, length * 0.92), MeshKit.INK)
	if crewed:
		MeshKit.box(self, Vector3(0, 0.50, -0.7), Vector3(1.16, 0.85, 1.2), MeshKit.INK)
		for side in [-1, 1]:
			MeshKit.box(self, Vector3(side * 0.32, 0.91, -0.82), Vector3(0.49, 0.07, 0.78), Color("315d6c"), 0.3)
			var crew := IndustrialDetail.person(self, Vector3(side * 0.29, 0.45, -0.75), MeshKit.GOLD, true)
			crew.scale = Vector3.ONE * 0.36
			IndustrialDetail.pipe(self, Vector3(side * 0.8, -0.05, 0), Vector3(side * 0.95, -0.1, 2.0), 0.13, MeshKit.STEEL)
		IndustrialDetail.vent(self, Vector3(0, 0.34, 0.6), 0.9, 0.75, 6)
		MeshKit.cylinder(self, Vector3(0, 0.45, 1.3), 0.32, 0.28, MeshKit.STEEL)
		IndustrialDetail.pipe(self, Vector3(-0.43, 0.6, 1.25), Vector3(0.43, 0.6, 1.25), 0.17, MeshKit.GOLD)
	else:
		for side in [-1, 1]:
			IndustrialDetail.pipe(self, Vector3(side * 0.43, 0, -0.4), Vector3(side * 0.9, -0.1, -0.9), 0.07, MeshKit.STEEL)
			MeshKit.box(self, Vector3(side * 0.88, -0.1, -0.97), Vector3(0.17, 0.20, 0.42), MeshKit.INK)
		MeshKit.box(self, Vector3(0, 0.37, -0.55), Vector3(0.54, 0.19, 0.17), MeshKit.CYAN, 1.2)
		IndustrialDetail.vent(self, Vector3(0, 0.32, 0.2), 0.66, 0.65, 5)
	for side in [-1, 1]:
		var tube := MeshKit.cylinder(self, Vector3(side * width * 0.6, 0, length * 0.30), 0.21, 0.95, MeshKit.INK)
		tube.rotation.x = PI / 2
		var exhaust := MeshKit.cylinder(self, Vector3(side * width * 0.6, 0, length * 0.58), 0.14, 0.09, MeshKit.CYAN, -1, 2)
		exhaust.rotation.x = PI / 2
	MeshKit.bake(self)
	for side in [-1, 1]:
		var flame := MeshKit.cylinder(self, Vector3(side * width * 0.6, 0, length * 0.68), 0.01, 0.6, MeshKit.CYAN, 0.13, 2.4)
		flame.rotation.x = PI / 2
		flames.append(flame)

func _process(delta: float) -> void:
	clock += delta
	for flame in flames: flame.scale.y = 0.3 + throttle * 0.55 + sin(clock * 21) * 0.05
