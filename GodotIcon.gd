extends Node

const CreateIcon := preload("res://CreateIcon.gd")
const ReplaceIcon := preload("res://ReplaceIcon.gd")

# TODO fix type
var icon_creator: CreateIcon.IconCreator
var icon_replacer: ReplaceIcon.IconReplacer
var image: Image
var headers: PackedByteArray
var resources: PackedByteArray


func _init() -> void:
	icon_creator = CreateIcon.IconCreator.new()
	icon_replacer = ReplaceIcon.IconReplacer.new()
	image = Image.create_from_data(1, 1, false, Image.FORMAT_RGBA8, PackedByteArray([0x12, 0x34, 0x56, 0xff]))
	var file := FileAccess.open("res://bin/headers.bin", FileAccess.READ)
	assert(file)
	headers = file.get_buffer(2048)
	file = FileAccess.open("res://bin/resources.bin", FileAccess.READ)
	assert(file)
	resources = file.get_buffer(360960)


func _ready():
	var methods = get_method_list()
	var method_names := []
	for method in methods:
		method_names.append(method.name)
	var base_methods = Node.new().get_method_list()
	for base_method in base_methods:
		method_names.erase(base_method.name)
	var test_methods = []
	for method_name in method_names:
		if method_name.begins_with("test_"):
			test_methods.append(method_name)
	var test_run_count := 0
	for test_method in test_methods:
		call(test_method)
		test_run_count += 1
		method_names.erase(test_method)
	print("Tests run: ", test_run_count, "\nMethods not run as tests: ", ", ".join(PackedStringArray(method_names)))
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()


func assert_equals(expected, actual) -> void:
	assert(expected == actual, str("Expected", expected, " but found ", actual))


func assert_array_equals(expected: Array, actual: Array) -> void:
	assert(expected.size() == actual.size(), str("Array sizes differ. Expected ", expected, " but found ", actual))
	for i in range(expected.size()):
		# TODO assert with error message
		assert(expected[i] == actual[i], str("Expected ", expected[i], " at index ", i, " but found ", actual[i], "\nE: ", expected, "\nA: ", actual))


func test_msb_first() -> void:
	assert_array_equals([0x4, 0x3, 0x2, 0x1], icon_creator.msb_first(0x04030201))


func test_lsb_first() -> void:
	assert_array_equals([0x1, 0x2, 0x3, 0x4], icon_creator.lsb_first(0x04030201))
	assert_array_equals([0x11, 0x22, 0x33, 0x44], icon_creator.lsb_first(0x44332211, 4))
	assert_array_equals([0xaa, 0xbb], icon_creator.lsb_first(0xddccbbaa, 2))


func test_block_size() -> void:
	assert_array_equals([0x2, 0x1, 0xfd, 0xfe], icon_creator.block_size(0x102))


func test_adler() -> void:
	assert_equals(0x1, icon_creator.adler(PackedByteArray([])))
	assert_equals(0x10001, icon_creator.adler(PackedByteArray([0x0])))
	assert_equals(0x20002, icon_creator.adler(PackedByteArray([0x1])))
	assert_equals(0x20001, icon_creator.adler(PackedByteArray([0x0, 0x0])))
	assert_equals(0x50003, icon_creator.adler(PackedByteArray([0x1, 0x1])))
	assert_equals(0x11e60398, icon_creator.adler(PackedByteArray([87, 105, 107, 105, 112, 101, 100, 105, 97]))) # Wikipedia


func test_crc() -> void:
	assert_equals(0xae426082, icon_creator.crc(PackedByteArray([0x49, 0x45, 0x4e, 0x44]))) # IEND


func test_filtered_pixels() -> void:
	assert_array_equals([0x0, 0x1, 0x2, 0x3, 0x4], icon_creator.filtered_pixels(1, 1, PackedByteArray([0x1, 0x2, 0x3, 0x4])))
	assert_array_equals([0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8], icon_creator.filtered_pixels(2, 1, PackedByteArray([0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8])))
	assert_array_equals([0x0, 0x1, 0x2, 0x3, 0x4, 0x0, 0x5, 0x6, 0x7, 0x8], icon_creator.filtered_pixels(1, 2, PackedByteArray([0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8])))


