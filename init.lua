local M = {}

function M:peek()
	local start, cache = os.clock(), ya.file_cache(self)
	if not cache or self:preload() ~= 1 then
		ya.err("linea 6: aki que sucede??")
		return
	end

	ya.err("linea 10: aki que sucede??")
	ya.sleep(math.max(0, PREVIEW.image_delay / 1000 + start - os.clock()))
	ya.image_show(cache, self.area)
	ya.preview_widgets(self, {})
end

function M:seek() end

-- Nueva función para convertir DOCX a PDF
function M:convert_to_pdf()
	-- Especificar directorio de salida del archivo PDF intermedio
	local tmp_dir = "/tmp/"
	-- Construimos el nombre del archivo PDF intermedio
	local pdf_file = tmp_dir .. self.file.name:gsub("%.docx$", ".pdf")
	-- Verificamos la existencia del archivo y su lectura
	file = io.open(pdf_file, "r")

	if file then
		file:close()
		ya.err("El archivo PDF ya existía en: " .. tostring(pdf_file))
		-- Devolvemos el URL del PDF generado
		return pdf_file
	else
		-- Si no existe, convertir el archivo DOCX a PDF
		local cmd = "libreoffice --headless --convert-to pdf --outdir " .. tmp_dir .. " " .. tostring(self.file.url)
		result = os.execute(cmd)
		-- Devolvemos el URL del PDF generado
		return pdf_file
	end
--[[
	local office_to_pdf = Command("libreoffice")
		:args({ "--headless", "--convert-to pdf", "--outdir", tmp_dir, tostring(self.file.url) })
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:output()
--]]

end


function M:preload()
	local cache = ya.file_cache(self)
	ya.err("El ya.file_cache es :" .. tostring(cache))

	if not cache or fs.cha(cache) then
		ya.err("Por alguna razón inexplicable esta condición se cumple.")
	end

	local pdf_file = self:convert_to_pdf()
	local output = Command("pdftoppm")
		-- :args({ "-singlefile", "-jpeg", "-jpegopt", "quality=75", "-f", tostring(self.skip + 1), tostring(self.file.url:gsub("%.docx$", ".pdf")) })
		:args({ "-singlefile", "-jpeg", "-jpegopt", "quality=75", "-f", tostring(self.skip + 1), tostring(pdf_file) })
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:output()


	ya.err("esto si quiera llega a ejecutarse??")
	ya.err("El segundo ya.file_cache es :" .. tostring(cache))
	return fs.write(cache, output.stdout) and 1 or 2
end

return M
