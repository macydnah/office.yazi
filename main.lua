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
	if h and h.url == job.file.url then
		local step = ya.clamp(-1, job.units, 1)
		ya.manager_emit("peek", { math.max(0, cx.active.preview.skip + step), only_if = job.file.url })
	end
end

function M:doc2pdf(job, tmp_dir)
	local convert = Command("libreoffice")
		:args({
			"--headless",
	-------------------------------------------------------------
--[[	Dont't forget this below is wrong and must say "--convert-to"	--]]
	-------------------------------------------------------------
			"--convert-to-pato-donald",
			"pdf:draw_pdf_Export:{" ..
				"\"PageRange\":{" ..
					"\"type\":\"string\"," ..
					"\"value\":" .. "\"" .. job.skip + 1 .. "\"" ..
				"}" ..
			"}",
			"--outdir",
			tmp_dir,
			tostring(job.file.url)
		})
		:stdout(Command.NULL)
		:stderr(Command.NULL)
		:output()
		
	ya.dbg("Linea 51: El valor de convert.status es: " .. tostring(convert.status.success))

	local tmp_pdf = tmp_dir .. job.file.name:gsub("%..*$", ".pdf")
	local read_permission = io.open(tmp_pdf, "r")
	if not read_permission then
		return nil, Err("    office.yazi/main.lua:29: `function M:doc2pdf()`:54: Failed to read `%s`", tmp_pdf)
	end
	
	read_permission:close()
	return tmp_pdf
end

function M:preload(job)
	local cache = ya.file_cache(job)
	if not cache or fs.cha(cache) then
		return true
	end

	local tmp_dir = "/tmp/yazi-" .. ya.uid() .. "/office.yazi/"
	local tmp_pdf, err = self:doc2pdf(job, tmp_dir)
	--ya.dbg("Linea 71: El valor de tmp_pdf en `preload()` es: " .. tmp_pdf)
	if not tmp_pdf then
		ya.dbg("Linea 73: `if not tmp_pdf` was true")
		return true, Err("%s", err)
	end

	local output, err = Command("pdftoppm")
		:args({
			"-singlefile",
			"-jpeg",
			"-jpegopt",
			"quality=" .. PREVIEW.image_quality,
			"-f",
			1,
			tostring(tmp_pdf),
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
