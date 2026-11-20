@tool
extends EditorPlugin

## Godot MCP Toolkit — editor side.
##
## Hosts a localhost TCP/WebSocket server (the "Editor channel") that the
## @npgamedev/godot-mcp-server npm bridge talks JSON-RPC over.

const PORT_MIN := 6550
const PORT_MAX := 6560

var _tcp: TCPServer = null
var _port: int = -1
var _peers: Array[StreamPeerTCP] = []
var _ws: WebSocketPeer = null

func _enter_tree() -> void:
	_start_server()

func _exit_tree() -> void:
	_stop_server()

func _process(_delta: float) -> void:
	if _tcp == null:
		return
	_accept_new()
	_poll_peers()

func _start_server() -> void:
	for port in range(PORT_MIN, PORT_MAX + 1):
		var tcp := TCPServer.new()
		var err: Error = tcp.listen(port, "127.0.0.1")
		if err != OK:
			tcp = null
			continue
		_tcp = tcp
		_port = port
		print("[MCPToolkit] Editor channel listening on ws://127.0.0.1:%d" % _port)
		return
	push_warning("[MCPToolkit] Could not bind any port in %d-%d" % [PORT_MIN, PORT_MAX])

func _stop_server() -> void:
	for p in _peers:
		if p != null:
			p.disconnect_from_host()
	_peers.clear()
	if _tcp != null:
		_tcp.stop()
		_tcp = null
	_port = -1

func _accept_new() -> void:
	if _tcp == null:
		return
	while _tcp.is_connection_available():
		var conn: StreamPeerTCP = _tcp.take_connection()
		if conn == null:
			break
		conn.set_no_delay(true)
		_peers.append(conn)
		print("[MCPToolkit] New TCP connection")

func _poll_peers() -> void:
	var to_remove: Array[int] = []
	for i in range(_peers.size()):
		var p: StreamPeerTCP = _peers[i]
		if p == null:
			to_remove.append(i)
			continue
		p.poll()
		if p.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			to_remove.append(i)
			continue
		var avail: int = p.get_available_bytes()
		if avail <= 0:
			continue
		var data: PackedByteArray = p.get_data(avail)[1]
		var text: String = data.get_string_from_utf8()
		# Minimal WebSocket handshake: if the request contains an Upgrade header,
		# reply with the 101 Switching Protocols response.
		if text.find("Upgrade: websocket") >= 0 or text.find("upgrade: websocket") >= 0:
			_do_handshake(p, text)
			continue
		var response: String = _handle_jsonrpc(text)
		if response != "":
			p.put_data(response.to_utf8_buffer())
	for i in range(to_remove.size() - 1, -1, -1):
		_peers.remove_at(to_remove[i])

func _do_handshake(p: StreamPeerTCP, request: String) -> void:
	# Extract the Sec-WebSocket-Key
	var key: String = ""
	for line in request.split("\r\n"):
		if line.to_lower().begins_with("sec-websocket-key:"):
			key = line.split(":", false, 1)[1].strip_edges()
			break
	var accept_key: String = _ws_accept_key(key)
	var resp: String = (
		"HTTP/1.1 101 Switching Protocols\r\n" +
		"Upgrade: websocket\r\n" +
		"Connection: Upgrade\r\n" +
		"Sec-WebSocket-Accept: " + accept_key + "\r\n" +
		"\r\n"
	)
	p.put_data(resp.to_utf8_buffer())

func _ws_accept_key(key: String) -> String:
	# RFC 6455: base64(sha1(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
	var magic := key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA1)
	ctx.update(magic.to_utf8_buffer())
	var digest: PackedByteArray = ctx.finish()
	return Marshalls.raw_to_base64(digest)

