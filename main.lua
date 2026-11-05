--- @since 25.2.7

local M = {}

local is_hovered = ya.sync(function(_, url)
	local h = cx.active.current.hovered
	return h and tostring(h.url) == url
end)

function M:peek(job)
	local start, cache = os.clock(), ya.file_cache(job)
	if not cache then
		return
	end

	local ok, err = self:preload(job)
	if not ok or err then
		return
	end

	ya.sleep(math.max(0, rt.preview.image_delay / 1000 + start - os.clock()))
	ya.image_show(cache, job.area)
	if ya.preview_widgets then
		ya.preview_widgets(job, {})
	end
end

function M:seek(job)
	local h = cx.active.current.hovered
	if h and h.url == job.file.url then
		local step = ya.clamp(-1, job.units, 1)
		ya.manager_emit("peek", { math.max(0, cx.active.preview.skip + step), only_if = job.file.url })
	end
end

function M:doc2pdf(job)
	local cache_home = os.getenv("XDG_CACHE_HOME")
	if not cache_home or cache_home == "" then
		local home = os.getenv("HOME")
		cache_home = home and (home .. "/.cache") or "/tmp"
	end
	-- Use one Yazi-only LibreOffice profile so conversions cannot attach to the
	-- desktop session, while still letting LibreOffice serialize concurrent
	-- requests through one instance. Keep output unique to avoid same-basename
	-- collisions (such as report.odt and report.ods).
	local root = cache_home .. "/yazi-office-" .. ya.uid() .. "/"
	local outdir = root .. "output/" .. ya.hash(tostring(job.file.url) .. tostring({})) .. "/"
	local profile = root .. "profile/"
	fs.create("dir_all", Url(outdir))
	fs.create("dir_all", Url(profile))

	-- LibreOffice expects UserInstallation to be a URL, not a filesystem path.
	local profile_url = "file://" .. profile:gsub("([^%w%-%._~/])", function(c)
		return string.format("%%%02X", string.byte(c))
	end)

	--[[	For Future Reference: Regarding `libreoffice` as preconverter
	  1. It prints errors to stdout (always, doesn't matter if it succeeded or it failed)
	  2. Always writes the converted files to the filesystem, so no "Mario|Bros|Piping|Magic" for the data stream (https://ask.libreoffice.org/t/using-convert-to-output-to-stdout/38753)
	  3. Plain `pdf` lets LibreOffice choose the correct export filter for the input file type. --]]
	local libreoffice, err = Command("libreoffice")
		:arg({
			"-env:UserInstallation=" .. profile_url,
			"--headless",
			"--norestore",
			"--nodefault",
			"--convert-to",
			"pdf",
			"--outdir",
			outdir,
			tostring(job.file.url),
		})
		:stdin(Command.NULL)
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:output()

	if not libreoffice then
		fs.remove("dir_all", Url(outdir))
		return nil, Err("Failed to start LibreOffice: %s", err)
	elseif not libreoffice.status.success then
		local output = libreoffice.stdout .. libreoffice.stderr
		local version = (output:match("LibreOffice .+") or ""):gsub("%\n.*", "")
		local error = (output:match("Error:? .+") or ""):gsub("%\n.*", "")
		if version ~= "" or error ~= "" then
			ya.err((version or "LibreOffice") .. " " .. (error or "Unknown error"))
		end
		fs.remove("dir_all", Url(outdir))
		return nil, Err("Failed to preconvert `%s` to a temporary PDF", job.file.name)
	end

	local tmp = outdir .. job.file.name:gsub("%.[^%.]+$", ".pdf")
	local read_permission = io.open(tmp, "r")
	if not read_permission then
		fs.remove("dir_all", Url(outdir))
		return nil, Err("Failed to read `%s`: make sure file exists and have read access", tmp)
	end
	read_permission:close()

	return tmp, outdir
end

function M:preload(job)
	-- Yazi invokes preloaders for every matching file on the visible page. Only
	-- convert the hovered file, even when office is accidentally configured as a
	-- preloader, to avoid a burst of LibreOffice processes.
	if not is_hovered(tostring(job.file.url)) then
		return true
	end

	local cache = ya.file_cache(job)
	if not cache or fs.cha(cache) then
		return true
	end

	local tmp_pdf, tmp_outdir_or_err = self:doc2pdf(job)
	if not tmp_pdf then
		return true, Err("    " .. "%s", tmp_outdir_or_err)
	end

	local output, err = Command("pdftoppm")
		:arg({
			"-singlefile",
			"-jpeg",
			"-jpegopt",
			"quality=" .. rt.preview.image_quality,
			"-f",
			1,
			tostring(tmp_pdf),
		})
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:output()

	local cleaned, clean_err = fs.remove("dir_all", Url(tmp_outdir_or_err))
	if not cleaned then
		return true, Err("Failed to remove %s, error: %s", tmp_outdir_or_err, clean_err)
	end

	if not output then
		return true, Err("Failed to start `pdftoppm`, error: %s", err)
	elseif not output.status.success then
		local pages = tonumber(output.stderr:match("the last page %((%d+)%)")) or 0
		if job.skip > 0 and pages > 0 then
			ya.mgr_emit("peek", { math.max(0, pages - 1), only_if = job.file.url, upper_bound = true })
		end
		return true, Err("Failed to convert %s to image, stderr: %s", tmp_pdf, output.stderr)
	end

	return fs.write(cache, output.stdout)
end

return M