func test_generate_end_chunk() -> void:
	assert_array_equals([0x49, 0x45, 0x4e, 0x44], icon_creator.generate_end_chunk())


func test_generate_header_chunk() -> void:
	assert_array_equals([0x49, 0x48, 0x44, 0x52, 0x0, 0x0, 0x0, 0x1, 0x0, 0x0, 0x0, 0x1, 0x8, 0x6, 0x0, 0x0, 0x0], icon_creator.generate_header_chunk(1, 1))
	assert_array_equals([0x49, 0x48, 0x44, 0x52, 0x0, 0x0, 0x1, 0x0, 0x0, 0x0, 0x2, 0x0, 0x8, 0x6, 0x0, 0x0, 0x0], icon_creator.generate_header_chunk(256, 512))


func test_generate_data_chunk() -> void:
	assert_array_equals([0x49, 0x44, 0x41, 0x54, 0x78, 0x01, 0x1, 0x5, 0x0, 0xfa, 0xff, 0x0, 0x12, 0x34, 0x56, 0xff, 0x2, 0x94, 0x1, 0x9c], icon_creator.generate_data_chunk(image))


func test_generate_chunk() -> void:
	assert_array_equals([0x0, 0x0, 0x0, 0x0, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82], icon_creator.generate_chunk(icon_creator.generate_end_chunk()))


func test_generate_png() -> void:
	var expected = [
		0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
		0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4,
		0x89, 0x00, 0x00, 0x00, 0x10, 0x49, 0x44, 0x41, 0x54, 0x78, 0x01, 0x01, 0x05, 0x00, 0xfa, 0xff,
		0x00, 0x12, 0x34, 0x56, 0xff, 0x02, 0x94, 0x01, 0x9c, 0xd7, 0x04, 0xca, 0xbd, 0x00, 0x00, 0x00,
		0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82
	] 
	assert_array_equals(expected, icon_creator.generate_png(image))


func test_generate_icon_header() -> void:
	assert_array_equals([0x0, 0x0, 0x1, 0x0, 0x1, 0x0], icon_creator.generate_icon_header(1))
	assert_array_equals([0x0, 0x0, 0x1, 0x0, 0x6, 0x0], icon_creator.generate_icon_header(6))


func test_generate_icon_entry() -> void:
	assert_array_equals([0x1, 0x1, 0x0, 0x0, 0x0, 0x0, 0x20, 0x0, 0x4, 0x3, 0x2, 0x1, 0x8, 0x7, 0x6, 0x5], icon_creator.generate_icon_entry(image, 0x01020304, 0x05060708))


func test_generate_icon() -> void:
	# TODO fix type infering
	var header: PackedByteArray = icon_creator.generate_icon_header(1)
	var png: PackedByteArray = icon_creator.generate_png(image)
	var entry: PackedByteArray = icon_creator.generate_icon_entry(image, png.size(), 22)
	var expected := PackedByteArray()
	expected.append_array(header)
	expected.append_array(entry)
	expected.append_array(png)
	assert_array_equals(expected, icon_creator.generate_icon([image]))


func test_generate_icon_size() -> void:
	var images := []
	var zlib_streams_size := 0
	for size in [16, 32, 48, 64, 128, 256]:
		var scaled_image := Image.new()
		scaled_image.copy_from(image)
		scaled_image.resize(size, size)
		images.append(scaled_image)
		zlib_streams_size += zlib_stream_size(size)
	# icon header + 6 * (icon entries + PNG signatures + IHDR chunks + IDAT chunks + IEND chunks) + zlib_streams
	var expected = 6 + 6 * (16 + 8 + 25 + 12 + 12) + zlib_streams_size
	assert_equals(expected, icon_creator.generate_icon(images).size())


func test_zlib_stream_size() -> void:
	assert_equals(2 + 5 + (2 * 2 * 4 + 2) + 4, zlib_stream_size(2))


func test_ir_lsb_first() -> void:
	assert_equals(0x0201, ReplaceIcon.IconReplacer.lsb_first(PackedByteArray([0x01, 0x02, 0x03, 0x04]), 0, 2))
	assert_equals(0x0403, ReplaceIcon.IconReplacer.lsb_first(PackedByteArray([0x01, 0x02, 0x03, 0x04]), 2, 2))
	assert_equals(0x04030201, ReplaceIcon.IconReplacer.lsb_first(PackedByteArray([0x01, 0x02, 0x03, 0x04]), 0))


