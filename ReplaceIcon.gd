class_name ReplaceIcon
extends SceneTree

const ICON_SIZE := 359559

var error_callable: Callable


func _init() -> void:
	var arguments = OS.get_cmdline_args()
	if arguments.size() != 4:
		print(
			"Usage:\n",
			"  godot -s ReplaceIcon.gd icon name\n",
			"\n",
			"Replaces ico file in windows PE32+ executable.\n",
			"Add --headless to hide Godot console.\n",
			"\n",
			"Arguments:\n",
			"  godot  path to Godot 4 beta2+ executable\n",
			"  icon   path to new icon\n",
			"  name   path to modified PE32+ executable\n"
		)
		quit()
		return
	replace_icon(arguments[3], arguments[2])
	quit()


func replace_icon(executable_path: String, icon_path: String) -> void:
	var icon_replacer := IconReplacer.new()

	var images := get_images(icon_path)

	var executable_file := FileAccess.open(executable_path, FileAccess.READ_WRITE)
	if not executable_file:
		print_error("Could not open executable file!")
		return
	var headers := executable_file.get_buffer(2048)
	var resources_section_entry := icon_replacer.find_resources_section_entry(headers)
	if not resources_section_entry:
		return
	if resources_section_entry.size_of_raw_data < 359559:
		print_error("Could not find icons in executable. Wrong template?")
		return

	executable_file.seek(resources_section_entry.pointer_to_raw_data)
	var resources := executable_file.get_buffer(resources_section_entry.size_of_raw_data)
	
	resources = icon_replacer.replace_icons(resources, resources_section_entry.virtual_address, images)
	if not resources.is_empty():
		executable_file.seek(resources_section_entry.pointer_to_raw_data)
		executable_file.store_buffer(resources)


func get_images(icon_path: String) -> Dictionary:
	var file := FileAccess.open(icon_path, FileAccess.READ)
	if not file:
		print_error(str("Could not open icon file!\n", FileAccess.get_open_error()))
		return {}
	return Icon.new(file.get_buffer(ICON_SIZE)).images


func print_error(error_message: String) -> void:
	printerr(error_message)
	if error_callable:
		error_callable.call(error_message)


