--- @since 25.2.7

local M = {}

function M:peek(job)
	local start, cache = os.clock(), ya.file_cache(job)
	if not cache then
		return
	end

	local ok, err = self:preload(job)
	if not ok or err then
		return
	end

	ya.sleep(math.max(0, PREVIEW.image_delay / 1000 + start - os.clock()))
	ya.image_show(cache, job.area)
	ya.preview_widgets(job, {})
end

function M:seek(job)
	local h = cx.active.current.hovered
	ya.dbg("Linea 23")
	ya.dbg("El url de cx.active.current.hovered es: " .. tostring(h.url))
	if h and h.url == job.file.url then
		local step = ya.clamp(-1, job.units, 1)
		ya.dbg("Linea 27")
		ya.dbg("El valor de los `steps` es: " .. tostring(step))
		ya.dbg("Linea 29")
		ya.dbg("El valor de cx.active.preview.skip es: " .. tostring(cx.active.preview.skip))
		ya.dbg("Linea 31")
		ya.dbg("El valor de `math.max(cx.active.preview.skip + step)` es: " .. math.max(0, cx.active.preview.skip + step))
		ya.manager_emit("peek", { math.max(0, cx.active.preview.skip + step), only_if = job.file.url })
	end
end

function M:document_to_pdf(job)
--[[
	if ya.target_family() = "unix" then
		local user_id = ya.uid()
	end
--]]
	local tmp = "/tmp/yazi-" .. ya.uid() .. "/office.yazi/"
	ya.dbg("Linea 44: el valor de `tmp` es: " .. tmp)
	local pdf_file = tmp .. job.file.name:gsub("%..*$", ".pdf")
	ya.dbg("Linea 46")
	ya.dbg("El valor de `job.skip + 1` es: " .. job.skip + 1)

	local read_permissions = io.open(pdf_file, "r")
	if read_permissions then
		ya.dbg("Linea 51: si hay permisos de lectura")
		read_permissions:close()
	end

	ya.dbg("Linea 55")
	ya.dbg(tostring(job.file.url))
	local convert = Command("libreoffice")
		:args({
			"--headless",
			"--convert-to",
			"pdf:draw_pdf_Export:{" ..
				"\"PageRange\":{" ..
					"\"type\":\"string\"," ..
					"\"value\":" .. "\"" .. job.skip + 1 .. "\"" ..
				"}" ..
			"}",
			"--outdir",
			tmp,
			tostring(job.file.url)
		})
		:stdout(Command.NULL)
		:stderr(Command.NULL)
		:output()
	
	return pdf_file
end

function M:preload(job)
	local cache = ya.file_cache(job)
	ya.dbg("Linea 80")
	ya.dbg(tostring(cache))
	if not cache or fs.cha(cache) then
		return true
	end

	local pdf_file = self:document_to_pdf(job)
	local output, err = Command("pdftoppm")
		:args({
			"-singlefile",
			"-jpeg",
			"-jpegopt",
			"quality=" .. PREVIEW.image_quality,
			"-f",
			1,
			tostring(pdf_file),
		})
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:output()

	if not output then
		return true, Err("Failed to start `pdftoppm`, error: %s", err)
	elseif not output.status.success then
		local pages = tonumber(output.stderr:match("the last page %((%d+)%)")) or 0
		if job.skip > 0 and pages > 0 then
			ya.manager_emit("peek", { math.max(0, pages - 1), only_if = job.file.url, upper_bound = true })
		end
		return true, Err("Failed to convert PDF to image, stderr: %s", output.stderr)
	end

	return fs.write(cache, output.stdout)
end

return M
