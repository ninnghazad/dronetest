Dronetest Protocol
==================

Messages are sent as tables.  The reason for tables over serialized tables is because serialized tables are needlessly serialized and then unserialized, and the reason for tables over parsed strings is that tables can contain arbitrary extra information, which is often convenient or necessary.

There are six normal message types: info, put, get, open, send, and close.  Each has a corresponding response message, of type info_ack, put_ack, get_ack, open_ack, send_ack, or close_ack.  Each message table has a field "type" whose value is the message type.  Each response message table has a field "success" whose value is a boolean true or false, depending on whether the request succeeded or failed.  If success = false, then there must be a field "error" whose value describes the error.

Devices may accept additional fields than those listed in this specification.  If any mandatory (and possibly additional) fields are not present in the request, the recipient must respond with
```
{
	type = "<type>_ack",
	success = false,
	error = "missing_fields"
	missing_fields = 
	{
		"<missing field 1>",
		...
	}
}
```

The info command must have no mandatory additional fields.  The success field for info must always be present and true.  A device not wishing to respond with success=true to an info command should simply not respond, instead of returning info_ack with success=false.  

Acknowledges should not be sent until the action has been completed (e.g. when telling a drone to move via send).

TODO: should there be two acknowledges, one to indicate the request was received, the other to indicate the action was completed?

Devices should ignore any request so malformed that they can not reply with an unambigous response.  For example, this is not a valid response:
```
{
	-- no type (no type was sent in the request), or type = "_ack",
	success = false,
	error = "missing_fields",
	missing fields = 
	{
		"type",
	},
}
```

## info
```
{
	type = "info",
}
```

### info_ack
```
{
	type = "info_ack",
	success = true,
	node_id = "<node id>",
	methods=
	{
		{
			method = "<supported method>",
			extra_fields = 
			{
				{
					name = "<extra field 1>",
					required = <boolean>,
				},
				...
			},
		},
		...
	},
}
```

* `<node id>`: Node/item id of the responding node (e.g. "dronetest:computer").  May be faked, e.g. if a computer is pretending to be a peripheral (NFS, remote login, general mischief, etc.).  


## put
```
{
	type = "put",
	id = <object identifier>,
	data = <data>,
}
```

* `<object identifier>`: Identifies the object.  See "Object Identifiers" below.  
* `<data>`: Data being put.  May be of any type, but the receiver may reject certain types.

### put_ack
#### success:
```
{
	type = "put_ack",
	success = true,
	id = <object identifier>,
}
```
* `<object identifier>`: Identifies the object.  See "Object Identifiers" below.  

Same as the packet that was sent, but the data field is omitted.  The id field is included to differentiate multiple requests that may be out to a device at once.  

#### failure:
```
{
	type = "put_ack",
	success = false,
	id = <object identifier>,
	error = <error message>,
}
```
* `<object identifier>`: Identifies the object.  See "Object Identifiers" below.  
* `<error message>`: 
  * "missing_fields": missing authorization (authorization should be its own field)
  * "bad_auth": authorization failed
  * "bad_id": bad object identifier
  * "bad_data": invalid data 
  * "bad_datatype": invalid data type (e.g. was table, should have been string)

## get
```
{
	type = "get",
	id = <object identifier>,
	datatype = 
	{
		"<datatype 1>",
		...
	}
}
```

* `<object identifier>`: Identifies the object.  See "Object Identifiers" below.  
* `<datatype n>`: Preferred data type (e.g. string or table).  May be list of strings, 

### get_ack
#### success:
```
{
	type = "get_ack",
	success = true,
	id = <object identifier>,
	data = <data>,
}
```
* `<data>`: Returned data.  May be of a type other than that requested if data of the type requested was not available.  
* `<object identifier>`: Included to differentiate multiple requests that may be out to a device at once.  See "Object Identifiers" below.  

#### failure:
```
{
	type = "get_ack",
	success = false,
	id = `<object identifier>`,
	error = `<error message>`,
}
```
* `<error message>`: 
  * "missing_fields": missing authorization (authorization should be its own field)
  * "bad_auth": authorization failed
  * "bad_id": bad object identifier

## open
```
{
	type = "open",
	id = <object identifier>,
}
```
* `<object identifier>`: Identifies the connection being opened and its purpose.  See "Object Identifiers" below.  

### open_ack
#### success:
```
{
	type = "open_ack",
	success = true,
	id = <object identifier>,
	cid = <connection handle>,
}
```
* `<connection handle>`: Connection handle, unique to the responding device, must be different from `<object identifier>`, may be a number or a string

#### failure:
```
{
	type = "open_ack",
	success = false,
	id = <object identifier>,
	error = "<error message>,
}
```
* `<object identifier>`: Identifies which request this is in response to.  See "Object Identifiers" below.  
* `<error message>`:
  * "missing_fields": missing authorization (authorization should be its own field)
  * "bad_auth": authorization failed

## send
```
{
	type = "send",
	id = <connection handle>,
	data = <data>,
}
```
* `<connection handle>`: connection handle (optional)
* `<data>`: data being sent

The `<connection handle>` field should be left out for transfer of connectionless data.  

### send_ack
#### success:
```
{
	type = "send_ack",
	success = true,
	id = <connection handle>,
	data = <data>,
}
```
* `<connection handle>`: connection handle (not present if it wasn't present in the request)
* `<data>`: copy of data being sent

#### failure:
```
{
	type = "send_ack",
	success = false,
	id = <connection handle>,
	error = "<error message>,
}
```
* `<connection handle>`: connection handle (not present if it wasn't present in the request)
* `<error message>`:
  * "missing_fields": no authorization, missing connection handle (when necessary), etc.  
  * "bad_auth": authorization failed
  * "invalid": invalid/already closed connection
  * "bad_data": could not understand sent data

## close
```
{
	type = "close",
	id = <connection handle>,
}
```
* `<connection handle>`: connection handle to be closed

### close_ack
#### success:
```
{
	type = "open_ack",
	success = true,
	id = <object identifier>,
	cid = <connection handle>,
}
```
* `<object identifier>`: Identifies the connection being opened and its purpose.  See "Object Identifiers" below.  
* `<connection handle>`: Connection handle

#### failure:
```
{
	type = "close_ack",
	success = false,
	id = <connection handle>,
	error = "<error message>,
}
```
* `<connection handle>`: Connection handle
* `<error message>`:
  * "missing_fields": no authorization, missing connection handle, etc.  
  * "bad_auth": authorization failed
  * "invalid": invalid/already closed connection


## Object Identifiers
An object identifier identifies an object (e.g. file, service, etc.) on a device.  They are used for file paths and such.  They may be of any type.  

Multiple different object identifiers may refer to the same object.  For example, "/path/to/some/file" and {"path","to","some","file"} both refer to the same file.  

Two object identifiers that are tables that have the same contents refer to the same object.  For example, although `{1,2,3} == {1,2,3}` evaluates to false in lua, both `{1,2,3}`s refer to the same object (on that device).