class IconReplacer:
	enum ImageType {PE32 = 0x10b, PE32_PLUS = 0x20b}

	const PE_HEADER_ADDRESS_OFFSET := 0x3c
	const NUMBER_OF_SECTIONS_OFFSET := 0x6
	const SIZE_OF_OPTIONAL_HEADER_OFFSET := 0x14
	const MAGIC_OFFSET := 0x18
	const COFF_HEADER_SIZE := 24
	const SECTION_SIZE := 40
	const SIZE_OF_RAW_DATA_OFFSET := 0x10
	const POINTER_TO_RAW_DATA_OFFSET := 0x14
	const DATA_ENTRY_SIZE := 16

	var error_callable: Callable


	func replace_icons(resources: PackedByteArray, rva_offset: int, images: Dictionary) -> PackedByteArray:
		var data_entries := find_data_entries(resources)
		for data_size in images.keys():
			var icon_offset := find_icon_offset(data_entries, data_size, rva_offset)
			if resources.slice(icon_offset + 1, icon_offset + 4).get_string_from_ascii() != "PNG":
				print_error("Wrong icon type, PNG signature missing")
				return PackedByteArray()
			resources = IconReplacer.replace(resources, images[data_size], icon_offset)
		return resources


	func find_icon_offset(data_entries: Array, data_size: int, rva_offset: int) -> int:
		for data_entry in data_entries:
			if data_entry.size == data_size:
				return data_entry.rva - rva_offset
		return -1


	func find_resources_section_entry(headers: PackedByteArray) -> SectionEntry:
		var header_offset := IconReplacer.lsb_first(headers, PE_HEADER_ADDRESS_OFFSET, 2)
		var image_type := IconReplacer.lsb_first(headers, header_offset + MAGIC_OFFSET, 2)
		if not image_type == ImageType.PE32_PLUS:
			print_error("Only PE32+ executables are handled.")
			return null
		var sections_size := IconReplacer.lsb_first(headers, header_offset + NUMBER_OF_SECTIONS_OFFSET, 2)
		var size_of_optional_header := IconReplacer.lsb_first(headers, header_offset + SIZE_OF_OPTIONAL_HEADER_OFFSET, 2)
		var sections_offset := header_offset + COFF_HEADER_SIZE + size_of_optional_header
		for _i in range(sections_size):
			var section_name  = headers.slice(sections_offset, sections_offset + 8).get_string_from_ascii()
			if section_name == ".rsrc":
				return SectionEntry.new(headers.slice(sections_offset, sections_offset + SECTION_SIZE))
			sections_offset += SECTION_SIZE
		return null


	func find_data_entries(resources: PackedByteArray) -> Array:
		var result := []
		parse_table(resources, 0, result)
		return result


	func parse_table(resources: PackedByteArray, offset: int, data_entries: Array) -> void:
		var entry_count := IconReplacer.lsb_first(resources, offset + 14, 2)
		offset += 16
		for _i in range(entry_count):
			parse_entry(resources, offset, data_entries)
			offset += 8


	func parse_entry(resources: PackedByteArray, offset: int, data_entries: Array) -> void:
		var entry_offset := IconReplacer.lsb_first(resources, offset + 4)
		if entry_offset & 0x80000000:
			parse_table(resources, entry_offset & 0x7fffffff, data_entries)
		else:
			parse_data_entry(resources, entry_offset, data_entries)


	func parse_data_entry(resources: PackedByteArray, offset: int, data_entries: Array) -> void:
		data_entries.append(DataEntry.new(resources.slice(offset, offset + DATA_ENTRY_SIZE)))


	func print_error(error_message: String) -> void:
		printerr(error_message)
		if error_callable:
			error_callable.call(error_message)


	static func lsb_first(bytes: PackedByteArray, offset: int, byte_count = 4) -> int:
		var result := 0
		for i in range(byte_count, 0, -1):
			result = (result << 8) + bytes[offset + i - 1]
		return result


	static func replace(bytes: PackedByteArray, replacement: PackedByteArray, index: int) -> PackedByteArray:
		for i in range(replacement.size()):
			bytes.set(index + i, replacement[i])
		return bytes


class SectionEntry:
	const VIRTUAL_ADDRESS_OFFSET := 0x0c
	const SIZE_OF_RAW_DATA_OFFSET = 0x10
	const POINTER_TO_RAW_DATA_OFFSET = 0x14

	var virtual_address: int
	var pointer_to_raw_data: int
	var size_of_raw_data: int


	func _init(bytes: PackedByteArray) -> void:
		virtual_address = IconReplacer.lsb_first(bytes, VIRTUAL_ADDRESS_OFFSET)
		size_of_raw_data = IconReplacer.lsb_first(bytes, SIZE_OF_RAW_DATA_OFFSET)
		pointer_to_raw_data = IconReplacer.lsb_first(bytes, POINTER_TO_RAW_DATA_OFFSET)


class DataEntry:
	const RVA_OFFSET := 0
	const SIZE_OFFSET := 4

	var rva: int
	var size: int


	func _init(bytes: PackedByteArray) -> void:
		rva = IconReplacer.lsb_first(bytes, RVA_OFFSET)
		size = IconReplacer.lsb_first(bytes, SIZE_OFFSET)


class Icon:
	const IMAGE_COUNT_OFFSET := 0x4
	const IMAGES_OFFSET := 0x6
	const ICON_ENTRY_SIZE := 16
	const SIZE_OFFSET := 0x8
	const DATA_OFFSET := 0xc

	var images := {}


	func _init(bytes: PackedByteArray) -> void:
		var image_count := IconReplacer.lsb_first(bytes, IMAGE_COUNT_OFFSET, 2)
		var offset := IMAGES_OFFSET
		for i in image_count:
			var size := IconReplacer.lsb_first(bytes, offset + SIZE_OFFSET)
			var data_offset := IconReplacer.lsb_first(bytes, offset + DATA_OFFSET)
			images[size] = bytes.slice(data_offset, data_offset + size)
			offset += ICON_ENTRY_SIZE