func _handle_jsonrpc(text: String) -> String:
	var json: Variant = JSON.parse_string(text)
	if json == null:
		return _error_response(null, -32700, "Parse error")
	if not (json is Dictionary):
		return _error_response(null, -32600, "Invalid Request")
	var req: Dictionary = json
	var id: Variant = req.get("id", null)
	var method: String = str(req.get("method", ""))
	var params: Dictionary = req.get("params", {})
	if not (params is Dictionary):
		params = {}
	var result: Variant = null
	var error_code: int = 0
	var error_msg: String = ""
	var ok: bool = false
	match method:
		"mcp.list_tools":
			result = _cmd_list_tools()
			ok = true
		"mcp.call_tool":
			var r: Dictionary = _cmd_call_tool(params)
			result = r.get("result", null)
			error_code = int(r.get("error_code", 0))
			error_msg = str(r.get("error_message", ""))
			ok = error_code == 0
		_:
			error_code = -32601
			error_msg = "Method not found: %s" % method
	if ok:
		return _success_response(id, result)
	return _error_response(id, error_code, error_msg)

func _success_response(id: Variant, result: Variant) -> String:
	var resp: Dictionary = {"jsonrpc": "2.0", "id": id, "result": result}
	return JSON.stringify(resp)

func _error_response(id: Variant, code: int, message: String) -> String:
	var resp: Dictionary = {"jsonrpc": "2.0", "id": id, "error": {"code": code, "message": message}}
	return JSON.stringify(resp)

func _cmd_list_tools() -> Array:
	var tools: Array = []
	tools.append({"name": "list_nodes", "description": "List nodes in the current edited scene.", "inputSchema": {"type": "object", "properties": {}}})
	tools.append({"name": "get_node_info", "description": "Get properties of a node by path.", "inputSchema": {"type": "object", "properties": {"path": {"type": "string"}}}})
	tools.append({"name": "call_method", "description": "Call a method on a node.", "inputSchema": {"type": "object", "properties": {"path": {"type": "string"}, "method": {"type": "string"}, "args": {"type": "array"}}}})
	tools.append({"name": "set_property", "description": "Set a property on a node.", "inputSchema": {"type": "object", "properties": {"path": {"type": "string"}, "property": {"type": "string"}, "value": {}}}})
	tools.append({"name": "get_property", "description": "Get a property from a node.", "inputSchema": {"type": "object", "properties": {"path": {"type": "string"}, "property": {"type": "string"}}}})
	tools.append({"name": "run_playtest", "description": "Start the project (playtest).", "inputSchema": {"type": "object", "properties": {}}})
	tools.append({"name": "stop_playtest", "description": "Stop the running playtest.", "inputSchema": {"type": "object", "properties": {}}})
	tools.append({"name": "get_scene_tree", "description": "Return the root scene's node tree.", "inputSchema": {"type": "object", "properties": {}}})
	return tools

func _cmd_call_tool(params: Dictionary) -> Dictionary:
	var name: String = str(params.get("name", ""))
	var args: Dictionary = params.get("arguments", {})
	if not (args is Dictionary):
		args = {}
	match name:
		"list_nodes":
			return {"result": _do_list_nodes()}
		"get_node_info":
			return {"result": _do_get_node_info(str(args.get("path", "")))}
		"call_method":
			return {"result": _do_call_method(str(args.get("path", "")), str(args.get("method", "")), args.get("args", []))}
		"set_property":
			return {"result": _do_set_property(str(args.get("path", "")), str(args.get("property", "")), args.get("value", null))}
		"get_property":
			return {"result": _do_get_property(str(args.get("path", "")), str(args.get("property", "")))}
		"run_playtest":
			return {"result": _do_run_playtest()}
		"stop_playtest":
			return {"result": _do_stop_playtest()}
		"get_scene_tree":
			return {"result": _do_get_scene_tree()}
		_:
			return {"error_code": -32602, "error_message": "Unknown tool: %s" % name}

func _do_list_nodes() -> Dictionary:
	var scene: Node = get_editor_interface().get_edited_scene_root()
	if scene == null:
		return {"error": "No scene open"}
	return {"nodes": _collect_nodes(scene)}