func test_replace() -> void:
	var bytes := PackedByteArray([0x0, 0x1, 0x2, 0x3, 0x4])
	var replacement := PackedByteArray([0x11, 0x12])
	bytes = ReplaceIcon.IconReplacer.replace(bytes, replacement, 2)
	assert_array_equals([0x0, 0x1, 0x11, 0x12, 0x4], bytes)


func test_find_resources_section_entry() -> void:
	var section_entry = icon_replacer.find_resources_section_entry(headers)
	assert_equals(0x1d2f000, section_entry.virtual_address)
	assert_equals(0x58200, section_entry.size_of_raw_data)
	assert_equals(0x1d17000, section_entry.pointer_to_raw_data)


func test_find_data_entries() -> void:
	# TODO fix type infering
	var data_entries: Array = icon_replacer.find_data_entries(resources)
	for data_entry in data_entries:
		assert(data_entry.size in [804, 1108, 4196, 9332, 16521, 65752, 262548])


func test_find_icon_offset() -> void:
	var data_entries := [ReplaceIcon.DataEntry.new(PackedByteArray([2, 2, 0, 0, 0, 0x1, 0, 0]))]
	# TODO assert with error message
	assert(0x100 == icon_replacer.find_icon_offset(data_entries, 0x100, 0x102))


func test_has_data_entry_with_size() -> void:
	var data_entries := [ReplaceIcon.DataEntry.new(PackedByteArray([0, 0, 0, 0, 0, 0x1, 0, 0]))]
	assert(has_data_entry_with_size(data_entries, 0x100))
	assert(not has_data_entry_with_size(data_entries, 0))


func test_replace_icons() -> void:
	var file := FileAccess.open("res://image/djbird.ico", FileAccess.READ)
	assert(file)
	var images := ReplaceIcon.Icon.new(file.get_buffer(ReplaceIcon.ICON_SIZE)).images
	assert(images.size() == 6)
	# TODO fix type infering
	var resources_section_entry: ReplaceIcon.SectionEntry = icon_replacer.find_resources_section_entry(headers)
	resources = icon_replacer.replace_icons(resources, resources_section_entry.virtual_address, images)
	assert_array_equals(images[1108], resources.slice(0x1f0, 0x1f0 + 1108))


func test_create_icon_error_handling() -> void:
	var error_message = "Create icon test error message!"
	var error_handler := ErrorHandler.new()
	var create_icon := CreateIcon.new()
	create_icon.error_callable = error_handler.handle
	create_icon.print_error(error_message)
	assert_equals(error_message, error_handler.error_message)


func test_replace_icon_error_handling() -> void:
	var error_message = "Replace icon test error message!"
	var error_handler := ErrorHandler.new()
	var replace_icon := ReplaceIcon.new()
	replace_icon.error_callable = error_handler.handle
	replace_icon.print_error(error_message)
	assert_equals(error_message, error_handler.error_message)


func test_icon_replacer_error_handling() -> void:
	var error_message = "Icon replacer test error message!"
	var error_handler := ErrorHandler.new()
	icon_replacer.error_callable = error_handler.handle
	icon_replacer.print_error(error_message)
	assert_equals(error_message, error_handler.error_message)


func has_data_entry_with_size(data_entries: Array, size: int) -> bool:
	for data_entry in data_entries:
		if data_entry.size == size:
			return true
	return false


func zlib_stream_size(size: int) -> int:
	var filtered_pixels_size := size * size * 4 + size
	@warning_ignore("integer_division")
	var block_count: int = filtered_pixels_size / icon_creator.ZLIB_BLOCK_SIZE
	if filtered_pixels_size % icon_creator.ZLIB_BLOCK_SIZE:
		block_count += 1
	return 2 + filtered_pixels_size + 5 * block_count + 4 # CMF+FLG + data + 5 * (chunk_block_size + chunk_final_flag) + adler



class ErrorHandler:
	var error_message: String


	func handle(_error_message) -> void:
		error_message = _error_message
