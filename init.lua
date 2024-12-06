local M = {}

function M:peek()
	local start, cache = os.clock(), ya.file_cache(self)
	if not cache or self:preload() ~= 1 then
		return
	end

	ya.sleep(math.max(0, PREVIEW.image_delay / 1000 + start - os.clock()))
	ya.image_show(cache, self.area)
end

function M:seek() end

function M:document_to_pdf()
	local tmp_dir = "/tmp/"
	local pdf_file = tmp_dir .. self.file.name:gsub("%..*$", ".pdf")

	read_perm = io.open(pdf_file, "r")
	if read_perm then
		read_perm:close()
	else
		local convert = Command("libreoffice"):args({
				"--headless",
				"--convert-to",
				"pdf:draw_pdf_Export:{\"PageRange\":{\"type\":\"string\",\"value\":\"1\"}}",
				"--outdir",
				tmp_dir,
				tostring(self.file.url)
			})
			:stdout(Command.NULL)
			:stderr(Command.NULL)
			:output()
	end

	return pdf_file
end

function M:preload()
	local cache = ya.file_cache(self)
	if not cache or fs.cha(cache) then
		local cha, err = fs.cha(cache)
		return 1
	end

	local pdf_file = self:document_to_pdf()
	local output = Command("pdftoppm")
		:args({ "-singlefile", "-jpeg", "-jpegopt", "quality=75", "-f", tostring(self.skip + 1), tostring(pdf_file) })
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:output()

	if not output then
		return 0
	elseif not output.status.success then
		local pages = tonumber(output.stderr:match("the last page %((%d+)%)")) or 0
		if self.skip > 0 and pages > 0 then
			ya.manager_emit("peek", { math.max(0, pages - 1), only_if = self.file.url, upper_bound = true })
		end
		return 0
	end

	return fs.write(cache, output.stdout) and 1 or 2
end

return M