func _collect_nodes(node: Node, prefix: String = "") -> Array:
	var out: Array = []
	var name: String = node.name
	var path: String = prefix + ("" if prefix == "" else "/") + name
	out.append({"path": path, "type": node.get_class()})
	for c in node.get_children():
		out.append_array(_collect_nodes(c, path))
	return out

func _do_get_node_info(path: String) -> Dictionary:
	var node: Node = _resolve_path(path)
	if node == null:
		return {"error": "Node not found: %s" % path}
	var props: Array = []
	for p in node.get_property_list():
		var pname: String = str(p.get("name", ""))
		if pname == "":
			continue
		var val: Variant = node.get(pname)
		props.append({"name": pname, "type": typeof(val), "value": _variant_to_json(val)})
	return {"path": path, "type": node.get_class(), "properties": props}

func _do_call_method(path: String, method: String, args: Variant) -> Dictionary:
	var node: Node = _resolve_path(path)
	if node == null:
		return {"error": "Node not found: %s" % path}
	var callable_args: Array = []
	if args is Array:
		for a in args:
			callable_args.append(a)
	var result: Variant = node.call(method, callable_args)
	return {"result": _variant_to_json(result)}

func _do_set_property(path: String, property: String, value: Variant) -> Dictionary:
	var node: Node = _resolve_path(path)
	if node == null:
		return {"error": "Node not found: %s" % path}
	node.set(property, value)
	return {"ok": true}

func _do_get_property(path: String, property: String) -> Dictionary:
	var node: Node = _resolve_path(path)
	if node == null:
		return {"error": "Node not found: %s" % path}
	var val: Variant = node.get(property)
	return {"value": _variant_to_json(val)}

func _do_run_playtest() -> Dictionary:
	var ei: EditorInterface = get_editor_interface()
	if ei == null:
		return {"error": "EditorInterface unavailable"}
	var scene: Node = ei.get_edited_scene_root()
	if scene != null:
		ei.play_custom_scene(scene.scene_file_path)
	return {"ok": true}

func _do_stop_playtest() -> Dictionary:
	var ei: EditorInterface = get_editor_interface()
	if ei == null:
		return {"error": "EditorInterface unavailable"}
	ei.stop()
	return {"ok": true}

func _do_get_scene_tree() -> Dictionary:
	var scene: Node = get_editor_interface().get_edited_scene_root()
	if scene == null:
		return {"error": "No scene open"}
	return {"root": _node_tree_dict(scene)}

func _node_tree_dict(node: Node) -> Dictionary:
	var d: Dictionary = {"name": node.name, "type": node.get_class(), "children": []}
	for c in node.get_children():
		d["children"].append(_node_tree_dict(c))
	return d

func _resolve_path(path: String) -> Node:
	if path == "" or path == ".":
		return get_editor_interface().get_edited_scene_root()
	var node: Node = get_editor_interface().get_edited_scene_root()
	if node == null:
		return null
	var parts: PackedStringArray = path.split("/")
	for p in parts:
		if p == "":
			continue
		node = node.get_node_or_null(p)
		if node == null:
			return null
	return node

func _variant_to_json(v: Variant) -> Variant:
	if v is String or v is int or v is float or v is bool:
		return v
	if v is Vector2 or v is Vector3 or v is Color or v is Transform3D or v is Basis or v is Rect2 or v is Rect2i or v is Vector2i or v is Vector3i:
		return str(v)
	if v is Array:
		var out: Array = []
		for e in v:
			out.append(_variant_to_json(e))
		return out
	if v is Dictionary:
		var out: Dictionary = {}
		for k in v.keys():
			out[str(k)] = _variant_to_json(v[k])
		return out
	if v is Object:
		return v.get_class() + ":" + str(v.get_instance_id())
	return str(v)
