class_name CartTrip
extends RefCounted
## A trip with a handcart, as any villager makes one: fetch the cart, pull it to `dest`, let go,
## see to the business there, then bring the cart home (stopping a shaft short, as it trails).


static func make(what: String, npc: Npc, cart: HandCart, dest: Vector3, business: Task, home_spot: Vector3) -> Sequence:
	var steps: Array[Task] = [
		GoTo.new(cart.handle_point(), 0.6, "Fetching the handcart"),
		DoNow.new("", func() -> void: cart.grab(npc)),
		GoTo.new(dest, 1.2, what),
		DoNow.new("", func() -> void: cart.release(npc)),
		business,
		ToCart.new(cart),   # back round to the handles, wherever the cart ended up
		DoNow.new("", func() -> void: cart.grab(npc)),
		GoTo.new(home_spot - Vector3(0, 0, HandCart.SHAFT), 1.0, "Bringing the cart home"),
		DoNow.new("", func() -> void: cart.release(npc)),
	]
	return Sequence.new(what, steps)


## Walk to wherever the cart's handles are now (they move when the cart is parked).
class ToCart extends GoTo:
	var _cart: HandCart

	func _init(c: HandCart) -> void:
		super(Vector3.ZERO, 0.6, "Going back for the cart")
		_cart = c

	func start(npc: Npc) -> void:
		target = _cart.handle_point()
		super(npc)
